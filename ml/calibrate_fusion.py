"""Measures the photo similarities the app's scan fusion has to separate.

Mirrors the app: 200-product shops, 3 taught photos per product, a scan's
score per product is its best cosine to that product's photos. Prints the
similarity of the right product, of the best wrong one, and of the best
product when the scanned item is not in the shop at all, so
FusionParams.photoThreshold (lib/features/scan/domain/scan_fusion.dart) can be
set from the real model.

    python -I ml/calibrate_fusion.py --data G:/Easy_sell/ml_data --checkpoint G:/Easy_sell/ml_runs/v2/best.pt
"""
import argparse
import random
import sys
from collections import defaultdict
from pathlib import Path

import torch

sys.path.insert(0, str(Path(__file__).parent))
from embedder import Embedder  # noqa: E402
from eval_fewshot import embed_entries, pack_entries  # noqa: E402


def fuse(s, weight, th):
    """scan_fusion.dart with no label text: softmax over the products'
    weight * (s - th) plus a "none of these" logit at 0."""
    l = weight * (s - th)
    shift = l.amax(1, keepdim=True).clamp(min=0)
    e = (l - shift).exp()
    return e / (e.sum(1, keepdim=True) + (-shift).exp())


def outcomes(conf, y, strong=0.80, margin=0.15, ask=0.50):
    """scan_decision.dart: auto-sell, "did you mean" chooser, or nothing.
    y is the right product per scan, or None for items the shop lacks."""
    top2 = conf.topk(2, dim=1)
    auto = (top2.values[:, 0] >= strong) & (top2.values[:, 0] - top2.values[:, 1] >= margin)
    chooser = ~auto & (top2.values[:, 0] >= ask)
    if y is None:
        return auto.float().mean().item(), chooser.float().mean().item()
    top1 = top2.indices[:, 0] == y
    top5 = (conf.topk(5, dim=1).indices == y[:, None]).any(1)
    in_chooser = chooser & top5 & (conf.gather(1, y[:, None])[:, 0] >= ask)
    return ((auto & top1).float().mean().item(), (auto & ~top1).float().mean().item(),
            in_chooser.float().mean().item())


def sims(emb, ys, k=3, shop=200, trials=10, max_q=10, seed=0, grid=None):
    by = defaultdict(list)
    for i, y in enumerate(ys.tolist()):
        by[y].append(i)
    classes = [c for c, v in by.items() if len(v) > k]
    rng = random.Random(seed)
    right, wrong, absent, correct = [], [], [], []
    full, fully, full_absent = [], [], []
    for _ in range(trials):
        pick = rng.sample(classes, min(shop + 50, len(classes)))
        sold, unsold = pick[:shop], pick[shop:]
        gal, q, qy = [], [], []
        for ci, c in enumerate(sold):
            idx = by[c][:]
            rng.shuffle(idx)
            gal.extend(idx[:k])
            rest = idx[k:k + max_q]
            q.extend(rest)
            qy.extend([ci] * len(rest))
        G = emb[gal].view(len(sold), k, -1)
        s = torch.einsum("qd,nkd->qnk", emb[q], G).amax(-1)
        y = torch.tensor(qy, device=emb.device)
        full.append(s.clone())
        fully.append(y)
        r = s.gather(1, y[:, None])[:, 0]
        s.scatter_(1, y[:, None], -1)
        w = s.amax(1)
        right.append(r)
        wrong.append(w)
        correct.append(r > w)
        aq = [i for c in unsold for i in by[c][:max_q]]
        if aq:
            sa = torch.einsum("qd,nkd->qnk", emb[aq], G).amax(-1)
            full_absent.append(sa)
            absent.append(sa.amax(1))
    if grid:
        S, Y = torch.cat(full), torch.cat(fully)
        SA = torch.cat(full_absent) if full_absent else None
        print("  weight th ask | right: auto-ok auto-WRONG chooser-has-it | absent: auto chooser")
        for weight, th, ask in grid:
            ok, bad, cho = outcomes(fuse(S, weight, th), Y, ask=ask)
            ab = outcomes(fuse(SA, weight, th), None, ask=ask) if SA is not None else (float("nan"),) * 2
            print(f"  {weight:5.0f} {th:.2f} {ask:.2f} | {ok:.3f} {bad:.3f} {cho:.3f} | {ab[0]:.3f} {ab[1]:.3f}")
    cat = lambda xs: torch.cat(xs) if xs else torch.zeros(0)
    return cat(right), cat(wrong), cat(absent), cat(correct)


def pct(t):
    qs = torch.tensor([0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95], device=t.device)
    return " ".join(f"{v:.3f}" for v in torch.quantile(t.float(), qs).tolist())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--checkpoint", type=Path, required=True)
    a = ap.parse_args()
    dev = "cuda" if torch.cuda.is_available() else "cpu"
    ck = torch.load(a.checkpoint, map_location="cpu")
    model = Embedder(ck["backbone"], pretrained=False)
    model.load_state_dict(ck["model"])
    model = model.to(dev).to(memory_format=torch.channels_last)
    print("percentiles 5 10 25 50 75 90 95")
    for name, stems in (("rp2k", ["rp2k_index"]),
                        ("grocery", ["grocery_train_index", "grocery_test_index"])):
        emb, ys = embed_entries(model, pack_entries(a.data, stems), dev)
        print(name)
        grid = [(w, th, ask) for w in (24, 32, 40, 50) for th in (0.45, 0.5, 0.55, 0.6)
                for ask in (0.5, 0.2)]
        r, w, ab, ok = sims(emb, ys, grid=grid)
        print(f"  top1 {ok.float().mean():.3f}")
        print(f"  right product      {pct(r)}")
        print(f"  best wrong product {pct(w)}")
        if len(ab):
            print(f"  item not in shop   {pct(ab)}")


if __name__ == "__main__":
    main()
