"""Decode + augment training batches on the GPU.

The PC's 6-core CPU could not decode and augment fast enough to keep the
RTX 3060 busy (it sat at ~15%). Here the CPU only hands over JPEG bytes:
nvJPEG decodes the whole batch on the GPU, and ONE grid_sample per batch does
random-resized-crop + rotation + shear for every image at once; colour,
blur, greyscale and erasing are batched tensor maths.

Same augmentations as embedder.train_transform (shop conditions: handheld,
tilted, fingers, odd light; no horizontal flip).
"""
import math

import torch
import torch.nn.functional as F
import torchvision
from torchvision.io import ImageReadMode

from embedder import MEAN, STD, SIZE

_mean = None
_std = None


def _norm_consts(device):
    global _mean, _std
    if _mean is None or _mean.device != device:
        _mean = torch.tensor(MEAN, device=device).view(1, 3, 1, 1)
        _std = torch.tensor(STD, device=device).view(1, 3, 1, 1)
    return _mean, _std


def _decode(jpegs, device):
    if isinstance(jpegs, tuple):  # (blob, lengths) from packs.collate_raw
        blob, lengths = jpegs
        jpegs = list(torch.split(blob, lengths.tolist()))
    try:
        return torchvision.io.decode_jpeg(jpegs, mode=ImageReadMode.RGB, device=device)
    except RuntimeError:
        # One bad file must not kill the batch: decode one by one, blank on error.
        out = []
        for j in jpegs:
            try:
                out.append(torchvision.io.decode_jpeg(j, mode=ImageReadMode.RGB, device=device))
            except RuntimeError:
                out.append(torch.zeros(3, SIZE, SIZE, dtype=torch.uint8, device=device))
        return out


def _squares(imgs, side, random_offset):
    """One square window per photo (side = its short side; random or centred
    along the long side), resized to `side` and stacked: a compact batch,
    instead of padding every photo to the largest one."""
    out = []
    for im in imgs:
        h, w = im.shape[1], im.shape[2]
        s = min(h, w)
        if random_offset:
            y0 = int(torch.randint(0, h - s + 1, (1,)))
            x0 = int(torch.randint(0, w - s + 1, (1,)))
        else:
            y0, x0 = (h - s) // 2, (w - s) // 2
        sq = im[:, y0:y0 + s, x0:x0 + s].unsqueeze(0).half()
        if s != side:
            sq = F.interpolate(sq, size=(side, side), mode="bilinear", antialias=s > side, align_corners=False)
        out.append(sq)
    return torch.cat(out) / 255.0

def _theta(cx, cy, cw, ch, A, H, W):
    """2x3 affine for grid_sample mapping the output square onto a crop
    centred (cx, cy) of size (cw, ch) pixels, transformed by 2x2 A."""
    t = torch.zeros(len(cx), 2, 3, device=cx.device)
    t[:, 0, 0] = A[:, 0, 0] * cw / W
    t[:, 0, 1] = A[:, 0, 1] * ch / W
    t[:, 1, 0] = A[:, 1, 0] * cw / H
    t[:, 1, 1] = A[:, 1, 1] * ch / H
    t[:, 0, 2] = 2 * cx / W - 1
    t[:, 1, 2] = 2 * cy / H - 1
    return t


@torch.no_grad()
@torch.autocast("cuda", enabled=False)
def train_batch(jpegs, device="cuda"):
    imgs = _decode(jpegs, device)
    x = _squares(imgs, 256, random_offset=True)
    B, H, W = x.shape[0], 256, 256
    h = w = torch.full((B,), 256.0, device=device)
    r = lambda lo, hi: torch.empty(B, device=device).uniform_(lo, hi)  # noqa: E731

    # RandomResizedCrop(scale 0.3-1, ratio 3/4-4/3).
    area = h * w * r(0.3, 1.0)
    ratio = torch.exp(r(math.log(3 / 4), math.log(4 / 3)))
    cw = torch.sqrt(area * ratio).clamp(max=w)
    ch = torch.sqrt(area / ratio).clamp(max=h)
    cx = cw / 2 + r(0, 1) * (w - cw)
    cy = ch / 2 + r(0, 1) * (h - ch)

    # Rotation +-20 deg and shear +-8 deg, each on half the batch.
    ang = torch.deg2rad(r(-20, 20)) * (torch.rand(B, device=device) < 0.5)
    sh = torch.tan(torch.deg2rad(r(-8, 8))) * (torch.rand(B, device=device) < 0.5)
    cos, sin = torch.cos(ang), torch.sin(ang)
    A = torch.stack([torch.stack([cos, -sin * 1 + cos * sh], 1),
                     torch.stack([sin, cos + sin * sh], 1)], 1)

    grid = F.affine_grid(_theta(cx, cy, cw, ch, A, H, W), (B, 3, SIZE, SIZE), align_corners=False)
    out = F.grid_sample(x, grid.half(), mode="bilinear", padding_mode="zeros", align_corners=False)

    # Colour jitter (brightness, contrast, saturation 0.65-1.35).
    out = out * r(0.65, 1.35).view(B, 1, 1, 1).half()
    m = out.mean((1, 2, 3), keepdim=True)
    out = (out - m) * r(0.65, 1.35).view(B, 1, 1, 1).half() + m
    gray = (out * torch.tensor([0.299, 0.587, 0.114], device=device, dtype=out.dtype).view(1, 3, 1, 1)).sum(1, keepdim=True)
    out = (out - gray) * r(0.7, 1.3).view(B, 1, 1, 1).half() + gray
    g = (torch.rand(B, device=device) < 0.05).view(B, 1, 1, 1)
    out = torch.where(g, gray.expand_as(out), out)

    # Blur a quarter of the batch (out-of-focus handheld shots).
    bl = torch.rand(B, device=device) < 0.25
    if bl.any():
        k = torch.tensor([1, 4, 6, 4, 1], device=device, dtype=out.dtype)
        k = (k[:, None] * k[None, :]) / 256
        k = k.expand(3, 1, 5, 5)
        out[bl] = F.conv2d(F.pad(out[bl], (2, 2, 2, 2), mode="replicate"), k, groups=3)

    out = out.clamp(0, 1)
    mean, std = _norm_consts(out.device)
    out = (out - mean.half()) / std.half()

    # Random erasing (a finger or a price sticker over the pack).
    er = torch.rand(B, device=device) < 0.25
    if er.any():
        idx = er.nonzero().flatten()
        side = (r(0.12, 0.38)[idx] * SIZE).long()
        x0 = (torch.rand(len(idx), device=device) * (SIZE - side)).long()
        y0 = (torch.rand(len(idx), device=device) * (SIZE - side)).long()
        for j, b in enumerate(idx.tolist()):
            out[b, :, y0[j]:y0[j] + side[j], x0[j]:x0[j] + side[j]] = 0
    return out.contiguous(memory_format=torch.channels_last)


@torch.no_grad()
@torch.autocast("cuda", enabled=False)
def eval_batch(jpegs, device="cuda"):
    """Short side to SIZE, centre square crop: what the app does."""
    x = _squares(_decode(jpegs, device), SIZE, random_offset=False)
    mean, std = _norm_consts(x.device)
    x = (x - mean.half()) / std.half()
    return x.contiguous(memory_format=torch.channels_last)