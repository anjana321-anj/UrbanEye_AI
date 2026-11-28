import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../data/services/device_services.dart';
import '../../data/services/media_service.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../widgets/ue_widgets.dart';

/// Full-screen in-app camera: flash modes, camera flip, capture animation,
/// preview with retake. Pops with an [Evidence] (or null).
/// Falls back to the system camera if no camera can be opened in-app.
class CameraCaptureScreen extends StatefulWidget {
  final String hint;
  const CameraCaptureScreen({super.key, this.hint = 'Center the issue in the frame'});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  List<CameraDescription> _cams = [];
  CameraController? _ctrl;
  int _camIndex = 0;
  FlashMode _flash = FlashMode.off;
  bool _capturing = false;
  bool _denied = false;
  bool _failed = false;
  Uint8List? _preview;
  late final AnimationController _shutter = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  late final AnimationController _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final perm = await Services.I.permissions.request(AppPermission.camera);
    if (perm == PermState.denied || perm == PermState.permanentlyDenied) {
      if (mounted) {
        setState(() {
          _denied = true;
        });
      }
      return;
    }
    try {
      _cams = await availableCameras();
      if (_cams.isEmpty) throw Exception('no camera');
      final back = _cams.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _camIndex = back < 0 ? 0 : back;
      await _open();
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
        });
      }
    }
  }

  Future<void> _open() async {
    final old = _ctrl;
    _ctrl = null;
    await old?.dispose();
    final c = CameraController(_cams[_camIndex], ResolutionPreset.medium, enableAudio: false);
    await c.initialize();
    try {
      await c.setFlashMode(_flash);
    } catch (_) {}
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() {
      _ctrl = c;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _ctrl = null;
      c.dispose();
    } else if (state == AppLifecycleState.resumed && _preview == null) {
      _open();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl?.dispose();
    _shutter.dispose();
    _scan.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    final next = switch (_flash) { FlashMode.off => FlashMode.auto, FlashMode.auto => FlashMode.always, _ => FlashMode.off };
    try {
      await _ctrl?.setFlashMode(next);
      setState(() => _flash = next);
      Haptics.tap();
    } catch (_) {
      showToast(context, 'Flash is not available on this camera', kind: ToastKind.warning);
    }
  }

  Future<void> _flip() async {
    if (_cams.length < 2) return;
    Haptics.tap();
    setState(() {
      _camIndex = (_camIndex + 1) % _cams.length;
    });
    await _open();
  }

  Future<void> _capture() async {
    final c = _ctrl;
    if (c == null || _capturing || !c.value.isInitialized) return;
    setState(() => _capturing = true);
    Haptics.medium();
    _shutter.forward(from: 0);
    try {
      final f = await c.takePicture();
      final bytes = await f.readAsBytes();
      if (mounted) setState(() => _preview = bytes);
    } catch (_) {
      if (mounted) showToast(context, 'Capture failed. Please try again.', kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _use() {
    Navigator.pop(
      context,
      Evidence(id: 'ev-${DateTime.now().microsecondsSinceEpoch}', kind: EvidenceKind.photo, bytes: _preview, capturedAt: DateTime.now()),
    );
  }

  Future<void> _systemFallback() async {
    final e = await MediaService.captureWithSystemCamera();
    if (mounted) Navigator.pop(context, e);
  }

  Future<void> _galleryFallback() async {
    final e = await MediaService.pickSinglePhoto();
    if (mounted) Navigator.pop(context, e);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_denied) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ErrorState(
          kind: ErrorKind.cameraDenied,
          onRetry: () => Services.I.permissions.openSettings(),
          secondaryLabel: 'Upload from gallery instead',
          onSecondary: _galleryFallback,
        ),
      );
    }
    if (_failed) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ErrorState(
          kind: ErrorKind.cameraDenied,
          message: context.t('The in-app camera could not start on this device. Use the system camera instead.'),
          retryLabel: 'Open System Camera',
          onRetry: _systemFallback,
          secondaryLabel: 'Upload from gallery instead',
          onSecondary: _galleryFallback,
        ),
      );
    }
    if (_preview != null) return _previewView();

    final c = _ctrl;
    return Stack(fit: StackFit.expand, children: [
      if (c != null && c.value.isInitialized)
        Center(child: AspectRatio(aspectRatio: 1 / c.value.aspectRatio, child: CameraPreview(c)))
      else
        const Center(child: CircularProgressIndicator(color: Colors.white)),

      // Viewfinder overlay
      IgnorePointer(
        child: AnimatedBuilder(
          animation: _scan,
          builder: (_, __) => CustomPaint(painter: _ViewfinderPainter(Motion.reduced(context) ? 0.5 : _scan.value)),
        ),
      ),

      // Shutter flash
      IgnorePointer(
        child: AnimatedBuilder(
          animation: _shutter,
          builder: (_, __) => Container(color: Colors.white.withValues(alpha: (1 - _shutter.value) * (_shutter.isAnimating ? 0.85 : 0))),
        ),
      ),

      // Top bar
      Positioned(
        top: 8,
        left: 8,
        right: 8,
        child: Row(children: [
          _roundBtn(Icons.close_rounded, 'Close', () => Navigator.pop(context)),
          const Spacer(),
          _roundBtn(
            switch (_flash) { FlashMode.off => Icons.flash_off_rounded, FlashMode.auto => Icons.flash_auto_rounded, _ => Icons.flash_on_rounded },
            'Flash ${_flash.name}',
            _toggleFlash,
          ),
        ]),
      ),
      Positioned(
        top: 70,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(20)),
            child: Text(context.t(widget.hint), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ),

      // Bottom controls
      Positioned(
        bottom: 24,
        left: 24,
        right: 24,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _roundBtn(Icons.photo_library_outlined, 'Upload from gallery', _galleryFallback, size: 52),
          Semantics(
            button: true,
            label: 'Capture photo',
            child: GestureDetector(
              onTap: _capture,
              child: AnimatedScale(
                scale: _capturing ? 0.88 : 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 78,
                  height: 78,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                  child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                ),
              ),
            ),
          ),
          _roundBtn(Icons.flip_camera_android_rounded, 'Flip camera', _cams.length > 1 ? _flip : null, size: 52),
        ]),
      ),
    ]);
  }

  Widget _previewView() {
    return Stack(fit: StackFit.expand, children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.92, end: 1),
        duration: Motion.d(context, 350),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Image.memory(_preview!, fit: BoxFit.contain, semanticLabel: 'Captured photo preview'),
      ),
      Positioned(
        bottom: 24,
        left: 20,
        right: 20,
        child: Row(children: [
          Expanded(
            child: UeButton(
              label: 'Retake',
              icon: Icons.refresh_rounded,
              variant: ButtonVariant.outline,
              onPressed: () => setState(() => _preview = null),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: UeButton(label: 'Use Photo', icon: Icons.check_rounded, variant: ButtonVariant.success, onPressed: _use)),
        ]),
      ),
    ]);
  }

  Widget _roundBtn(IconData icon, String label, VoidCallback? onTap, {double size = 46}) {
    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
            child: Icon(icon, color: Colors.white, size: size * 0.46),
          ),
        ),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  final double scan;
  _ViewfinderPainter(this.scan);

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Rect.fromCenter(center: s.center(Offset.zero), width: s.width * 0.78, height: s.width * 0.78);
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 28.0;
    for (final corner in [
      [rect.topLeft, const Offset(1, 0), const Offset(0, 1)],
      [rect.topRight, const Offset(-1, 0), const Offset(0, 1)],
      [rect.bottomLeft, const Offset(1, 0), const Offset(0, -1)],
      [rect.bottomRight, const Offset(-1, 0), const Offset(0, -1)],
    ]) {
      final o = corner[0];
      canvas.drawLine(o, o + corner[1] * l, p);
      canvas.drawLine(o, o + corner[2] * l, p);
    }
    // Rule-of-thirds grid
    final g = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(s.width * i / 3, 0), Offset(s.width * i / 3, s.height), g);
      canvas.drawLine(Offset(0, s.height * i / 3), Offset(s.width, s.height * i / 3), g);
    }
    // AI scan line
    final y = rect.top + rect.height * scan;
    canvas.drawLine(Offset(rect.left + 8, y), Offset(rect.right - 8, y), Paint()
      ..color = AppColors.emerald.withValues(alpha: 0.8)
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter old) => old.scan != scan;
}
