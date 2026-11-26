import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/di/service_locator.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../state/auth_controller.dart';
import '../../state/notifications_controller.dart';
import '../../state/place_resolver.dart';
import '../../state/reports_controller.dart';
import '../../widgets/charts.dart';
import '../../widgets/ue_widgets.dart';
import '../citizen/citizen_shell.dart';
import '../notifications/notifications_screen.dart';
import '../report/category_hub_screen.dart';
import '../report/report_flow_screen.dart';
import '../reports/drafts_screen.dart';
import '../reports/report_detail_screen.dart';
import '../transparency/public_dashboard_screen.dart';
import '../waste/waste_screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CityStats? _stats;
  PlaceLocation? _place;
  bool _statsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    PlaceResolver.current().then((p) {
      if (mounted) setState(() => _place = p);
    });
    try {
      final s = await Services.I.analytics.cityStats();
      if (mounted) {
        setState(() {
          _stats = s;
          _statsError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsError = true);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([context.read<ReportsController>().refresh(silent: true), _load()]);
  }

  String _greeting(String name) {
    final h = DateTime.now().hour;
    if (h < 12) return context.t('Good Morning, {name}', {'name': name});
    if (h < 17) return context.t('Good Afternoon, {name}', {'name': name});
    return context.t('Good Evening, {name}', {'name': name});
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final rc = context.watch<ReportsController>();
    final notifs = context.watch<NotificationsController>();
    final waste = context.watch<WasteController>();
    final ue = context.ue;
    final firstLoad = rc.state == LoadState.loading && rc.mine.isEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: ue.secondary,
          child: firstLoad
              ? ListView(padding: const EdgeInsets.all(20), children: const [LoadingSkeleton(kind: SkeletonKind.home)])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                  children: [
                    // ---------------- Header ----------------
                    FadeSlideIn(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Semantics(
                              header: true,
                              child: Text('${_greeting(user?.firstName ?? 'there')} 👋', style: AppText.h2(context).copyWith(fontSize: 24)),
                            ),
                            const SizedBox(height: 4),
                            Text(context.t('Help make your city better today.'), style: AppText.bodySm(context)),
                          ]),
                        ),
                        UeIconButton(
                          icon: Icons.notifications_none_rounded,
                          tooltip: 'Notifications',
                          badge: notifs.unread,
                          onPressed: () => context.push(const NotificationsScreen()),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    FadeSlideIn(index: 1, child: _LocationChip(place: _place, onTap: () async {
                      final p = await PlaceResolver.current(refresh: true);
                      if (mounted) setState(() => _place = p);
                    })),
                    const SizedBox(height: 18),

                    // ---------------- Hero CTA ----------------
                    FadeSlideIn(index: 2, child: _ReportHero(onTap: () => context.push(const ReportFlowScreen()))),
                    const SizedBox(height: 14),

                    if (rc.drafts.isNotEmpty || rc.outbox.isNotEmpty)
                      FadeSlideIn(
                        index: 3,
                        child: AppCard(
                          onTap: () => context.push(const DraftsScreen()),
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            IconTile(icon: Icons.drafts_outlined, color: ue.warning),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${rc.drafts.length} ${context.t('draft(s)')} · ${rc.outbox.length} ${context.t('waiting to upload')}',
                                style: AppText.label(context),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: ue.textSubtle),
                          ]),
                        ),
                      ),

                    if (waste.active != null) ...[
                      const SizedBox(height: 4),
                      FadeSlideIn(index: 3, child: _ActivePickupCard(pickup: waste.active!)),
                    ],
                    const SizedBox(height: 24),

                    // ---------------- Quick actions ----------------
                    const SectionHeader(title: 'Quick Actions'),
                    const SizedBox(height: 12),
                    FadeSlideIn(index: 4, child: _QuickActions()),
                    const SizedBox(height: 28),

                    // ---------------- City status ----------------
                    SectionHeader(
                      title: 'Your City Today',
                      action: 'Transparency',
                      onAction: () => context.push(const PublicDashboardScreen()),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      index: 5,
                      child: _statsError
                          ? AppCard(child: ErrorState(kind: ErrorKind.server, onRetry: _load))
                          : _stats == null
                              ? const Shimmer(child: SkeletonBox(height: 230, radius: 20))
                              : _CityStatus(stats: _stats!),
                    ),
                    const SizedBox(height: 28),

                    // ---------------- Recent ----------------
                    SectionHeader(title: 'Recent Activity', action: 'See all', onAction: () => context.read<ShellNav>().go(3)),
                    const SizedBox(height: 12),
                    if (rc.state == LoadState.error && rc.mine.isEmpty)
                      ErrorState(kind: ErrorKind.network, onRetry: rc.refresh)
                    else if (rc.mine.isEmpty)
                      EmptyState(kind: EmptyKind.reports, actionLabel: 'Report a City Issue', onAction: () => context.push(const ReportFlowScreen()))
                    else
                      for (var i = 0; i < math.min(3, rc.mine.length); i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FadeSlideIn(
                            index: 6 + i,
                            child: ReportCard(
                              report: rc.mine[i],
                              onTap: () => context.push(ReportDetailScreen(reportId: rc.mine[i].id)),
                            ),
                          ),
                        ),
                    const SizedBox(height: 12),
                    _EmergencyNote(),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  final PlaceLocation? place;
  final VoidCallback onTap;
  const _LocationChip({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final denied = PlaceResolver.lastError != null;
    return Align(
      alignment: Alignment.centerLeft,
      child: PressableScale(
        onTap: onTap,
        semanticLabel: 'Current location: ${place?.address ?? 'locating'}',
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          decoration: BoxDecoration(color: ue.surface, borderRadius: BorderRadius.circular(AppRadii.pill), border: Border.all(color: ue.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: (denied ? ue.warning : ue.secondary).withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Icon(denied ? Icons.location_disabled_rounded : Icons.near_me_rounded, size: 14, color: denied ? ue.warning : ue.secondary),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(context.t(denied ? 'Approximate location' : 'Current Location'), style: AppText.caption(context).copyWith(fontSize: 10.5)),
                Text(place?.address ?? context.t('Locating…'),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label(context).copyWith(fontSize: 12.5)),
              ]),
            ),
            const SizedBox(width: 6),
            Icon(Icons.expand_more_rounded, size: 18, color: ue.textSubtle),
          ]),
        ),
      ),
    );
  }
}

/// Dominant CTA with an animated scanning camera icon.
class _ReportHero extends StatefulWidget {
  final VoidCallback onTap;
  const _ReportHero({required this.onTap});
  @override
  State<_ReportHero> createState() => _ReportHeroState();
}

class _ReportHeroState extends State<_ReportHero> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return PressableScale(
      onTap: widget.onTap,
      semanticLabel: context.t('Report a City Issue'),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, AppColors.navy500, Color(0xFF2456D6)],
          ),
          boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 14))],
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.emerald.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF6EE7B7)),
                    const SizedBox(width: 4),
                    Text(context.t('AI-assisted'), style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(context.t('Report a City Issue'),
                    style: AppText.h2(context).copyWith(color: Colors.white, fontSize: 24, height: 1.15)),
                const SizedBox(height: 6),
                Text(context.t('Photo, location and details in under a minute'),
                    style: AppText.bodySm(context).copyWith(color: Colors.white.withValues(alpha: 0.75))),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.pill)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(context.t('Start report'), style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 13.5)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.navy),
                  ]),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final t = reduced ? 0.0 : _c.value;
                return SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(alignment: Alignment.center, children: [
                    for (final k in [0.0, 0.5])
                      Opacity(
                        opacity: (1 - ((t + k) % 1)) * 0.5,
                        child: Container(
                          width: 56 + 40 * ((t + k) % 1),
                          height: 56 + 40 * ((t + k) % 1),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5)),
                        ),
                      ),
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: ClipOval(
                        child: Stack(alignment: Alignment.center, children: [
                          const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 28),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 62 * (0.5 + 0.5 * math.sin(t * math.pi * 2)) - 1,
                            child: Container(height: 2, color: const Color(0xFF6EE7B7).withValues(alpha: 0.9)),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ]),
        ]),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = <(ReportCategory, String, VoidCallback)>[
      (ReportCategory.waste, 'Waste Management', () => context.push(const WasteHubScreen())),
      (ReportCategory.parking, 'Illegal Parking', () => context.push(const CategoryHubScreen(category: ReportCategory.parking))),
      (ReportCategory.water, 'Water Leakage', () => context.push(const CategoryHubScreen(category: ReportCategory.water))),
      (ReportCategory.streetlight, 'Streetlight', () => context.push(const CategoryHubScreen(category: ReportCategory.streetlight))),
      (ReportCategory.road, 'Road Condition', () => context.push(const CategoryHubScreen(category: ReportCategory.road))),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 560 ? 5 : 3;
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final it in items)
            SizedBox(
              width: w,
              height: 104,
              child: CategoryCard(category: it.$1, labelOverride: it.$2, onTap: it.$3),
            ),
          SizedBox(
            width: w,
            height: 104,
            child: CategoryCard(
              category: ReportCategory.other,
              labelOverride: 'Water Points',
              iconOverride: Icons.water_rounded,
              onTap: () => context.push(const ServicePointsScreen(kind: PointKind.water)),
            ),
          ),
        ],
      );
    });
  }
}

class _CityStatus extends StatelessWidget {
  final CityStats stats;
  const _CityStatus({required this.stats});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedCounter(value: stats.resolved, style: AppText.h1(context).copyWith(fontSize: 34)),
              Text(context.t('Reports Resolved'), style: AppText.bodySm(context)),
              const SizedBox(height: 10),
              Sparkline(values: const [12, 18, 15, 22, 19, 27, 31, 29, 36], color: ue.success, width: 120, height: 32),
            ]),
          ),
          ProgressRing(
            value: stats.resolutionRate,
            size: 96,
            stroke: 9,
            color: ue.success,
            center: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedCounter(value: (stats.resolutionRate * 100).round(), suffix: '%', style: AppText.h3(context)),
              Text(context.t('Resolution Rate'), textAlign: TextAlign.center, style: AppText.caption(context).copyWith(fontSize: 8.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Divider(color: ue.border),
        const SizedBox(height: 12),
        Row(children: [
          _mini(context, Icons.campaign_outlined, stats.reported, 'Issues Reported', AppColors.electric),
          _mini(context, Icons.local_shipping_outlined, stats.wastePickups, 'Waste Pickups', AppColors.emerald),
          _mini(context, Icons.construction_rounded, stats.activeMaintenance, 'Active Maintenance', AppColors.amber),
        ]),
      ]),
    );
  }

  Widget _mini(BuildContext context, IconData icon, int v, String label, Color c) => Expanded(
        child: Column(children: [
          IconTile(icon: icon, color: c, size: 36, iconSize: 18, radius: 12),
          const SizedBox(height: 8),
          AnimatedCounter(value: v, style: AppText.title(context)),
          Text(context.t(label), textAlign: TextAlign.center, maxLines: 2, style: AppText.caption(context).copyWith(fontSize: 11)),
        ]),
      );
}

class _ActivePickupCard extends StatelessWidget {
  final WastePickup pickup;
  const _ActivePickupCard({required this.pickup});
  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final eta = pickup.eta;
    return AppCard(
      onTap: () => context.push(PickupTrackingScreen(pickupId: pickup.id)),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        const IconTile(icon: Icons.local_shipping_rounded, color: AppColors.emerald),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${context.t('Waste Pickup')} #${pickup.ticket}', style: AppText.label(context)),
            const SizedBox(height: 2),
            Text(
              eta != null && pickup.status.index >= PickupStatus.assigned.index
                  ? '${context.t(pickup.status.label)} · ${context.t('ETA')} ${Fmt.time(eta)}'
                  : context.t(pickup.status.label),
              style: AppText.caption(context),
            ),
          ]),
        ),
        Pill('Track', icon: Icons.near_me_rounded, color: ue.secondary),
      ]),
    );
  }
}

class _EmergencyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ue.error.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(AppRadii.md)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.emergency_outlined, color: ue.error, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            context.t('UrbanEye is not an emergency service. In an emergency call 100 (Police), 101 (Fire) or 102 (Ambulance).'),
            style: AppText.caption(context).copyWith(color: ue.textMuted),
          ),
        ),
      ]),
    );
  }
}
