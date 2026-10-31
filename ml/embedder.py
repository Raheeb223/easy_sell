"""EasySell Vision: the on-device product "fingerprint" model.

A small mobile backbone turns a photo into a 256-number L2-normalised vector.
The app stores 2-3 vectors per product (enrollment) and recognises a scan by
cosine similarity -- few-shot, so a new product needs no retraining.
"""
import csv
from pathlib import Path

import timm
import timm.data
import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image
from torch.utils.data import Dataset
from torchvision import transforms as T

MEAN = (0.485, 0.456, 0.406)
STD = (0.229, 0.224, 0.225)
SIZE = 224
DIM = 256


class Embedder(nn.Module):
    def __init__(self, backbone: str, dim: int = DIM, pretrained: bool = True):
        super().__init__()
        self.backbone = timm.create_model(
            backbone, pretrained=pretrained, num_classes=0, global_pool="avg"
        )
        # Measured, not num_features: MobileNetV3's head conv makes the pooled
        # output wider (1280) than num_features reports (960).
        with torch.no_grad():
            self.backbone.eval()
            width = self.backbone(torch.zeros(1, 3, SIZE, SIZE)).shape[1]
            self.backbone.train()
        self.proj = nn.Linear(width, dim, bias=False)
        self.bn = nn.BatchNorm1d(dim)

    def forward(self, x):
        return F.normalize(self.bn(self.proj(self.backbone(x))), dim=1)


def create_backbone(name: str, pretrained: bool = True):
    """A timm backbone returning pooled features. ViTs (the DINOv2 teacher)
    run at SIZE with their own token pooling."""
    if "vit" in name:
        return timm.create_model(name, pretrained=pretrained, num_classes=0, img_size=SIZE)
    return timm.create_model(name, pretrained=pretrained, num_classes=0, global_pool="avg")


class RawBackbone(nn.Module):
    """Untrained baseline (or frozen teacher): a backbone's pooled features.
    Takes ImageNet-normalised input and re-normalises to what the model was
    trained with (SigLIP uses 0.5/0.5)."""

    def __init__(self, backbone: str):
        super().__init__()
        self.backbone = create_backbone(backbone)
        cfg = timm.data.resolve_model_data_config(self.backbone)
        self.register_buffer("m_in", torch.tensor(MEAN).view(1, 3, 1, 1))
        self.register_buffer("s_in", torch.tensor(STD).view(1, 3, 1, 1))
        self.register_buffer("m_out", torch.tensor(cfg["mean"]).view(1, 3, 1, 1))
        self.register_buffer("s_out", torch.tensor(cfg["std"]).view(1, 3, 1, 1))

    def forward(self, x):
        x = (x * self.s_in + self.m_in - self.m_out) / self.s_out
        return F.normalize(self.backbone(x), dim=1)


class ExportWrapper(nn.Module):
    """What ships in the app: float pixels 0..255 in, embedding out.
    Normalisation is inside the model so the app only resizes and crops.
    Exported NCHW; onnx2tf turns the TFLite input into NHWC [1,224,224,3]."""

    def __init__(self, model: nn.Module):
        super().__init__()
        self.model = model
        self.register_buffer("mean", torch.tensor(MEAN).view(1, 3, 1, 1) * 255)
        self.register_buffer("std", torch.tensor(STD).view(1, 3, 1, 1) * 255)

    def forward(self, x):
        return self.model((x - self.mean) / self.std)


class ArcFace(nn.Module):
    """Additive angular margin head (Deng et al. 2019)."""

    def __init__(self, dim: int, classes: int, s: float = 30.0, m: float = 0.3):
        super().__init__()
        self.w = nn.Parameter(torch.randn(classes, dim) * 0.01)
        self.s, self.m = s, m

    def forward(self, emb, labels):
        cos = F.linear(emb, F.normalize(self.w, dim=1)).float()
        # The margin only touches each image's own product: computing acos
        # over all ~300k classes (and a one-hot of that size) was the slowest
        # part of a training step.
        tc = cos.gather(1, labels[:, None]).clamp(-1 + 1e-7, 1 - 1e-7)
        target = torch.cos(torch.acos(tc) + self.m)
        logits = cos.scatter(1, labels[:, None], target) * self.s
        return F.cross_entropy(logits, labels, label_smoothing=0.1)


class PartialArcFace(nn.Module):
    """ArcFace over the batch's own products plus a random sample of the rest
    (Partial FC, An et al. 2022). With ~1M products the full head's logits,
    gradients and Adam state do not fit next to the model in 12 GB; here only
    the sampled rows get a (sparse) gradient. Train it with SparseAdam."""

    def __init__(self, dim: int, classes: int, sample: int = 65536, s: float = 30.0, m: float = 0.3):
        super().__init__()
        self.w = nn.Embedding(classes, dim, sparse=True)
        nn.init.normal_(self.w.weight, std=0.01)
        self.sample, self.s, self.m = sample, s, m

    def forward(self, emb, labels):
        n = self.w.num_embeddings
        idx = torch.cat([labels, torch.randint(0, n, (self.sample,), device=labels.device)]).unique()
        labels = torch.searchsorted(idx, labels)
        cos = F.linear(emb, F.normalize(self.w(idx), dim=1)).float()
        tc = cos.gather(1, labels[:, None]).clamp(-1 + 1e-7, 1 - 1e-7)
        target = torch.cos(torch.acos(tc) + self.m)
        logits = cos.scatter(1, labels[:, None], target) * self.s
        return F.cross_entropy(logits, labels, label_smoothing=0.1)

def train_transform():
    # Shop conditions: handheld, tilted, partly covered by fingers, odd light.
    # No horizontal flip -- mirrored label text never happens in a real scan.
    return T.Compose([
        T.RandomResizedCrop(SIZE, scale=(0.3, 1.0), ratio=(0.75, 1.333)),
        T.RandomApply([T.RandomAffine(degrees=20, shear=8)], p=0.5),
        T.RandomPerspective(distortion_scale=0.25, p=0.3),
        T.ColorJitter(0.35, 0.35, 0.3, 0.04),
        T.RandomGrayscale(p=0.05),
        T.RandomApply([T.GaussianBlur(5, sigma=(0.1, 2.0))], p=0.25),
        T.ToTensor(),
        T.Normalize(MEAN, STD),
        T.RandomErasing(p=0.25, scale=(0.02, 0.15)),
    ])


def eval_transform():
    # Matches the app: centre square crop of the frame, resized to SIZE.
    return T.Compose([
        T.Resize(SIZE),
        T.CenterCrop(SIZE),
        T.ToTensor(),
        T.Normalize(MEAN, STD),
    ])


def read_index(path: Path):
    with open(path, encoding="utf-8") as f:
        r = csv.DictReader(f)
        return [(row["path"], row["label"]) for row in r]


class ImageList(Dataset):
    def __init__(self, items, label_ids, transform):
        self.items, self.label_ids, self.transform = items, label_ids, transform

    def __len__(self):
        return len(self.items)

    def __getitem__(self, i):
        path, label = self.items[i]
        try:
            im = Image.open(path).convert("RGB")
        except Exception:
            im = Image.new("RGB", (SIZE, SIZE))
        return self.transform(im), self.label_ids[label]
