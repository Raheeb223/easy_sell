import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'scan_camera.dart';

/// The `camera` package behind the [ScanCamera] seam.
///
/// Resolution is [ResolutionPreset.high] (1280x720). Nothing is uploaded any
/// more (recognition runs on the phone), and on-device ML Kit needs the extra
/// pixels to read small print like `500ml`; the vision model scales the frame
/// down to 224px itself.
class RealScanCamera implements ScanCamera {
  CameraController? _controller;

  /// Bumped at the start of every [initialize] call and every [dispose]
  /// call. Each [initialize] call captures the value at its own start; if
  /// that no longer matches [_generation] by the time the call finishes
  /// awaiting hardware, a *later* call (or an explicit [dispose]) has
  /// started since, and this call has been superseded.
  ///
  /// Why this exists: [initialize] was already made safe against
  /// *sequential* re-entry (dispose-then-recreate), but the app-lifecycle
  /// handler in `scan_session_screen.dart` can call it *concurrently* --
  /// `initState` starts an `initialize()`, the runtime permission prompt
  /// takes focus and fires `inactive` (calling `dispose()`, a no-op because
  /// `_controller` is still null -- the first call hasn't published yet),
  /// the user grants permission, `resumed` fires and starts a *second*
  /// `initialize()` while the first is still awaiting its own
  /// `controller.initialize()`. Both eventually resolve, and without this
  /// guard whichever finishes last wins by overwriting `_controller`,
  /// leaking the other -- still bound to live CameraX hardware, still
  /// holding an open orientation-stream subscription -- for the app's
  /// lifetime, because `scanCameraProvider` is a plain (non-autoDispose)
  /// `Provider` that never disposes this object on its own. The generation
  /// counter makes whichever call is superseded dispose its OWN controller
  /// instead of publishing it, regardless of completion order.
  int _generation = 0;

  @override
  Future<void> initialize() async {
    final myGeneration = ++_generation;

    // scanCameraProvider is a plain (non-autoDispose) Provider, so one
    // RealScanCamera outlives every app-lifecycle pause/resume and
    // initialize() can land again without a preceding dispose(). Retiring
    // whatever controller is already here first (a no-op the first time)
    // stops that path from silently abandoning a controller that still
    // holds a live device-orientation subscription and bound platform
    // camera resources -- the frozen/black preview after backgrounding.
    await _disposeQuietly(_controller);
    _controller = null;

    final cameras = await availableCameras();
    if (myGeneration != _generation) return; // superseded; nothing bound yet
    if (cameras.isEmpty) throw const CameraUnavailable();
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
    } on CameraException catch (e) {
      // A failure here can land after the plugin has already bound the
      // camera to the process lifecycle (ProcessCameraProvider.bindToLifecycle
      // in android_camera_camerax.dart, called from initializeCamera before
      // this can throw), so the controller may be holding live hardware and
      // an active stream subscription. Dispose it before mapping/rethrowing
      // so nothing is ever abandoned. A pure permission refusal throws
      // earlier, in createCameraWithSettings, before anything is bound --
      // disposing here is a no-op for that case, not a workaround for it.
      await _disposeQuietly(controller);
      // The plugin reports a refusal as an access-denied code rather than a
      // typed error; anything else is a real device fault worth rethrowing.
      if (e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt' ||
          e.code == 'CameraAccessRestricted') {
        throw const CameraPermissionDenied();
      }
      rethrow;
    }

    if (myGeneration != _generation) {
      // Superseded while awaiting controller.initialize(): a later
      // initialize() (or a dispose() while this one was in flight) has
      // already claimed -- or cleared -- the field. This controller is
      // bound to live hardware that nobody would otherwise ever dispose;
      // retire it instead of publishing over the newer, authoritative
      // outcome. Note this call still returns normally (it did succeed,
      // from its own point of view) rather than throwing -- there is no
      // real failure to report to whoever awaited this specific call.
      await _disposeQuietly(controller);
      return;
    }
    _controller = controller;
  }

  /// Best-effort disposal used during cleanup paths where we are already
  /// mid-error-handling or replacing a controller nobody asked to keep: a
  /// dispose() that itself throws must never mask the reason we were
  /// disposing in the first place, and must never block bringing up the
  /// controller that follows it.
  static Future<void> _disposeQuietly(CameraController? controller) async {
    if (controller == null) return;
    try {
      await controller.dispose();
    } catch (_) {
      // Swallowed deliberately -- see doc comment above.
    }
  }

  @override
  Widget buildPreview(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return CameraPreview(c);
  }

  @override
  Future<Uint8List> capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      throw StateError('capture() before initialize()');
    }
    final shot = await c.takePicture();
    return shot.readAsBytes();
  }

  @override
  Future<void> dispose() async {
    // Bump first: any initialize() currently in flight must discover, once
    // its own await resolves, that it has been superseded and dispose its
    // own controller rather than publish it here.
    _generation++;
    final c = _controller;
    _controller = null;
    await c?.dispose();
  }
}
