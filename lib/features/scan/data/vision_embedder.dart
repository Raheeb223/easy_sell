import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// EasySell Vision (design §5a): the app's own product-fingerprint model,
/// trained for this app on retail products (see `ml/`). It turns a photo into
/// [dim] numbers; two photos of the same product give nearby fingerprints.
///
/// The model runs in a background isolate so a scan never stalls the UI.
class VisionEmbedder {
  VisionEmbedder._(this._send, this._isolate);

  /// Bump with the model file; stored on every fingerprint so a new model
  /// re-embeds the saved thumbnails instead of mixing two spaces.
  static const modelId = 'esv1';
  static const asset = 'assets/models/easysell_vision.tflite';
  static const size = 224;
  static const dim = 256;

  final SendPort _send;
  final Isolate _isolate;
  int _seq = 0;
  final _pending = <int, Completer<Float32List>>{};
  late final StreamSubscription<dynamic> _sub;

  static Future<VisionEmbedder> load() async {
    final model = await rootBundle.load(asset);
    final port = ReceivePort();
    final isolate = await Isolate.spawn(
      _worker,
      (port.sendPort, TransferableTypedData.fromList([model.buffer.asUint8List()])),
      debugName: 'EasySellVision',
    );
    final events = port.asBroadcastStream();
    final send = await events.first as SendPort;
    final e = VisionEmbedder._(send, isolate);
    e._sub = events.listen(e._onReply);
    return e;
  }

  void _onReply(dynamic msg) {
    final (int id, Object result) = msg as (int, Object);
    final c = _pending.remove(id);
    if (c == null) return;
    if (result is String) {
      c.completeError(StateError(result));
    } else {
      c.complete(result as Float32List);
    }
  }

  /// Fingerprint of a JPEG photo: the centre square, like the scan frame.
  Future<Embedding> embedJpeg(Uint8List jpeg) async {
    final rgba = await _decodeSquare(jpeg);
    return Embedding(await _run(rgba), rgba);
  }

  /// Runs the model once on a blank frame: the first run sets up the CPU
  /// kernels, so doing it before the first scan keeps that scan fast.
  Future<void> warmUp() => _run(Uint8List(size * size * 4));

  Future<Float32List> _run(Uint8List rgba) {
    final id = _seq++;
    final c = Completer<Float32List>();
    _pending[id] = c;
    _send.send((id, TransferableTypedData.fromList([rgba])));
    return c.future;
  }

  void dispose() {
    _sub.cancel();
    _isolate.kill(priority: Isolate.immediate);
    for (final c in _pending.values) {
      c.completeError(StateError('disposed'));
    }
    _pending.clear();
  }

  /// Decodes with the platform codec (native, off the UI thread), scaled so
  /// the short side is [size], then crops the centre square. Returns RGBA.
  static Future<Uint8List> _decodeSquare(Uint8List jpeg) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(jpeg);
    final desc = await ui.ImageDescriptor.encoded(buffer);
    final s = size / math.min(desc.width, desc.height);
    final codec = await desc.instantiateCodec(
      targetWidth: math.max(size, (desc.width * s).round()),
      targetHeight: math.max(size, (desc.height * s).round()),
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width, h = image.height;
    image.dispose();
    codec.dispose();
    desc.dispose();
    buffer.dispose();
    final src = data!.buffer.asUint8List();
    final x0 = (w - size) ~/ 2, y0 = (h - size) ~/ 2;
    final out = Uint8List(size * size * 4);
    for (var y = 0; y < size; y++) {
      final from = ((y0 + y) * w + x0) * 4;
      out.setRange(y * size * 4, (y + 1) * size * 4, src, from);
    }
    return out;
  }
}

/// A fingerprint plus the 224px frame it came from (saved as a thumbnail so a
/// future model can re-embed without new photos).
class Embedding {
  Embedding(this.vector, this._rgba);
  final Float32List vector;
  final Uint8List _rgba;
  Future<Uint8List>? _thumb;

  /// The frame as a JPEG. Encoded only when the fingerprint is saved, in the
  /// background, so it never slows a scan.
  Future<Uint8List> thumbJpeg() => _thumb ??= Isolate.run(() => _encodeThumb(_rgba));
}

Uint8List _encodeThumb(Uint8List rgba) => img.encodeJpg(
      img.Image.fromBytes(
        width: VisionEmbedder.size,
        height: VisionEmbedder.size,
        bytes: rgba.buffer,
        numChannels: 4,
      ),
      quality: 80,
    );

/// Background isolate: owns the TFLite interpreter.
Future<void> _worker((SendPort, TransferableTypedData) args) async {
  final (reply, modelData) = args;
  final port = ReceivePort();
  reply.send(port.sendPort);

  Interpreter? interpreter;
  String? loadError;
  try {
    final options = InterpreterOptions()..threads = 4;
    interpreter = Interpreter.fromBuffer(
      modelData.materialize().asUint8List(),
      options: options,
    );
    interpreter.allocateTensors();
  } catch (e) {
    loadError = 'model load failed: $e';
  }

  const size = VisionEmbedder.size;
  final input = Float32List(size * size * 3);
  final output = Float32List(VisionEmbedder.dim);

  await for (final msg in port) {
    final (int id, TransferableTypedData data) = msg as (int, TransferableTypedData);
    if (interpreter == null) {
      reply.send((id, loadError ?? 'no model'));
      continue;
    }
    try {
      final rgba = data.materialize().asUint8List();
      for (var i = 0, j = 0; i < size * size; i++, j += 4) {
        input[i * 3] = rgba[j].toDouble();
        input[i * 3 + 1] = rgba[j + 1].toDouble();
        input[i * 3 + 2] = rgba[j + 2].toDouble();
      }
      interpreter.getInputTensor(0).setTo(input.buffer.asUint8List());
      interpreter.invoke();
      interpreter.getOutputTensor(0).copyTo(output.buffer.asUint8List());
      final v = Float32List.fromList(output);
      _normalize(v);
      reply.send((id, v));
    } catch (e) {
      reply.send((id, 'inference failed: $e'));
    }
  }
}

void _normalize(Float32List v) {
  var s = 0.0;
  for (final x in v) {
    s += x * x;
  }
  final n = math.sqrt(s);
  if (n == 0) return;
  for (var i = 0; i < v.length; i++) {
    v[i] = v[i] / n;
  }
}
