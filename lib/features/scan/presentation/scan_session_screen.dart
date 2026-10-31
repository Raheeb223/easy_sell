import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/haptics.dart';
import '../../../core/config/theme.dart';
import '../../../core/l10n/l10n_ext.dart';
import '../../../l10n/app_localizations.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../data/scan_camera.dart';
import '../data/vision_scan_repository.dart';
import '../domain/scan_item.dart';
import 'product_picker_sheet.dart';
import 'scan_session_controller.dart';
import 'scan_tray.dart';
import 'top_sellers_strip.dart';

/// The scan session. The viewfinder never closes and recognition happens behind
/// it, so a basket is shot in one continuous run instead of one modal per item.
/// Nothing reaches the cart until "Add" -- the tray, not a per-item sheet, is
/// where AI output gets confirmed.
class ScanSessionScreen extends ConsumerStatefulWidget {
  const ScanSessionScreen({super.key});

  @override
  ConsumerState<ScanSessionScreen> createState() => _ScanSessionScreenState();
}

class _ScanSessionScreenState extends ConsumerState<ScanSessionScreen>
    with WidgetsBindingObserver {
  bool _ready = false;
  bool _denied = false;

  /// The device reports no camera hardware at all (most often an emulator).
  /// Kept distinct from [_denied]: "open Settings" is the right recovery for a
  /// refused permission but wrong advice here -- there is no permission to
  /// grant, so that button is simply not shown for this state.
  bool _unavailable = false;

  /// Any camera fault that is neither a permission refusal nor "no hardware"
  /// -- a generic `CameraException`, `availableCameras()` throwing, a
  /// `MissingPluginException` on an unconfigured platform. Without a state
  /// for this, `_start()` left it uncaught and the screen sat on an
  /// indeterminate spinner forever with no message and no way to retry.
  bool _error = false;

  /// True from the moment a shutter tap starts a capture until it settles
  /// (success or failure). Guards against a second tap landing while the
  /// first capture is still in flight: the real `camera` plugin throws
  /// `CameraException('Previous capture has not returned yet.')` on an
  /// overlapping call, and without this the FAB stays tappable through that
  /// window.
  bool _capturing = false;

  /// Captured once in [initState] rather than read from `ref` again in
  /// [dispose]/[didChangeAppLifecycleState]: those can run while this
  /// element's own `ref` is no longer safe to read (e.g. the whole tree
  /// unmounting at once, as widget-test teardown does), and `ref.read` there
  /// throws "using ref when a widget is about to or has been unmounted".
  late final ScanCamera _camera;

  @override
  void initState() {
    super.initState();
    _camera = ref.read(scanCameraProvider);
    WidgetsBinding.instance.addObserver(this);
    _start();
    // While the camera starts: load the model and label reader, so the first
    // capture is recognised as fast as every later one.
    ref.read(visionScanRepositoryProvider).warmUp().ignore();
  }

  Future<void> _start() async {
    try {
      await _camera.initialize();
      if (mounted) {
        setState(() {
          _ready = true;
          _denied = false;
          _unavailable = false;
          _error = false;
        });
      }
    } on CameraPermissionDenied {
      if (mounted) setState(() => _denied = true);
    } on CameraUnavailable {
      if (mounted) setState(() => _unavailable = true);
    } catch (_) {
      // Anything else -- a generic CameraException, availableCameras()
      // throwing, a MissingPluginException -- must not leave _ready false
      // forever with no message and no retry, the way an uncaught throw
      // here used to. Mirrors the deleted scan_screen.dart's error state.
      if (mounted) setState(() => _error = true);
    }
  }

  /// Android reclaims the camera when the app leaves the foreground. Without
  /// this the user returns to a frozen preview and a leaked handle -- the
  /// best-known trap in the `camera` package. The tray is untouched by it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _camera.dispose();
      if (mounted) setState(() => _ready = false);
    } else if (state == AppLifecycleState.resumed &&
        !_denied &&
        !_unavailable) {
      _start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.dispose();
    super.dispose();
  }

  Future<void> _shutter() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    AppHaptics.tap();
    try {
      await ref.read(scanSessionProvider.notifier).capture();
    } catch (_) {
      // The real plugin throws routinely (an overlapping capture, a
      // transient hardware fault); left unguarded that became an uncaught
      // zone error -- a tap that produced nothing but still felt confirmed
      // by the haptic above. Surface it instead of swallowing it silently.
      AppHaptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.l10n.scan_failed)));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _pick(ScanItem item) async {
    final all = item.choices.isNotEmpty
        ? item.choices
        : (ref.read(productsStreamProvider).value ?? const <Product>[]);
    final picked = await showProductPickerSheet(
      context,
      products: all,
      title: context.l10n.scan_didYouMean,
      readLabel: item.readLabel,
    );
    if (picked != null) {
      ref.read(scanSessionProvider.notifier).choose(item.id, picked);
    }
  }

  Future<void> _addAll() async {
    final items = ref.read(scanSessionProvider);
    final unresolved = items.where((i) => !i.isAddable).length;
    if (unresolved > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.scan_discardTitle),
          content: Text(ctx.l10n.scan_discardBody(unresolved)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(ctx.l10n.common_add),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    ref.read(scanSessionProvider.notifier).addAllToCart();
    AppHaptics.success();
    if (mounted) context.pop();
  }

  Future<bool> _confirmLeave() async {
    final items = ref.read(scanSessionProvider);
    if (items.isEmpty) return true;
    // Only addable chips are what "Add" actually stages -- match _addAll's
    // count so this dialog does not overstate how much is at stake (e.g. "3
    // scanned items" when only 2 would ever reach the cart).
    final addable = items.where((i) => i.isAddable).length;
    final choice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.scan_leaveTitle),
        content: Text(ctx.l10n.scan_leaveBody(addable)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.common_discard),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.common_add),
          ),
        ],
      ),
    );
    // barrierDismissible is false, but a dialog route can still resolve null
    // through other exits (e.g. the system back gesture popping the dialog's
    // own route). Treat that the same as "changed my mind": stay here with
    // the tray intact, rather than defaulting to Discard.
    if (choice == null) return false;
    if (choice) {
      ref.read(scanSessionProvider.notifier).addAllToCart();
    } else {
      ref.read(scanSessionProvider.notifier).clear();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = ref.watch(scanSessionProvider);
    final pending = items.where((i) => i.isPending).length;
    final addable = items.where((i) => i.isAddable).length;
    // Nullable: this screen's tests pump it without the app theme.
    final colors = Theme.of(context).extension<AppColors>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.inventory_scanProduct)),
        body: Column(
          children: [
            // The viewfinder card: black, radius 22, glowing outline. Black
            // only while the camera runs, so the permission / error states
            // (dark text) stay readable on the light theme's card.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Container(
                  clipBehavior: colors == null ? Clip.none : Clip.antiAlias,
                  decoration: colors == null
                      ? null
                      : _ready && !_denied && !_unavailable && !_error
                      ? BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: colors.glowBorder),
                          boxShadow: colors.cardShadow,
                        )
                      : colors.card(context),
                  child: _viewfinder(l10n),
                ),
              ),
            ),
            const TopSellersStrip(),
            ScanTray(onPick: _pick),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  key: const Key('scan-add-all'),
                  onPressed: (pending > 0 || addable == 0) ? null : _addAll,
                  child: Text(
                    pending > 0
                        ? l10n.scan_recognizing(pending)
                        // An empty tray gets no count. The disabled button used
                        // to read "Add 0 items", which scans as an error rather
                        // than as "nothing staged yet" -- the state it actually
                        // describes is the ordinary one you land on.
                        // An empty tray gets no count. The disabled button used
                        // to read "Add 0 items", which scans as an error rather
                        // than as "nothing staged yet" -- the state it actually
                        // describes is the ordinary one you land on.
                        : addable == 0
                        ? l10n.scan_addEmpty
                        : l10n.scan_addItems(addable),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewfinder(AppLocalizations l10n) {
    if (_denied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, size: 48),
              const SizedBox(height: 12),
              Text(l10n.scan_cameraDenied, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              // Deliberately relabelled, not wired to system settings: doing
              // that needs a permission_handler/app_settings dependency this
              // app does not carry. This button is a plain retry -- after a
              // first denial that happens to re-prompt, but after "Don't ask
              // again" it does nothing observable, so the label must not
              // promise more than a retry. A recorded downgrade from spec §7
              // ("a button into system settings"), not an oversight.
              FilledButton(
                onPressed: _start,
                child: Text(l10n.scan_openSettings),
              ),
            ],
          ),
        ),
      );
    }
    if (_unavailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(l10n.scan_cameraUnavailable, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(l10n.scan_failed, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _start, child: Text(l10n.common_retry)),
            ],
          ),
        ),
      );
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return Stack(
      fit: StackFit.expand,
      children: [
        _camera.buildPreview(context),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _ShutterButton(onPressed: _capturing ? null : _shutter),
          ),
        ),
      ],
    );
  }
}

/// The shutter, drawn as the ring-and-disc every camera app uses.
///
/// This was a `FloatingActionButton.large` and it looked wrong for two reasons
/// that compound. Material's large FAB is a 96dp *rounded square* filled with
/// the brand colour, and its documented meaning is the screen's primary
/// compose action -- create, add, write. On a viewfinder that reads as a giant
/// "add" button: it claims the eye, competes with the thing the shopkeeper is
/// actually pointing the phone at, and says nothing about taking a picture
/// beyond the small icon sitting inside all that fill.
///
/// The ring-and-disc needs no icon because it is the one control every phone
/// owner already knows, and being monochrome it sits on top of the preview
/// instead of fighting it. 72dp outer keeps the touch target well above the
/// 48dp minimum while occupying roughly half the visual weight of the FAB.
///
/// While a capture is in flight the disc shrinks and dims -- the same feedback
/// a physical shutter gives, and the visible half of the in-flight guard that
/// stops an overlapping tap from being silently swallowed.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onPressed});

  /// Null while a capture is in flight, which both disables the tap and
  /// switches the button to its fired appearance.
  final VoidCallback? onPressed;

  static const double _outer = 72;
  static const double _inner = 58;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: context.l10n.inventory_scanProduct,
      child: InkResponse(
        key: const Key('scan-shutter'),
        onTap: onPressed,
        radius: _outer / 2,
        customBorder: const CircleBorder(),
        child: Container(
          width: _outer,
          height: _outer,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled ? Colors.white : Colors.white38,
              width: 3,
            ),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: enabled ? _inner : _inner - 12,
              height: enabled ? _inner : _inner - 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
