"""Fine-tune EasySell Vision on retail products (ArcFace metric learning).

Trains on Products-10K (about 9.7k packaged-goods SKUs). Held-out SKUs, RP2K
shelf products and Grocery Store phone photos are never trained on in the
default run, so the few-shot scores measure products the model has NEVER
seen -- which is every product in a real shop. `--all-data` adds RP2K and
Grocery to training for the final shipped model, after the recipe is proven.

    python -I ml/train.py --data G:/Easy_sell/ml_data --out G:/Easy_sell/ml_runs/v1
"""
import argparse
import json
import math
import random
import sys
import time
from collections import Counter
from pathlib import Path

import torch
from torch.utils.data import DataLoader

sys.path.insert(0, str(Path(__file__).parent))
from embedder import ArcFace, Embedder, ImageList, read_index, train_transform  # noqa: E402
from eval_fewshot import embed, evaluate, fewshot, fmt  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--backbone", default="mobilenetv4_conv_medium.e500_r256_in1k")
    ap.add_argument("--epochs", type=int, default=12)
    ap.add_argument("--batch", type=int, default=128)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--holdout", type=int, default=400)
    ap.add_argument("--all-data", action="store_true")
    ap.add_argument("--workers", type=int, default=6)
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    torch.manual_seed(0)
    random.seed(0)
    dev = "cuda"
    torch.backends.cudnn.benchmark = True

    items = read_index(a.data / "p10k_index.csv")
    counts = Counter(l for _, l in items)
    classes = sorted(c for c, n in counts.items() if n >= 2)
    rng = random.Random(0)
    held = set(rng.sample(classes, a.holdout))
    train_items = [(p, l) for p, l in items if counts[l] >= 2 and l not in held]
    held_items = [(p, l) for p, l in items if l in held]
    if a.all_data:
        train_items += held_items
        train_items += read_index(a.data / "rp2k_index.csv")
        train_items += read_index(a.data / "grocery_train_index.csv")
    labels = sorted({l for _, l in train_items})
    ids = {l: i for i, l in enumerate(labels)}
    print(f"train: {len(train_items)} images, {len(labels)} classes; held-out SKUs: {len(held)}", flush=True)

    dl = DataLoader(
        ImageList(train_items, ids, train_transform()), batch_size=a.batch, shuffle=True,
        num_workers=a.workers, pin_memory=True, drop_last=True,
        persistent_workers=True, prefetch_factor=4,
    )
    model = Embedder(a.backbone).to(dev).to(memory_format=torch.channels_last)
    head = ArcFace(model.proj.out_features, len(labels)).to(dev)
    opt = torch.optim.AdamW([
        {"params": model.backbone.parameters(), "lr": a.lr * 0.5},
        {"params": list(model.proj.parameters()) + list(model.bn.parameters()), "lr": a.lr},
        {"params": head.parameters(), "lr": a.lr * 10, "weight_decay": 0},
    ], weight_decay=1e-4)
    base = [g["lr"] for g in opt.param_groups]
    steps = a.epochs * len(dl)
    warm = len(dl)

    best, log = -1.0, []
    step = 0
    for ep in range(a.epochs):
        model.train()
        t0, run = time.time(), 0.0
        for i, (x, y) in enumerate(dl):
            f = step / warm if step < warm else 0.5 * (1 + math.cos(math.pi * (step - warm) / (steps - warm)))
            for g, b in zip(opt.param_groups, base):
                g["lr"] = b * f
            x = x.to(dev, non_blocking=True).to(memory_format=torch.channels_last)
            y = y.to(dev, non_blocking=True)
            with torch.autocast("cuda", dtype=torch.bfloat16):
                emb = model(x)
            loss = head(emb.float(), y)
            opt.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            opt.step()
            run += loss.item()
            step += 1
            if i % 200 == 0:
                print(f"ep {ep} it {i}/{len(dl)} loss {run / (i + 1):.3f} {(i + 1) * a.batch / (time.time() - t0):.0f} img/s", flush=True)

        res = evaluate(model, a.data, dev)
        if held_items and not a.all_data:
            e, ys = embed(model, held_items, dev)
            res["p10k_heldout"] = fewshot(e, ys)
        score = sum(r["shop"][0] for r in res.values()) / len(res)
        print(f"== epoch {ep} ({time.time() - t0:.0f}s) score {score:.4f} :: {fmt(res)}", flush=True)
        log.append({"epoch": ep, "score": score, "res": res})
        ck = {"backbone": a.backbone, "model": model.state_dict(), "epoch": ep, "res": res}
        torch.save(ck, a.out / "last.pt")
        if score > best:
            best = score
            torch.save(ck, a.out / "best.pt")
        (a.out / "log.json").write_text(json.dumps(log, indent=1))
    print(f"best score {best:.4f}", flush=True)


if __name__ == "__main__":
    main()
