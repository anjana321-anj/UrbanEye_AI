import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../widgets/charts.dart';
import '../../widgets/ue_widgets.dart';

/// Public, anonymised transparency dashboard. Contains aggregate numbers
/// only — never citizen identities, exact addresses or photos.
class PublicDashboardScreen extends StatefulWidget {
  const PublicDashboardScreen({super.key});
  @override
  State<PublicDashboardScreen> createState() => _PublicDashboardScreenState();
}

class _PublicDashboardScreenState extends State<PublicDashboardScreen> {
  CityStats? _stats;
  AnalyticsSnapshot? _snap;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final r = await Future.wait([Services.I.analytics.cityStats(), Services.I.analytics.snapshot()]);
      if (mounted) {
        setState(() {
          _stats = r[0] as CityStats;
          _snap = r[1] as AnalyticsSnapshot;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('City Transparency'))),
      body: _error
          ? ErrorState(kind: ErrorKind.server, onRetry: _load)
          : _stats == null || _snap == null
              ? const Padding(padding: EdgeInsets.all(20), child: LoadingSkeleton(kind: SkeletonKind.dashboard))
              : RefreshIndicator(onRefresh: _load, child: _body(_stats!, _snap!)),
    );
  }

  Widget _body(CityStats s, AnalyticsSnapshot a) {
    final ue = context.ue;
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 820;
      final kpis = [
        _Kpi(Icons.inbox_rounded, s.reported.toDouble(), '', 'Reports received', AppColors.electric),
        _Kpi(Icons.task_alt_rounded, s.resolved.toDouble(), '', 'Reports resolved', AppColors.emerald),
        _Kpi(Icons.timer_outlined, s.avgResolutionHours, ' h', 'Average resolution time', AppColors.amber, decimals: 1),
        _Kpi(Icons.percent_rounded, s.resolutionRate * 100, '%', 'Resolution rate', AppColors.violet),
      ];
      final segments = [
        for (final e in a.byCategory.entries.where((e) => e.value > 0)) DonutSegment(e.key.shortLabel, e.value.toDouble(), e.key.color),
      ];
      return ListView(padding: EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        Text(context.t('Kathmandu Metropolitan City'), style: AppText.h2(context)),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: ue.textSubtle),
          const SizedBox(width: 4),
          Expanded(child: Text(context.t('Aggregated & anonymised · updated live'), style: AppText.caption(context))),
        ]),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: wide ? 4 : 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: wide ? 1.7 : 1.25,
          children: [for (var i = 0; i < kpis.length; i++) FadeSlideIn(index: i, child: kpis[i])],
        ),
        const SizedBox(height: 14),
        Flex(
          direction: wide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
          children: [
            _wrap(wide, AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.t('Issues by category'), style: AppText.title(context)),
                const SizedBox(height: 14),
                Row(children: [
                  DonutChart(
                    segments: segments,
                    size: 140,
                    center: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${segments.fold<double>(0, (p, e) => p + e.value).round()}', style: AppText.h3(context)),
                      Text(context.t('total'), style: AppText.caption(context)),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: ChartLegend(items: segments)),
                ]),
              ]),
            )),
            SizedBox(width: wide ? 14 : 0, height: wide ? 0 : 14),
            _wrap(wide, AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.t('City improvement trend'), style: AppText.title(context)),
                Text(context.t('Monthly resolution rate'), style: AppText.caption(context)),
                const SizedBox(height: 10),
                LineChart(data: a.monthlyResolutionRate, color: AppColors.emerald, percent: true, height: 170),
              ]),
            )),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.t('Reports received · last 14 days'), style: AppText.title(context)),
            const SizedBox(height: 10),
            BarChart(data: a.daily, color: AppColors.electric, height: 170),
          ]),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.t('Average hours to resolve, by category'), style: AppText.title(context)),
            const SizedBox(height: 12),
            RankBars(data: a.resolutionHoursByCategory, color: AppColors.amber, format: (v) => '${v.toStringAsFixed(0)}h'),
          ]),
        ),
      ]);
    });
  }

  Widget _wrap(bool wide, Widget child) => wide ? Expanded(child: child) : child;
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final double value;
  final String suffix;
  final String label;
  final Color color;
  final int decimals;
  const _Kpi(this.icon, this.value, this.suffix, this.label, this.color, {this.decimals = 0});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconTile(icon: icon, color: color, size: 36, iconSize: 18, radius: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(child: AnimatedCounter(value: value, suffix: suffix, decimals: decimals, style: AppText.h2(context))),
            Text(context.t(label), maxLines: 2, style: AppText.caption(context)),
          ]),
        ]),
      );
}
