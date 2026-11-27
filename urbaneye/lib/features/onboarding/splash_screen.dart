import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../widgets/brand.dart';

/// Animated splash:
/// 1. Eye fades in  2. Eye opens & scans across the skyline
/// 3. Official logo appears  4. Tagline fades in  5. Transition onward.
class SplashScreen extends StatefulWidget {
  final Widget next;
  const SplashScreen({super.key, required this.next});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));

  late final Animation<double> _fadeIn = CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.15, curve: Curves.easeOut));
  late final Animation<double> _open = CurvedAnimation(parent: _c, curve: const Interval(0.05, 0.28, curve: Curves.easeOutBack));
  late final Animation<double> _skyline = CurvedAnimation(parent: _c, curve: const Interval(0.15, 0.4, curve: Curves.easeOutCubic));
  late final Animation<double> _scan = CurvedAnimation(parent: _c, curve: const Interval(0.25, 0.6, curve: Curves.easeInOutSine));
  late final Animation<double> _logo = CurvedAnimation(parent: _c, curve: const Interval(0.58, 0.78, curve: Curves.easeOutCubic));
  late final Animation<double> _tag = CurvedAnimation(parent: _c, curve: const Interval(0.74, 0.92, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (Motion.reduced(context)) {
        _c.value = 1;
        await Future.delayed(const Duration(milliseconds: 900));
      } else {
        await _c.forward();
        await Future.delayed(const Duration(milliseconds: 250));
      }
      if (mounted) context.replace(widget.next);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [Color(0xFF16357A), AppColors.navy, Color(0xFF050B1A)],
          ),
        ),
        child: Semantics(
          label: 'UrbanEye. See It. Report It. Fix It.',
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final scanning = _scan.value > 0 && _scan.value < 1;
              return Stack(children: [
                // Ambient grid dots
                Positioned.fill(child: CustomPaint(painter: _GridPainter(_fadeIn.value))),
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      height: 230,
                      width: 300,
                      child: Stack(alignment: Alignment.center, children: [
                        // Vector eye scanning the skyline
                        Opacity(
                          opacity: (_fadeIn.value * (1 - _logo.value)).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.9 + 0.1 * _fadeIn.value,
                            child: EyeScanMark(
                              size: 240,
                              open: _open.value.clamp(0.02, 1.2),
                              scan: scanning ? _scan.value : -1,
                              skyline: _skyline.value,
                            ),
                          ),
                        ),
                        // Official logo reveal
                        Opacity(
                          opacity: _logo.value,
                          child: Transform.scale(
                            scale: 0.85 + 0.15 * _logo.value,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(36),
                                boxShadow: [BoxShadow(color: AppColors.electric.withValues(alpha: 0.45 * _logo.value), blurRadius: 50)],
                              ),
                              child: const BrandLogo(width: 230),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 28),
                    Opacity(
                      opacity: _logo.value,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - _logo.value)),
                        child: const Wordmark(size: 38, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: _tag.value,
                      child: Text(
                        context.t('See It. Report It. Fix It.'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 15,
                          letterSpacing: 1.2 + 1.2 * (1 - _tag.value),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 48,
                  child: Opacity(
                    opacity: _tag.value * 0.6,
                    child: Text(
                      context.t('Every citizen can be the eyes of the city.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double t;
  _GridPainter(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.05 * t);
    for (var x = 0.0; x < s.width; x += 26) {
      for (var y = 0.0; y < s.height; y += 26) {
        canvas.drawCircle(Offset(x, y), 1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.t != t;
}
