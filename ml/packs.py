"""Reading the packed datasets (see pack_data.py / build_off.py).

A pack is one file of JPEG bytes plus `<stem>.offsets.npy` ([offsets,
lengths]) and `<stem>.labels.txt`. Training streams it in large contiguous
blocks -- the data sits on a hard disk, where sequential reads are fast and
random small reads starve the GPU.
"""
import io
import math
import random
from pathlib import Path

import numpy as np
import torch
from PIL import Image
from torch.utils.data import Dataset, IterableDataset, get_worker_info


class Pack:
    def __init__(self, data: Path, stem: str):
        self.path = data / f"{stem}.pack"
        o = np.load(data / f"{stem}.offsets.npy")
        self.offsets, self.lengths = o[0], o[1]
        self.labels = (data / f"{stem}.labels.txt").read_text(encoding="utf-8").split("\n")
        n = min(len(self.offsets), len(self.labels))
        self.offsets, self.lengths, self.labels = self.offsets[:n], self.lengths[:n], self.labels[:n]

    def __len__(self):
        return len(self.labels)


def decode(b: bytes):
    try:
        return Image.open(io.BytesIO(b)).convert("RGB")
    except Exception:
        return Image.new("RGB", (256, 256))


class PackStream(IterableDataset):
    """Yields (image, label_id, index) from selected entries of packs,
    reading blocks of consecutive entries and shuffling within a buffer."""

    def __init__(self, entries, transform, block=512, buffer=4096, seed=0):
        # entries: list of (pack_path, offset, length, label_id, global_index),
        # in file order per pack.
        self.entries = entries
        self.transform = transform
        self.block = block
        self.buffer = buffer
        self.seed = seed
        self.epoch = 0

    def _item(self, b):
        # Without a transform the GPU decodes and augments (gpu_aug.py).
        if self.transform is None:
            return b
        return self.transform(decode(b))

    def set_epoch(self, e):
        self.epoch = e

    def __len__(self):
        return len(self.entries)

    def __iter__(self):
        info = get_worker_info()
        wid, nw = (info.id, info.num_workers) if info else (0, 1)
        # A block is read as one span of one file, so it never crosses packs.
        blocks, run = [], []
        for e in self.entries:
            if run and (e[0] != run[0][0] or len(run) == self.block):
                blocks.append(run)
                run = []
            run.append(e)
        if run:
            blocks.append(run)
        rng = random.Random(self.seed + self.epoch)
        rng.shuffle(blocks)
        blocks = blocks[wid::nw]
        files = {}
        buf = []
        for blk in blocks:
            path = blk[0][0]
            f = files.get(path) or files.setdefault(path, open(path, "rb"))
            start = blk[0][1]
            end = blk[-1][1] + blk[-1][2]
            f.seek(start)
            raw = f.read(end - start)
            for (_, off, ln, y, gi) in blk:
                buf.append((raw[off - start: off - start + ln], y, gi))
            if len(buf) >= self.buffer:
                rng.shuffle(buf)
                while len(buf) > self.buffer // 2:
                    b, y, gi = buf.pop()
                    yield self._item(b), y, gi
        rng.shuffle(buf)
        for b, y, gi in buf:
            yield self._item(b), y, gi
        for f in files.values():
            f.close()


class PackList(Dataset):
    """Random access (evaluation, teacher embedding) in file order."""

    def __init__(self, entries, transform):
        self.entries = entries
        self.transform = transform
        self._files = {}

    def __len__(self):
        return len(self.entries)

    def __getitem__(self, i):
        path, off, ln, y, gi = self.entries[i]
        f = self._files.get(path)
        if f is None:
            f = self._files[path] = open(path, "rb")
        f.seek(off)
        b = f.read(ln)
        if self.transform is None:
            return b, y, gi
        return self.transform(decode(b)), y, gi


def entries_of(pack: Pack, keep, label_ids, start_index=0):
    """Entries for the pack positions whose label is in `keep`, file order."""
    out = []
    for i, (off, ln, lab) in enumerate(zip(pack.offsets, pack.lengths, pack.labels)):
        if lab in keep:
            out.append((str(pack.path), int(off), int(ln), label_ids[lab], start_index + i))
    return out


def collate_raw(batch):
    """A batch of JPEG bytes as ONE tensor plus lengths. Windows moves every
    tensor between processes through its own shared-memory file, so 192
    small tensors per batch were the training bottleneck; one blob is not."""
    xs, ys, gis = zip(*batch)
    blob = torch.frombuffer(bytearray(b"".join(xs)), dtype=torch.uint8)
    return (blob, torch.tensor([len(x) for x in xs])), torch.tensor(ys), torch.tensor(gis)


def split_raw(raw):
    """(blob, lengths) -> list of per-image byte tensors (views, no copy)."""
    blob, lengths = raw
    return list(torch.split(blob, lengths.tolist()))
