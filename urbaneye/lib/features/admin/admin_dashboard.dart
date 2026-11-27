import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../data/mock/mock_db.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../state/admin_controller.dart';
import '../../widgets/charts.dart';
import '../../widgets/map_view.dart';
import '../../widgets/ue_widgets.dart';
import 'admin_shell.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AdminController>();
    final nav = context.read<AdminNav>();
    final ue = context.ue;
    if (ac.error != null && ac.reports.isEmpty) return ErrorState(kind: ErrorKind.server, message: ac.error, onRetry: ac.refresh);
    if (ac.stats == null || ac.snapshot == null) {
      return const Padding(padding: EdgeInsets.all(28), child: SingleChildScrollView(child: LoadingSkeleton(kind: SkeletonKind.dashboard)));
    }
    final s = ac.stats!;
    final a = ac.snapshot!;
    final open = ac.reports.where((r) => r.status.isOpen).toList();
    final critical = open.where((r) => r.severity == Severity.critical || r.escalated).toList()
      ..sort((x, y) => ac.remaining(x).compareTo(ac.remaining(y)));
    final wide = MediaQuery.sizeOf(context).width > 1100;

    final segments = [
      for (final e in a.byCategory.entries.where((e) => e.value > 0)) DonutSegment(e.key.shortLabel, e.value.toDouble(), e.key.color),
    ];

    Widget row(List<Widget> items, List<int> flex) => wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(flex: flex[i], child: items[i]),
            ],
          ])
        : Column(children: [
            for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 14), items[i]],
          ]);

    return AdminPage(
      title: 'Dashboard',
      subtitle: '${MockDb.municipality.name} · ${Fmt.dateTime(DateTime.now())}',
      onRefresh: ac.refresh,
      actions: [
        UeButton(label: 'Refresh', icon: Icons.refresh_rounded, variant: ButtonVariant.outline, expand: false, height: 44, onPressed: ac.refresh),
        UeButton(label: 'View reports', icon: Icons.inbox_rounded, expand: false, height: 44, onPressed: () => nav.go('reports')),
      ],
      children: [
        ResponsiveGrid(minItemWidth: 200, children: [
          KpiCard(label: 'Total Reports', value: s.reported, icon: Icons.inbox_rounded, color: AppColors.electric, delta: '+12%', onTap: () => nav.go('reports')),
          KpiCard(label: 'Pending', value: s.pending, icon: Icons.schedule_rounded, color: AppColors.amber, delta: '-4%', onTap: () => nav.go('reports')),
          KpiCard(label: 'In Progress', value: s.inProgress, icon: Icons.autorenew_rounded, color: AppColors.electricSoft, onTap: () => nav.go('reports')),
          KpiCard(label: 'Resolved', value: s.resolved, icon: Icons.check_circle_outline_rounded, color: AppColors.emerald, delta: '+8%'),
          KpiCard(label: 'Critical Issues', value: s.critical, icon: Icons.warning_amber_rounded, color: AppColors.red, delta: s.critical > 3 ? 'Attention' : null, deltaGood: false, onTap: () => nav.go('sla')),
        ]),
        const SizedBox(height: 14),
        row([
          PanelCard(
            title: 'Live city map',
            subtitle: '${open.length} open issues · tap a marker to open',
            child: SizedBox(height: 360, child: ClipRRect(borderRadius: BorderRadius.circular(AppRadii.md), child: AdminCityMap(reports: open))),
          ),
          PanelCard(
            title: 'Needs attention',
            subtitle: 'Critical & escalated, sorted by SLA',
            child: SizedBox(
              height: 360,
              child: critical.isEmpty
                  ? const EmptyState(kind: EmptyKind.nearby, title: 'All clear', message: 'No critical or escalated issues right now.')
                  : ListView.separated(
                      itemCount: critical.length,
                      separatorBuilder: (_, __) => Divider(color: ue.border, height: 1),
                      itemBuilder: (_, i) {
                        final r = critical[i];
                        final rem = ac.remaining(r);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          onTap: () => nav.openReport(r.id),
                          leading: IconTile(icon: r.category.icon, color: r.category.color, size: 38, iconSize: 18),
                          title: Text('${r.ticket} · ${context.t(r.title)}', style: AppText.label(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(r.location.area, style: AppText.caption(context)),
                          trailing: SlaChip(remaining: rem),
                        );
                      },
                    ),
            ),
          ),
        ], [3, 2]),
        const SizedBox(height: 14),
        row([
          PanelCard(
            title: 'Daily Reports',
            subtitle: 'Last 14 days',
            child: BarChart(data: a.daily, color: AppColors.electric, height: 210),
          ),
          PanelCard(
            title: 'Reports by Category',
            child: Row(children: [
              DonutChart(segments: segments, size: 150, center: Text('${segments.fold<double>(0, (p, e) => p + e.value).round()}', style: AppText.h3(context))),
              const SizedBox(width: 14),
              Expanded(child: ChartLegend(items: segments)),
            ]),
          ),
        ], [3, 2]),
        const SizedBox(height: 14),
        row([
          PanelCard(title: 'Reports by Location', subtitle: 'Top areas', child: RankBars(data: a.byArea, color: AppColors.violet)),
          PanelCard(
            title: 'Resolution Time',
            subtitle: 'Average hours by category',
            child: BarChart(data: a.resolutionHoursByCategory, color: AppColors.amber, height: 200, format: (v) => '${v.round()}h', highlightIndex: 4),
          ),
          PanelCard(
            title: 'Monthly Resolution Rate',
            child: LineChart(data: a.monthlyResolutionRate, color: AppColors.emerald, height: 200, percent: true),
          ),
        ], [1, 1, 1]),
        const SizedBox(height: 14),
        AiInsightsCard(insights: a.insights),
      ],
    );
  }
}

class SlaChip extends StatelessWidget {
  final Duration remaining;
  const SlaChip({super.key, required this.remaining});
  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final overdue = remaining.isNegative;
    final risk = !overdue && remaining.inHours < 6;
    final c = overdue ? ue.error : (risk ? ue.warning : ue.success);
    return Pill(
      overdue ? 'Overdue ${Fmt.duration(-remaining)}' : '${Fmt.duration(remaining)} left',
      icon: overdue ? Icons.alarm_off_rounded : Icons.timer_outlined,
      color: c,
    );
  }
}

class AiInsightsCard extends StatelessWidget {
  final List<String> insights;
  const AiInsightsCard({super.key, required this.insights});
  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return AppCard(
      gradient: LinearGradient(colors: [ue.secondary.withValues(alpha: 0.12), AppColors.emerald.withValues(alpha: 0.08)]),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome, color: ue.secondary),
          const SizedBox(width: 8),
          Expanded(child: Text(context.t('AI insights'), style: AppText.title(context))),
          Pill('Advisory — human review required', icon: Icons.verified_user_outlined, color: ue.secondary),
        ]),
        const SizedBox(height: 12),
        for (final i in insights)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.arrow_right_rounded, color: ue.secondary),
              const SizedBox(width: 4),
              Expanded(child: Text(i, style: AppText.bodySm(context).copyWith(color: ue.text))),
            ]),
          ),
      ]),
    );
  }
}

/// Operations map showing reports (and optionally trucks / teams).
class AdminCityMap extends StatelessWidget {
  final List<Report> reports;
  final List<Vehicle> vehicles;
  final List<WastePickup> pickups;
  final List<Team> teams;
  const AdminCityMap({super.key, this.reports = const [], this.vehicles = const [], this.pickups = const [], this.teams = const []});

  @override
  Widget build(BuildContext context) {
    final nav = context.read<AdminNav>();
    return UeMap(
      center: MockDb.municipality.center,
      zoom: 13,
      lines: [for (final v in vehicles) if (v.route.length > 1) MapLine(points: v.route, color: AppColors.electric.withValues(alpha: 0.7), width: 4)],
      pins: [
        for (final r in reports)
          MapPin(
            id: r.id,
            point: r.location.point,
            size: 40,
            semanticLabel: '${r.ticket} ${r.status.label}',
            onTap: () => nav.openReport(r.id),
            child: PulseMarker(
              color: r.severity == Severity.critical ? AppColors.red : r.status.bucket.color,
              icon: r.category.icon,
              pulse: r.severity == Severity.critical || r.escalated,
            ),
          ),
        for (final p in pickups)
          MapPin(
            id: p.id,
            point: p.location.point,
            size: 36,
            semanticLabel: 'Pickup ${p.ticket}',
            child: PulseMarker(color: p.wasteType.color, icon: Icons.delete_outline_rounded),
          ),
        for (final t in teams)
          MapPin(id: t.id, point: t.location, size: 40, semanticLabel: t.name, child: PulseMarker(color: AppColors.navy500, icon: Icons.groups_2_rounded)),
        for (final v in vehicles)
          MapPin(
            id: v.id,
            point: v.position,
            size: 46,
            semanticLabel: 'Truck ${v.id}',
            child: Tooltip(
              message: '${v.id} · ${v.status}',
              child: Container(
                decoration: BoxDecoration(color: AppColors.navy, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
      ],
    );
  }
}
