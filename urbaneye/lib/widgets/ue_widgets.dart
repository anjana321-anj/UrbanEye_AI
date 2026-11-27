import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/l10n/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../core/utils/utils.dart';
import '../domain/models/enums.dart';
import '../domain/models/models.dart';
import 'scene_image.dart';

// ===========================================================================
// Press feedback
// ===========================================================================

/// Scales its child down slightly while pressed — the base micro-interaction
/// for every tappable card and button. Includes a haptic tick.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final String? semanticLabel;
  final BorderRadius? borderRadius;
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.semanticLabel,
    this.borderRadius,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onLongPress: widget.onLongPress,
        onTap: widget.onTap == null
            ? null
            : () {
                Haptics.tap();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Motion.d(context, 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

// ===========================================================================
// Buttons
// ===========================================================================

enum ButtonVariant { primary, secondary, outline, ghost, danger, success }

class UeButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final bool loading;
  final bool expand;
  final double height;
  final bool trailingIcon;

  const UeButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.height = 56,
    this.trailingIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final disabled = onPressed == null || loading;
    final (Color bg, Color fg, BorderSide? border, Gradient? grad) = switch (variant) {
      ButtonVariant.primary => (
          context.isDark ? AppColors.electric : AppColors.navy,
          Colors.white,
          null,
          LinearGradient(
            colors: context.isDark ? [AppColors.electric, AppColors.electricSoft] : [AppColors.navy, AppColors.navy500],
          )
        ),
      ButtonVariant.secondary => (ue.secondary.withValues(alpha: 0.12), ue.secondary, null, null),
      ButtonVariant.outline => (Colors.transparent, ue.text, BorderSide(color: ue.border, width: 1.4), null),
      ButtonVariant.ghost => (Colors.transparent, ue.secondary, null, null),
      ButtonVariant.danger => (ue.error, Colors.white, null, null),
      ButtonVariant.success => (ue.success, Colors.white, null, null),
    };

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
        else ...[
          if (icon != null && !trailingIcon) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 10)],
          Flexible(
            child: Text(context.t(label),
                overflow: TextOverflow.ellipsis, style: AppText.button(context).copyWith(color: fg)),
          ),
          if (icon != null && trailingIcon) ...[const SizedBox(width: 10), Icon(icon, size: 20, color: fg)],
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: context.t(label),
      excludeSemantics: true,
      child: PressableScale(
        onTap: disabled ? null : onPressed,
        child: AnimatedOpacity(
          duration: Motion.d(context, 200),
          opacity: disabled && !loading ? 0.45 : 1,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: grad == null ? bg : null,
              gradient: grad,
              borderRadius: BorderRadius.circular(AppRadii.md + 2),
              border: border == null ? null : Border.fromBorderSide(border),
              boxShadow: variant == ButtonVariant.primary && !disabled
                  ? [BoxShadow(color: AppColors.electric.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 8))]
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class UeIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;
  final Color? background;
  final int? badge;
  const UeIconButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.color, this.background, this.badge});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return Tooltip(
      message: context.t(tooltip),
      child: PressableScale(
        onTap: onPressed,
        semanticLabel: context.t(tooltip),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: background ?? ue.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: ue.border),
                ),
                child: Icon(icon, size: 21, color: color ?? ue.text),
              ),
              if (badge != null && badge! > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(color: ue.error, borderRadius: BorderRadius.circular(10), border: Border.all(color: ue.surface, width: 2)),
                    child: Text('${badge! > 9 ? '9+' : badge}',
                        textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Surfaces
// ===========================================================================

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final bool bordered;
  final String? semanticLabel;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.gradient,
    this.radius = AppRadii.lg,
    this.bordered = true,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? ue.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: bordered && gradient == null ? Border.all(color: ue.border.withValues(alpha: context.isDark ? 1 : 0.7)) : null,
        boxShadow: AppShadows.soft(context),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return PressableScale(onTap: onTap, semanticLabel: semanticLabel, child: card);
  }
}

/// Frosted glass panel used sparingly (map overlays, hero chips).
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.radius = AppRadii.lg});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: context.ue.glass,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: context.isDark ? 0.08 : 0.6)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  const SectionHeader({super.key, required this.title, this.action, this.onAction, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Semantics(header: true, child: Text(context.t(title), style: AppText.h3(context)))),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(minimumSize: const Size(48, 40)),
              child: Text(context.t(action!), style: AppText.label(context).copyWith(color: context.ue.secondary)),
            ),
        ],
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;
  const IconTile({super.key, required this.icon, required this.color, this.size = 44, this.iconSize = 22, this.radius = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

// ===========================================================================
// Status
// ===========================================================================

/// Accessible status pill: colour + icon + text (never colour alone).
class StatusBadge extends StatelessWidget {
  final ReportStatus status;
  final bool compact;
  const StatusBadge({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final b = status.bucket;
    final c = b.color;
    return Semantics(
      label: 'Status: ${context.t(status.label)}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Motion.d(context, 300),
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: context.isDark ? 0.2 : 0.12),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(b.icon, size: compact ? 12 : 14, color: c),
          const SizedBox(width: 5),
          Text(context.t(status.label),
              style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: compact ? 11 : 12, letterSpacing: 0.1)),
        ]),
      ),
    );
  }
}

class SeverityBadge extends StatelessWidget {
  final Severity severity;
  const SeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    final c = severity.color;
    return Semantics(
      label: 'Severity: ${severity.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: c.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(severity.icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(context.t(severity.label), style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 11)),
        ]),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  const Pill(this.text, {super.key, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.ue.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
        Text(context.t(text), style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 11.5)),
      ]),
    );
  }
}

// ===========================================================================
// Category card
// ===========================================================================

class CategoryCard extends StatelessWidget {
  final ReportCategory category;
  final VoidCallback onTap;
  final bool large;
  final String? labelOverride;
  final IconData? iconOverride;
  const CategoryCard({super.key, required this.category, required this.onTap, this.large = false, this.labelOverride, this.iconOverride});

  @override
  Widget build(BuildContext context) {
    final label = context.t(labelOverride ?? category.label);
    return AppCard(
      onTap: onTap,
      semanticLabel: label,
      padding: EdgeInsets.all(large ? 18 : 14),
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AnimatedIconTile(icon: iconOverride ?? category.icon, color: category.color, size: 52),
                const SizedBox(height: 14),
                Text(label, style: AppText.title(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(context.t(category.blurb), style: AppText.caption(context), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AnimatedIconTile(icon: iconOverride ?? category.icon, color: category.color, size: 48),
                const SizedBox(height: 10),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(context).copyWith(fontSize: 12, height: 1.2)),
              ],
            ),
    );
  }
}

/// Icon tile with a gentle one-shot "breathe" entrance.
class _AnimatedIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _AnimatedIconTile({required this.icon, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: Motion.d(context, 650),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: IconTile(icon: icon, color: color, size: size, iconSize: size * 0.48, radius: size * 0.32),
    );
  }
}

// ===========================================================================
// Report card
// ===========================================================================

class ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback onTap;
  final bool showThumb;
  const ReportCard({super.key, required this.report, required this.onTap, this.showThumb = true});

  @override
  Widget build(BuildContext context) {
    final r = report;
    final ue = context.ue;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      semanticLabel: '${r.category.label}, ticket ${r.ticket}, ${r.status.label}',
      child: Row(
        children: [
          if (showThumb) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(width: 76, height: 76, child: EvidenceImage(evidence: r.evidence.firstOrNull, category: r.category)),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(r.category.icon, size: 15, color: r.category.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(context.t(r.category.label),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title(context).copyWith(fontSize: 15)),
                  ),
                  if (r.escalated || r.isEmergency) Icon(Icons.priority_high_rounded, size: 16, color: ue.error, semanticLabel: 'Escalated'),
                ]),
                const SizedBox(height: 2),
                Text(r.ticket, style: AppText.caption(context).copyWith(fontWeight: FontWeight.w700, color: ue.textMuted)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.place_outlined, size: 13, color: ue.textSubtle),
                  const SizedBox(width: 3),
                  Expanded(
                      child: Text(r.location.area, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(context))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  StatusBadge(status: r.status, compact: true),
                  const Spacer(),
                  Flexible(
                    child: Text(Fmt.relative(r.createdAt),
                        overflow: TextOverflow.ellipsis, style: AppText.caption(context).copyWith(fontSize: 11)),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Timeline
// ===========================================================================

class TimelineStep {
  final String title;
  final String? subtitle;
  final IconData icon;
  const TimelineStep(this.title, {this.subtitle, this.icon = Icons.check_rounded});
}

/// Vertical progress timeline whose connector animates to the current step.
class ReportTimeline extends StatelessWidget {
  final List<TimelineStep> steps;
  final int current; // index of the active step
  final bool failed;
  const ReportTimeline({super.key, required this.steps, required this.current, this.failed = false});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _row(context, i, ue),
      ],
    );
  }

  Widget _row(BuildContext context, int i, UeColors ue) {
    final done = i < current || (i == current && i == steps.length - 1 && !failed);
    final active = i == current && !done;
    final color = failed && i == current ? ue.error : (done ? ue.success : (active ? ue.secondary : ue.border));
    final s = steps[i];
    return Semantics(
      label: '${s.title}: ${done ? 'completed' : active ? 'current step' : 'upcoming'}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 30,
              child: Column(children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Motion.d(context, 400 + i * 180),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) => Transform.scale(scale: v.clamp(0, 1.2), child: child),
                  child: active
                      ? _PulsingDot(color: color)
                      : Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: done ? color : ue.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 2),
                          ),
                          child: done ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
                        ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: i < current ? 1 : 0),
                        duration: Motion.d(context, 600 + i * 200),
                        curve: Curves.easeInOutCubic,
                        builder: (_, v, __) => CustomPaint(painter: _LinePainter(v, ue.border, ue.success)),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18, top: 2),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.t(s.title),
                      style: AppText.title(context).copyWith(
                          fontSize: 14.5, color: (done || active) ? ue.text : ue.textSubtle, fontWeight: active ? FontWeight.w800 : FontWeight.w700)),
                  if (s.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(s.subtitle!, style: AppText.caption(context)),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final double v;
  final Color track;
  final Color fill;
  _LinePainter(this.v, this.track, this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.width / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, r), Paint()..color = track);
    if (v > 0) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height * v), r), Paint()..color = fill);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.v != v || old.fill != fill;
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return SizedBox(
      width: 26,
      height: 26,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          if (!reduced)
            Container(
              width: 14 + 12 * _c.value,
              height: 14 + 12 * _c.value,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.35 * (1 - _c.value))),
            ),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color, border: Border.all(color: Colors.white, width: 2)),
          ),
        ]),
      ),
    );
  }
}

// ===========================================================================
// Counters & progress
// ===========================================================================

class AnimatedCounter extends StatelessWidget {
  final num value;
  final String suffix;
  final int decimals;
  final TextStyle? style;
  final Duration? duration;
  const AnimatedCounter({super.key, required this.value, this.suffix = '', this.decimals = 0, this.style, this.duration});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: Motion.reduced(context) ? Duration.zero : (duration ?? const Duration(milliseconds: 1400)),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(
        decimals == 0 ? '${Fmt.number(v.round())}$suffix' : '${v.toStringAsFixed(decimals)}$suffix',
        style: style ?? AppText.h2(context),
      ),
    );
  }
}

class UeProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;
  const UeProgressBar({super.key, required this.value, this.color, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return Semantics(
      value: '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Container(
          height: height,
          color: ue.surfaceAlt,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0, 1)),
              duration: Motion.d(context, 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color ?? ue.secondary, (color ?? ue.secondary).withValues(alpha: 0.7)]),
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Widget? center;
  const ProgressRing({super.key, required this.value, this.size = 64, this.stroke = 7, required this.color, this.center});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: Motion.d(context, 1200),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: Size.square(size), painter: _RingPainter(v, color, context.ue.surfaceAlt, stroke)),
          if (center != null) center!,
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color color;
  final Color track;
  final double stroke;
  _RingPainter(this.v, this.color, this.track, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(stroke / 2), 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(rect.deflate(stroke / 2), -math.pi / 2, math.pi * 2 * v, false, p..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v || old.color != color;
}

// ===========================================================================
// Skeleton loading
// ===========================================================================

class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.ue.surfaceAlt;
    final hi = context.isDark ? const Color(0xFF1E2C4D) : Colors.white;
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment(-1.5 + 3 * _c.value, 0),
            end: Alignment(-0.5 + 3 * _c.value, 0),
            colors: [base, hi, base],
          ).createShader(r),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: context.ue.surfaceAlt, borderRadius: BorderRadius.circular(radius)),
      );
}

enum SkeletonKind { home, list, map, dashboard, profile, detail }

/// Polished skeleton layouts for every major screen.
class LoadingSkeleton extends StatelessWidget {
  final SkeletonKind kind;
  const LoadingSkeleton({super.key, this.kind = SkeletonKind.list});

  @override
  Widget build(BuildContext context) {
    Widget card({double h = 96}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: h,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.ue.surface, borderRadius: BorderRadius.circular(AppRadii.lg)),
            child: Row(children: [
              const SkeletonBox(width: 72, height: 72, radius: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: const [
                  SkeletonBox(width: 140, height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 80, height: 10),
                  SizedBox(height: 12),
                  SkeletonBox(width: 90, height: 20, radius: 20),
                ]),
              ),
            ]),
          ),
        );

    final body = switch (kind) {
      SkeletonKind.list => Column(children: List.generate(5, (_) => card())),
      SkeletonKind.home => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SkeletonBox(width: 200, height: 26),
          const SizedBox(height: 10),
          const SkeletonBox(width: 240, height: 14),
          const SizedBox(height: 24),
          const SkeletonBox(height: 150, radius: 28),
          const SizedBox(height: 24),
          Row(children: List.generate(4, (_) => const Expanded(child: Padding(padding: EdgeInsets.all(4), child: SkeletonBox(height: 90, radius: 20))))),
          const SizedBox(height: 24),
          const SkeletonBox(height: 160, radius: 20),
        ]),
      SkeletonKind.map => const SkeletonBox(height: double.infinity, radius: 0),
      SkeletonKind.dashboard => Column(children: [
          Row(children: List.generate(4, (_) => const Expanded(child: Padding(padding: EdgeInsets.all(6), child: SkeletonBox(height: 110, radius: 20))))),
          const SizedBox(height: 12),
          Row(children: const [
            Expanded(flex: 2, child: Padding(padding: EdgeInsets.all(6), child: SkeletonBox(height: 280, radius: 20))),
            Expanded(child: Padding(padding: EdgeInsets.all(6), child: SkeletonBox(height: 280, radius: 20))),
          ]),
        ]),
      SkeletonKind.profile => Column(children: [
          const SkeletonBox(width: 88, height: 88, radius: 44),
          const SizedBox(height: 14),
          const SkeletonBox(width: 160, height: 18),
          const SizedBox(height: 24),
          Row(children: List.generate(3, (_) => const Expanded(child: Padding(padding: EdgeInsets.all(4), child: SkeletonBox(height: 80, radius: 18))))),
          const SizedBox(height: 20),
          ...List.generate(5, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: SkeletonBox(height: 52, radius: 14))),
        ]),
      SkeletonKind.detail => Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          SkeletonBox(height: 220, radius: 24),
          SizedBox(height: 18),
          SkeletonBox(width: 180, height: 22),
          SizedBox(height: 10),
          SkeletonBox(width: 240, height: 14),
          SizedBox(height: 24),
          SkeletonBox(height: 200, radius: 20),
        ]),
    };
    return Shimmer(child: body);
  }
}

// ===========================================================================
// Empty / error / success
// ===========================================================================

enum EmptyKind { reports, nearby, notifications, savedLocations, pickups, trucks, search, drafts }

class EmptyState extends StatelessWidget {
  final EmptyKind kind;
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.kind, this.title, this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String t, String m) = switch (kind) {
      EmptyKind.reports => (Icons.inbox_outlined, 'No reports yet', 'When you report an issue it will appear here, with live progress from the municipality.'),
      EmptyKind.nearby => (Icons.near_me_disabled_outlined, 'No nearby issues', 'Great news — nothing has been reported around you. Spotted something?'),
      EmptyKind.notifications => (Icons.notifications_none_rounded, 'You\'re all caught up', 'Updates about your reports and pickups will show up here.'),
      EmptyKind.savedLocations => (Icons.bookmark_border_rounded, 'No saved locations', 'Save Home, Work or University to report from there in one tap.'),
      EmptyKind.pickups => (Icons.local_shipping_outlined, 'No pickup requests', 'Request a waste pickup and track the truck in real time.'),
      EmptyKind.trucks => (Icons.departure_board_outlined, 'No active trucks', 'Collection trucks will appear here once they start their routes.'),
      EmptyKind.search => (Icons.search_off_rounded, 'No results', 'Try a different keyword or clear your filters.'),
      EmptyKind.drafts => (Icons.drafts_outlined, 'No drafts', 'Reports you save while offline are kept here until they are sent.'),
    };
    return EmptyIllustrationLayout(
      icon: icon,
      color: context.ue.secondary,
      title: title ?? t,
      message: message ?? m,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

enum ErrorKind { network, locationDenied, cameraDenied, uploadFailed, aiFailed, mapFailed, server, sessionExpired }

class ErrorState extends StatelessWidget {
  final ErrorKind kind;
  final String? message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;
  const ErrorState({super.key, required this.kind, this.message, this.onRetry, this.retryLabel, this.onSecondary, this.secondaryLabel});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String t, String m, String a) = switch (kind) {
      ErrorKind.network => (Icons.wifi_off_rounded, 'You\'re offline', 'Check your connection. Reports you create now are saved and sent automatically.', 'Retry'),
      ErrorKind.locationDenied => (Icons.location_off_outlined, 'Location access needed', 'Allow location to pin the issue precisely, or choose the place on the map manually.', 'Open Settings'),
      ErrorKind.cameraDenied => (Icons.no_photography_outlined, 'Camera access needed', 'Allow camera access to capture evidence, or upload a photo from your gallery instead.', 'Open Settings'),
      ErrorKind.uploadFailed => (Icons.cloud_off_rounded, 'Upload failed', 'Your report is safe on this device. We\'ll retry when the connection improves.', 'Retry Upload'),
      ErrorKind.aiFailed => (Icons.auto_awesome_outlined, 'AI analysis unavailable', 'No problem — you can choose the category and describe the issue yourself.', 'Try Again'),
      ErrorKind.mapFailed => (Icons.map_outlined, 'Map couldn\'t load', 'Check your connection. You can still search for an address.', 'Reload Map'),
      ErrorKind.server => (Icons.dns_outlined, 'Something went wrong', 'The municipality server is not responding. Please try again in a moment.', 'Try Again'),
      ErrorKind.sessionExpired => (Icons.lock_clock_outlined, 'Session expired', 'For your security, please sign in again. Your drafts are kept.', 'Sign In'),
    };
    return EmptyIllustrationLayout(
      icon: icon,
      color: context.ue.error,
      title: t,
      message: message ?? m,
      actionLabel: onRetry == null ? null : (retryLabel ?? a),
      onAction: onRetry,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
    );
  }
}

class EmptyIllustrationLayout extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  const EmptyIllustrationLayout({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Motion.d(context, 700),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.scale(scale: 0.8 + 0.2 * v, child: child)),
            child: SizedBox(
              width: 132,
              height: 132,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.0)]),
                  ),
                ),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: context.ue.surface,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.soft(context),
                    border: Border.all(color: context.ue.border),
                  ),
                  child: Icon(icon, size: 38, color: color),
                ),
                Positioned(top: 18, right: 22, child: _dot(color, 10)),
                Positioned(bottom: 24, left: 18, child: _dot(AppColors.emerald, 7)),
                Positioned(top: 40, left: 10, child: _dot(AppColors.amber, 5)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Text(context.t(title), textAlign: TextAlign.center, style: AppText.h3(context)),
          const SizedBox(height: 8),
          Text(context.t(message), textAlign: TextAlign.center, style: AppText.bodySm(context)),
          if (actionLabel != null) ...[
            const SizedBox(height: 22),
            UeButton(label: actionLabel!, onPressed: onAction, expand: false, height: 50),
          ],
          if (secondaryLabel != null) ...[
            const SizedBox(height: 8),
            UeButton(label: secondaryLabel!, onPressed: onSecondary, expand: false, height: 46, variant: ButtonVariant.ghost),
          ],
        ]),
      ),
    );
  }

  Widget _dot(Color c, double s) => Container(width: s, height: s, decoration: BoxDecoration(color: c.withValues(alpha: 0.6), shape: BoxShape.circle));
}

/// Animated success checkmark: circle draws, then check strokes in.
class SuccessCheck extends StatefulWidget {
  final double size;
  final Color? color;
  const SuccessCheck({super.key, this.size = 120, this.color});
  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Motion.reduced(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
      Haptics.success();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.ue.success;
    return Semantics(
      label: 'Success',
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(size: Size.square(widget.size), painter: _CheckPainter(_c.value, color)),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double t;
  final Color color;
  _CheckPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    // Burst ring
    final burst = Curves.easeOut.transform(((t - 0.45) / 0.55).clamp(0, 1));
    if (burst > 0 && burst < 1) {
      canvas.drawCircle(
          c,
          r * (0.9 + 0.35 * burst),
          Paint()
            ..color = color.withValues(alpha: 0.35 * (1 - burst))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    // Fill
    final fill = Curves.easeOutBack.transform((t / 0.45).clamp(0, 1));
    canvas.drawCircle(c, r * 0.82 * fill, Paint()..color = color.withValues(alpha: 0.14));
    // Ring
    final ring = Curves.easeInOut.transform((t / 0.5).clamp(0, 1));
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.62),
        -math.pi / 2,
        math.pi * 2 * ring,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.09
          ..strokeCap = StrokeCap.round);
    // Check
    final ck = Curves.easeOutCubic.transform(((t - 0.45) / 0.45).clamp(0, 1));
    if (ck > 0) {
      final p1 = c + Offset(-r * 0.26, r * 0.02);
      final p2 = c + Offset(-r * 0.07, r * 0.2);
      final p3 = c + Offset(r * 0.28, -r * 0.18);
      final path = Path()..moveTo(p1.dx, p1.dy);
      if (ck < 0.4) {
        final q = Offset.lerp(p1, p2, ck / 0.4)!;
        path.lineTo(q.dx, q.dy);
      } else {
        path.lineTo(p2.dx, p2.dy);
        final q = Offset.lerp(p2, p3, (ck - 0.4) / 0.6)!;
        path.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.1
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.t != t;
}

// ===========================================================================
// Toasts, banners, sheets
// ===========================================================================

enum ToastKind { info, success, error, warning }

void showToast(BuildContext context, String message, {ToastKind kind = ToastKind.info, String? action, VoidCallback? onAction}) {
  final ue = context.ue;
  final (IconData icon, Color c) = switch (kind) {
    ToastKind.info => (Icons.info_outline_rounded, AppColors.electricSoft),
    ToastKind.success => (Icons.check_circle_rounded, ue.success),
    ToastKind.error => (Icons.error_outline_rounded, ue.error),
    ToastKind.warning => (Icons.warning_amber_rounded, ue.warning),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: c, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(context.t(message))),
      ]),
      action: action == null ? null : SnackBarAction(label: context.t(action), onPressed: onAction ?? () {}, textColor: AppColors.electricSoft),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      duration: const Duration(seconds: 3),
    ));
}

class OfflineBanner extends StatelessWidget {
  final bool online;
  final bool syncing;
  final double progress;
  final int queued;
  const OfflineBanner({super.key, required this.online, this.syncing = false, this.progress = 0, this.queued = 0});

  @override
  Widget build(BuildContext context) {
    final visible = !online || syncing;
    final ue = context.ue;
    return AnimatedSize(
      duration: Motion.d(context, 300),
      curve: Curves.easeOutCubic,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (online ? ue.secondary : ue.warning).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(online ? Icons.cloud_upload_outlined : Icons.cloud_off_rounded, size: 18, color: online ? ue.secondary : ue.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        online
                            ? context.t('Uploading saved reports…')
                            : '${context.t('Waiting for connection')}${queued > 0 ? ' · $queued queued' : ''}',
                        style: AppText.label(context),
                      ),
                    ),
                  ]),
                  if (syncing) ...[const SizedBox(height: 8), UeProgressBar(value: progress, height: 5)],
                ]),
              ),
            ),
    );
  }
}

Future<T?> showUeSheet<T>(BuildContext context, {required Widget Function(BuildContext) builder, bool scroll = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: scroll ? SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: builder(ctx)) : builder(ctx),
    ),
  );
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String confirm = 'Confirm', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.t(title), style: AppText.h3(context)),
      content: Text(context.t(message), style: AppText.bodySm(context)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('Cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger ? context.ue.error : null),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(context.t(confirm)),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Fade + slide-up entrance for list items / sections (staggered by index).
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  final double offset;
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.offset = 18});

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + math.min(index, 8) * 70),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, offset * (1 - v)), child: c)),
      child: child,
    );
  }
}

class UeAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final Color? color;
  const UeAvatar({super.key, required this.initials, this.size = 44, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.electric;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [c, Color.lerp(c, AppColors.navy, 0.5)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

/// Segmented pill tabs with an animated indicator.
class SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final List<int?>? counts;
  const SegmentedTabs({super.key, required this.labels, required this.index, required this.onChanged, this.counts});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                selected: i == index,
                button: true,
                child: PressableScale(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: Motion.d(context, 250),
                    curve: Curves.easeOutCubic,
                    constraints: const BoxConstraints(minHeight: 42),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: i == index ? (context.isDark ? AppColors.electric : AppColors.navy) : ue.surface,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: i == index ? Colors.transparent : ue.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(context.t(labels[i]),
                          style: AppText.label(context).copyWith(color: i == index ? Colors.white : ue.textMuted)),
                      if (counts != null && counts![i] != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: i == index ? Colors.white.withValues(alpha: 0.2) : ue.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${counts![i]}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: i == index ? Colors.white : ue.textMuted)),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final String? hint;
  const LabeledField({super.key, required this.label, required this.child, this.hint});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.t(label), style: AppText.label(context)),
        if (hint != null) ...[const SizedBox(height: 2), Text(context.t(hint!), style: AppText.caption(context))],
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

class KeyValueRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  const KeyValueRow({super.key, required this.icon, required this.label, required this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        IconTile(icon: icon, color: context.ue.secondary, size: 38, iconSize: 18, radius: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.t(label), style: AppText.caption(context)),
            const SizedBox(height: 1),
            Text(value, style: AppText.label(context)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
