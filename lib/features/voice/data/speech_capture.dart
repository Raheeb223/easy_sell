import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// What one listening session heard: the best transcript and the
/// recogniser's other guesses (the parser picks whichever matches the shop's
/// products best).
class Heard {
  const Heard(this.text, [this.alternatives = const []]);
  final String text;
  final List<String> alternatives;
  bool get isEmpty => text.trim().isEmpty;
}

/// Speech to text on the phone (design §6), behind a seam so the controller
/// is testable. Replaces recording audio and uploading it to Gemini: the
/// words appear while the shopkeeper speaks, and nothing leaves the phone.
abstract class SpeechCapture {
  Future<bool> hasPermission();

  /// Readies the recogniser ahead of the first tap, if the mic is already
  /// allowed (it never asks for permission).
  Future<void> warmUp();

  /// Starts listening in [localeId] (`bn_BD`, `en_US`). [hints] are product
  /// names and learned words the recogniser should expect.
  Future<void> start({
    required String localeId,
    List<String> hints = const [],
  });

  /// Words so far, updated live.
  Stream<String> get partials;

  /// Loudness 0..1 for the level meter.
  Stream<double> get levels;

  /// Completes when the recogniser decides the speaker has finished (a pause
  /// or the time cap), with what it heard.
  Future<Heard> get done;

  /// Stops now and returns what was heard.
  Future<Heard> stop();

  Future<void> cancel();
}

class DeviceSpeechCapture implements SpeechCapture {
  final _stt = SpeechToText();
  bool _ready = false;
  var _partials = StreamController<String>.broadcast();
  var _levels = StreamController<double>.broadcast();
  Completer<Heard>? _done;
  SpeechRecognitionResult? _last;
  String? _localeId;
  List<String> _hints = const [];
  bool _triedOnDevice = false;
  bool _fellBack = false;

  /// Max length of one sale sentence, and the pause that ends it. Android's
  /// recogniser usually ends the sentence sooner by itself; this is the cap
  /// on waiting in silence, kept short so the sale is read quickly.
  static const listenFor = Duration(seconds: 20);
  static const pauseFor = Duration(seconds: 2);

  /// Asked-for locale -> the recogniser's spelling. Listing the locales is a
  /// slow round trip on Android, so it happens once.
  final _locales = <String, String>{};

  Future<bool> _init() async {
    if (_ready) return true;
    _ready = await _stt.initialize(onError: _onError, onStatus: _onStatus);
    return _ready;
  }

  @override
  Future<bool> hasPermission() => _init();

  @override
  Future<void> warmUp() async {
    try {
      if (!await _stt.hasPermission) return;
      if (!await _init()) return;
      await _bestLocale('bn_BD');
      await _bestLocale('en_US');
    } catch (_) {}
  }

  @override
  Future<void> start({
    required String localeId,
    List<String> hints = const [],
  }) async {
    if (!await _init()) throw StateError('speech unavailable');
    _partials = StreamController<String>.broadcast();
    _levels = StreamController<double>.broadcast();
    _done = Completer<Heard>();
    _last = null;
    _localeId = await _bestLocale(localeId);
    _hints = hints.take(100).toList();
    _fellBack = false;
    await _listen(onDevice: true);
  }

  Future<void> _listen({required bool onDevice}) async {
    _triedOnDevice = onDevice;
    await _stt.listen(
      onResult: _onResult,
      onSoundLevelChange: (level) {
        // Android reports roughly -2..10 dB; map to 0..1.
        if (!_levels.isClosed) _levels.add(((level + 2) / 12).clamp(0.0, 1.0));
      },
      listenOptions: SpeechListenOptions(
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: _localeId,
        partialResults: true,
        onDevice: onDevice,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        contextualPhrases: _hints,
      ),
    );
  }

  /// The recogniser's own spelling of the locale (`bn-BD` vs `bn_BD`), or the
  /// closest language match, or the request unchanged.
  Future<String> _bestLocale(String want) async {
    if (_locales[want] case final String known) return known;
    try {
      final all = await _stt.locales();
      final norm = want.replaceAll('-', '_').toLowerCase();
      for (final l in all) {
        if (l.localeId.replaceAll('-', '_').toLowerCase() == norm) {
          return _locales[want] = l.localeId;
        }
      }
      final lang = norm.split('_').first;
      for (final l in all) {
        if (l.localeId.toLowerCase().startsWith(lang)) {
          return _locales[want] = l.localeId;
        }
      }
      // Listed, but no match: the request itself is the best guess.
      if (all.isNotEmpty) _locales[want] = want;
    } catch (_) {}
    return want;
  }

  void _onResult(SpeechRecognitionResult r) {
    _last = r;
    if (!_partials.isClosed) _partials.add(r.recognizedWords);
    if (r.finalResult) _finish();
  }

  void _onStatus(String status) {
    if ((status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) &&
        _last?.finalResult == true) {
      _finish();
    }
  }

  void _onError(SpeechRecognitionError e) {
    // The offline language pack is missing: try the phone's standard
    // recogniser once rather than fail the sale.
    final languageMissing =
        e.errorMsg.contains('language') || e.errorMsg.contains('server');
    if (_triedOnDevice && !_fellBack && languageMissing && _last == null) {
      _fellBack = true;
      unawaited(_listen(onDevice: false));
      return;
    }
    _finish();
  }

  void _finish() {
    final c = _done;
    if (c == null || c.isCompleted) return;
    final r = _last;
    c.complete(
      r == null
          ? const Heard('')
          : Heard(r.recognizedWords, [
              for (final a in r.alternates.skip(1)) a.recognizedWords,
            ]),
    );
  }

  @override
  Stream<String> get partials => _partials.stream;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<Heard> get done => _done?.future ?? Future.value(const Heard(''));

  @override
  Future<Heard> stop() async {
    await _stt.stop();
    // The final result arrives just after stop(); don't wait forever for it.
    return done.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        _finish();
        return _done?.future ?? Future.value(const Heard(''));
      },
    );
  }

  @override
  Future<void> cancel() async {
    await _stt.cancel();
    _finish();
  }
}

final speechCaptureProvider = Provider<SpeechCapture>(
  (ref) => DeviceSpeechCapture(),
);
