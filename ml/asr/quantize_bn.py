"""Shrinks the Bangla streaming speech model (sherpa-onnx Zipformer, from
alphacep/vosk-model-small-streaming-bn, Apache-2.0) for the app: int8 weights
for the encoder and joiner, then checks the transcripts against the float
model on the given recordings.

    python -I ml/asr/quantize_bn.py --model DIR --out DIR [WAV ...]
"""
import argparse
import shutil
import sys
import wave
from pathlib import Path

import numpy as np
import sherpa_onnx
from onnxruntime.quantization import QuantType, quantize_dynamic

FILES = ("encoder", "decoder", "joiner")


def recognizer(d: Path, hotwords: str | None = None):
    kw = {}
    if hotwords:
        kw = dict(decoding_method="modified_beam_search", hotwords_file=hotwords,
                  hotwords_score=2.0, modeling_unit="bpe", bpe_vocab=str(d / "unigram_500.vocab"))
    return sherpa_onnx.OnlineRecognizer.from_transducer(
        tokens=str(d / "tokens.txt"), encoder=str(d / "encoder.onnx"),
        decoder=str(d / "decoder.onnx"), joiner=str(d / "joiner.onnx"),
        num_threads=2, sample_rate=16000, feature_dim=80, **kw)


def transcribe(rec, wav: Path):
    with wave.open(str(wav)) as w:
        assert w.getsampwidth() == 2 and w.getnchannels() == 1
        rate = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768
    s = rec.create_stream()
    s.accept_waveform(rate, x)  # sherpa-onnx resamples to 16 kHz
    s.accept_waveform(rate, np.zeros(rate // 2, dtype=np.float32))
    s.input_finished()
    while rec.is_ready(s):
        rec.decode_stream(s)
    return rec.get_result(s).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("wavs", nargs="*", type=Path)
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")  # Bangla transcripts on Windows
    a.out.mkdir(parents=True, exist_ok=True)
    for f in ("tokens.txt", "bpe.model", "decoder.onnx"):
        shutil.copy(a.model / f, a.out / f)
    # Hotwords (product names) are split into word pieces with this vocab. One
    # piece is a line break, which breaks sherpa-onnx's "piece score" lines;
    # no product name contains it, so drop it.
    lines = (a.model / "unigram_500.vocab").read_bytes().decode("utf-8").split("\n")
    good = [l for l in lines if len(l.split("\t")) == 2 and l.split("\t")[0].strip()]
    (a.out / "unigram_500.vocab").write_bytes(("\n".join(good) + "\n").encode("utf-8"))
    print(f"vocab: kept {len(good)} of {len([l for l in lines if l])} lines")
    for f in ("encoder", "joiner"):
        quantize_dynamic(str(a.model / f"{f}.onnx"), str(a.out / f"{f}.onnx"),
                         weight_type=QuantType.QUInt8)
    for f in FILES:
        print(f"{f}: {(a.model / f'{f}.onnx').stat().st_size / 1e6:.1f} MB -> "
              f"{(a.out / f'{f}.onnx').stat().st_size / 1e6:.1f} MB")
    wavs = a.wavs or sorted((a.model / "test_wavs").glob("*.wav"))
    ref, small = recognizer(a.model), recognizer(a.out)
    same = 0
    for w in wavs:
        r, s = transcribe(ref, w), transcribe(small, w)
        same += r == s
        print(f"{w.name}\n  float: {r}\n  int8:  {s}")
    print(f"identical transcripts: {same}/{len(wavs)}")


if __name__ == "__main__":
    main()
