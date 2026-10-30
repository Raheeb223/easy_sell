import 'dart:async';

import 'package:ai_shopkeeper/core/error/failure.dart';
import 'package:ai_shopkeeper/core/error/result.dart';
import 'package:ai_shopkeeper/features/inventory/domain/product.dart';
import 'package:ai_shopkeeper/features/inventory/presentation/inventory_controller.dart';
import 'package:ai_shopkeeper/features/transactions/presentation/sales_providers.dart';
import 'package:ai_shopkeeper/features/voice/data/speech_capture.dart';
import 'package:ai_shopkeeper/features/voice/data/voice_sale_repository.dart';
import 'package:ai_shopkeeper/features/voice/domain/voice_decision.dart';
import 'package:ai_shopkeeper/features/voice/domain/voice_parse_result.dart';
import 'package:ai_shopkeeper/features/voice/presentation/voice_controller.dart';
import 'package:ai_shopkeeper/shared/providers/locale_provider.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/voice_fakes.dart';

const _pepsi = Product(id: 'p1', shopId: 's', name: 'Pepsi', quantity: 10);
const _chips = Product(id: 'p2', shopId: 's', name: 'Chips', quantity: 10);

const _twoPepsi = VoiceParseResult(
  heardText: 'two pepsi',
  items: [
    VoiceItem(
      heard: 'two pepsi',
      quantity: 2,
      quantityAssumed: false,
      phrase: 'pepsi',
      matches: [VoiceMatch(productId: 'p1', confidence: 0.95)],
    ),
  ],
);

const _unsure = VoiceParseResult(
  heardText: 'drink',
  items: [
    VoiceItem(
      heard: 'drink',
      quantity: 1,
      quantityAssumed: true,
      phrase: 'drink',
      matches: [
        VoiceMatch(productId: 'p1', confidence: 0.6),
        VoiceMatch(productId: 'p2', confidence: 0.55),
      ],
    ),
  ],
);

ProviderContainer _container(
  FakeSpeechCapture speech,
  VoiceSaleRepository repo, {
  Locale locale = const Locale('bn'),
}) {
  final c = ProviderContainer(
    overrides: [
      speechCaptureProvider.overrideWithValue(speech),
      voiceSaleRepositoryProvider.overrideWithValue(repo),
      productsStreamProvider.overrideWith(
        (ref) => Stream.value(const [_pepsi, _chips]),
      ),
      recentUnitsSoldProvider.overrideWith((ref) => const <String, double>{}),
      initialLocaleProvider.overrideWithValue(locale),
    ],
  );
  addTearDown(c.dispose);
  // Let the products stream deliver before the first listen.
  c.listen(productsStreamProvider, (_, _) {});
  return c;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('mic denied -> error micDenied, nothing started', () async {
    final speech = FakeSpeechCapture(permissionOk: false);
    final c = _container(speech, FakeVoiceRepo());
    await c.read(voiceControllerProvider.notifier).startListening();
    expect(c.read(voiceControllerProvider).phase, VoicePhase.error);
    expect(c.read(voiceControllerProvider).errorMessage, 'micDenied');
    expect(speech.started, isFalse);
  });

  test('listens in the app language with product names as hints', () async {
    final speech = FakeSpeechCapture();
    final c = _container(speech, FakeVoiceRepo());
    await _settle();
    await c.read(voiceControllerProvider.notifier).startListening();
    expect(c.read(voiceControllerProvider).phase, VoicePhase.listening);
    expect(speech.localeId, 'bn_BD');
    expect(speech.hints, containsAll(['Pepsi', 'Chips']));
    expect(c.read(voiceControllerProvider).listenDeadline, isNotNull);
  });

  test('words appear live while listening', () async {
    final speech = FakeSpeechCapture();
    final c = _container(speech, FakeVoiceRepo());
    await c.read(voiceControllerProvider.notifier).startListening();
    speech.say('দুইটা পেপ');
    await _settle();
    expect(c.read(voiceControllerProvider).heardText, 'দুইটা পেপ');
    expect(c.read(voiceControllerProvider).phase, VoicePhase.listening);
  });

  test('the recogniser ending the sentence parses it, alternatives too', () async {
    final speech = FakeSpeechCapture();
    final repo = FakeVoiceRepo(const Result.success(_twoPepsi));
    final c = _container(speech, repo);
    await c.read(voiceControllerProvider.notifier).startListening();
    speech.finish(const Heard('two pepsi', ['to pepsi']));
    await _settle();
    await _settle();
    final s = c.read(voiceControllerProvider);
    expect(s.phase, VoicePhase.reviewing);
    expect(repo.lastTranscript, 'two pepsi');
    expect(repo.lastAlternatives, ['to pepsi']);
    expect(s.lines.single.chosenProductId, 'p1');
    expect(s.canAdd, isTrue);
  });

  test('Stop reads what was heard so far', () async {
    final speech = FakeSpeechCapture();
    final repo = FakeVoiceRepo(const Result.success(_twoPepsi));
    final c = _container(speech, repo);
    final n = c.read(voiceControllerProvider.notifier);
    await n.startListening();
    await n.stopAndParse();
    expect(speech.stopCalls, 1);
    expect(repo.parseCalls, 1);
    expect(c.read(voiceControllerProvider).phase, VoicePhase.reviewing);
  });

  test('nothing heard -> noSpeech, and the parser is never asked', () async {
    final speech = FakeSpeechCapture(heard: const Heard(''));
    final repo = FakeVoiceRepo();
    final c = _container(speech, repo);
    final n = c.read(voiceControllerProvider.notifier);
    await n.startListening();
    await n.stopAndParse();
    expect(c.read(voiceControllerProvider).errorMessage, 'noSpeech');
    expect(repo.parseCalled, isFalse);
  });

  test('a start failure is noSpeech and the recogniser is released', () async {
    final speech = FakeSpeechCapture(throwOnStart: true);
    final c = _container(speech, FakeVoiceRepo());
    await c.read(voiceControllerProvider.notifier).startListening();
    expect(c.read(voiceControllerProvider).errorMessage, 'noSpeech');
    expect(speech.cancelled, isTrue);
  });

  test('no product matched -> noMatch', () async {
    final speech = FakeSpeechCapture();
    final c = _container(
      speech,
      FakeVoiceRepo(const Result.success(VoiceParseResult(heardText: 'hm'))),
    );
    final n = c.read(voiceControllerProvider.notifier);
    await n.startListening();
    await n.stopAndParse();
    expect(c.read(voiceControllerProvider).errorMessage, 'noMatch');
  });

  test('a parse failure keeps the words so retry needs no repeat', () async {
    final speech = FakeSpeechCapture();
    final repo = FakeVoiceRepo(
      const Result.failure(UnexpectedFailure('Could not understand that.')),
    );
    final c = _container(speech, repo);
    final n = c.read(voiceControllerProvider.notifier);
    await n.startListening();
    await n.stopAndParse();
    expect(c.read(voiceControllerProvider).canRetryAudio, isTrue);

    repo.result = const Result.success(_twoPepsi);
    await n.retryLastAudio();
    expect(repo.parseCalls, 2);
    expect(speech.stopCalls, 1, reason: 'retry must not listen again');
    expect(c.read(voiceControllerProvider).phase, VoicePhase.reviewing);
  });

  test('picking the product yourself teaches the words as an alias', () async {
    final speech = FakeSpeechCapture();
    final repo = FakeVoiceRepo(const Result.success(_unsure));
    final c = _container(speech, repo);
    final n = c.read(voiceControllerProvider.notifier);
    await n.startListening();
    await n.stopAndParse();
    expect(
      c.read(voiceControllerProvider).lines.single.status,
      VoiceLineStatus.ambiguous,
    );
    n.choose(0, 'p2');
    await _settle();
    expect(repo.learned, [('p2', 'drink')]);
    expect(c.read(voiceControllerProvider).canAdd, isTrue);
  });

  test('confirming the automatic pick teaches nothing', () async {
    final speech = FakeSpeechCapture();
    final repo = FakeVoiceRepo(const Result.success(_twoPepsi));
    final c = _container(speech, repo);
    final n = c.read(voiceControllerProvider.notifier);
    await n.startListening();
    await n.stopAndParse();
    n.choose(0, 'p1');
    await _settle();
    expect(repo.learned, isEmpty);
  });

  test('reset during a parse discards the late result', () async {
    final speech = FakeSpeechCapture();
    final pending = Completer<Result<VoiceParseResult>>();
    final repo = FakeVoiceRepo(null, pending);
    final c = _container(speech, repo);
    final n = c.read(voiceControllerProvider.notifier);
    await n.startListening();
    unawaited(n.stopAndParse());
    await _settle();
    expect(c.read(voiceControllerProvider).phase, VoicePhase.thinking);
    n.reset();
    pending.complete(const Result.success(_twoPepsi));
    await _settle();
    expect(c.read(voiceControllerProvider).phase, VoicePhase.idle);
    expect(c.read(voiceControllerProvider).lines, isEmpty);
    expect(speech.cancelled, isTrue);
  });

  test('English app listens in English', () async {
    final speech = FakeSpeechCapture();
    final c = _container(speech, FakeVoiceRepo(), locale: const Locale('en'));
    await c.read(voiceControllerProvider.notifier).startListening();
    expect(speech.localeId, 'en_US');
  });
}
