"""Few-shot recognition test that mirrors the app.

For each product: K photos are "enrolled", the rest are scans. A scan's score
for a product is its best cosine similarity to that product's enrolled
photos; the top-scoring product is the answer. Reported for a shop-sized
catalogue (200 products, averaged over random shops) and for every class.

    python -I ml/eval_fewshot.py --data G:/Easy_sell/ml_data --backbone mobilenetv4_conv_medium.e500_r256_in1k
    python -I ml/eval_fewshot.py --data ... --checkpoint G:/Easy_sell/ml_runs/x/best.pt
"""
import argparse
import random
import sys
from collections import defaultdict
from pathlib import Path

import torch
from torch.utils.data import DataLoader

sys.path.insert(0, str(Path(__file__).parent))
from embedder import Embedder, ImageList, RawBackbone, eval_transform, read_index  # noqa: E402
from packs import Pack, PackList  # noqa: E402

# Each Windows DataLoader worker loads its own torch + CUDA (~1 GB commit).
WORKERS = 3


@torch.no_grad()
def embed(model, items, device, batch=128, workers=None):
    workers = WORKERS if workers is None else workers
    labels = sorted({l for _, l in items})
    ids = {l: i for i, l in enumerate(labels)}
    dl = DataLoader(ImageList(items, ids, eval_transform()), batch_size=batch,
                    num_workers=workers, pin_memory=True)
    out, ys = [], []
    model.eval()
    for x, y in dl:
        with torch.autocast("cuda", dtype=torch.bfloat16):
            e = model(x.to(device, non_blocking=True).to(memory_format=torch.channels_last))
        out.append(e.float())
        ys.append(y.to(device))
    return torch.nn.functional.normalize(torch.cat(out), dim=1), torch.cat(ys)


@torch.no_grad()
def embed_entries(model, entries, device, batch=128, workers=None, transform=None):
    """Like [embed], from pack entries (path, offset, length, label, index),
    read in file order -- fast on a hard disk."""
    workers = WORKERS if workers is None else workers
    dl = DataLoader(PackList(entries, transform or eval_transform()), batch_size=batch,
                    num_workers=workers, pin_memory=True)
    out, ys = [], []
    model.eval()
    for x, y, _ in dl:
        with torch.autocast("cuda", dtype=torch.bfloat16):
            e = model(x.to(device, non_blocking=True).to(memory_format=torch.channels_last))
        out.append(e.float())
        ys.append(y.to(device))
    return torch.nn.functional.normalize(torch.cat(out), dim=1), torch.cat(ys)


def pack_entries(data: Path, stems):
    """All entries of the given packs, labels numbered across them."""
    packs = [Pack(data, s) for s in stems]
    labels = sorted({l for p in packs for l in p.labels})
    ids = {l: i for i, l in enumerate(labels)}
    out = []
    for p in packs:
        out += [(str(p.path), int(o), int(n), ids[l], i)
                for i, (o, n, l) in enumerate(zip(p.offsets, p.lengths, p.labels))]
    return out


def fewshot(emb, ys, k=3, shop=200, trials=10, max_q=10, seed=0):
    by = defaultdict(list)
    for i, y in enumerate(ys.tolist()):
        by[y].append(i)
    classes = [c for c, v in by.items() if len(v) > k]
    rng = random.Random(seed)
    res = {}
    for name, n, t in (("shop", min(shop, len(classes)), trials), ("all", len(classes), 1)):
        top1 = top5 = total = 0
        for _ in range(t):
            pick = rng.sample(classes, n)
            gal, q, qy = [], [], []
            for ci, c in enumerate(pick):
                idx = by[c][:]
                rng.shuffle(idx)
                gal.extend(idx[:k])
                rest = idx[k:k + max_q]
                q.extend(rest)
                qy.extend([ci] * len(rest))
            G = emb[gal].view(n, k, -1)
            Q = emb[q]
            qy_t = torch.tensor(qy, device=emb.device)
            for s in range(0, len(q), 4096):
                sims = torch.einsum("qd,nkd->qnk", Q[s:s + 4096], G).amax(-1)
                top = sims.topk(min(5, n), dim=1).indices
                y = qy_t[s:s + 4096]
                top1 += (top[:, 0] == y).sum().item()
                top5 += (top == y[:, None]).any(1).sum().item()
                total += len(y)
        res[name] = (top1 / total, top5 / total, n)
    return res


def evaluate(model, data: Path, device, sets=("rp2k", "grocery")):
    out = {}
    for s in sets:
        stems = ["rp2k_index"] if s == "rp2k" else ["grocery_train_index", "grocery_test_index"]
        if all((data / f"{st}.offsets.npy").exists() for st in stems):
            emb, ys = embed_entries(model, pack_entries(data, stems), device)
        else:
            items = [it for st in stems for it in read_index(data / f"{st}.csv")]
            emb, ys = embed(model, items, device)
        out[s] = fewshot(emb, ys)
    return out


def fmt(res):
    return "  ".join(
        f"{s}: shop200 top1 {r['shop'][0]:.3f} top5 {r['shop'][1]:.3f} | all({r['all'][2]}) top1 {r['all'][0]:.3f}"
        for s, r in res.items()
    )


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--backbone", nargs="*", default=[])
    ap.add_argument("--checkpoint", type=Path)
    ap.add_argument("--workers", type=int, default=WORKERS)
    a = ap.parse_args()
    WORKERS = a.workers
    dev = "cuda"
    for b in a.backbone:
        m = RawBackbone(b).to(dev).to(memory_format=torch.channels_last)
        print(f"[baseline] {b}: {fmt(evaluate(m, a.data, dev))}", flush=True)
    if a.checkpoint:
        ck = torch.load(a.checkpoint, map_location="cpu")
        m = Embedder(ck["backbone"], pretrained=False)
        m.load_state_dict(ck["model"])
        m = m.to(dev).to(memory_format=torch.channels_last)
        print(f"[trained] {a.checkpoint}: {fmt(evaluate(m, a.data, dev))}", flush=True)
