"""Bangla speech training data for the app's offline recogniser: reads the
recordings straight out of the downloaded archives, normalises the text to
the model's word pieces, and stores 80-dim fbank features computed exactly as
sherpa-onnx does on the phone (kaldi-native-fbank, same options), as float16.

Sources (all allow commercial use; credited in the app's licences page):
  slr53   OpenSLR 53, Bangladesh read speech        CC BY-SA 4.0
  slr37   OpenSLR 37, Bangladesh + India studio     CC BY-SA 4.0
  fleurs  Google FLEURS bn_in                       CC BY 4.0

Held out for testing (never trained on): 40 SLR53 speakers, FLEURS test.

    python -I ml/asr/prep_bn.py --raw DIR --bpe bpe.model --out DIR [--only slr37 fleurs]

Writes per source and split: <name>.f16 (all frames back to back) and
<name>.jsonl (offset, frames, tokens, text, audio location).
"""
import argparse
import io
import json
import re
import sys
import tarfile
import zipfile
from math import gcd
from multiprocessing import Pool
from pathlib import Path

import kaldi_native_fbank as knf
import numpy as np
import sentencepiece as spm
import soundfile as sf
from scipy.signal import resample_poly

RATE = 16000
_sp = None
_bpe = None


def fbank(samples: np.ndarray) -> np.ndarray:
    """sherpa-onnx's online features: 25 ms / 10 ms povey frames, 80 mel bins
    20 Hz..(8000-400) Hz, no dither, no snip, samples in -1..1."""
    o = knf.FbankOptions()
    o.frame_opts.samp_freq = RATE
    o.frame_opts.dither = 0
    o.frame_opts.snip_edges = False
    o.mel_opts.num_bins = 80
    o.mel_opts.low_freq = 20
    o.mel_opts.high_freq = -400
    f = knf.OnlineFbank(o)
    f.accept_waveform(RATE, samples.tolist())
    f.input_finished()
    return np.stack([f.get_frame(i) for i in range(f.num_frames_ready)]) if f.num_frames_ready else np.zeros((0, 80))


_NUKTA = {"য়": "য়", "ড়": "ড়", "ঢ়": "ঢ়"}
_KEEP = re.compile(r"[^ঀ-ৣৰ-৾ ]")


def normalise(text: str):
    """Bangla letters and spaces only, nukta letters precomposed as in the
    model's word pieces. None if the sentence has digits or Latin (the model
    cannot spell them, and guessing how they were read aloud adds errors)."""
    if re.search(r"[0-9A-Za-z০-৯]", text):
        return None
    for a, b in _NUKTA.items():
        text = text.replace(a, b)
    text = text.replace("‌", "").replace("‍", "")
    text = " ".join(_KEEP.sub(" ", text).split())
    return text or None


def to_16k(x: np.ndarray, sr: int) -> np.ndarray:
    if x.ndim > 1:
        x = x.mean(1)
    if sr != RATE:
        g = gcd(sr, RATE)
        x = resample_poly(x, RATE // g, sr // g)
    return x.astype(np.float32)


def _init(bpe):
    global _sp
    _sp = spm.SentencePieceProcessor(model_file=bpe)


def _work(item):
    """(key, audio bytes, text, where) -> (key, fbank, tokens, text, where, seconds) or None."""
    key, data, text, where = item
    text = normalise(text)
    if text is None:
        return None
    toks = _sp.encode(text)
    if not toks or _sp.unk_id() in toks:
        return None
    try:
        x, sr = sf.read(io.BytesIO(data), dtype="float32")
    except Exception:
        return None
    x = to_16k(x, sr)
    secs = len(x) / RATE
    if not 0.8 <= secs <= 20 or len(toks) > secs * 12:
        return None
    return key, fbank(x).astype(np.float16), toks, text, where, secs


def slr53(raw: Path):
    """(split, key, bytes, text, where). Speaker-disjoint test set: the 40
    speakers whose ids sort first."""
    d = raw / "slr53"
    rows = [l.split("\t") for l in (d / "utt_spk_text.tsv").read_text(encoding="utf-8").splitlines()]
    meta = {r[0]: (r[1], r[2]) for r in rows if len(r) == 3}
    test_spk = set(sorted({s for s, _ in meta.values()})[:40])
    for z in sorted(d.glob("asr_bengali_*.zip")):
        try:
            zf = zipfile.ZipFile(z)
        except zipfile.BadZipFile:
            print(f"skip incomplete {z.name}", flush=True)
            continue
        for n in zf.namelist():
            utt = Path(n).stem
            if not n.endswith(".flac") or utt not in meta:
                continue
            spk, text = meta[utt]
            yield ("test" if spk in test_spk else "train"), utt, zf.read(n), text, f"{z.name}:{n}"


def slr37(raw: Path):
    for name in ("bn_bd", "bn_in"):
        zf = zipfile.ZipFile(raw / "slr37" / f"{name}.zip")
        lines = zf.read("line_index.tsv").decode("utf-8").splitlines()
        for l in lines:
            p = l.split("\t")
            if len(p) < 2:
                continue
            n = f"wavs/{p[0].strip()}.wav"
            try:
                data = zf.read(n)
            except KeyError:
                continue
            yield "train", f"{name}_{p[0].strip()}", data, p[-1], f"{name}.zip:{n}"


def fleurs(raw: Path):
    d = raw / "fleurs_bn"
    for split in ("train", "dev", "test"):
        text = {}
        for l in (d / f"{split}.tsv").read_text(encoding="utf-8").splitlines():
            p = l.split("\t")
            if len(p) > 3:
                text[p[1]] = p[3]
        with tarfile.open(d / f"{split}.tar.gz") as t:
            for m in t:
                name = Path(m.name).name
                if m.isfile() and name in text:
                    yield ("test" if split == "test" else "train"), name, t.extractfile(m).read(), text[name], f"{split}.tar.gz:{m.name}"


SOURCES = {"slr53": slr53, "slr37": slr37, "fleurs": fleurs}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", type=Path, required=True)
    ap.add_argument("--bpe", required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--only", nargs="*", default=list(SOURCES))
    ap.add_argument("--workers", type=int, default=3)
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    a.out.mkdir(parents=True, exist_ok=True)
    for src in a.only:
        files, counts = {}, {}
        items = ((f"{src}_{split}", key, data, text, where) for split, key, data, text, where in SOURCES[src](a.raw))
        # The split travels in the key's slot so the workers stay simple.
        packed = (((name, key), data, text, where) for name, key, data, text, where in items)
        with Pool(a.workers, initializer=_init, initargs=(a.bpe,)) as pool:
            for r in pool.imap(_work, packed, chunksize=16):
                if r is None:
                    continue
                (name, key), feats, toks, text, where, secs = r
                if name not in files:
                    files[name] = (open(a.out / f"{name}.f16", "wb"), open(a.out / f"{name}.jsonl", "w", encoding="utf-8"), [0])
                    counts[name] = [0, 0.0]
                fb, fj, off = files[name]
                fb.write(feats.tobytes())
                fj.write(json.dumps({"key": key, "offset": off[0], "frames": len(feats), "tokens": toks,
                                     "text": text, "where": where}, ensure_ascii=False) + "\n")
                off[0] += len(feats)
                counts[name][0] += 1
                counts[name][1] += secs
                if counts[name][0] % 2000 == 0:
                    print(f"{name}: {counts[name][0]} utts, {counts[name][1] / 3600:.1f} h", flush=True)
        for fb, fj, _ in files.values():
            fb.close()
            fj.close()
        for name, (n, s) in counts.items():
            print(f"DONE {name}: {n} utts, {s / 3600:.1f} h", flush=True)


if __name__ == "__main__":
    main()
