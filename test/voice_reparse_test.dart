
import 'package:ai_shopkeeper/core/error/result.dart';
import 'package:ai_shopkeeper/features/inventory/domain/product.dart';
import 'package:ai_shopkeeper/features/inventory/presentation/inventory_controller.dart';
import 'package:ai_shopkeeper/features/voice/data/speech_capture.dart';
import 'package:ai_shopkeeper/features/voice/data/voice_sale_repository.dart';
import 'package:ai_shopkeeper/features/voice/domain/voice_parse_result.dart';
import 'package:ai_shopkeeper/features/voice/presentation/voice_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/voice_fakes.dart';

/// First parse (speech) returns [audio]; later ones (typed text) [text].
class _FakeRepo extends FakeVoiceRepo {
  _FakeRepo(this.audio, this.text);
  final Result<VoiceParseResult> audio;
  final Result<VoiceParseResult> text;

  @override
  Future<Result<VoiceParseResult>> parseTranscript({
    required String transcript,
    required List<Product> products,
    List<String> alternatives = const [],
    Map<String, double> recentUnits = const {},
  }) async {
    final first = parseCalls == 0;
    await super.parseTranscript(transcript: transcript, products: products);
    return resolveVoiceIndexes(first ? audio : text, products);
  }
}

void main() {
  test('reparseFromText replaces lines and heardText from the edited text', () async {
    final audio = VoiceParseResult(
      heardText: 'pepci',
      items: [VoiceItem(heard: 'pepci', quantity: 1, quantityAssumed: true, matches: const [])],
    );
    final text = VoiceParseResult(
      heardText: '2 pepsi',
      items: [
        VoiceItem(
          heard: 'pepsi', quantity: 2, quantityAssumed: false,
          matches: const [VoiceMatch(productId: 'p1', confidence: 0.9)],
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        speechCaptureProvider.overrideWithValue(FakeSpeechCapture()),
        voiceSaleRepositoryProvider.overrideWithValue(_FakeRepo(Result.success(audio), Result.success(text))),
        productsStreamProvider.overrideWith(
          (ref) => Stream.value(const [Product(id: 'p1', shopId: 's', name: 'Pepsi 1L', quantity: 9)]),
        ),
      ],
    );
    final n = container.read(voiceControllerProvider.notifier);
    await n.startListening();
    await n.stopAndParse(); // now reviewing with the (mis-heard) audio result

    await n.reparseFromText('2 pepsi');

    final state = container.read(voiceControllerProvider);
    expect(state.phase, VoicePhase.reviewing);
    expect(state.heardText, '2 pepsi');
    expect(state.lines.length, 1);
    expect(state.lines.first.quantity, 2);
  });

  test('reparseFromText ignores empty input', () async {
    final container = ProviderContainer(
      overrides: [
        speechCaptureProvider.overrideWithValue(FakeSpeechCapture()),
        voiceSaleRepositoryProvider.overrideWithValue(
          _FakeRepo(Result.success(const VoiceParseResult(items: [])), Result.success(const VoiceParseResult(items: []))),
        ),
        productsStreamProvider.overrideWith((ref) => Stream.value(const <Product>[])),
      ],
    );
    final n = container.read(voiceControllerProvider.notifier);
    await n.reparseFromText('   ');
    expect(container.read(voiceControllerProvider).phase, VoicePhase.idle);
  });
}
