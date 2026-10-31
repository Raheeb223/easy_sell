"""Checks ml/asr/bn_model.py against sherpa-onnx before any training: same
transcripts as the phone's engine on the model's test recordings, a finite
loss with gradients, and weights written back reproducing the ONNX outputs.

    python -I ml/asr/check_bn_model.py --model DIR
"""
import argparse
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
import onnxruntime as ort
import sentencepiece as spm
import sherpa_onnx
import torch

sys.path.insert(0, str(Path(__file__).parent))
from bn_model import Transducer  # noqa: E402
from prep_bn import fbank, to_16k  # noqa: E402


def read_wav(p: Path):
    with wave.open(str(p)) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768
        return to_16k(x, w.getframerate())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", type=Path, required=True)
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    torch.set_num_threads(2)
    d = a.model
    sp = spm.SentencePieceProcessor(model_file=str(d / "bpe.model"))
    m = Transducer(d)
    print("trainable parameters:", sum(p.numel() for p in m.parameters()) / 1e6, "M")
    rec = sherpa_onnx.OnlineRecognizer.from_transducer(
        tokens=str(d / "tokens.txt"), encoder=str(d / "encoder.onnx"), decoder=str(d / "decoder.onnx"),
        joiner=str(d / "joiner.onnx"), num_threads=2, sample_rate=16000, feature_dim=80)
    same = 0
    wavs = sorted((d / "test_wavs").glob("*.wav"))
    for w in wavs:
        x = read_wav(w)
        s = rec.create_stream()
        s.accept_waveform(16000, x)
        s.accept_waveform(16000, np.zeros(16000 // 3, dtype=np.float32))
        s.input_finished()
        while rec.is_ready(s):
            rec.decode_stream(s)
        ref = rec.get_result(s).strip()
        f = torch.from_numpy(fbank(x).astype(np.float32))[None]
        hyp = sp.decode(m.greedy(f, torch.tensor([f.shape[1]]))[0]).strip()
        same += ref == hyp
        print(f"{w.name}\n  sherpa: {ref}\n  torch:  {hyp}")
    print(f"same transcripts: {same}/{len(wavs)}")

    # Loss and gradients on the first recording, labelled with its transcript.
    x = read_wav(wavs[0])
    f = torch.from_numpy(fbank(x).astype(np.float32))[None]
    ys = torch.tensor([sp.encode(sp.decode(m.greedy(f, torch.tensor([f.shape[1]]))[0]))])
    loss = m.loss(f, torch.tensor([f.shape[1]]), ys, torch.tensor([ys.shape[1]]))
    loss.backward()
    g = sum(float(p.grad.abs().sum()) for p in m.parameters() if p.grad is not None)
    n_grad = sum(1 for p in m.parameters() if p.grad is not None)
    print(f"loss {float(loss):.4f} per frame; grad sum {g:.3e} over {n_grad} tensors")

    # Write the (unchanged) weights back: outputs must equal the originals.
    with tempfile.TemporaryDirectory(dir=str(d.parent)) as t:
        m.save_onnx(Path(t))
        for f_ in ("decoder", "joiner"):
            a_, b_ = ort.InferenceSession(str(d / f"{f_}.onnx")), ort.InferenceSession(str(Path(t) / f"{f_}.onnx"))
            feeds = ({"y": np.array([[3, 7]], dtype=np.int64)} if f_ == "decoder" else
                     {"encoder_out": np.random.randn(2, 512).astype(np.float32),
                      "decoder_out": np.random.randn(2, 512).astype(np.float32)})
            print(f"{f_} roundtrip max diff", float(np.abs(a_.run(None, feeds)[0] - b_.run(None, feeds)[0]).max()))
        ea, eb = ort.InferenceSession(str(d / "encoder.onnx")), ort.InferenceSession(str(Path(t) / "encoder.onnx"))
        feeds = {}
        for i in ea.get_inputs():
            shape = [1 if not isinstance(s, int) else s for s in i.shape]
            feeds[i.name] = (np.zeros(shape, dtype=np.int64) if "int64" in i.type
                             else (np.random.randn(*shape).astype(np.float32) if i.name == "x" else np.zeros(shape, np.float32)))
        print("encoder roundtrip max diff", float(np.abs(ea.run(None, feeds)[0] - eb.run(None, feeds)[0]).max()))
        del ea, eb, a_, b_


if __name__ == "__main__":
    main()
