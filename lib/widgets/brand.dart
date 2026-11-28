import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// Official raster logo (from the brand artwork).
class BrandLogo extends StatelessWidget {
  final double width;
  final bool full;
  const BrandLogo({super.key, this.width = 160, this.full = false});

  @override
  Widget build(BuildContext context) => Image.asset(
        full ? 'assets/images/logo_full.png' : 'assets/images/logo_mark.png',
        width: width,
        fit: BoxFit.contain,
        semanticLabel: 'UrbanEye logo',
      );
}

/// Circular app mark (iris crop) for compact placements.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.electric.withValues(alpha: 0.5), width: 2),
        ),
        child: ClipOval(child: Image.asset('assets/images/logo_iris.png', fit: BoxFit.cover, semanticLabel: 'UrbanEye')),
      );
}

class Wordmark extends StatelessWidget {
  final double size;
  final Color? color;
  const Wordmark({super.key, this.size = 28, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.ue.text;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'Urban', style: TextStyle(color: c, fontWeight: FontWeight.w800)),
        TextSpan(text: 'Eye', style: TextStyle(color: context.isDark ? AppColors.electricSoft : AppColors.electric, fontWeight: FontWeight.w800)),
      ]),
      style: AppText.h1(context).copyWith(fontSize: size, letterSpacing: -0.5),
    );
  }
}

/// Minimal vector eye + skyline. [open] 0..1 opens the eyelids,
/// [scan] 0..1 sweeps a scan beam across the skyline in the iris.
class EyeScanMark extends StatelessWidget {
  final double size;
  final double open;
  final double scan;
  final double skyline;
  const EyeScanMark({super.key, this.size = 200, this.open = 1, this.scan = -1, this.skyline = 1});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size * 0.62), painter: _EyePainter(open, scan, skyline));
}

class _EyePainter extends CustomPainter {
  final double open;
  final double scan;
  final double skyline;
  _EyePainter(this.open, this.scan, this.skyline);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final c = Offset(w / 2, h / 2);
    final lid = h * 0.5 * open;

    final eye = Path()
      ..moveTo(0, c.dy)
      ..quadraticBezierTo(w / 2, c.dy - lid * 2, w, c.dy)
      ..quadraticBezierTo(w / 2, c.dy + lid * 2, 0, c.dy)
      ..close();

    // Outer glow
    canvas.drawPath(eye, Paint()
      ..color = AppColors.electric.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

    canvas.drawPath(eye, Paint()..shader = const LinearGradient(colors: [Color(0xFF0E2350), Color(0xFF16357A)]).createShader(Offset.zero & s));
    canvas.drawPath(eye, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022
      ..shader = const LinearGradient(colors: [AppColors.electricSoft, AppColors.sky, AppColors.electric]).createShader(Offset.zero & s));

    canvas.save();
    canvas.clipPath(eye);

    // Iris
    final r = h * 0.42;
    canvas.drawCircle(c, r, Paint()..shader = const RadialGradient(colors: [Color(0xFF9CC7FF), Color(0xFF2F6BFF)]).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018
      ..color = Colors.white.withValues(alpha: 0.9));

    // Skyline inside iris
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r - 2)));
    final base = c.dy + r * 0.55;
    final sky = Paint()..color = AppColors.navy.withValues(alpha: 0.9);
    final heights = [0.35, 0.6, 0.45, 0.95, 0.55, 0.75, 0.4, 0.65, 0.3];
    final bw = (r * 2) / heights.length;
    for (var i = 0; i < heights.length; i++) {
      final bh = r * heights[i] * skyline;
      final x = c.dx - r + i * bw;
      canvas.drawRect(Rect.fromLTWH(x + 1, base - bh, bw - 2, bh + r), sky);
      if (i == 3) {
        // Pagoda / tower tip
        final tip = Path()
          ..moveTo(x - 2, base - bh)
          ..lineTo(x + bw / 2, base - bh - r * 0.18 * skyline)
          ..lineTo(x + bw + 2, base - bh)
          ..close();
        canvas.drawPath(tip, sky);
      }
    }
    canvas.drawRect(Rect.fromLTWH(c.dx - r, base, r * 2, r), Paint()..color = AppColors.navy);

    // Scan beam
    if (scan >= 0 && scan <= 1) {
      final sx = c.dx - r + scan * r * 2;
      final beam = Rect.fromLTWH(sx - r * 0.35, c.dy - r, r * 0.35, r * 2);
      canvas.drawRect(beam, Paint()..shader = LinearGradient(colors: [Colors.transparent, AppColors.emerald.withValues(alpha: 0.55)]).createShader(beam));
      canvas.drawLine(Offset(sx, c.dy - r), Offset(sx, c.dy + r), Paint()
        ..color = const Color(0xFF6EE7B7)
        ..strokeWidth = 2);
    }
    canvas.restore();

    // Pupil highlight
    canvas.drawCircle(c + Offset(-r * 0.4, -r * 0.45), r * 0.12, Paint()..color = Colors.white.withValues(alpha: 0.8));
    canvas.restore();

    // Tech nodes on the outline
    final node = Paint()..color = Colors.white;
    for (final t in [0.2, 0.8]) {
      final y = c.dy - 4 * t * (1 - t) * lid;
      canvas.drawCircle(Offset(w * t, y), w * 0.014, node);
    }
  }

  @override
  bool shouldRepaint(covariant _EyePainter old) => old.open != open || old.scan != scan || old.skyline != skyline;
}
