"""Packs an index CSV's JPEGs into ONE file plus an offsets table.

The datasets live on a hard disk (G:). Opening ~140k small files in random
order there starves the GPU (it sat at ~5% busy). One packed file is read in
order once, stays in the OS file cache, and every later read is from RAM.

    python -I ml/pack_data.py --data G:/Easy_sell/ml_data --index p10k_index.csv
"""
import argparse
import csv
from pathlib import Path

import numpy as np


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--index", nargs="+", required=True)
    a = ap.parse_args()
    for name in a.index:
        src = a.data / name
        stem = src.stem
        offsets, lengths, labels = [], [], []
        pos = 0
        with open(src, encoding="utf-8") as f, open(a.data / f"{stem}.pack", "wb") as out:
            for row in csv.DictReader(f):
                try:
                    b = Path(row["path"]).read_bytes()
                except OSError:
                    continue
                out.write(b)
                offsets.append(pos)
                lengths.append(len(b))
                labels.append(row["label"])
                pos += len(b)
        np.save(a.data / f"{stem}.offsets.npy", np.array([offsets, lengths], dtype=np.int64))
        with open(a.data / f"{stem}.labels.txt", "w", encoding="utf-8") as f:
            f.write("\n".join(labels))
        print(f"{stem}: {len(labels)} images, {pos / 1e9:.2f} GB packed", flush=True)


if __name__ == "__main__":
    main()
