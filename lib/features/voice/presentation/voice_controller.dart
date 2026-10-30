import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../shared/providers/locale_provider.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../transactions/presentation/sales_providers.dart';
import '../data/speech_capture.dart';
import '../data/voice_sale_repository.dart';
import '../domain/voice_decision.dart';
import '../domain/voice_level.dart';
import '../domain/voice_line.dart';
import '../domain/voice_parse_result.dart';


enum VoicePhase { idle, listening, thinking, reviewing, error }

/// State for the voice-sale flow: listening (words appear live) -> parsed on
/// the phone -> reviewable lines. Mirrors the vision-scan controller's shape,
/// with the eyes swapped for ears.
class VoiceSaleState {
  const VoiceSaleState({
    this.phase = VoicePhase.idle,
    this.heardText,
    this.lines = const <VoiceLine>[],
    this.errorMessage,
    this.listenDeadline,
    this.canRetryAudio = false,
    this.background = false,
  });

  final VoicePhase phase;

  /// True once the shopkeeper dismissed the sheet while the parse was still in
  /// flight, so the result has nowhere on screen to land.
  ///
  /// The parse deliberately keeps running: in a busy shop those few seconds are
  /// better spent taking cash than watching a spinner, so dismissing means
  /// "carry on without me", not "cancel". [VoiceReadyBanner] takes over as the
  /// sale's handle for the whole time it stays set -- while it is still being
  /// parsed as much as once it finishes -- so the work is never invisible.
  final bool background;

  /// When the current recording will auto-stop, so the listening pane can warn
  /// before it happens instead of cutting the shopkeeper off mid-sentence. Null
  /// outside `listening`, and also for the brief window after `listening` is
  /// entered but before `recorder.start()` resolves -- there is no deadline to
  /// show until the timer that enforces it actually exists.
  final DateTime? listenDeadline;

  /// True in the `error` phase when the failure happened *after* words were
  /// heard, so retrying can re-read them instead of making the shopkeeper say
  /// the whole sale again. False when nothing usable was heard (mic denied,
  /// silence).
  final bool canRetryAudio;

  /// What the phone heard: live while listening, then the transcript the sale
  /// was read from, so a mishear is obvious to the user.
  final String? heardText;

  final List<VoiceLine> lines;

  /// A magic string key (`micDenied` / `noSpeech` / `noMatch`) or a repository
  /// `Failure.message` -- the UI maps these to localized copy.
  final String? errorMessage;

  bool get canAdd => canAddToCart(lines);

  /// A voice sale that exists but has no sheet on screen -- whether it is still
  /// being parsed or already finished. [VoiceReadyBanner] renders exactly this.
  ///
  /// Deliberately NOT limited to finished parses. It was, and that left a dead
  /// zone: between dismissing the sheet and the result landing, nothing was
  /// shown anywhere, so a spoken sale was invisible. The shopkeeper could not
  /// watch it, reopen it, or cancel it -- and tapping the mic again would
  /// silently supersede it (see [startListening]'s session bump), losing a sale
  /// they had already spoken. The banner is the handle on that work for its
  /// whole life, not just its last moment.
  bool get hasBackgroundSale =>
      background &&
      (phase == VoicePhase.thinking ||
          phase == VoicePhase.reviewing ||
          phase == VoicePhase.error);

  /// True while a backgrounded sale is still being parsed -- the state that had
  /// no representation at all before.
  bool get isBackgroundPending => background && phase == VoicePhase.thinking;

  /// [errorMessage], [listenDeadline], [canRetryAudio] and [background] are
  /// intentionally NOT defaulted to their current values: each describes one
  /// specific moment, so every transition must state it explicitly and a stale
  /// error, a deadline from a finished recording, a retry offer for discarded
  /// audio, or a backgrounded flag left over from the previous sale can never
  /// leak into a later state.
  VoiceSaleState copyWith({
    VoicePhase? phase,
    String? heardText,
    List<VoiceLine>? lines,
    String? errorMessage,
    DateTime? listenDeadline,
    bool canRetryAudio = false,
    bool background = false,
  }) => VoiceSaleState(
    phase: phase ?? this.phase,
    heardText: heardText ?? this.heardText,
    lines: lines ?? this.lines,
    errorMessage: errorMessage,
    listenDeadline: listenDeadline,
    canRetryAudio: canRetryAudio,
    background: background,
  );
}

/// Orchestrates listen -> on-device parse -> reviewable lines. Everything runs
/// on the phone: speech recognition (on-device first), then the sale parser
/// against the shop's products and taught words. Never builds widgets.
class VoiceController extends Notifier<VoiceSaleState> {
  /// Bumped by [startListening] and [reset] to invalidate any in-flight
  /// listening/parse from a previous session. Every `await` re-checks it
  /// before touching [state].
  int _session = 0;

  /// Backstop for the listening cap, in case the recogniser never reports
  /// that it finished.
  Timer? _capTimer;

  StreamSubscription<double>? _levelSub;
  StreamSubscription<String>? _partialSub;

  /// The last thing heard, kept so "Try again" re-reads it without making
  /// the shopkeeper repeat the sale.
  Heard? _lastHeard;

  /// The one path that ends a listening session: the recogniser reports the
  /// sentence finished (after a pause, or because Stop was tapped) and this
  /// reads it. Stop waits on it rather than finishing a second time.
  Future<void>? _finishing;

  @override
  VoiceSaleState build() {
    // Keep the catalogue loaded while voice is in use: the parser and the
    // recogniser's hints both need it the moment the shopkeeper speaks.
    ref.listen(productsStreamProvider, (_, _) {});
    ref.onDispose(_stopWatching);
    ref.onDispose(() => _capTimer?.cancel());
    return const VoiceSaleState();
  }

  List<Product> get _products =>
      ref.read(productsStreamProvider).value ?? const <Product>[];

  Future<void> startListening() async {
    final session = ++_session;
    _lastHeard = null;

    final capture = ref.read(speechCaptureProvider);
    final ok = await capture.hasPermission();
    if (_session != session) return; // superseded while awaiting permission
    if (!ok) {
      state = state.copyWith(phase: VoicePhase.error, errorMessage: 'micDenied');
      return;
    }

    // Warm the 30-day sales figures the parser uses to break ties.
    ref.read(recentUnitsSoldProvider);
    final hints = await ref.read(voiceSaleRepositoryProvider).hints(_products);
    if (_session != session) return;

    state = state.copyWith(phase: VoicePhase.listening);
    final bn = ref.read(localeProvider).languageCode == 'bn';
    try {
      await capture.start(localeId: bn ? 'bn_BD' : 'en_US', hints: hints);
    } catch (_) {
      unawaited(capture.cancel());
      if (_session != session) return;
      state = state.copyWith(phase: VoicePhase.error, errorMessage: 'noSpeech');
      return;
    }
    if (_session != session) return;

    ref.read(voiceHapticsProvider).recordingStarted();
    final cap = ref.read(maxRecordingDurationProvider);
    _capTimer?.cancel();
    _capTimer = Timer(cap + const Duration(seconds: 2), () {
      if (_session == session && state.phase == VoicePhase.listening) {
        unawaited(stopAndParse());
      }
    });
    final deadline = clock.now().add(cap);
    _watch(capture, session, deadline);
    state = state.copyWith(
      phase: VoicePhase.listening,
      listenDeadline: deadline,
    );

    // The recogniser ends the sentence itself after a pause.
    _finishing = capture.done.then((heard) {
      if (_session == session && state.phase == VoicePhase.listening) {
        return _finishListening(heard, session);
      }
    });
  }

  void _watch(SpeechCapture capture, int session, DateTime deadline) {
    _stopWatching();
    ref.read(micLevelProvider.notifier).clear();
    _levelSub = capture.levels.listen((level) {
      if (_session != session || state.phase != VoicePhase.listening) return;
      ref.read(micLevelProvider.notifier).reportLevel(level);
    }, onError: (_) {});
    _partialSub = capture.partials.listen((words) {
      if (_session != session || state.phase != VoicePhase.listening) return;
      // Live words while the shopkeeper speaks.
      state = state.copyWith(
        phase: VoicePhase.listening,
        heardText: words,
        listenDeadline: deadline,
      );
    }, onError: (_) {});
  }

  void _stopWatching() {
    _levelSub?.cancel();
    _levelSub = null;
    _partialSub?.cancel();
    _partialSub = null;
  }

  /// Stops listening now (the Stop button) and reads the sale.
  Future<void> stopAndParse() async {
    if (state.phase != VoicePhase.listening) return;
    final session = _session;
    try {
      await ref.read(speechCaptureProvider).stop();
    } catch (_) {
      if (_session != session || state.phase != VoicePhase.listening) return;
      _capTimer?.cancel();
      _stopWatching();
      state = state.copyWith(phase: VoicePhase.error, errorMessage: 'noSpeech');
      return;
    }
    await _finishing;
  }

  Future<void> _finishListening(Heard heard, int session) async {
    _capTimer?.cancel();
    _capTimer = null;
    _stopWatching();
    ref.read(voiceHapticsProvider).recordingStopped();
    if (heard.isEmpty) {
      state = state.copyWith(phase: VoicePhase.error, errorMessage: 'noSpeech');
      return;
    }
    _lastHeard = heard;
    await _parse(heard, session, canRetry: true);
  }

  /// Re-reads the last thing heard (after a failure), or starts over.
  Future<void> retryLastAudio() async {
    final heard = _lastHeard;
    if (heard == null) {
      reset();
      return;
    }
    _capTimer?.cancel();
    _capTimer = null;
    _stopWatching();
    final session = ++_session;
    await _parse(heard, session, canRetry: true);
  }

  /// Parses typed or corrected text instead of speech.
  Future<void> reparseFromText(String transcript) async {
    _capTimer?.cancel();
    _capTimer = null;
    _stopWatching();
    final text = transcript.trim();
    if (text.isEmpty) return;
    final session = ++_session;
    await _parse(Heard(text), session, canRetry: false);
  }

  Future<void> _parse(
    Heard heard,
    int session, {
    required bool canRetry,
  }) async {
    state = state.copyWith(
      phase: VoicePhase.thinking,
      heardText: heard.text,
      background: state.background,
    );
    final result = await ref
        .read(voiceSaleRepositoryProvider)
        .parseTranscript(
          transcript: heard.text,
          alternatives: heard.alternatives,
          products: _products,
          recentUnits: ref.read(recentUnitsSoldProvider).value ?? const {},
        );
    if (_session != session) return;
    _applyResult(
      result,
      canRetryAudio: canRetry,
      fallbackHeardText: heard.text,
    );
  }

  void _applyResult(
    Result<VoiceParseResult> result, {
    required bool canRetryAudio,
    String? fallbackHeardText,
  }) {
    final wasBackgrounded = state.background;

    result.when(
      success: (parsed) {
        final lines = buildVoiceLines(
          parsed,
          thresholds: ref.read(voiceThresholdsProvider),
        );
        _logCalibration(parsed, lines);
        state = state.copyWith(
          phase: lines.isEmpty ? VoicePhase.error : VoicePhase.reviewing,
          heardText: parsed.heardText ?? fallbackHeardText,
          lines: lines,
          errorMessage: lines.isEmpty ? 'noMatch' : null,
          background: wasBackgrounded,
          canRetryAudio: false,
        );
      },
      failure: (f) => state = state.copyWith(
        phase: VoicePhase.error,
        errorMessage: f.message,
        canRetryAudio: canRetryAudio,
        background: wasBackgrounded,
      ),
    );

    if (wasBackgrounded) ref.read(voiceHapticsProvider).resultReady();
  }

  /// Debug-only: what the parser was sure of, to tune [VoiceThresholds].
  void _logCalibration(VoiceParseResult parsed, List<VoiceLine> lines) {
    if (!kDebugMode) return;
    for (var i = 0; i < parsed.items.length && i < lines.length; i++) {
      final ranked = [...parsed.items[i].matches]
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
      final top = ranked.isNotEmpty ? ranked.first.confidence : null;
      final second = ranked.length > 1 ? ranked[1].confidence : null;
      debugPrint(
        'voice-calibration: heard="${parsed.items[i].heard}" '
        'status=${lines[i].status.name} top=$top runnerUp=$second',
      );
    }
  }

  /// The shopkeeper settled a line. When they picked the product themselves
  /// (it was unsure, unknown, or they changed it), the words they used are
  /// taught as an alias so next time those words find it straight away.
  void choose(int index, String productId) {
    final line = state.lines[index];
    final autoPicked =
        line.status == VoiceLineStatus.resolved &&
        line.choices.isNotEmpty &&
        line.choices.first.productId == productId;
    final phrase = line.phrase;
    if (!autoPicked && phrase != null && phrase.trim().isNotEmpty) {
      ref
          .read(voiceSaleRepositoryProvider)
          .learnAlias(productId, phrase)
          .ignore();
    }
    _replace(index, line.chooseProduct(productId));
  }

  void setQuantity(int index, double quantity) =>
      _replace(index, state.lines[index].withQuantity(quantity));

  void removeLine(int index) =>
      state = state.copyWith(lines: removeLineAt(state.lines, index));

  /// The sheet was dismissed. A sale still being read carries on in the
  /// background ([VoiceReadyBanner] is its handle); anything else resets.
  void releaseSheet() {
    if (state.phase == VoicePhase.thinking) {
      state = state.copyWith(phase: VoicePhase.thinking, background: true);
      return;
    }
    reset();
  }

  void resumeFromBackground() {
    if (!state.background) return;
    state = state.copyWith(
      phase: state.phase,
      errorMessage: state.errorMessage,
      canRetryAudio: state.canRetryAudio,
    );
  }

  void reset() {
    _capTimer?.cancel();
    _capTimer = null;
    _stopWatching();
    _lastHeard = null;
    _session++;
    unawaited(ref.read(speechCaptureProvider).cancel());
    state = const VoiceSaleState();
  }

  void _replace(int index, VoiceLine line) {
    final next = [...state.lines];
    next[index] = line;
    state = state.copyWith(lines: next);
  }
}

final voiceControllerProvider =
    NotifierProvider<VoiceController, VoiceSaleState>(VoiceController.new);

/// How long one sale sentence may run before listening stops by itself.
/// A provider (not a bare constant) so tests can shorten it.
final maxRecordingDurationProvider = Provider<Duration>(
  (ref) => DeviceSpeechCapture.listenFor,
);

/// How long before [maxRecordingDurationProvider] elapses the listening pane
/// starts counting down. Long enough to finish a sentence, short enough that the
/// warning is not on screen for most of a normal recording.
const autoStopWarning = Duration(seconds: 5);

/// Whether a recording stops itself once the shopkeeper stops speaking. A
/// provider so it can be turned off wholesale if silence detection ever proves
/// wrong for a particular shop, without touching the recording path.
final autoStopOnSilenceProvider = Provider<bool>((ref) => true);

/// Thresholds mapping model confidence onto a review action. A provider (not a
/// bare const) because the shipped values are estimates that want calibrating
/// against real speech -- see [VoiceController._logCalibration] for how to
/// gather the evidence, then override this.
final voiceThresholdsProvider = Provider<VoiceThresholds>(
  (ref) => const VoiceThresholds(),
);

/// The live microphone level, `0.0..1.0`, for the listening pane's meter.
///
/// Separate from [VoiceSaleState] on purpose: this changes five times a second,
/// and folding it into the controller's state would rebuild the whole sheet --
/// review rows and all -- at that rate. Here, only the meter watches it.
class MicLevel extends Notifier<double> {
  @override
  double build() => 0;

  /// Publishes one raw dBFS reading from the recorder.
  void report(double dbfs) => state = normalizeMicLevel(dbfs);

  /// A level already on the 0..1 scale (the speech recogniser's).
  void reportLevel(double level) => state = level.clamp(0.0, 1.0);

  void clear() => state = 0;
}

final micLevelProvider = NotifierProvider<MicLevel, double>(MicLevel.new);

/// Physical confirmation that recording started and stopped, so a shopkeeper
/// mid-transaction does not have to look at the screen to know the phone heard
/// the tap. Behind a seam because it is a platform channel: tests override it,
/// and every call is best-effort -- a device without a vibrator, or a test
/// binding with no platform, must never turn a missing buzz into a failed sale.
class VoiceHaptics {
  const VoiceHaptics();

  void recordingStarted() => _fire(HapticFeedback.mediumImpact);

  void recordingStopped() => _fire(HapticFeedback.selectionClick);

  /// A backgrounded parse finished. Heavier than the other two on purpose: the
  /// phone is likely in a pocket or face-down on the counter while the
  /// shopkeeper handles the customer, so this one has to be felt rather than
  /// merely noticed.
  void resultReady() => _fire(HapticFeedback.heavyImpact);

  static void _fire(Future<void> Function() effect) {
    try {
      effect().catchError((_) {});
    } catch (_) {
      // Synchronous throw (no platform binding at all) -- same non-event.
    }
  }
}

final voiceHapticsProvider = Provider<VoiceHaptics>(
  (ref) => const VoiceHaptics(),
);
