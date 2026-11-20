import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../domain/models/enums.dart';
import '../../state/settings_controller.dart';
import '../../widgets/brand.dart';
import '../../widgets/scene_image.dart';
import '../../widgets/ue_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  double _page = 0;

  static const _pages = [
    ('Make Your City Better.', 'Report problems around you and help your municipality build a cleaner, safer and smarter city.'),
    ('Report With One Tap.', 'Capture a photo, share your location and send a report directly to the municipality.'),
    ('Track Every Report.', 'Stay updated from the moment you report a problem until it is resolved.'),
  ];

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => setState(() => _page = _pc.page ?? 0));
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _finish() => context.read<SettingsController>().completeOnboarding();

  @override
  Widget build(BuildContext context) {
    final i = _page.round();
    final last = i == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(children: [
              const BrandMark(size: 34),
              const SizedBox(width: 10),
              const Wordmark(size: 20),
              const Spacer(),
              AnimatedOpacity(
                opacity: last ? 0 : 1,
                duration: Motion.d(context, 200),
                child: TextButton(
                  onPressed: last ? null : _finish,
                  style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                  child: Text(context.t('Skip'), style: AppText.label(context).copyWith(color: context.ue.textMuted)),
                ),
              ),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _pages.length,
              itemBuilder: (_, idx) {
                final delta = (_page - idx);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(children: [
                    const Spacer(),
                    Transform.translate(
                      offset: Offset(delta * -60, 0),
                      child: Opacity(
                        opacity: (1 - delta.abs()).clamp(0.0, 1.0),
                        child: SizedBox(height: 300, child: _Illustration(index: idx)),
                      ),
                    ),
                    const Spacer(),
                    Transform.translate(
                      offset: Offset(delta * -30, 0),
                      child: Column(children: [
                        Semantics(
                          header: true,
                          child: Text(context.t(_pages[idx].$1), textAlign: TextAlign.center, style: AppText.h1(context)),
                        ),
                        const SizedBox(height: 14),
                        Text(context.t(_pages[idx].$2), textAlign: TextAlign.center, style: AppText.body(context).copyWith(color: context.ue.textMuted)),
                      ]),
                    ),
                    const SizedBox(height: 24),
                  ]),
                );
              },
            ),
          ),
          // Progress indicator
          Semantics(
            label: 'Page ${i + 1} of ${_pages.length}',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (d) {
                final active = (d - _page).abs() < 0.5;
                return AnimatedContainer(
                  duration: Motion.d(context, 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? context.ue.secondary : context.ue.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: UeButton(
              label: last ? 'Get Started' : 'Next',
              icon: Icons.arrow_forward_rounded,
              trailingIcon: true,
              onPressed: () {
                if (last) {
                  _finish();
                } else {
                  _pc.nextPage(duration: Motion.d(context, 450), curve: Curves.easeOutCubic);
                }
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _Illustration extends StatefulWidget {
  final int index;
  const _Illustration({required this.index});
  @override
  State<_Illustration> createState() => _IllustrationState();
}

class _IllustrationState extends State<_Illustration> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = reduced ? 0.0 : _c.value;
        final float = math.sin(t * math.pi * 2) * 6;
        return switch (widget.index) {
          0 => _cityPhone(float),
          1 => _flow(t),
          _ => _timeline(float),
        };
      },
    );
  }

  Widget _frame(Widget child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: AppShadows.soft(context),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(32), child: child),
      );

  Widget _cityPhone(double float) {
    return Stack(alignment: Alignment.center, children: [
      Positioned.fill(child: _frame(const SceneImage(category: ReportCategory.road, seed: 11))),
      Positioned(
        right: 22,
        bottom: 14 + float,
        child: Container(
          width: 120,
          height: 210,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: Colors.white,
              child: Column(children: [
                const SizedBox(height: 8),
                const BrandMark(size: 26),
                const SizedBox(height: 6),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  height: 70,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                  clipBehavior: Clip.antiAlias,
                  child: const SceneImage(category: ReportCategory.road, seed: 3),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('Report', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(height: 6),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle, size: 12, color: AppColors.emerald),
                  SizedBox(width: 4),
                  Text('Sent', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.emerald)),
                ]),
              ]),
            ),
          ),
        ),
      ),
      Positioned(
        left: 18,
        top: 18 - float,
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.auto_awesome, size: 16, color: AppColors.electric),
            const SizedBox(width: 6),
            Text('Pothole · 94%', style: AppText.label(context)),
          ]),
        ),
      ),
    ]);
  }

  Widget _flow(double t) {
    final ue = context.ue;
    Widget node(IconData icon, Color c, String label, double phase) {
      final active = ((t * 3) % 3 - phase).abs() < 0.6;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedScale(
          scale: active ? 1.12 : 1,
          duration: const Duration(milliseconds: 300),
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: ue.surface,
              shape: BoxShape.circle,
              border: Border.all(color: active ? c : ue.border, width: 2),
              boxShadow: active ? AppShadows.glow(c) : AppShadows.soft(context),
            ),
            child: Icon(icon, color: c, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(context.t(label), style: AppText.label(context)),
      ]);
    }

    return Stack(alignment: Alignment.center, children: [
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              colors: [ue.secondary.withValues(alpha: 0.08), AppColors.emerald.withValues(alpha: 0.08)],
            ),
          ),
        ),
      ),
      Positioned(
        left: 50,
        right: 50,
        top: 120,
        child: CustomPaint(size: const Size(double.infinity, 4), painter: _DashPainter(t, ue.secondary)),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        node(Icons.photo_camera_rounded, AppColors.electric, 'Photo', 0),
        node(Icons.place_rounded, AppColors.amber, 'Location', 1),
        node(Icons.send_rounded, AppColors.emerald, 'Send', 2),
      ]),
    ]);
  }

  Widget _timeline(double float) {
    return Center(
      child: Transform.translate(
        offset: Offset(0, float),
        child: AppCard(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: 280,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const IconTile(icon: Icons.local_parking_rounded, color: AppColors.violet, size: 38, iconSize: 18),
                const SizedBox(width: 10),
                Expanded(child: Text('UE-10284', style: AppText.title(context))),
                const StatusBadge(status: ReportStatus.onTheWay, compact: true),
              ]),
              const SizedBox(height: 16),
              const ReportTimeline(current: 3, steps: [
                TimelineStep('Reported', subtitle: '10:32 AM'),
                TimelineStep('Verified', subtitle: '10:41 AM'),
                TimelineStep('Assigned', subtitle: '10:50 AM'),
                TimelineStep('Team On The Way'),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final double t;
  final Color color;
  _DashPainter(this.t, this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dash = 8.0, gap = 8.0;
    final shift = (t * 64) % (dash + gap);
    for (var x = -dash + shift; x < s.width; x += dash + gap) {
      canvas.drawLine(Offset(math.max(0.0, x), 2), Offset(math.min(s.width, x + dash), 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.t != t;
}
