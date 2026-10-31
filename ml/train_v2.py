"""EasySell Vision v2: big-data, distilled training.

Student: a phone-sized backbone (MobileNetV3-L by default), 256-d embedding.
Signals:
  * ArcFace on product identity (Open Food / Beauty / Products Facts, plus
    Grocery Store for loose produce) -- commercially licensed data only;
  * relational distillation from a big teacher trained on billions of images
    (SigLIP / DINOv2, Apache-2.0): within each batch the student's
    photo-to-photo similarities are pulled toward the teacher's. The teacher's
    embeddings are precomputed once (embed_teacher.py) on clean images; the
    student sees augmented shop-like views, so it also learns invariance.

Data is streamed from packed files in large sequential blocks (hard disk).

    python -I ml/train_v2.py --data G:/Easy_sell/ml_data --out G:/Easy_sell/ml_runs/v2 \
        --packs off_index grocery_train_index --teacher siglip
"""
import argparse
import json
import queue
import threading
import math
import random
import sys
import time
from collections import Counter
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from torch.utils.data import DataLoader

sys.path.insert(0, str(Path(__file__).parent))
from embedder import ArcFace, Embedder, train_transform  # noqa: E402
from eval_fewshot import embed_entries, evaluate, fewshot, fmt  # noqa: E402
from gpu_aug import train_batch  # noqa: E402
from packs import Pack, PackStream, collate_raw, entries_of  # noqa: E402


def gpu_batches(dl, dev):
    """Decodes + augments the NEXT batch on its own CUDA stream in a thread
    while the current one trains (nvJPEG does part of its work on the CPU)."""
    q = queue.Queue(maxsize=3)
    stream = torch.cuda.Stream()

    def work():
        try:
            for x, y, gi in dl:
                with torch.cuda.stream(stream):
                    xb = train_batch(x, dev)
                    yb = y.to(dev, non_blocking=True)
                    ev = torch.cuda.Event()
                    ev.record(stream)
                q.put((xb, yb, gi, ev))
        finally:
            q.put(None)

    threading.Thread(target=work, daemon=True).start()
    while (item := q.get()) is not None:
        xb, yb, gi, ev = item
        torch.cuda.current_stream().wait_event(ev)
        xb.record_stream(torch.cuda.current_stream())
        yb.record_stream(torch.cuda.current_stream())
        yield xb, yb, gi


def load_teacher(path: Path, dev, max_bytes=1.5e9, dim=256):
    """Teacher embeddings on the GPU. When they are too big to sit next to the
    model (millions of photos), keep only their top `dim` directions: the KD
    loss uses photo-to-photo similarities, which these preserve."""
    t = np.load(path, mmap_mode="r")
    if t.shape[0] * t.shape[1] * 2 <= max_bytes:
        return torch.from_numpy(t[:]).to(dev).half()
    chunks = range(0, t.shape[0], 200_000)
    gram = torch.zeros(t.shape[1], t.shape[1], device=dev, dtype=torch.float64)
    for s in chunks:
        x = F.normalize(torch.from_numpy(t[s:s + 200_000].astype(np.float32)).to(dev), dim=1)
        gram += (x.T @ x).double()
    vals, vecs = torch.linalg.eigh(gram)
    keep = vecs[:, -dim:].float()
    print(f"teacher reduced {t.shape[1]} -> {dim} dims, keeping "
          f"{vals[-dim:].sum().item() / vals.sum().item():.1%} of its energy", flush=True)
    out = torch.empty(t.shape[0], dim, device=dev, dtype=torch.half)
    for s in chunks:
        x = F.normalize(torch.from_numpy(t[s:s + 200_000].astype(np.float32)).to(dev), dim=1)
        out[s:s + len(x)] = (x @ keep).half()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--packs", nargs="+", default=["off_index", "grocery_train_index"])
    ap.add_argument("--backbone", default="mobilenetv3_large_100.ra_in1k")
    ap.add_argument("--teacher", default=None, help="name used by embed_teacher.py")
    ap.add_argument("--kd", type=float, default=1.0)
    ap.add_argument("--epochs", type=int, default=10)
    ap.add_argument("--batch", type=int, default=192)
    ap.add_argument("--lr", type=float, default=2e-3)
    ap.add_argument("--holdout", type=int, default=1000)
    ap.add_argument("--workers", type=int, default=3)
    ap.add_argument("--cpu-aug", action="store_true", help="augment on the CPU (old path)")
    ap.add_argument("--resume", type=Path)
    ap.add_argument("--max-steps", type=int, default=0, help="smoke test: stop each epoch early")
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    torch.manual_seed(0)
    torch.backends.cudnn.benchmark = True
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True
    dev = "cuda"

    packs = [Pack(a.data, s) for s in a.packs]
    counts = Counter(l for p in packs for l in p.labels)
    usable = sorted(l for l, n in counts.items() if n >= 2)
    rng = random.Random(0)
    pool = [l for l in usable if l.startswith(("food:", "beauty:", "products:"))]
    held = set(rng.sample(pool, min(a.holdout, len(pool) // 20)))
    train_labels = [l for l in usable if l not in held]
    ids = {l: i for i, l in enumerate(train_labels)}
    held_ids = {l: i for i, l in enumerate(sorted(held))}

    entries, held_entries, base = [], [], 0
    for p in packs:
        entries += entries_of(p, set(train_labels), ids, base)
        held_entries += entries_of(p, held, held_ids, base)
        base += len(p)
    print(f"train: {len(entries)} images, {len(ids)} products; held-out products: {len(held)}", flush=True)

    teacher = None
    if a.teacher:
        tpath = a.data / f"teacher_{a.teacher}.npy"
        teacher = load_teacher(tpath, dev)
        print(f"teacher {a.teacher}: {tuple(teacher.shape)}", flush=True)

    # GPU path: workers only read JPEG bytes; nvJPEG + gpu_aug do the rest.
    ds = PackStream(entries, train_transform() if a.cpu_aug else None)
    dl = DataLoader(ds, batch_size=a.batch, num_workers=a.workers, pin_memory=a.cpu_aug,
                    drop_last=True, persistent_workers=True, prefetch_factor=4,
                    collate_fn=None if a.cpu_aug else collate_raw)
    model = Embedder(a.backbone).to(dev).to(memory_format=torch.channels_last)
    head = ArcFace(model.proj.out_features, len(ids)).to(dev)
    opt = torch.optim.AdamW([
        {"params": model.backbone.parameters(), "lr": a.lr * 0.5},
        {"params": list(model.proj.parameters()) + list(model.bn.parameters()), "lr": a.lr},
        {"params": head.parameters(), "lr": a.lr * 10, "weight_decay": 0},
    ], weight_decay=5e-5)
    base_lr = [g["lr"] for g in opt.param_groups]
    steps_per_epoch = len(entries) // a.batch
    total = a.epochs * steps_per_epoch
    warm = min(steps_per_epoch, 2000)
    start_ep = 0
    if a.resume:
        ck = torch.load(a.resume, map_location="cpu")
        model.load_state_dict(ck["model"])
        head.load_state_dict(ck["head"])
        opt.load_state_dict(ck["opt"])
        start_ep = ck["epoch"] + 1

    best, log, step = -1.0, [], start_ep * steps_per_epoch
    for ep in range(start_ep, a.epochs):
        ds.set_epoch(ep)
        model.train()
        # Loss totals stay on the GPU: .item() every step would stall it.
        t0 = t_win = time.time()
        run_ce = torch.zeros((), device=dev)
        run_kd = torch.zeros((), device=dev)
        batches = dl if a.cpu_aug else gpu_batches(dl, dev)
        for i, (x, y, gi) in enumerate(batches):
            f = step / warm if step < warm else 0.5 * (1 + math.cos(math.pi * (step - warm) / max(1, total - warm)))
            for g, b in zip(opt.param_groups, base_lr):
                g["lr"] = b * f
            if a.cpu_aug:
                x = x.to(dev, non_blocking=True).to(memory_format=torch.channels_last)
                y = y.to(dev, non_blocking=True)
            with torch.autocast("cuda", dtype=torch.bfloat16):
                emb = model(x)
            emb = emb.float()
            with torch.autocast("cuda", dtype=torch.bfloat16):
                loss = ce = head(emb, y)
            if teacher is not None:
                t = F.normalize(teacher[gi.to(dev)].float(), dim=1)
                tau = 0.05
                mask = torch.eye(len(t), device=dev, dtype=torch.bool)
                ts = (t @ t.T / tau).masked_fill(mask, -1e4)
                ss = (emb @ emb.T / tau).masked_fill(mask, -1e4)
                kd = F.kl_div(F.log_softmax(ss, 1), F.softmax(ts, 1), reduction="batchmean")
                loss = ce + a.kd * kd
                run_kd += kd.detach()
            opt.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            opt.step()
            run_ce += ce.detach()
            step += 1
            if a.max_steps and i + 1 >= a.max_steps:
                break
            if i % 200 == 0:
                # Speed over the last 200 steps (worker start-up excluded).
                now = time.time()
                rate = 200 * a.batch / (now - t_win) if i else 0
                t_win = now
                print(f"ep {ep} it {i}/{steps_per_epoch} ce {run_ce.item() / (i + 1):.3f} "
                      f"kd {run_kd.item() / (i + 1):.3f} {rate:.0f} img/s", flush=True)

        res = evaluate(model, a.data, dev)
        if held_entries:
            e, ys = embed_entries(model, held_entries, dev)
            res["off_heldout"] = fewshot(e, ys)
        score = sum(r["shop"][0] for r in res.values()) / len(res)
        print(f"== epoch {ep} ({(time.time() - t0) / 60:.1f} min) score {score:.4f} :: {fmt(res)}", flush=True)
        log.append({"epoch": ep, "score": score, "res": res})
        ck = {"backbone": a.backbone, "model": model.state_dict(), "head": head.state_dict(),
              "opt": opt.state_dict(), "epoch": ep, "res": res}
        torch.save(ck, a.out / "last.pt")
        if score > best:
            best = score
            torch.save({k: ck[k] for k in ("backbone", "model", "epoch", "res")}, a.out / "best.pt")
        (a.out / "log.json").write_text(json.dumps(log, indent=1))
    print(f"best score {best:.4f}", flush=True)


if __name__ == "__main__":
    main()
