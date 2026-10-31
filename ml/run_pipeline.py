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
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
PY = sys.executable


def run(args, log: Path):
    log.parent.mkdir(parents=True, exist_ok=True)
    print(f"[pipeline] {' '.join(args)}  > {log}", flush=True)
    env = dict(os.environ, PYTHONUNBUFFERED="1")
    with open(log, "a", encoding="utf-8") as f:
        code = subprocess.call([PY, "-I", *args], stdout=f, stderr=subprocess.STDOUT,
                               cwd=HERE.parent, env=env)
    if code != 0:
        sys.exit(f"[pipeline] stage failed ({code}); see {log}")


def builder_running():
    out = subprocess.run(
        ["powershell", "-NoProfile", "-c",
         "(Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | "
         "Where-Object { $_.CommandLine -like '*build_off.py*' }).Count"],
        capture_output=True, text=True)
    return out.stdout.strip() not in ("", "0")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--runs", type=Path, required=True)
    ap.add_argument("--name", default="v2")
    ap.add_argument("--teacher-name", default=None)
    ap.add_argument("--teacher-model", default=None)
    ap.add_argument("--backbone", default="mobilenetv3_large_100.ra_in1k")
    ap.add_argument("--epochs", type=int, default=14)
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
    if (out / "last.pt").exists():
        train += ["--resume", str(out / "last.pt")]
    run(train, logs / f"train_{a.name}.log")

    run(["ml/export_tflite.py", "--checkpoint", str(out / "best.pt"), "--data", str(a.data),
         "--work", str(out / "export")], logs / f"export_{a.name}.log")
    print("[pipeline] done", flush=True)


if __name__ == "__main__":
    main()
