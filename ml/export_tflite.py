"""Export a trained EasySell Vision checkpoint to the TFLite file the app ships.

PyTorch -> ONNX -> onnx2tf (TFLite). Writes float32, float16 and
dynamic-range int8 variants, checks each against PyTorch on real photos, and
copies the smallest one that agrees (cosine >= 0.995 on every photo) to
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
from embedder import SIZE, Embedder, ExportWrapper, read_index  # noqa: E402

ASSET = Path(__file__).resolve().parent.parent / "assets" / "models" / "easysell_vision.tflite"


def app_pixels(path):
    """Exactly what the app feeds the model: short side to SIZE, centre crop,
    RGB 0..255 floats, NHWC."""
    im = Image.open(path).convert("RGB")
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
    out_dir = a.work / "tflite"
    onnx2tf.convert(
        input_onnx_file_path=str(onnx_path),
        output_folder_path=str(out_dir),
        output_dynamic_range_quantized_tflite=True,
        non_verbose=True,
    )

    # Check every variant against PyTorch on real photos.
    try:
        from ai_edge_litert.interpreter import Interpreter
    except ImportError:
        import tensorflow as tf
        Interpreter = tf.lite.Interpreter
    items = read_index(a.data / "grocery_test_index.csv") + read_index(a.data / "rp2k_index.csv")
    random.Random(0).shuffle(items)
    photos = [app_pixels(p) for p, _ in items[:64]]
    with torch.no_grad():
        ref = torch.cat([
            wrapped(torch.from_numpy(x).permute(2, 0, 1)[None]) for x in photos
        ]).numpy()

    results = {}
    for f in sorted(out_dir.glob("*.tflite")):
        it = Interpreter(model_path=str(f), num_threads=4)
        it.allocate_tensors()
        inp, out = it.get_input_details()[0], it.get_output_details()[0]
        cos = []
        for x, r in zip(photos, ref):
            it.set_tensor(inp["index"], x[None])
            it.invoke()
            v = it.get_tensor(out["index"])[0]
            v = v / np.linalg.norm(v)
            cos.append(float(np.dot(v, r)))
        results[f.name] = (f.stat().st_size, min(cos), float(np.mean(cos)))
        print(f"{f.name}: {f.stat().st_size / 1e6:.1f} MB, input {inp['shape']}, "
              f"cosine vs PyTorch min {min(cos):.4f} mean {np.mean(cos):.4f}", flush=True)

    good = [(size, name) for name, (size, mn, _) in results.items() if mn >= 0.995]
    if not good:
        sys.exit("no variant matched PyTorch closely enough; not shipping")
    size, name = min(good)
    ASSET.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(out_dir / name, ASSET)
    print(f"shipped {name} ({size / 1e6:.1f} MB) -> {ASSET}")


if __name__ == "__main__":
    main()
