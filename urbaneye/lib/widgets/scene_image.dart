import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models/enums.dart';
import '../domain/models/models.dart';

/// Shows captured evidence. Seeded demo data has no real photo, so we render
/// a tasteful illustrated street scene specific to the issue category.
class EvidenceImage extends StatelessWidget {
  final Evidence? evidence;
  final ReportCategory category;
  final BoxFit fit;
  const EvidenceImage({super.key, required this.evidence, required this.category, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final e = evidence;
    if (e?.bytes != null) {
      return Image.memory(
        e!.bytes!,
        fit: fit,
        gaplessPlayback: true,
        cacheWidth: 1200,
        semanticLabel: 'Photo evidence',
        errorBuilder: (_, __, ___) => SceneImage(category: category, seed: e.sceneSeed, after: e.isAfter),
      );
    }
    return Semantics(
      label: e?.isAfter == true ? 'After photo' : 'Evidence photo',
      image: true,
      child: SceneImage(category: category, seed: e?.sceneSeed ?? 0, after: e?.isAfter ?? false),
    );
  }
}

class SceneImage extends StatelessWidget {
  final ReportCategory category;
  final int seed;
  final bool after;
  const SceneImage({super.key, required this.category, this.seed = 0, this.after = false});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ScenePainter(category, seed, after), child: const SizedBox.expand());
}

class _ScenePainter extends CustomPainter {
  final ReportCategory cat;
  final int seed;
  final bool after;
  _ScenePainter(this.cat, this.seed, this.after);

  @override
  void paint(Canvas canvas, Size s) {
    final rnd = math.Random(seed);
    final night = cat == ReportCategory.streetlight;
    final w = s.width, h = s.height;

    // Sky
    final skyTop = night ? const Color(0xFF0B1B3F) : Color.lerp(const Color(0xFF6FA8FF), const Color(0xFF9CC7FF), rnd.nextDouble())!;
    final skyBot = night ? const Color(0xFF243B73) : const Color(0xFFE6F0FF);
    canvas.drawRect(Offset.zero & s, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [skyTop, skyBot]).createShader(Offset.zero & s));

    // Distant hills
    final hills = Path()..moveTo(0, h * 0.5);
    for (var x = 0.0; x <= w; x += w / 6) {
      hills.quadraticBezierTo(x + w / 12, h * (0.36 + rnd.nextDouble() * 0.08), x + w / 6, h * 0.48);
    }
    hills
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hills, Paint()..color = (night ? const Color(0xFF1B2E5E) : const Color(0xFFB9D3F5)));

    // Skyline with pagoda roofs
    final bp = Paint()..color = night ? const Color(0xFF14254D) : const Color(0xFF8FB0DC);
    var x = -10.0;
    while (x < w) {
      final bw = 14 + rnd.nextDouble() * 26;
      final bh = h * (0.12 + rnd.nextDouble() * 0.22);
      final top = h * 0.58 - bh;
      canvas.drawRect(Rect.fromLTWH(x, top, bw, bh + 2), bp);
      if (rnd.nextDouble() > 0.72) {
        // pagoda tiers
        for (var t = 0; t < 3; t++) {
          final ty = top - t * 8.0;
          final tw = bw + 10 - t * 6;
          final roof = Path()
            ..moveTo(x + bw / 2 - tw / 2, ty)
            ..lineTo(x + bw / 2, ty - 7)
            ..lineTo(x + bw / 2 + tw / 2, ty)
            ..close();
          canvas.drawPath(roof, Paint()..color = night ? const Color(0xFF3A2A4A) : const Color(0xFFB4654A));
        }
      } else if (!night) {
        final wp = Paint()..color = Colors.white.withValues(alpha: 0.35);
        for (var wy = top + 5; wy < h * 0.56; wy += 7) {
          canvas.drawRect(Rect.fromLTWH(x + 3, wy, bw - 6, 2), wp);
        }
      } else {
        final wp = Paint()..color = const Color(0xFFFFD27A).withValues(alpha: 0.55);
        for (var wy = top + 5; wy < h * 0.56; wy += 8) {
          if (rnd.nextBool()) canvas.drawRect(Rect.fromLTWH(x + 3, wy, 3, 3), wp);
        }
      }
      x += bw + 2;
    }

    // Ground / footpath
    canvas.drawRect(Rect.fromLTWH(0, h * 0.58, w, h * 0.42), Paint()..color = night ? const Color(0xFF2A3350) : const Color(0xFFCBD3DF));
    // Road (perspective)
    final road = Path()
      ..moveTo(w * 0.42, h * 0.58)
      ..lineTo(w * 0.58, h * 0.58)
      ..lineTo(w * 1.05, h)
      ..lineTo(-w * 0.05, h)
      ..close();
    canvas.drawPath(road, Paint()..color = night ? const Color(0xFF1C2238) : const Color(0xFF5B6475));
    // Lane markings
    final lane = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 2.5;
    for (var i = 0; i < 5; i++) {
      final t0 = i / 5, t1 = t0 + 0.1;
      canvas.drawLine(Offset(w * 0.5, h * (0.6 + t0 * 0.4)), Offset(w * 0.5, h * (0.6 + t1 * 0.4)), lane..strokeWidth = 1.5 + t0 * 3);
    }

    _subject(canvas, s, rnd, night);

    // Subtle photographic vignette
    canvas.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = RadialGradient(colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)], stops: const [0.6, 1])
              .createShader(Offset.zero & s));
  }

  void _subject(Canvas c, Size s, math.Random rnd, bool night) {
    final w = s.width, h = s.height;
    switch (cat) {
      case ReportCategory.road:
      case ReportCategory.other:
        if (!after) {
          c.drawOval(Rect.fromCenter(center: Offset(w * 0.36, h * 0.82), width: w * 0.3, height: h * 0.1), Paint()..color = const Color(0xFF2B2F38));
          c.drawOval(Rect.fromCenter(center: Offset(w * 0.36, h * 0.83), width: w * 0.22, height: h * 0.06), Paint()..color = const Color(0xFF6B7A99).withValues(alpha: 0.6));
          final crack = Paint()
            ..color = const Color(0xFF2B2F38)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;
          c.drawPath(Path()..moveTo(w * 0.5, h * 0.8)..lineTo(w * 0.6, h * 0.86)..lineTo(w * 0.66, h * 0.84)..lineTo(w * 0.76, h * 0.92), crack);
        } else {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.36, h * 0.82), width: w * 0.32, height: h * 0.1), const Radius.circular(6)),
              Paint()..color = const Color(0xFF3E4655));
        }
      case ReportCategory.waste:
        // Bin
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.7, h * 0.56, w * 0.12, h * 0.2), const Radius.circular(4)), Paint()..color = const Color(0xFF10B981));
        if (!after) {
          final colors = [const Color(0xFF8D6E63), const Color(0xFFFFFFFF), const Color(0xFF64B5F6), const Color(0xFF424242), const Color(0xFFFFB74D)];
          for (var i = 0; i < 26; i++) {
            final cx = w * (0.6 + rnd.nextDouble() * 0.32);
            final cy = h * (0.72 + rnd.nextDouble() * 0.1);
            c.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 10 + rnd.nextDouble() * 18, height: 7 + rnd.nextDouble() * 10),
                Paint()..color = colors[i % colors.length]);
          }
        }
      case ReportCategory.water:
        if (!after) {
          c.drawOval(Rect.fromCenter(center: Offset(w * 0.3, h * 0.84), width: w * 0.5, height: h * 0.12), Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.65));
          final spray = Paint()..color = const Color(0xFF7DD3FC);
          for (var i = 0; i < 14; i++) {
            c.drawCircle(Offset(w * (0.18 + rnd.nextDouble() * 0.12), h * (0.64 + rnd.nextDouble() * 0.15)), 2 + rnd.nextDouble() * 2.5, spray);
          }
        }
        c.drawRect(Rect.fromLTWH(0, h * 0.78, w * 0.24, 6), Paint()..color = const Color(0xFF94A3B8));
      case ReportCategory.streetlight:
        final pole = Paint()
          ..color = const Color(0xFF475569)
          ..strokeWidth = 4;
        final lean = after ? 0.0 : (seed.isEven ? 0.0 : 10.0);
        c.drawLine(Offset(w * 0.72, h * 0.95), Offset(w * 0.72 + lean, h * 0.3), pole);
        c.drawLine(Offset(w * 0.72 + lean, h * 0.3), Offset(w * 0.62 + lean, h * 0.3), pole);
        final lampOn = after;
        if (lampOn) {
          c.drawCircle(Offset(w * 0.62, h * 0.32), 40, Paint()..color = const Color(0xFFFFE08A).withValues(alpha: 0.25));
          final cone = Path()
            ..moveTo(w * 0.6, h * 0.32)
            ..lineTo(w * 0.42, h * 0.95)
            ..lineTo(w * 0.82, h * 0.95)
            ..close();
          c.drawPath(cone, Paint()..color = const Color(0xFFFFE08A).withValues(alpha: 0.18));
        }
        c.drawOval(Rect.fromCenter(center: Offset(w * 0.62 + lean, h * 0.32), width: 18, height: 8),
            Paint()..color = lampOn ? const Color(0xFFFFE08A) : const Color(0xFF64748B));
      case ReportCategory.parking:
        if (!after) {
          final car = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.56, h * 0.66, w * 0.34, h * 0.14), const Radius.circular(8));
          c.drawRRect(car, Paint()..color = const Color(0xFFF1F5F9));
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.62, h * 0.6, w * 0.2, h * 0.08), const Radius.circular(6)), Paint()..color = const Color(0xFFE2E8F0));
          c.drawRect(Rect.fromLTWH(w * 0.64, h * 0.615, w * 0.16, h * 0.05), Paint()..color = const Color(0xFF7DA2D6));
          for (final dx in [0.62, 0.84]) {
            c.drawCircle(Offset(w * dx, h * 0.8), 7, Paint()..color = const Color(0xFF1F2937));
          }
        }
        // No parking sign
        c.drawLine(Offset(w * 0.12, h * 0.95), Offset(w * 0.12, h * 0.55), Paint()..color = const Color(0xFF64748B)..strokeWidth = 3);
        c.drawCircle(Offset(w * 0.12, h * 0.52), 12, Paint()..color = const Color(0xFFEF4444));
        c.drawCircle(Offset(w * 0.12, h * 0.52), 8, Paint()..color = const Color(0xFF2F6BFF));
      case ReportCategory.infrastructure:
        if (!after) {
          c.drawOval(Rect.fromCenter(center: Offset(w * 0.24, h * 0.76), width: w * 0.2, height: h * 0.07), Paint()..color = const Color(0xFF111827));
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.34, h * 0.72, w * 0.14, 6), const Radius.circular(3)), Paint()..color = const Color(0xFF6B7280));
        } else {
          c.drawOval(Rect.fromCenter(center: Offset(w * 0.24, h * 0.76), width: w * 0.2, height: h * 0.07), Paint()..color = const Color(0xFF6B7280));
        }
        final rail = Paint()
          ..color = const Color(0xFF94A3B8)
          ..strokeWidth = 2.5;
        c.drawLine(Offset(w * 0.55, h * 0.62), Offset(w * 0.95, h * 0.62), rail);
        for (var i = 0; i < 5; i++) {
          final bx = w * (0.57 + i * 0.09);
          c.drawLine(Offset(bx, h * 0.62), Offset(bx + (after || i != 2 ? 0 : 8), h * 0.72), rail);
        }
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => old.seed != seed || old.cat != cat || old.after != after;
}
