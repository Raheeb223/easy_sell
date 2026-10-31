"""Export a trained EasySell Vision checkpoint to the TFLite file the app ships.

PyTorch -> ONNX -> onnx2tf (TFLite). Writes float32, float16 and
dynamic-range int8 variants, checks each against PyTorch on real shop photos
(few-shot recognition, as in the app), and copies the smallest one that
recognises as well (top-1 within 0.5 points) to
assets/models/easysell_vision.tflite.

    python -I ml/export_tflite.py --checkpoint G:/Easy_sell/ml_runs/v1/best.pt \
        --data G:/Easy_sell/ml_data --work G:/Easy_sell/ml_runs/v1/export
"""
import argparse
import random
import shutil
import sys
from pathlib import Path

import numpy as np
import torch
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from embedder import SIZE, Embedder, ExportWrapper  # noqa: E402
from eval_fewshot import fewshot  # noqa: E402
from packs import Pack, decode  # noqa: E402

ASSET = Path(__file__).resolve().parent.parent / "assets" / "models" / "easysell_vision.tflite"


def labeled_photos(data: Path, stem: str, cap: int):
    """App-ready pixels (uint8, to keep RAM low) and label ids for whole
    products of a pack, in random product order, up to [cap] photos. Read from
    the pack: the loose files are gone once packed."""
    p = Pack(data, stem)
    by = {}
    for i, l in enumerate(p.labels):
        by.setdefault(l, []).append(i)
    labels = sorted(by)
    random.Random(0).shuffle(labels)
    photos, ys = [], []
    with open(p.path, "rb") as f:
        for y, l in enumerate(labels):
            if len(photos) + len(by[l]) > cap:
                continue
            for i in by[l]:
                f.seek(int(p.offsets[i]))
                photos.append(app_pixels(decode(f.read(int(p.lengths[i])))).astype(np.uint8))
                ys.append(y)
    return photos, ys


def app_pixels(im):
    """Exactly what the app feeds the model: short side to SIZE, centre crop,
    RGB 0..255 floats, NHWC."""
    w, h = im.size
    s = SIZE / min(w, h)
    im = im.resize((max(SIZE, round(w * s)), max(SIZE, round(h * s))), Image.BILINEAR)
    w, h = im.size
    x0, y0 = (w - SIZE) // 2, (h - SIZE) // 2
    return np.asarray(im.crop((x0, y0, x0 + SIZE, y0 + SIZE)), dtype=np.float32)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--checkpoint", type=Path, required=True)
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--work", type=Path, required=True)
    a = ap.parse_args()
    a.work.mkdir(parents=True, exist_ok=True)

    ck = torch.load(a.checkpoint, map_location="cpu")
    model = Embedder(ck["backbone"], pretrained=False)
    model.load_state_dict(ck["model"])
    wrapped = ExportWrapper(model).eval()

    onnx_path = a.work / "easysell_vision.onnx"
    torch.onnx.export(
        wrapped, torch.zeros(1, 3, SIZE, SIZE), str(onnx_path),
        input_names=["pixels"], output_names=["embedding"], opset_version=17,
        dynamo=False,
    )

    import onnx2tf
    # onnx2tf downloads a sample-image .npy from GitHub for its self-check;
    # when that request returns an error page, np.load fails ("pickled
    # data"). The sample only feeds the check, so supply one locally.
    sys.modules["onnx2tf.onnx2tf"].download_test_image_data = lambda: (
        np.random.default_rng(0).random((20, 128, 128, 3), dtype=np.float32))
    out_dir = a.work / "tflite"
    onnx2tf.convert(
        input_onnx_file_path=str(onnx_path),
        output_folder_path=str(out_dir),
        output_dynamic_range_quantized_tflite=True,
        non_verbose=True,
    )

    # Check every variant against PyTorch on real shop photos, by what the
    # app does with it: few-shot recognition in 200-product shops. A smaller
    # (quantised) variant ships only if it recognises as well (top-1 within
    # 0.5 points) -- per-photo cosine alone rejected int8 models that rank
    # products just as well.
    try:
        from ai_edge_litert.interpreter import Interpreter
    except ImportError:
        import tensorflow as tf
        Interpreter = tf.lite.Interpreter
    sets = {s: labeled_photos(a.data, f"{s}_index", 1500) for s in ("grocery_test", "rp2k")}

    def score(embed_one):
        out = {}
        for s, (photos, ys) in sets.items():
            e = torch.nn.functional.normalize(
                torch.from_numpy(np.stack([embed_one(x) for x in photos])), dim=1)
            out[s] = (e, fewshot(e, torch.tensor(ys))["shop"][0])
        return out

    with torch.no_grad():
        ref = score(lambda x: wrapped(
            torch.from_numpy(x.astype(np.float32)).permute(2, 0, 1)[None])[0].numpy())
    ref_top1 = np.mean([t for _, t in ref.values()])
    print(f"PyTorch: shop200 top1 {ref_top1:.4f}", flush=True)

    results = {}
    for f in sorted(out_dir.glob("*.tflite")):
        it = Interpreter(model_path=str(f), num_threads=4)
        it.allocate_tensors()
        inp, out = it.get_input_details()[0], it.get_output_details()[0]

        def run(x):
            it.set_tensor(inp["index"], x.astype(np.float32)[None])
            it.invoke()
            return it.get_tensor(out["index"])[0].copy()

        got = score(run)
        top1 = np.mean([t for _, t in got.values()])
        cos = torch.cat([(got[s][0] * ref[s][0]).sum(1) for s in sets])
        results[f.name] = (f.stat().st_size, top1, float(cos.mean()))
        print(f"{f.name}: {f.stat().st_size / 1e6:.1f} MB, input {inp['shape']}, "
              f"shop200 top1 {top1:.4f} (PyTorch {ref_top1:.4f}), "
              f"cosine vs PyTorch min {cos.min():.4f} mean {cos.mean():.4f}", flush=True)

    good = [(size, name) for name, (size, top1, mean_cos) in results.items()
            if top1 >= ref_top1 - 0.005 and mean_cos >= 0.97]
    if not good:
        sys.exit("no variant recognised as well as PyTorch; not shipping")
    size, name = min(good)
    ASSET.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(out_dir / name, ASSET)
    print(f"shipped {name} ({size / 1e6:.1f} MB) -> {ASSET}")


if __name__ == "__main__":
    main()
