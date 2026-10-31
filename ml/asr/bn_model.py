"""The app's Bangla streaming transducer as trainable PyTorch, loaded from its
ONNX files (ml/asr/onnx_to_torch.py explains why), with the streaming
forward, an RNN-T loss, greedy decoding and writing the trained weights back
into the same ONNX graphs, so the app runs the result unchanged.
"""
from pathlib import Path

import numpy as np
import onnx
import torch
from onnx import numpy_helper
from onnx2torch import convert
from torch.utils.checkpoint import checkpoint

CHUNK, SHIFT = 77, 64  # frames per encoder call, and the step (sherpa-onnx)
SILENCE = float(np.log(np.finfo(np.float32).eps))  # fbank of digital silence
BLANK = 0


def _load(path: Path):
    """onnx2torch module whose weights (the graph's float initializers) are
    parameters, plus parameter -> initializer name for writing back."""
    m = onnx.load(str(path))
    weights = {i.name for i in m.graph.initializer}
    # onnx2torch wants Clip's bounds as initializers, not Constant nodes.
    clip_in = {x for n in m.graph.node if n.op_type == "Clip" for x in n.input[1:]}
    for n in list(m.graph.node):
        if n.op_type == "Constant" and n.output[0] in clip_in:
            t = onnx.helper.get_attribute_value(n.attribute[0])
            t.name = n.output[0]
            m.graph.initializer.append(t)
            m.graph.node.remove(n)
    module = convert(m)
    by_value = {}
    for init in m.graph.initializer:
        a = numpy_helper.to_array(init)
        if init.name in weights and a.dtype == np.float32 and a.size > 1:
            by_value.setdefault((a.shape, a.tobytes()), []).append(init.name)
    names = {}
    # Conv and Gemm weights come out as ordinary parameters; MatMul and Gather
    # weights as buffers (made parameters below). Both are matched to their
    # initializer by value; a transposed match is a Gemm with transB=0.
    for name, p in module.named_parameters():
        a = p.detach().numpy()
        for key, transposed in (((a.shape, a.tobytes()), False),
                                ((a.T.shape, np.ascontiguousarray(a.T).tobytes()), True)):
            if by_value.get(key):
                names[name] = (by_value[key].pop(0), transposed)
                break
    for sub_name, sub in list(module.named_modules()):
        for name, buf in list(sub.named_buffers(recurse=False)):
            if buf.dtype != torch.float32 or buf.numel() <= 1:
                continue
            key = (tuple(buf.shape), buf.numpy().tobytes())
            if by_value.get(key):
                delattr(sub, name)
                p = torch.nn.Parameter(buf.clone())
                sub.register_parameter(name, p)
                names[f"{sub_name}.{name}" if sub_name else name] = (by_value[key].pop(0), False)
    left = sum(len(v) for v in by_value.values())
    if left:
        raise ValueError(f"{path.name}: {left} weights not found in the PyTorch module")
    return module, names


class Decoder(torch.nn.Module):
    """decoder.onnx by hand (onnx2torch cannot read its Clip): embedding of
    the last 2 tokens (negative = none, zero vector), grouped conv over them,
    ReLU, projection."""

    ONNX = {"emb": "decoder.embedding.weight", "conv": "decoder.conv.weight",
            "proj_w": "decoder_proj.weight", "proj_b": "decoder_proj.bias"}

    def __init__(self, path: Path):
        super().__init__()
        w = {i.name: torch.from_numpy(numpy_helper.to_array(i).copy())
             for i in onnx.load(str(path)).graph.initializer}
        for k, v in self.ONNX.items():
            self.register_parameter(k, torch.nn.Parameter(w[v]))
        self.groups = self.emb.shape[1] // self.conv.shape[1]

    def forward(self, y):  # (N, 2) int64 -> (N, D)
        e = self.emb[y.clamp(min=0)] * (y >= 0).unsqueeze(-1).float()
        h = torch.nn.functional.conv1d(e.transpose(1, 2), self.conv, groups=self.groups)
        return torch.relu(h).squeeze(2) @ self.proj_w.T + self.proj_b


class Transducer(torch.nn.Module):
    def __init__(self, model_dir: Path):
        super().__init__()
        self.dir = Path(model_dir)
        self.encoder, self.enc_names = _load(self.dir / "encoder.onnx")
        self.decoder = Decoder(self.dir / "decoder.onnx")
        self.dec_names = {k: (v, False) for k, v in Decoder.ONNX.items()}
        self.joiner, self.join_names = _load(self.dir / "joiner.onnx")
        enc = onnx.load(str(self.dir / "encoder.onnx"), load_external_data=False)
        self.state_specs = []
        for i in enc.graph.input[1:]:
            dims = [d.dim_value if d.dim_value else -1 for d in i.type.tensor_type.shape.dim]
            dt = torch.int64 if i.type.tensor_type.elem_type == onnx.TensorProto.INT64 else torch.float32
            self.state_specs.append((dims, dt))

    def init_states(self, n, device):
        return [torch.zeros([n if d == -1 else d for d in dims], dtype=dt, device=device)
                for dims, dt in self.state_specs]

    def encode(self, feats, frames):
        """Streaming encoder over whole utterances, chunk by chunk as on the
        phone. feats (B, F, 80); frames (B,) real lengths. The tail is padded
        with silence, as the app flushes the last words.
        Returns (B, T, 512) and output lengths (B,)."""
        b, f, _ = feats.shape
        need = f + 32
        chunks = max(1, -(-(need - (CHUNK - SHIFT)) // SHIFT))
        total = (chunks - 1) * SHIFT + CHUNK
        x = torch.full((b, total, 80), SILENCE, device=feats.device, dtype=feats.dtype)
        x[:, :f] = feats
        pos = torch.arange(f, device=feats.device)[None, :]
        x[:, :f][pos.expand(b, f) >= frames[:, None]] = SILENCE
        states = self.init_states(b, feats.device)
        outs = []
        for c in range(chunks):
            out = self.encoder(x[:, c * SHIFT: c * SHIFT + CHUNK], *states)
            outs.append(out[0])
            states = list(out[1:])
        enc = torch.cat(outs, 1)
        lens = torch.clamp((frames + 32) // 4, max=enc.shape[1])
        return enc, lens

    def decode_inputs(self, ys, ulens):
        """(B, U+1, 2) decoder contexts: [-1, blank] then the last 2 tokens."""
        b, u = ys.shape
        hist = torch.cat([torch.full((b, 1), -1, dtype=ys.dtype, device=ys.device),
                          torch.full((b, 1), BLANK, dtype=ys.dtype, device=ys.device), ys], 1)
        return torch.stack([hist[:, :-1], hist[:, 1:]], 2)[:, : u + 1]

    def loss(self, feats, frames, ys, ulens, slab=24):
        """RNN-T loss (nats per output frame). ys (B, U) padded with 0."""
        enc, tlens = self.encode(feats, frames)
        b, t, _ = enc.shape
        u1 = ys.shape[1] + 1
        dec = self.decoder(self.decode_inputs(ys, ulens).reshape(-1, 2)).reshape(b, u1, -1)
        labels = torch.cat([ys, torch.zeros_like(ys[:, :1])], 1)  # (B, U+1)

        def joint(e):  # (B, s, D) -> (B, s, U+1, 2) log p(blank), log p(next label)
            s = e.shape[1]
            h = (e[:, :, None, :] + dec[:, None, :, :]).reshape(-1, dec.shape[-1])
            logp = self._joiner_tail(h).log_softmax(-1).reshape(b, s, u1, -1)
            lab = logp.gather(3, labels[:, None, :, None].expand(b, s, u1, 1))
            return torch.cat([logp[..., BLANK:BLANK + 1], lab], 3)

        parts = [checkpoint(joint, enc[:, i: i + slab], use_reentrant=False) for i in range(0, t, slab)]
        lp = torch.cat(parts, 1).float()  # (B, T, U+1, 2)
        blank, emit = lp[..., 0], lp[..., 1]
        neg = -1e4
        a = torch.full((b, u1), neg, device=enc.device)
        a[:, 0] = 0
        alphas = []
        for ti in range(t):
            c = torch.cat([torch.zeros_like(emit[:, ti, :1]), emit[:, ti, :-1].cumsum(1)], 1)
            row = c + torch.logcumsumexp(a - c, 1)
            alphas.append(row)
            a = row + blank[:, ti]
        alphas = torch.stack(alphas, 1)  # (B, T, U+1)
        bi = torch.arange(b, device=enc.device)
        final = alphas[bi, tlens - 1, ulens] + blank[bi, tlens - 1, ulens]
        return -final.sum() / tlens.sum()  # per output frame: stable across lengths

    def _joiner_tail(self, h):
        """The joiner without its add: tanh then the output layer (the ONNX
        joiner is Add -> Tanh -> Gemm)."""
        w = dict(self.joiner.named_parameters())
        weight = next(v for k, v in w.items() if v.dim() == 2)
        bias = next(v for k, v in w.items() if v.dim() == 1)
        return torch.tanh(h) @ (weight.T if weight.shape[0] == 500 else weight) + bias

    @torch.no_grad()
    def greedy(self, feats, frames, max_sym=3):
        """Greedy transducer search, as sherpa-onnx's greedy_search."""
        enc, tlens = self.encode(feats, frames)
        out = []
        for i in range(enc.shape[0]):
            hyp = [-1, BLANK]
            dec = self.decoder(torch.tensor([hyp[-2:]], device=enc.device))
            for ti in range(int(tlens[i])):
                for _ in range(max_sym):
                    k = int(self._joiner_tail(enc[i, ti][None] + dec).argmax(-1))
                    if k == BLANK:
                        break
                    hyp.append(k)
                    dec = self.decoder(torch.tensor([hyp[-2:]], device=enc.device))
            out.append(hyp[2:])
        return out

    def save_onnx(self, out_dir: Path):
        """The original ONNX graphs with this model's weights."""
        out_dir.mkdir(parents=True, exist_ok=True)
        for f, mod, names in (("encoder", self.encoder, self.enc_names),
                              ("decoder", self.decoder, self.dec_names),
                              ("joiner", self.joiner, self.join_names)):
            m = onnx.load(str(self.dir / f"{f}.onnx"))
            params = dict(mod.named_parameters())
            new = {}
            for k, (init_name, transposed) in names.items():
                a = params[k].detach().cpu().numpy().astype(np.float32)
                new[init_name] = np.ascontiguousarray(a.T) if transposed else a
            for init in m.graph.initializer:
                if init.name in new:
                    init.CopyFrom(numpy_helper.from_array(new[init.name], init.name))
            onnx.save(m, str(out_dir / f"{f}.onnx"))
