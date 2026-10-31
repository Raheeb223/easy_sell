"""Runs the whole EasySell Vision build unattended, one stage after another:

  1. wait for build_off.py to finish packing the product photos;
  2. compute the teacher's embeddings (embed_teacher.py);
  3. train the phone model with distillation (train_v2.py);
  4. export the best checkpoint to assets/models (export_tflite.py).

Each stage is skipped when its output already exists, so the pipeline can be
started again after any interruption. Logs go to <runs>/logs/.

    python -I ml/run_pipeline.py --data G:/Easy_sell/ml_data --runs G:/Easy_sell/ml_runs \
        --teacher-name siglip --teacher-model vit_base_patch16_siglip_224.webli
"""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
PY = sys.executable


def run(args, log: Path, check=True):
    log.parent.mkdir(parents=True, exist_ok=True)
    print(f"[pipeline] {' '.join(args)}  > {log}", flush=True)
    env = dict(os.environ, PYTHONUNBUFFERED="1")
    with open(log, "a", encoding="utf-8") as f:
        code = subprocess.call([PY, "-I", *args], stdout=f, stderr=subprocess.STDOUT,
                               cwd=HERE.parent, env=env)
    if code != 0 and check:
        sys.exit(f"[pipeline] stage failed ({code}); see {log}")
    return code


def builder_running():
    out = subprocess.run(
        ["powershell", "-NoProfile", "-c",
         "(Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | "
         "Where-Object { $_.CommandLine -like '*build_off.py*' }).Count"],
        capture_output=True, text=True)
    return out.stdout.strip() not in ("", "0")


def bench(ckpt: Path) -> float:
    """Mean shop200 top-1 on the fixed benchmarks (RP2K, Grocery). The OFF
    held-out set depends on a run's packs, so runs are compared without it."""
    import torch
    res = torch.load(ckpt, map_location="cpu", weights_only=False)["res"]
    fixed = [r["shop"][0] for k, r in res.items() if k != "off_heldout"]
    return sum(fixed) / len(fixed)


def shipped_bench(runs: Path, name: str):
    """Score of the model now in the app: shipped.json, or else the best run
    that already has an exported model (runs from before shipped.json)."""
    rec = runs / "shipped.json"
    if rec.exists():
        return json.loads(rec.read_text())["bench"]
    done = [d for d in runs.iterdir() if d.name != name and list(d.glob("export/*.tflite"))]
    return max((bench(d / "best.pt") for d in done if (d / "best.pt").exists()), default=None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--runs", type=Path, required=True)
    ap.add_argument("--name", default="v2")
    ap.add_argument("--teacher-name", default=None)
    ap.add_argument("--teacher-model", default=None)
    ap.add_argument("--backbone", default="mobilenetv3_large_100.ra_in1k")
    ap.add_argument("--epochs", type=int, default=14)
    ap.add_argument("--batch", type=int, default=192)
    ap.add_argument("--packs", nargs="+", default=["off_index", "grocery_train_index"])
    ap.add_argument("--wait-download", action="store_true",
                    help="wait for a running build_off.py first")
    a = ap.parse_args()
    logs = a.runs / "logs"
    packs = a.packs

    while a.wait_download and builder_running():
        print("[pipeline] waiting for the photo download to finish...", flush=True)
        time.sleep(120)

    # One teacher file per run: it is indexed by the run's own pack order.
    tname = f"{a.teacher_name}_{a.name}" if a.teacher_name else None
    if tname:
        t = a.data / f"teacher_{tname}.npy"
        if not t.exists():
            run(["ml/embed_teacher.py", "--data", str(a.data), "--name", tname,
                 "--model", a.teacher_model, "--packs", *packs], logs / f"teacher_{a.name}.log")

    out = a.runs / a.name
    train = ["ml/train_v2.py", "--data", str(a.data), "--out", str(out),
             "--packs", *packs, "--backbone", a.backbone, "--epochs", str(a.epochs)]
    if a.teacher_name:
        train += ["--teacher", tname]
    # Bigger datasets mean a bigger product head; if the GPU runs out of
    # memory, carry on with a smaller batch rather than stopping.
    log, batch = logs / f"train_{a.name}.log", a.batch
    while True:
        resume = ["--resume", str(out / "last.pt")] if (out / "last.pt").exists() else []
        code = run(train + ["--batch", str(batch), *resume], log, check=False)
        if code == 0:
            break
        tail = log.read_text(encoding="utf-8", errors="replace")[-4000:]
        if "out of memory" not in tail or batch <= 96:
            sys.exit(f"[pipeline] stage failed ({code}); see {log}")
        batch -= 32
        print(f"[pipeline] GPU out of memory; retrying with batch {batch}", flush=True)

    # Only replace the app's model with a better one.
    score, current = bench(out / "best.pt"), shipped_bench(a.runs, a.name)
    print(f"[pipeline] {a.name} bench {score:.4f}, shipped {current}", flush=True)
    if current is not None and score <= current:
        print("[pipeline] not better than the shipped model; keeping it", flush=True)
        return
    run(["ml/export_tflite.py", "--checkpoint", str(out / "best.pt"), "--data", str(a.data),
         "--work", str(out / "export")], logs / f"export_{a.name}.log")
    (a.runs / "shipped.json").write_text(json.dumps({"run": a.name, "bench": score}))
    print("[pipeline] done", flush=True)


if __name__ == "__main__":
    main()
