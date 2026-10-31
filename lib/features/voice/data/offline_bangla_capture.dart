import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../../core/matching/bangla_translit.dart';
import 'speech_capture.dart';

/// Bangla speech to text entirely on the phone: a streaming Zipformer
/// (sherpa-onnx, from alphacep/vosk-model-small-streaming-bn, Apache-2.0;
/// int8 via ml/asr/quantize_bn.py). Android's own recogniser has no offline
/// Bangla on most phones (Pixel: error_language_not_supported), so without
/// this Bangla voice needed the internet and Google's servers.
///
/// The shop's product names and learned phrases are passed as hotwords, so
/// the recogniser prefers them over similar-sounding words.
class OfflineBanglaCapture implements SpeechCapture {
  static const _asset = 'assets/models/asr_bn';
  static const _files = [
    'encoder.onnx',
    'decoder.onnx',
    'joiner.onnx',
    'tokens.txt',
    'unigram_500.vocab',
  ];
  static const _rate = 16000;

  /// Same caps as the Android path: the longest sale sentence, and how long
  /// to wait for the first word.
  static const listenFor = Duration(seconds: 20);
  static const silenceFor = Duration(seconds: 8);

  final _recorder = AudioRecorder();
  sherpa.OnlineRecognizer? _recognizer;
  Future<sherpa.OnlineRecognizer>? _loading;
  sherpa.OnlineStream? _stream;
  StreamSubscription<Uint8List>? _mic;
  var _partials = StreamController<String>.broadcast();
  var _levels = StreamController<double>.broadcast();
  Completer<Heard>? _done;
  Timer? _cap;
  DateTime _startedAt = DateTime.now();
  String _text = '';
  int? _oddByte;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> warmUp() async {
    try {
      await _load();
    } catch (_) {}
  }

  /// Copies the model out of the APK once (sherpa-onnx reads files) and
  /// creates the recogniser. Shared by concurrent callers.
  Future<sherpa.OnlineRecognizer> _load() =>
      _loading ??= () async {
        final dir = Directory('${(await getApplicationSupportDirectory()).path}/asr_bn');
        await dir.create(recursive: true);
        for (final f in _files) {
          final data = await rootBundle.load('$_asset/$f');
          final file = File('${dir.path}/$f');
          if (!await file.exists() || await file.length() != data.lengthInBytes) {
            await file.writeAsBytes(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
              flush: true,
            );
          }
        }
        sherpa.initBindings();
        final p = dir.path;
        return _recognizer = sherpa.OnlineRecognizer(
          sherpa.OnlineRecognizerConfig(
            model: sherpa.OnlineModelConfig(
              transducer: sherpa.OnlineTransducerModelConfig(
                encoder: '$p/encoder.onnx',
                decoder: '$p/decoder.onnx',
                joiner: '$p/joiner.onnx',
              ),
              tokens: '$p/tokens.txt',
              numThreads: 2,
              debug: false,
              modelType: 'zipformer2',
              modelingUnit: 'bpe',
              bpeVocab: '$p/unigram_500.vocab',
            ),
            // Beam search is needed for hotwords, and fixed real errors in
            // testing ("ঘণ্টায় ঘণ্টায়").
            decodingMethod: 'modified_beam_search',
            hotwordsScore: 2.0,
            // End the sentence 1 s after the shopkeeper stops talking.
            rule1MinTrailingSilence: 2.4,
            rule2MinTrailingSilence: 1.0,
            rule3MinUtteranceLength: 20,
          ),
        );
      }();

  /// Hotwords the Bangla word pieces can spell: Bangla-script names and
  /// phrases, one per entry ("/"-separated for sherpa-onnx).
  @visibleForTesting
  static String hotwordsOf(List<String> hints) => hints
      .map((h) => h.replaceAll(RegExp(r'[/\n]'), ' ').trim())
      .where((h) => h.isNotEmpty && h.length <= 40 && isBangla(h))
      .take(200)
      .join('/');

  @override
  Future<void> start({
    required String localeId,
    List<String> hints = const [],
  }) async {
    final rec = await _load();
    _partials = StreamController<String>.broadcast();
    _levels = StreamController<double>.broadcast();
    _done = Completer<Heard>();
    _text = '';
    _oddByte = null;
    final hotwords = hotwordsOf(hints);
    _stream = hotwords.isEmpty ? rec.createStream() : rec.createStream(hotwords: hotwords);
    final audio = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _rate,
        numChannels: 1,
        noiseSuppress: true,
      ),
    );
    _startedAt = DateTime.now();
    _cap = Timer(listenFor, () => unawaited(stop()));
    _mic = audio.listen(_onAudio, onError: (_) => _finish());
    debugPrint('voice: offline bn listen, ${hotwords.isEmpty ? 0 : hotwords.split('/').length} hotwords');
  }

  void _onAudio(Uint8List bytes) {
    final rec = _recognizer, stream = _stream;
    if (rec == null || stream == null || (_done?.isCompleted ?? true)) return;
    final samples = _toFloat(bytes);
    if (samples.isEmpty) return;
    var sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    final db = 10 * math.log(sum / samples.length + 1e-10) / math.ln10;
    if (!_levels.isClosed) _levels.add(((db + 50) / 40).clamp(0.0, 1.0));

    stream.acceptWaveform(samples: samples, sampleRate: _rate);
    while (rec.isReady(stream)) {
      rec.decode(stream);
    }
    final text = rec.getResult(stream).text.trim();
    if (text != _text) {
      _text = text;
      if (!_partials.isClosed) _partials.add(text);
    }
    if (rec.isEndpoint(stream)) {
      if (_text.isNotEmpty) {
        unawaited(stop());
      } else if (DateTime.now().difference(_startedAt) > silenceFor) {
        _finish();
      } else {
        rec.reset(stream);
      }
    }
  }

  /// 16-bit little-endian PCM -> -1..1 floats. A chunk can end mid-sample;
  /// that byte is carried into the next chunk.
  Float32List _toFloat(Uint8List bytes) {
    var b = bytes;
    if (_oddByte case final int carry) {
      b = Uint8List(bytes.length + 1)
        ..[0] = carry
        ..setRange(1, bytes.length + 1, bytes);
      _oddByte = null;
    }
    if (b.length.isOdd) {
      _oddByte = b.last;
      b = Uint8List.sublistView(b, 0, b.length - 1);
    }
    final pcm = ByteData.sublistView(b);
    final out = Float32List(b.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = pcm.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  @override
  Stream<String> get partials => _partials.stream;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<Heard> get done => _done?.future ?? Future.value(const Heard(''));

  @override
  Future<Heard> stop() async {
    final rec = _recognizer, stream = _stream;
    await _stopMic();
    if (rec != null && stream != null && !(_done?.isCompleted ?? true)) {
      // Flush the last words: a little silence, then end of input.
      stream.acceptWaveform(samples: Float32List(_rate ~/ 3), sampleRate: _rate);
      stream.inputFinished();
      while (rec.isReady(stream)) {
        rec.decode(stream);
      }
      _text = rec.getResult(stream).text.trim();
    }
    _finish();
    return done;
  }

  @override
  Future<void> cancel() async {
    _text = '';
    await _stopMic();
    _finish();
  }

  Future<void> _stopMic() async {
    _cap?.cancel();
    _cap = null;
    await _mic?.cancel();
    _mic = null;
    try {
      await _recorder.stop();
    } catch (_) {}
  }

  void _finish() {
    final c = _done;
    if (c == null || c.isCompleted) return;
    _stream?.free();
    _stream = null;
    unawaited(_stopMic());
    debugPrint('voice: offline bn done, ${_text.length} chars');
    c.complete(Heard(_text));
  }
}

/// Bangla goes to the offline model on the phone; English (and Bangla, if
/// that model cannot load) to Android's recogniser.
class HybridSpeechCapture implements SpeechCapture {
  HybridSpeechCapture(this._bangla, this._device);

  final OfflineBanglaCapture _bangla;
  final SpeechCapture _device;
  late SpeechCapture _active = _device;

  @override
  Future<bool> hasPermission() async =>
      await _bangla.hasPermission() && await _device.hasPermission();

  @override
  Future<void> warmUp() async {
    await Future.wait([_bangla.warmUp(), _device.warmUp()]);
  }

  @override
  Future<void> start({
    required String localeId,
    List<String> hints = const [],
  }) async {
    if (localeId.toLowerCase().startsWith('bn')) {
      try {
        _active = _bangla;
        return await _bangla.start(localeId: localeId, hints: hints);
      } catch (e) {
        debugPrint('voice: offline bn failed ($e); using Android');
      }
    }
    _active = _device;
    await _device.start(localeId: localeId, hints: hints);
  }

  @override
  Stream<String> get partials => _active.partials;

  @override
  Stream<double> get levels => _active.levels;

  @override
  Future<Heard> get done => _active.done;

  @override
  Future<Heard> stop() => _active.stop();

  @override
  Future<void> cancel() => _active.cancel();
}
