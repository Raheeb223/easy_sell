"""Decode the training/eval datasets once into small JPEGs plus an index CSV.

Training reads ~150k images per epoch; decoding 800px originals on a 6-core CPU
would starve the GPU, so every image is resized here (short side 256) once.

Usage (paths are outside the repo; datasets are never committed):
    python -I ml/prepare_data.py --data G:/Easy_sell/ml_data
"""
import argparse
import csv
import io
import os
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import pyarrow.parquet as pq
from PIL import Image

SHORT = 256


def _save(raw: bytes, out: Path) -> bool:
    try:
        im = Image.open(io.BytesIO(raw)).convert("RGB")
    except Exception:
        return False
    w, h = im.size
    s = SHORT / min(w, h)
    if s < 1:
        im = im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.BICUBIC)
    im.save(out, "JPEG", quality=90)
    return True


def _p10k_shard(args):
    shard, out_dir = args
    rows = []
    pf = pq.ParquetFile(shard)
    stem = Path(shard).stem
    i = 0
    for batch in pf.iter_batches(batch_size=64):
        for r in batch.to_pylist():
            out = Path(out_dir) / f"{stem}_{i}.jpg"
            i += 1
            if out.exists() or _save(r["image"]["bytes"], out):
                rows.append((str(out), "p10k_" + str(r["sku"])))
    return rows


def prepare_p10k(data: Path):
    out_dir = data / "p10k_img"
    out_dir.mkdir(exist_ok=True)
    shards = sorted((data / "p10k" / "data").glob("train-*.parquet"))
    rows = []
    # 3 workers: each holds a parquet row group; 6 ran a 16 GB PC out of memory.
    with ProcessPoolExecutor(max_workers=3) as ex:
        for part in ex.map(_p10k_shard, [(str(s), str(out_dir)) for s in shards]):
            rows.extend(part)
    _write(data / "p10k_index.csv", rows)


def prepare_rp2k(data: Path):
    out_dir = data / "rp2k_img"
    out_dir.mkdir(exist_ok=True)
    rows = []
    pf = pq.ParquetFile(data / "rp2k_mteb" / "corpus-00000-of-00001.parquet")
    i = 0
    for batch in pf.iter_batches(batch_size=512):
        for r in batch.to_pylist():
            out = out_dir / f"{i}.jpg"
            i += 1
            # ids look like "<product name>_<capture id>"; the name is the class.
            label = "rp2k_" + r["id"].split("_")[0]
            if out.exists() or _save(r["image"], out):
                rows.append((str(out), label))
    _write(data / "rp2k_index.csv", rows)


def prepare_grocery(data: Path):
    root = next((data / "grocery").glob("GroceryStoreDataset-*")) / "dataset"
    for split in ("train", "val", "test"):
        rows = []
        for line in (root / f"{split}.txt").read_text().splitlines():
            path, fine, _coarse = [x.strip() for x in line.split(",")]
            rows.append((str(root / path), "gsd_" + fine))
        _write(data / f"grocery_{split}_index.csv", rows)


def _write(path: Path, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["path", "label"])
        w.writerows(rows)
    print(f"{path.name}: {len(rows)} images, {len({r[1] for r in rows})} classes")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--only", choices=["p10k", "rp2k", "grocery"])
    a = ap.parse_args()
    if a.only in (None, "grocery"):
        prepare_grocery(a.data)
    if a.only in (None, "rp2k"):
        prepare_rp2k(a.data)
    if a.only in (None, "p10k"):
        prepare_p10k(a.data)
