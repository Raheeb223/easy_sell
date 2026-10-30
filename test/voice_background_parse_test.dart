import 'dart:async';

import 'package:ai_shopkeeper/core/error/failure.dart';
import 'package:ai_shopkeeper/core/error/result.dart';
import 'package:ai_shopkeeper/features/inventory/domain/product.dart';
import 'package:ai_shopkeeper/features/inventory/presentation/inventory_controller.dart';
import 'package:ai_shopkeeper/features/transactions/presentation/sales_providers.dart';
import 'package:ai_shopkeeper/features/voice/data/speech_capture.dart';
import 'package:ai_shopkeeper/features/voice/data/voice_sale_repository.dart';
import 'package:ai_shopkeeper/features/voice/domain/voice_parse_result.dart';
import 'package:ai_shopkeeper/features/voice/presentation/voice_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/voice_fakes.dart';

class _PendingRepo extends FakeVoiceRepo {
  _PendingRepo() : this._(Completer<Result<VoiceParseResult>>());
  _PendingRepo._(this.completer) : super(null, completer);
  final Completer<Result<VoiceParseResult>> completer;
}

/// Covers letting a slow parse finish after its sheet is gone.
///
/// The point of the feature is that a shopkeeper can speak a sale, close the
/// sheet, and go back to serving the customer while the parse runs. So the
/// behaviour worth pinning down is precisely that dismissal does NOT cancel the
/// work -- the old `whenComplete(reset)` did exactly that, and reinstating it
/// would silently throw away a sale the shopkeeper had already spoken.

class _FakeHaptics extends VoiceHaptics {
  const _FakeHaptics(this.log);

  final List<String> log;

  @override
  void recordingStarted() => log.add('start');

  @override
  void recordingStopped() => log.add('stop');

  @override
  void resultReady() => log.add('ready');
}

ProviderContainer _container({
  required FakeSpeechCapture recorder,
  required VoiceSaleRepository repo,
  required List<String> hapticLog,
}) {
  final container = ProviderContainer(
    overrides: [
      speechCaptureProvider.overrideWithValue(recorder),
      voiceSaleRepositoryProvider.overrideWithValue(repo),
      productsStreamProvider.overrideWith(
        (ref) =>
            Stream.value([const Product(id: 'p1', shopId: 's', name: 'Pepsi')]),
      ),
      recentUnitsSoldProvider.overrideWith((ref) => const <String, double>{}),
      autoStopOnSilenceProvider.overrideWithValue(false),
      voiceHapticsProvider.overrideWithValue(_FakeHaptics(hapticLog)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Runs the controller up to the point where `parse` is genuinely in flight.
Future<VoiceController> _upToThinking(
  ProviderContainer container,
  _PendingRepo repo,
) async {
  final notifier = container.read(voiceControllerProvider.notifier);
  await notifier.startListening();
  // Deliberately NOT awaited: `stopAndParse` only completes once the parse
  // does, and holding it pending across the dismissal is the whole scenario.
  unawaited(notifier.stopAndParse());
  while (!repo.parseCalled) {
    await Future<void>.delayed(Duration.zero);
  }
  return notifier;
}

const _parsed = VoiceParseResult(
  heardText: 'two pepsi',
  items: [
    VoiceItem(
      heard: 'pepsi',
      quantity: 2,
      quantityAssumed: false,
      matches: [VoiceMatch(productId: '0', confidence: 0.95)],
    ),
  ],
);

void main() {
  test('dismissing the sheet mid-parse keeps the parse running', () async {
    final repo = _PendingRepo();
    final log = <String>[];
    final container = _container(
      recorder: FakeSpeechCapture(),
      repo: repo,
      hapticLog: log,
    );
    final notifier = await _upToThinking(container, repo);
    expect(container.read(voiceControllerProvider).phase, VoicePhase.thinking);

    // The shopkeeper swipes the sheet away to serve the customer.
    notifier.releaseSheet();
    expect(
      container.read(voiceControllerProvider).phase,
      VoicePhase.thinking,
      reason: 'dismissal must not cancel a sale already spoken',
    );
    expect(container.read(voiceControllerProvider).background, isTrue);

    // The result lands with nobody watching.
    repo.completer.complete(const Result.success(_parsed));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(voiceControllerProvider);
    expect(state.phase, VoicePhase.reviewing);
    expect(state.lines, hasLength(1));
    expect(state.hasBackgroundSale, isTrue);
    expect(log, contains('ready'), reason: 'the buzz is the only notification');
  });

  test('a failed background parse still asks to be claimed', () async {
    final repo = _PendingRepo();
    final log = <String>[];
    final container = _container(
      recorder: FakeSpeechCapture(),
      repo: repo,
      hapticLog: log,
    );
    final notifier = await _upToThinking(container, repo);
    notifier.releaseSheet();

    repo.completer.complete(
      const Result.failure(NetworkFailure('no internet')),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(voiceControllerProvider);
    expect(state.phase, VoicePhase.error);
    expect(state.hasBackgroundSale, isTrue);
    expect(log, contains('ready'));
  });

  test('dismissing outside the thinking phase still resets', () async {
    final repo = _PendingRepo();
    final recorder = FakeSpeechCapture();
    final container = _container(recorder: recorder, repo: repo, hapticLog: []);
    final notifier = container.read(voiceControllerProvider.notifier);
    await notifier.startListening();
    expect(container.read(voiceControllerProvider).phase, VoicePhase.listening);

    notifier.releaseSheet();

    final state = container.read(voiceControllerProvider);
    expect(state.phase, VoicePhase.idle);
    expect(state.background, isFalse);
    expect(recorder.cancelled, isTrue, reason: 'a live mic must be released');
  });

  test(
    'resuming from the banner clears the flag but keeps the lines',
    () async {
      final repo = _PendingRepo();
      final container = _container(
        recorder: FakeSpeechCapture(),
        repo: repo,
        hapticLog: [],
      );
      final notifier = await _upToThinking(container, repo);
      notifier.releaseSheet();
      repo.completer.complete(const Result.success(_parsed));
      await Future<void>.delayed(Duration.zero);

      notifier.resumeFromBackground();

      final state = container.read(voiceControllerProvider);
      expect(state.background, isFalse);
      expect(state.hasBackgroundSale, isFalse);
      expect(state.phase, VoicePhase.reviewing);
      expect(state.lines, hasLength(1), reason: 'the parsed sale must survive');
    },
  );

  test('starting a new sale clears a stale background flag', () async {
    final repo = _PendingRepo();
    final container = _container(
      recorder: FakeSpeechCapture(),
      repo: repo,
      hapticLog: [],
    );
    final notifier = await _upToThinking(container, repo);
    notifier.releaseSheet();
    repo.completer.complete(const Result.success(_parsed));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(voiceControllerProvider).background, isTrue);

    await notifier.startListening();

    expect(
      container.read(voiceControllerProvider).background,
      isFalse,
      reason: 'the banner must not linger over a fresh recording',
    );
  });

  test('a sale still parsing is visible the whole time it runs', () async {
    // The dead zone this feature originally shipped with: between dismissing
    // the sheet and the result landing, nothing was shown anywhere, so a spoken
    // sale simply vanished from the UI until it finished.
    final repo = _PendingRepo();
    final container = _container(
      recorder: FakeSpeechCapture(),
      repo: repo,
      hapticLog: [],
    );
    final notifier = await _upToThinking(container, repo);
    notifier.releaseSheet();

    final pendingState = container.read(voiceControllerProvider);
    expect(pendingState.phase, VoicePhase.thinking);
    expect(
      pendingState.hasBackgroundSale,
      isTrue,
      reason: 'a sale mid-parse must still have a handle on screen',
    );
    expect(pendingState.isBackgroundPending, isTrue);

    // ...and it stays visible, changing state rather than disappearing.
    repo.completer.complete(const Result.success(_parsed));
    await Future<void>.delayed(Duration.zero);

    final doneState = container.read(voiceControllerProvider);
    expect(doneState.hasBackgroundSale, isTrue);
    expect(doneState.isBackgroundPending, isFalse);
  });

  test(
    'reopening mid-parse claims the sale instead of restarting it',
    () async {
      final repo = _PendingRepo();
      final container = _container(
        recorder: FakeSpeechCapture(),
        repo: repo,
        hapticLog: [],
      );
      final notifier = await _upToThinking(container, repo);
      notifier.releaseSheet();

      // What tapping the mic (or the banner) now does -- both route through
      // `showVoiceSaleSheet`, which always resumes first.
      notifier.resumeFromBackground();

      expect(
        container.read(voiceControllerProvider).phase,
        VoicePhase.thinking,
      );
      expect(container.read(voiceControllerProvider).background, isFalse);

      // The parse was never superseded, so its result still arrives.
      repo.completer.complete(const Result.success(_parsed));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(voiceControllerProvider);
      expect(state.phase, VoicePhase.reviewing);
      expect(
        state.lines,
        hasLength(1),
        reason: 'reopening must not cost the shopkeeper the sale they spoke',
      );
    },
  );

  test('cancelling a pending background sale drops it deliberately', () async {
    final repo = _PendingRepo();
    final container = _container(
      recorder: FakeSpeechCapture(),
      repo: repo,
      hapticLog: [],
    );
    final notifier = await _upToThinking(container, repo);
    notifier.releaseSheet();

    notifier.reset(); // the banner's ✕

    expect(container.read(voiceControllerProvider).phase, VoicePhase.idle);
    expect(container.read(voiceControllerProvider).hasBackgroundSale, isFalse);

    // A result arriving after the cancel must not resurrect the sale.
    repo.completer.complete(const Result.success(_parsed));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(voiceControllerProvider);
    expect(state.phase, VoicePhase.idle);
    expect(state.lines, isEmpty);
  });
}
