"""Precomputes the big teacher's embedding for every training image, once.

The teacher (trained on billions / hundreds of millions of images) is far too
big for a phone, so train_v2.py distils it into the small student. Running it
once here, on clean centre crops, keeps the GPU on the student while training.

Output: <data>/teacher_<name>.npy, float16 [N, D], in the global order
train_v2.py uses (packs concatenated in --packs order).

    python -I ml/embed_teacher.py --data G:/Easy_sell/ml_data --name siglip \
        --model vit_base_patch16_siglip_224.webli --packs off_index grocery_train_index
"""
import argparse
import sys
from pathlib import Path

import numpy as np
import torch
from torch.utils.data import DataLoader

sys.path.insert(0, str(Path(__file__).parent))
from embedder import RawBackbone, eval_transform  # noqa: E402
from packs import Pack, PackList  # noqa: E402


@torch.no_grad()
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--model", required=True)
    ap.add_argument("--packs", nargs="+", required=True)
    ap.add_argument("--batch", type=int, default=256)
    ap.add_argument("--workers", type=int, default=4)
    a = ap.parse_args()
    dev = "cuda"
    model = RawBackbone(a.model).to(dev).eval().to(memory_format=torch.channels_last)

    entries = []
    for st in a.packs:
        p = Pack(a.data, st)
        base = len(entries)
        entries += [(str(p.path), int(o), int(n), 0, base + i)
                    for i, (o, n) in enumerate(zip(p.offsets, p.lengths))]
    dl = DataLoader(PackList(entries, eval_transform()), batch_size=a.batch,
                    num_workers=a.workers, pin_memory=True)
    out = None
    done = 0
    for x, _, gi in dl:
        with torch.autocast("cuda", dtype=torch.bfloat16):
            e = model(x.to(dev, non_blocking=True).to(memory_format=torch.channels_last))
        e = e.float().cpu().numpy().astype(np.float16)
        if out is None:
            out = np.lib.format.open_memmap(
                a.data / f"teacher_{a.name}.npy", mode="w+", dtype=np.float16,
                shape=(len(entries), e.shape[1]))
        out[gi.numpy()] = e
        done += len(e)
        if done % (a.batch * 100) < a.batch:
            print(f"{done}/{len(entries)}", flush=True)
    out.flush()
    print(f"teacher {a.name}: {out.shape} written", flush=True)


if __name__ == "__main__":
    main()
