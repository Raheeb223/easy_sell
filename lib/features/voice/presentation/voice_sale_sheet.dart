import 'dart:async' show Timer;
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/motion.dart';
import '../../../core/config/theme.dart';
import '../../../core/l10n/l10n_ext.dart';
import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';
import 'voice_controller.dart';
import 'voice_review_sheet.dart';
import 'voice_transcript_dialog.dart';

/// Presents [VoiceSaleSheet] as a modal bottom sheet -- mirrors the other
/// `show*Sheet` entry points (`showAddToCartSheet`, `showProductPickerSheet`).
/// A live recorder must never keep recording once the sheet is gone, so
/// dismissal by ANY route -- swipe, back button, or the phase reaching
/// `reviewing` and the review sheet popping itself -- always goes through
/// [VoiceController.releaseSheet] via `whenComplete`.
///
/// `releaseSheet`, not `reset`: dismissing mid-parse now backgrounds the work
/// instead of cancelling it, so the shopkeeper can serve the customer while the
/// sale is still being understood. Every other phase still resets exactly as
/// before (and doing so twice is harmless -- [VoiceController.reset] is
/// idempotent).
///
/// Opening always claims a backgrounded sale if one exists, whatever phase it
/// is in ([VoiceController.resumeFromBackground] is a no-op otherwise).
///
/// This is what stops the mic from eating a sale. [VoiceController.startListening]
/// bumps the session counter, so beginning a fresh recording discards any parse
/// still in flight -- silently, since the result is simply dropped when it
/// lands. Routing every entry point through the resume path means tapping the
/// mic while a background sale is pending REOPENS that sale rather than
/// replacing it. Two voice sales can't be in progress at once anyway, so there
/// is nothing to choose between: showing the one that exists is always the
/// answer that cannot lose work.
///
/// The caller's context is not always usable. `VoiceReadyBanner` is mounted in
/// `app.dart`'s builder, which `WidgetsApp` places *above* the router — so the
/// banner has no `Navigator` ancestor and pushing from its context threw
/// "Navigator operation requested with a context that does not include a
/// Navigator". `useRootNavigator: true` does not help: `Navigator.of` only ever
/// searches upwards, and in router mode there is nothing above to find. So fall
/// back to the root navigator's own context, which is by definition inside one.
Future<void> showVoiceSaleSheet(BuildContext context, WidgetRef ref) {
  // Resolved before any state is touched: a tap that cannot open the sheet must
  // not consume the background sale on its way to doing nothing, which is
  // exactly how the banner used to vanish while leaving the cart unreachable.
  final host = Navigator.maybeOf(context) != null
      ? context
      : rootNavigatorKey.currentContext;
  if (host == null || !host.mounted) return Future<void>.value();

  ref.read(voiceControllerProvider.notifier).resumeFromBackground();
  return showModalBottomSheet<void>(
    context: host,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const VoiceSaleSheet(),
  ).whenComplete(
    () => ref.read(voiceControllerProvider.notifier).releaseSheet(),
  );
}

/// Hosts the whole voice-sale flow in one bottom sheet, switching on
/// [VoiceSaleState.phase]: mic idle, listening/recording, a thinking
/// placeholder while `parse-sale` runs, the review step (delegates entirely to
/// [VoiceReviewSheet], which closes the sheet itself once a sale is added),
/// and an error state with retry. This widget only renders whatever
/// [voiceControllerProvider] currently says -- [showVoiceSaleSheet] owns
/// resetting the controller when the sheet goes away.
class VoiceSaleSheet extends ConsumerWidget {
  const VoiceSaleSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceControllerProvider);
    final notifier = ref.read(voiceControllerProvider.notifier);

    return switch (state.phase) {
      VoicePhase.idle => _IdlePane(onStart: notifier.startListening),
      VoicePhase.listening => _ListeningPane(
        onStop: notifier.stopAndParse,
        deadline: state.listenDeadline,
        words: state.heardText,
      ),
      VoicePhase.thinking => const _ThinkingPane(),
      VoicePhase.reviewing => const VoiceReviewSheet(),
      VoicePhase.error => _ErrorPane(
        errorKey: state.errorMessage,
        // When words were heard before the failure, retrying re-reads them --
        // the shopkeeper already said the sale once. When they weren't, retry
        // can only mean starting over.
        onRetry: state.canRetryAudio ? notifier.retryLastAudio : notifier.reset,
        onRecordAgain: state.canRetryAudio ? notifier.reset : null,
        // Retrying into the same noise repeats the same failure, so offer the
        // text path as a real way out. `context`/`ref` are available here, so
        // `_ErrorPane` stays a plain StatelessWidget.
        onTypeInstead: () =>
            showVoiceTranscriptDialog(context, ref, state.heardText ?? ''),
      ),
    };
  }
}

/// Shared padding for every non-review pane -- matches `VoiceReviewSheet`'s and
/// `_AddToCartSheet`'s bottom-sheet insets so the mic sheet's phases don't
/// visually jump against the review step that follows them.
class _PanePadding extends StatelessWidget {
  const _PanePadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
    );
  }
}

/// A large circular icon button -- the mic to start listening, or (in its
/// error-colored form) the stop button while listening. No tooltip, matching
/// this feature's own icon-only convention (see `_NotFoundRow`'s close
/// button in `voice_review_sheet.dart`).
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.stop = false,
  });

  final IconData icon;
  final VoidCallback onPressed;

  /// The salmon stop button (dark square) rather than the blue mic.
  final bool stop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>();
    final size = stop ? 100.0 : 120.0;
    final decoration = stop
        ? BoxDecoration(
            shape: BoxShape.circle,
            color: colors?.stop ?? Theme.of(context).colorScheme.error,
            boxShadow: [
              BoxShadow(
                color: (colors?.stop ?? Colors.red).withValues(alpha: 0.35),
                blurRadius: 24,
              ),
            ],
          )
        : _micDecoration(context);
    final button = DecoratedBox(
      decoration: decoration,
      child: SizedBox(
        width: size,
        height: size,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: stop ? 44 : 48),
          style: IconButton.styleFrom(
            foregroundColor: stop
                ? const Color(0xFF14161F)
                : const Color(0xFF06102A),
            shape: const CircleBorder(),
          ),
        ),
      ),
    );
    return stop ? button : _MicHalo(child: button);
  }
}

/// The big mic's fill: a light-blue gradient with a soft blue glow.
BoxDecoration _micDecoration(BuildContext context) => const BoxDecoration(
  shape: BoxShape.circle,
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF6FAEFF), Color(0xFF3D82F5)],
  ),
  boxShadow: [BoxShadow(color: Color(0x734D92FE), blurRadius: 26)],
);

/// The soft halo ring around the big mic.
class _MicHalo extends StatelessWidget {
  const _MicHalo({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary.withValues(alpha: 0.10),
        border: Border.all(color: primary.withValues(alpha: 0.14)),
      ),
      child: child,
    );
  }
}

class _IdlePane extends StatelessWidget {
  const _IdlePane({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return _PanePadding(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundIconButton(icon: Icons.mic, onPressed: onStart),
          const SizedBox(height: 24),
          Text(
            l10n.voice_hintIdle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _ListeningPane extends StatelessWidget {
  const _ListeningPane({required this.onStop, this.deadline, this.words});

  final VoidCallback onStop;

  /// What the phone has heard so far, shown live so a mishear is caught
  /// while the shopkeeper is still speaking.
  final String? words;

  /// When the recording will auto-stop, or null before the cap is armed.
  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return _PanePadding(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _MicLevelMeter(),
          const SizedBox(height: 20),
          Text(
            l10n.voice_recording,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          // Fixed height so the pane does not jump as words arrive.
          SizedBox(
            height: 52,
            child: Center(
              child: Text(
                words ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          // Fixed height so the pane does not jump when the countdown appears.
          SizedBox(height: 28, child: _AutoStopCountdown(deadline: deadline)),
          _RoundIconButton(icon: Icons.stop, onPressed: onStop, stop: true),
        ],
      ),
    );
  }
}

/// The live microphone level: a mic glyph that grows with what the phone is
/// actually hearing, over a row of bars.
///
/// This replaces a mic that pulsed on a fixed 900ms timer regardless of input.
/// That pulse was a fuel gauge welded to half-full -- it looked like feedback
/// while telling the shopkeeper nothing, so a phone that could not hear them at
/// all (pocket noise, hand over the mic, a metre too far away in a loud shop)
/// looked identical to one hearing them perfectly. Real bars let a person fix
/// the problem themselves, in the moment, which no amount of server-side
/// tuning can do for them.
///
/// Reduced motion suppresses the scale transform but keeps the bars: they are
/// information, not decoration.
class _MicLevelMeter extends ConsumerStatefulWidget {
  const _MicLevelMeter();

  @override
  ConsumerState<_MicLevelMeter> createState() => _MicLevelMeterState();
}

class _MicLevelMeterState extends ConsumerState<_MicLevelMeter> {
  static const _barCount = 12;

  /// Level below which the recording is treated as "nothing is reaching the
  /// mic" for the purpose of the hint. Well under normal speech, which peaks
  /// far higher even across a room.
  static const _inaudible = 0.08;

  /// Grace before nagging: people take a moment to start talking, and a hint
  /// that appears the instant recording begins is noise.
  static const _hintAfter = Duration(milliseconds: 2500);

  double _peak = 0;
  bool _hintDue = false;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    // A one-shot timer, not a check on rebuild: when the level is a flat zero
    // the notifier emits no changes at all (Riverpod drops equal values), so
    // there would be no rebuild to notice the silence on.
    _hintTimer = Timer(_hintAfter, () {
      if (mounted) setState(() => _hintDue = true);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = ref.watch(micLevelProvider);
    if (level > _peak) _peak = level;

    final scheme = theme.colorScheme;
    final core = _MicHalo(
      child: SizedBox(
        width: 120,
        height: 120,
        child: DecoratedBox(
          decoration: _micDecoration(context),
          child: const Icon(Icons.mic, size: 48, color: Color(0xFF06102A)),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (AppMotion.reduced(context))
          core
        else
          // Same 1.0-1.12 range the old decorative pulse used, so the pane's
          // proportions are unchanged -- only what drives it is different.
          Transform.scale(scale: 1 + level * 0.12, child: core),
        const SizedBox(height: 16),
        Semantics(
          label: context.l10n.voice_levelLabel,
          value: '${(level * 100).round()}%',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _barCount; i++)
                _LevelBar(lit: level * _barCount > i, scheme: scheme),
            ],
          ),
        ),
        if (_hintDue && _peak < _inaudible) ...[
          const SizedBox(height: 12),
          Text(
            context.l10n.voice_speakCloser,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.lit, required this.scheme});

  final bool lit;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final idle =
        Theme.of(context).extension<AppColors>()?.barIdle ??
        scheme.surfaceContainerHighest;
    return Container(
      width: 9,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: lit ? scheme.primary : idle,
      ),
    );
  }
}

/// Counts down the last few seconds before the recording auto-stops.
///
/// The cap exists so a clip can never grow unbounded, but it used to fire in
/// total silence -- mid-sentence, with no warning, like a phone call that hangs
/// up at fifteen seconds without a beep. Shows nothing until the recording is
/// within [autoStopWarning] of its deadline.
class _AutoStopCountdown extends StatefulWidget {
  const _AutoStopCountdown({required this.deadline});

  final DateTime? deadline;

  @override
  State<_AutoStopCountdown> createState() => _AutoStopCountdownState();
}

class _AutoStopCountdownState extends State<_AutoStopCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Sub-second so the number shown is never a whole second stale; setState is
    // cheap here because this widget's subtree is one Text.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deadline = widget.deadline;
    if (deadline == null) return const SizedBox.shrink();

    // Must be the same clock the deadline was stamped from -- see
    // `VoiceController.startListening`.
    final remaining = deadline.difference(clock.now());
    if (remaining > autoStopWarning || remaining.isNegative) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    // Ceiling, so a recording with 0.4s left reads "1" rather than "0".
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    return Center(
      child: Text(
        context.l10n.voice_stoppingIn(seconds),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

/// How long each stage of [_ThinkingPane] is shown before the next takes over.
///
/// Paced on a timer, NOT on server progress. `parse-sale` transcribes and parses
/// in a single Gemini call and reports nothing until it returns, so there is no
/// real intermediate signal to display -- these are honest *labels* for what is
/// happening, on a plausible schedule, not measurements. They exist because one
/// unbroken blank wait reads as "frozen" while a sequence that visibly moves
/// reads as "working"; the seconds are identical either way.
///
/// The last stage has no duration: it stays until the result lands, however
/// long that takes, rather than advancing into a lie about being nearly done.
const _thinkingStageDurations = <Duration>[
  Duration(milliseconds: 900),
  Duration(milliseconds: 1500),
];

/// Ceiling for the progress bar's estimate. It creeps toward this and waits: a
/// bar that reaches 100% before the answer arrives is worse than no bar at all.
const _thinkingProgressCeiling = 0.92;

/// Time constant for that creep -- progress is `1 - e^(-t/tau)`, so it is quick
/// early (where most parses finish) and slows down the longer it runs, which is
/// also roughly how the real wait is distributed.
const _thinkingProgressTau = Duration(milliseconds: 2600);

/// The wait between "stop talking" and "cart appears".
///
/// Replaces two static grey skeleton cards. Those told the shopkeeper nothing:
/// a frozen screen and a broken screen look the same, which is what made a
/// three-second wait feel like a hang. This shows named stages that advance, a
/// bar that moves, and -- most importantly -- says out loud that they can close
/// the sheet and get on with serving the customer.
class _ThinkingPane extends StatefulWidget {
  const _ThinkingPane();

  @override
  State<_ThinkingPane> createState() => _ThinkingPaneState();
}

class _ThinkingPaneState extends State<_ThinkingPane> {
  /// Same `clock.now()` discipline as [_AutoStopCountdown]: identical to
  /// `DateTime.now()` in production, but advances with virtual time under
  /// `fake_async` so this pane is testable without real waiting.
  final DateTime _startedAt = clock.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 100ms keeps the bar visibly smooth without rebuilding a subtree that is
    // only ever a few Texts and a progress bar.
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Index of the stage the elapsed time has reached, saturating at the last.
  int _stageIndex(Duration elapsed) {
    var remaining = elapsed;
    for (var i = 0; i < _thinkingStageDurations.length; i++) {
      if (remaining < _thinkingStageDurations[i]) return i;
      remaining -= _thinkingStageDurations[i];
    }
    return _thinkingStageDurations.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final elapsed = clock.now().difference(_startedAt);
    final stage = _stageIndex(elapsed);
    final labels = [
      l10n.voice_stageHeard,
      l10n.voice_stageUnderstanding,
      l10n.voice_stageMatching,
    ];

    final progress =
        (1 -
            math.exp(
              -elapsed.inMilliseconds / _thinkingProgressTau.inMilliseconds,
            )) *
        _thinkingProgressCeiling;

    return _PanePadding(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            _ThinkingStageRow(
              label: labels[i],
              done: i < stage,
              active: i == stage,
            ),
            if (i < labels.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: AppMotion.reduced(context) ? null : progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 12),
          // A real control, not just the hint that used to sit here alone.
          // Telling someone "you can close this" while giving them nothing to
          // press makes them hunt for the gesture -- tap-outside and swipe-down
          // both work, but a shopkeeper mid-transaction should not have to
          // guess. Popping the sheet routes through `showVoiceSaleSheet`'s
          // `whenComplete`, so this is exactly the same path as a swipe: the
          // parse carries on and `VoiceReadyBanner` takes over.
          TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            label: Text(l10n.voice_thinkingMinimize),
          ),
          Text(
            l10n.voice_thinkingDismissHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of [_ThinkingPane]'s checklist: a tick once passed, a live spinner
/// while current, and dimmed until reached.
class _ThinkingStageRow extends StatelessWidget {
  const _ThinkingStageRow({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final muted = theme.colorScheme.onSurfaceVariant;

    final Widget leading = done
        ? Icon(Icons.check_circle, size: 18, color: colors.positive)
        : active
        // Full 18px, matching the tick and the outline it sits between. It was
        // inset by 2 with a thinner stroke, which on-device read as a faint dot
        // rather than something spinning.
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: theme.colorScheme.primary,
            ),
          )
        : Icon(
            Icons.circle_outlined,
            size: 18,
            color: muted.withValues(alpha: 0.4),
          );

    return Row(
      children: [
        leading,
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: done || active ? theme.colorScheme.onSurface : muted,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({
    required this.errorKey,
    required this.onRetry,
    required this.onTypeInstead,
    this.onRecordAgain,
  });

  final String? errorKey;
  final VoidCallback onRetry;
  final VoidCallback onTypeInstead;

  /// Offered only when [onRetry] re-sends kept audio, as the way to discard it
  /// and speak again. Null when retry already means starting over.
  final VoidCallback? onRecordAgain;

  /// Maps the controller's magic error keys to localized copy. Anything else
  /// is a repository `Failure.message`, already user-friendly, and is shown
  /// as-is.
  String _message(AppLocalizations l10n) => switch (errorKey) {
    'micDenied' => l10n.voice_errMicDenied,
    'noSpeech' => l10n.voice_errNoSpeech,
    'noMatch' => l10n.voice_errNoMatch,
    'tooQuiet' => l10n.voice_errTooQuiet,
    final other? => other,
    // Unreachable in practice -- every real transition to `error` sets a
    // non-null errorMessage (a magic key or a repository Failure.message).
    // Kept only so the switch stays exhaustive over String?; deliberately
    // returns the same copy as the 'noMatch' case above rather than implying
    // some distinct behavior.
    null => l10n.voice_errNoMatch,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return _PanePadding(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            _message(l10n),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton.tonal(onPressed: onRetry, child: Text(l10n.voice_retry)),
          if (onRecordAgain case final recordAgain?) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: recordAgain,
              child: Text(l10n.voice_recordAgain),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: onTypeInstead,
            child: Text(l10n.voice_typeInstead),
          ),
        ],
      ),
    );
  }
}
