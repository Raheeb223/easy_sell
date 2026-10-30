import 'dart:async';

import 'package:ai_shopkeeper/core/error/result.dart';
import 'package:ai_shopkeeper/features/inventory/domain/product.dart';
import 'package:ai_shopkeeper/features/voice/data/speech_capture.dart';
import 'package:ai_shopkeeper/features/voice/data/voice_sale_repository.dart';
import 'package:ai_shopkeeper/features/voice/domain/voice_parse_result.dart';

/// Fake on-device speech recogniser. By default `stop()` returns [heard];
/// tests can also end the sentence themselves with [finish], as the real
/// recogniser does after a pause, and push live [say] partials and levels.
class FakeSpeechCapture implements SpeechCapture {
  FakeSpeechCapture({
    this.permissionOk = true,
    this.heard = const Heard('two pepsi'),
    this.throwOnStart = false,
    this.throwOnStop = false,
  });

  final bool permissionOk;
  final bool throwOnStart;
  final bool throwOnStop;
  Heard heard;

  bool started = false;
  bool cancelled = false;
  int stopCalls = 0;
  String? localeId;
  List<String> hints = const [];

  final _partials = StreamController<String>.broadcast();
  final _levels = StreamController<double>.broadcast();
  Completer<Heard> _done = Completer<Heard>();

  @override
  Future<bool> hasPermission() async => permissionOk;

  @override
  Future<void> start({
    required String localeId,
    List<String> hints = const [],
  }) async {
    if (throwOnStart) throw Exception('mic busy');
    started = true;
    this.localeId = localeId;
    this.hints = hints;
    _done = Completer<Heard>();
  }

  /// Words heard so far, as the live transcript.
  void say(String words) => _partials.add(words);

  void level(double v) => _levels.add(v);

  /// The recogniser decided the speaker finished.
  void finish([Heard? h]) {
    if (!_done.isCompleted) _done.complete(h ?? heard);
  }

  @override
  Stream<String> get partials => _partials.stream;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<Heard> get done => _done.future;

  @override
  Future<Heard> stop() async {
    stopCalls++;
    if (throwOnStop) throw Exception('stop failed');
    finish();
    return heard;
  }

  @override
  Future<void> cancel() async => cancelled = true;
}

/// Old-style test results name products by catalogue INDEX ('0', '1');
/// the on-device parser returns real ids. Maps the first to the second.
Result<VoiceParseResult> resolveVoiceIndexes(
  Result<VoiceParseResult> r,
  List<Product> products,
) => r.when(
  success: (v) => Result.success(
    v.resolveIds((raw) {
      final i = int.tryParse(raw);
      if (i == null) return raw;
      return i >= 0 && i < products.length ? products[i].id : null;
    }),
  ),
  failure: Result.failure,
);

/// Fake parser repository: returns [result] (or waits on [pending] when
/// set) and records what it was asked.
class FakeVoiceRepo implements VoiceSaleRepository {
  FakeVoiceRepo([Result<VoiceParseResult>? result, this.pending])
    : result = result ?? const Result.success(VoiceParseResult());

  Result<VoiceParseResult> result;
  final Completer<Result<VoiceParseResult>>? pending;
  String? lastTranscript;
  List<String>? lastAlternatives;
  int parseCalls = 0;
  final learned = <(String, String)>[];

  bool get parseCalled => parseCalls > 0;

  @override
  Future<Result<VoiceParseResult>> parseTranscript({
    required String transcript,
    required List<Product> products,
    List<String> alternatives = const [],
    Map<String, double> recentUnits = const {},
  }) {
    parseCalls++;
    lastTranscript = transcript;
    lastAlternatives = alternatives;
    return (pending?.future ?? Future.value(result)).then(
      (r) => resolveVoiceIndexes(r, products),
    );
  }

  @override
  Future<List<String>> hints(List<Product> products) async => [
    for (final p in products) p.name,
  ];

  @override
  Future<void> learnAlias(String productId, String phrase) async =>
      learned.add((productId, phrase));

  @override
  void invalidate() {}
}
