"""Fine-tunes the app's Bangla streaming recogniser (ml/asr/bn_model.py) on
the features from ml/asr/prep_bn.py, through the same chunked streaming
encoder the phone runs.

Word error rate on held-out speakers (SLR53) and FLEURS test is measured
before training and at every evaluation; the best model is written as ONNX
(same graphs as the app's, new weights) only when it beats the original.
Background noise is mixed into the features so it copes with a busy shop.

    python -I ml/asr/finetune_bn.py --model DIR --feats DIR --out DIR
        [--train slr53_train fleurs_train slr37_train] [--minutes 60]
"""
import argparse
import json
import math
import random
import sys
import time
from pathlib import Path

import numpy as np
import sentencepiece as spm
import torch

sys.path.insert(0, str(Path(__file__).parent))
from bn_model import Transducer  # noqa: E402


class Set:
    """One prep_bn.py output: memory-mapped features plus the index."""

    def __init__(self, feats: Path, name: str):
        self.rows = [json.loads(l) for l in (feats / f"{name}.jsonl").read_text(encoding="utf-8").splitlines()]
        self.data = np.memmap(feats / f"{name}.f16", dtype=np.float16, mode="r").reshape(-1, 80)

    def feats(self, r):
        return np.asarray(self.data[r["offset"]: r["offset"] + r["frames"]], dtype=np.float32)


def batches(items, max_frames, shuffle=True):
    """Length-bucketed batches of at most max_frames padded frames."""
    items = sorted(items, key=lambda x: x[1]["frames"])
    out, cur = [], []
    for it in items:
        if cur and (len(cur) + 1) * it[1]["frames"] > max_frames:
            out.append(cur)
            cur = []
        cur.append(it)
    if cur:
        out.append(cur)
    if shuffle:
        random.shuffle(out)
    return out


def collate(batch, device, augment=False):
    fs = [s.feats(r) for s, r in batch]
    if augment:
        fs = [augment_feats(f) for f in fs]
    n, t = len(fs), max(len(f) for f in fs)
    x = np.zeros((n, t, 80), np.float32)
    for i, f in enumerate(fs):
        x[i, : len(f)] = f
    u = max(len(r["tokens"]) for _, r in batch)
    ys = np.zeros((n, u), np.int64)
    for i, (_, r) in enumerate(batch):
        ys[i, : len(r["tokens"])] = r["tokens"]
    return (torch.from_numpy(x).to(device), torch.tensor([len(f) for f in fs], device=device),
            torch.from_numpy(ys).to(device), torch.tensor([len(r["tokens"]) for _, r in batch], device=device))


def augment_feats(f):
    """Shop-like conditions: stationary background noise added in the mel
    power domain (fans, traffic, chatter), a random loudness, and light
    SpecAugment."""
    f = f.copy()
    if random.random() < 0.6:
        level = np.percentile(f, 50, axis=0)  # per-bin typical speech level
        snr_db = random.uniform(3, 20)  # small = loud noise
        tilt = np.linspace(random.uniform(-2, 2), random.uniform(-2, 2), 80)
        noise = level - 0.2303 * snr_db + tilt + np.random.randn(*f.shape) * 0.5  # dB -> ln power
        f = np.logaddexp(f, noise)
    f += random.uniform(-1.5, 1.5)  # gain: log-power shifts uniformly
    for _ in range(2):
        w = random.randint(0, 8)
        s = random.randint(0, 80 - w)
        f[:, s: s + w] = f.mean()
    for _ in range(max(1, len(f) // 300)):
        w = random.randint(0, min(20, len(f) // 10))
        s = random.randint(0, max(0, len(f) - w))
        f[s: s + w] = f.mean()
    return f


def wer(model, items, sp, device, max_frames=6000):
    """Word error rate (%) with greedy search, as decoded on the phone."""
    model.eval()
    errs = words = 0
    for b in batches(items, max_frames, shuffle=False):
        x, fl, _, _ = collate(b, device)
        for (_, r), hyp in zip(b, model.greedy(x, fl)):
            ref, h = r["text"].split(), sp.decode(hyp).split()
            d = list(range(len(h) + 1))
            for i, rw in enumerate(ref, 1):
                prev, d[0] = d[0], i
                for j, hw in enumerate(h, 1):
                    prev, d[j] = d[j], min(d[j] + 1, d[j - 1] + 1, prev + (rw != hw))
            errs += d[-1]
            words += len(ref)
    model.train()
    return 100 * errs / max(words, 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", type=Path, required=True)
    ap.add_argument("--feats", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--train", nargs="+", default=["slr53_train", "fleurs_train", "slr37_train"])
    ap.add_argument("--test", nargs="+", default=["slr53_test", "fleurs_test"])
    ap.add_argument("--test-n", type=int, default=400)
    ap.add_argument("--epochs", type=float, default=2)
    ap.add_argument("--lr", type=float, default=5e-5)
    ap.add_argument("--max-frames", type=int, default=24000)
    ap.add_argument("--eval-every", type=int, default=800)
    ap.add_argument("--minutes", type=float, default=0, help="stop after this long (0: no limit)")
    ap.add_argument("--device", default="cuda")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    random.seed(0)
    torch.manual_seed(0)
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True
    dev = a.device
    a.out.mkdir(parents=True, exist_ok=True)
    t0 = time.time()

    sp = spm.SentencePieceProcessor(model_file=str(a.model / "bpe.model"))
    train = []
    for n in a.train:
        if (a.feats / f"{n}.jsonl").exists():
            s = Set(a.feats, n)
            train += [(s, r) for r in s.rows]
            print(f"train {n}: {len(s.rows)} utts, {sum(r['frames'] for r in s.rows) / 360000:.1f} h", flush=True)
    tests = {}
    for n in a.test:
        if (a.feats / f"{n}.jsonl").exists():
            s = Set(a.feats, n)
            rows = random.Random(1).sample(s.rows, min(a.test_n, len(s.rows)))
            tests[n] = [(s, r) for r in rows]

    model = Transducer(a.model).to(dev)
    model.train()
    state_path = a.out / "last.pt"
    step, best, start_epoch = 0, None, 0
    opt = torch.optim.AdamW(model.parameters(), lr=a.lr, weight_decay=0.0)
    steps_per_epoch = len(batches(train, a.max_frames))
    total = int(steps_per_epoch * a.epochs)
    if state_path.exists():
        st = torch.load(state_path, map_location=dev, weights_only=False)
        model.load_state_dict(st["model"])
        opt.load_state_dict(st["opt"])
        step, best, start_epoch = st["step"], st["best"], st["epoch"]
        print(f"resumed at step {step}", flush=True)

    def evaluate():
        return {n: wer(model, it, sp, dev) for n, it in tests.items()}

    if best is None:
        base = evaluate()
        best = {"score": sum(base.values()) / len(base), "wer": base, "step": 0}
        json.dump({"original": base}, open(a.out / "baseline.json", "w"))
        print(f"original model WER: {base} (mean {best['score']:.2f})", flush=True)

    def lr_at(s):
        warm = 300
        if s < warm:
            return a.lr * s / warm
        p = min(1.0, (s - warm) / max(1, total - warm))
        return a.lr * (0.1 + 0.9 * 0.5 * (1 + math.cos(math.pi * p)))

    def checkpoint_eval():
        nonlocal best
        res = evaluate()
        score = sum(res.values()) / len(res)
        better = score < best["score"]
        print(f"step {step}: WER {res} (mean {score:.2f}; best {best['score']:.2f}){'  NEW BEST' if better else ''}",
              flush=True)
        if better:
            best = {"score": score, "wer": res, "step": step}
            model.save_onnx(a.out / "best_onnx")
            json.dump(best, open(a.out / "best.json", "w"))
        torch.save({"model": model.state_dict(), "opt": opt.state_dict(), "step": step, "best": best,
                    "epoch": step // steps_per_epoch}, state_path)

    stop = False
    for epoch in range(start_epoch, math.ceil(a.epochs)):
        random.seed(100 + epoch)
        for b in batches(train, a.max_frames):
            if step >= total:
                stop = True
                break
            x, fl, ys, ul = collate(b, dev, augment=True)
            for g in opt.param_groups:
                g["lr"] = lr_at(step)
            loss = model.loss(x, fl, ys, ul)
            if not torch.isfinite(loss):
                print(f"step {step}: non-finite loss, batch skipped", flush=True)
                opt.zero_grad(set_to_none=True)
                continue
            opt.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            opt.step()
            step += 1
            if step % 50 == 0:
                el = (time.time() - t0) / 60
                print(f"ep {epoch} step {step}/{total} loss {float(loss):.4f} lr {lr_at(step):.2e} "
                      f"{el:.1f} min", flush=True)
            if step % a.eval_every == 0:
                checkpoint_eval()
            if a.minutes and time.time() - t0 > a.minutes * 60:
                stop = True
                break
        if stop:
            break
    checkpoint_eval()
    print(f"FINISHED best {best}", flush=True)


if __name__ == "__main__":
    main()
