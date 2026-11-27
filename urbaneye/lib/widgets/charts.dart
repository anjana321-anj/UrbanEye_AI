import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/utils.dart';
import '../domain/models/models.dart';

/// Lightweight animated charts drawn with CustomPainter (no chart package),
/// so they theme perfectly and animate in on first build.

class _Animated extends StatelessWidget {
  final Widget Function(double t) builder;
  final int ms;
  const _Animated({required this.builder, this.ms = 1100});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.d(context, ms),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => builder(t),
      );
}

// ---------------------------------------------------------------------------
// Bar chart
// ---------------------------------------------------------------------------

class BarChart extends StatelessWidget {
  final List<SeriesPoint> data;
  final Color color;
  final double height;
  final String Function(double)? format;
  final int? highlightIndex;
  const BarChart({super.key, required this.data, required this.color, this.height = 180, this.format, this.highlightIndex});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return Semantics(
      label: 'Bar chart: ${data.map((d) => '${d.label} ${d.value.round()}').join(', ')}',
      child: SizedBox(
        height: height,
        child: _Animated(
          builder: (t) => CustomPaint(
            size: Size.infinite,
            painter: _BarPainter(data, color, ue.textSubtle, ue.border, t, highlightIndex ?? data.length - 1, format),
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<SeriesPoint> data;
  final Color color, label, grid;
  final double t;
  final int hi;
  final String Function(double)? format;
  _BarPainter(this.data, this.color, this.label, this.grid, this.t, this.hi, this.format);

  @override
  void paint(Canvas canvas, Size s) {
    if (data.isEmpty) return;
    const bottom = 20.0, top = 18.0;
    final maxV = data.map((e) => e.value).reduce(math.max) * 1.1;
    final chartH = s.height - bottom - top;
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = top + chartH * i / 3;
      canvas.drawLine(Offset(0, y), Offset(s.width, y), gp);
    }
    final slot = s.width / data.length;
    final bw = math.min(28.0, slot * 0.56);
    for (var i = 0; i < data.length; i++) {
      final v = data[i].value / maxV * chartH * Curves.easeOutBack.transform((t * 1.15 - i * 0.03).clamp(0, 1));
      final x = slot * i + (slot - bw) / 2;
      final rect = RRect.fromRectAndCorners(Rect.fromLTWH(x, top + chartH - v, bw, v),
          topLeft: const Radius.circular(7), topRight: const Radius.circular(7));
      final isHi = i == hi;
      canvas.drawRRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isHi ? [color, color.withValues(alpha: 0.7)] : [color.withValues(alpha: 0.35), color.withValues(alpha: 0.18)],
            ).createShader(rect.outerRect));
      if (isHi && t > 0.9) {
        _text(canvas, format?.call(data[i].value) ?? data[i].value.round().toString(), Offset(x + bw / 2, top + chartH - v - 15), color, 11, true);
      }
      if (data.length <= 16 && (data.length <= 8 || i.isEven)) {
        _text(canvas, data[i].label, Offset(x + bw / 2, s.height - 14), label, 10, false);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.t != t || old.data != data;
}

void _text(Canvas c, String s, Offset center, Color color, double size, bool bold) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 80);
  tp.paint(c, center - Offset(tp.width / 2, 0));
}

// ---------------------------------------------------------------------------
// Line / area chart
// ---------------------------------------------------------------------------

class LineChart extends StatelessWidget {
  final List<SeriesPoint> data;
  final Color color;
  final double height;
  final bool percent;
  final double? minY;
  const LineChart({super.key, required this.data, required this.color, this.height = 180, this.percent = false, this.minY});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return Semantics(
      label: 'Line chart: ${data.map((d) => '${d.label} ${percent ? '${(d.value * 100).round()}%' : d.value.round()}').join(', ')}',
      child: SizedBox(
        height: height,
        child: _Animated(
          ms: 1400,
          builder: (t) => CustomPaint(size: Size.infinite, painter: _LinePainter(data, color, ue.textSubtle, ue.border, ue.surface, t, percent, minY)),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<SeriesPoint> data;
  final Color color, label, grid, surface;
  final double t;
  final bool percent;
  final double? minY;
  _LinePainter(this.data, this.color, this.label, this.grid, this.surface, this.t, this.percent, this.minY);

  @override
  void paint(Canvas canvas, Size s) {
    if (data.length < 2) return;
    const bottom = 20.0, top = 22.0, side = 8.0;
    final values = data.map((e) => e.value).toList();
    final maxV = values.reduce(math.max);
    final minV = minY ?? values.reduce(math.min) * 0.9;
    final range = (maxV - minV).abs() < 1e-9 ? 1 : (maxV - minV);
    final h = s.height - top - bottom;
    final w = s.width - side * 2;
    Offset pt(int i) => Offset(side + w * i / (data.length - 1), top + h - (values[i] - minV) / range * h);

    final gp = Paint()..color = grid;
    for (var i = 0; i <= 3; i++) {
      canvas.drawLine(Offset(0, top + h * i / 3), Offset(s.width, top + h * i / 3), gp);
    }

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < data.length; i++) {
      final p0 = pt(i - 1), p1 = pt(i);
      final mx = (p0.dx + p1.dx) / 2;
      path.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
    }
    // Reveal left → right
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, s.width * t, s.height));
    final area = Path.from(path)
      ..lineTo(pt(data.length - 1).dx, top + h)
      ..lineTo(pt(0).dx, top + h)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)])
              .createShader(Rect.fromLTWH(0, top, s.width, h)));
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
    canvas.restore();

    final last = pt(data.length - 1);
    if (t > 0.95) {
      canvas.drawCircle(last, 7, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawCircle(last, 4.5, Paint()..color = surface);
      canvas.drawCircle(last, 3, Paint()..color = color);
      final v = values.last;
      _text(canvas, percent ? '${(v * 100).toStringAsFixed(0)}%' : v.round().toString(), last - const Offset(0, 22), color, 11, true);
    }
    final step = (data.length / 7).ceil();
    for (var i = 0; i < data.length; i += step) {
      _text(canvas, data[i].label, Offset(pt(i).dx, s.height - 14), label, 10, false);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.t != t || old.data != data;
}

// ---------------------------------------------------------------------------
// Donut
// ---------------------------------------------------------------------------

class DonutSegment {
  final String label;
  final double value;
  final Color color;
  const DonutSegment(this.label, this.value, this.color);
}

class DonutChart extends StatelessWidget {
  final List<DonutSegment> segments;
  final double size;
  final Widget? center;
  const DonutChart({super.key, required this.segments, this.size = 160, this.center});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Donut chart: ${segments.map((s) => '${s.label} ${s.value.round()}').join(', ')}',
      child: SizedBox(
        width: size,
        height: size,
        child: _Animated(
          ms: 1300,
          builder: (t) => Stack(alignment: Alignment.center, children: [
            CustomPaint(size: Size.square(size), painter: _DonutPainter(segments, t, context.ue.surface)),
            if (center != null) Opacity(opacity: t, child: center),
          ]),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segs;
  final double t;
  final Color gapColor;
  _DonutPainter(this.segs, this.t, this.gapColor);

  @override
  void paint(Canvas canvas, Size s) {
    final total = segs.fold<double>(0, (a, b) => a + b.value);
    if (total <= 0) return;
    final stroke = s.width * 0.13;
    final rect = (Offset.zero & s).deflate(stroke / 2);
    var start = -math.pi / 2;
    for (final seg in segs) {
      final sweep = seg.value / total * math.pi * 2 * t;
      canvas.drawArc(
          rect,
          start,
          math.max(0, sweep - 0.04),
          false,
          Paint()
            ..color = seg.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.butt);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.t != t;
}

class ChartLegend extends StatelessWidget {
  final List<DonutSegment> items;
  final bool showValues;
  const ChartLegend({super.key, required this.items, this.showValues = true});

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (a, b) => a + b.value);
    return Column(
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: i.color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Expanded(child: Text(i.label, style: AppText.caption(context).copyWith(color: context.ue.textMuted), overflow: TextOverflow.ellipsis)),
              if (showValues)
                Text('${i.value.round()} · ${total == 0 ? 0 : (i.value / total * 100).round()}%',
                    style: AppText.caption(context).copyWith(fontWeight: FontWeight.w700, color: context.ue.text)),
            ]),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal bars (rankings)
// ---------------------------------------------------------------------------

class RankBars extends StatelessWidget {
  final List<SeriesPoint> data;
  final Color color;
  final String Function(double)? format;
  const RankBars({super.key, required this.data, required this.color, this.format});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();
    final maxV = data.map((e) => e.value).reduce(math.max);
    final ue = context.ue;
    return Column(
      children: [
        for (var i = 0; i < data.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(
                width: 118,
                child: Text(data[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(context).copyWith(color: ue.textMuted, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: data[i].value / maxV),
                  duration: Motion.d(context, 900 + i * 90),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Stack(children: [
                    Container(height: 10, decoration: BoxDecoration(color: ue.surfaceAlt, borderRadius: BorderRadius.circular(6))),
                    FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(colors: [color.withValues(alpha: i == 0 ? 1 : 0.55), color.withValues(alpha: i == 0 ? 0.75 : 0.35)]),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 46,
                child: Text(format?.call(data[i].value) ?? data[i].value.round().toString(),
                    textAlign: TextAlign.right, style: AppText.caption(context).copyWith(fontWeight: FontWeight.w800, color: ue.text)),
              ),
            ]),
          ),
      ],
    );
  }
}

/// Tiny inline trend line for KPI cards.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double width;
  final double height;
  const Sparkline({super.key, required this.values, required this.color, this.width = 80, this.height = 30});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: _Animated(
          builder: (t) => CustomPaint(painter: _SparkPainter(values, color, t)),
        ),
      );
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  final Color color;
  final double t;
  _SparkPainter(this.v, this.color, this.t);
  @override
  void paint(Canvas canvas, Size s) {
    if (v.length < 2) return;
    final maxV = v.reduce(math.max), minV = v.reduce(math.min);
    final r = (maxV - minV) == 0 ? 1 : maxV - minV;
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final p = Offset(s.width * i / (v.length - 1), s.height - (v[i] - minV) / r * s.height);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, s.width * t, s.height));
    canvas.drawPath(path, Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.t != t;
}
