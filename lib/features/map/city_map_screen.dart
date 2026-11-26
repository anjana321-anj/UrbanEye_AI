import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../state/place_resolver.dart';
import '../../state/reports_controller.dart';
import '../../widgets/map_view.dart';
import '../../widgets/scene_image.dart';
import '../../widgets/ue_widgets.dart';
import '../reports/report_detail_screen.dart';

enum _StatusFilter { critical, pending, inProgress, resolved }

class CityMapScreen extends StatefulWidget {
  const CityMapScreen({super.key});
  @override
  State<CityMapScreen> createState() => _CityMapScreenState();
}

class _CityMapScreenState extends State<CityMapScreen> {
  final _map = UeMapController();
  final Set<ReportCategory> _cats = {};
  final Set<_StatusFilter> _status = {};
  bool _nearby = false;
  double _zoom = 14;
  Report? _selected;
  GeoPoint _me = PlaceResolver.mapCenter();

  @override
  void initState() {
    super.initState();
    PlaceResolver.current().then((_) {
      if (mounted) setState(() => _me = PlaceResolver.mapCenter());
    });
  }

  Color _statusColor(Report r) {
    if (r.status.isOpen && r.severity == Severity.critical) return AppColors.red;
    return r.status.bucket.color;
  }

  bool _matchStatus(Report r) {
    if (_status.isEmpty) return r.status != ReportStatus.rejected;
    return _status.any((s) => switch (s) {
          _StatusFilter.critical => r.status.isOpen && r.severity == Severity.critical,
          _StatusFilter.pending => r.status.bucket == StatusBucket.pending,
          _StatusFilter.inProgress => r.status.bucket == StatusBucket.inProgress,
          _StatusFilter.resolved => r.status.bucket == StatusBucket.resolved,
        });
  }

  List<Report> _visible(List<Report> all) => all
      .where((r) => _cats.isEmpty || _cats.contains(r.category))
      .where(_matchStatus)
      .where((r) => !_nearby || r.location.point.distanceTo(_me) < 1500)
      .toList();

  /// Grid clustering: merge markers that fall in the same cell at low zoom.
  List<MapPin> _pins(List<Report> reports) {
    final pins = <MapPin>[MapPin(id: 'me', point: _me, child: const UserDot(), semanticLabel: 'Your location')];
    if (_zoom >= 14.5) {
      for (final r in reports) {
        pins.add(_reportPin(r));
      }
      return pins;
    }
    final cell = _zoom < 12.5 ? 0.02 : 0.008;
    final groups = <String, List<Report>>{};
    for (final r in reports) {
      final k = '${(r.location.point.lat / cell).floor()}:${(r.location.point.lng / cell).floor()}';
      groups.putIfAbsent(k, () => []).add(r);
    }
    for (final g in groups.values) {
      if (g.length == 1) {
        pins.add(_reportPin(g.first));
      } else {
        final lat = g.map((r) => r.location.point.lat).reduce((a, b) => a + b) / g.length;
        final lng = g.map((r) => r.location.point.lng).reduce((a, b) => a + b) / g.length;
        final hasCritical = g.any((r) => r.status.isOpen && r.severity == Severity.critical);
        pins.add(MapPin(
          id: 'c-${g.first.id}',
          point: GeoPoint(lat, lng),
          size: 46,
          semanticLabel: '${g.length} reports',
          onTap: () => _map.move(GeoPoint(lat, lng), _zoom + 2),
          child: ClusterMarker(count: g.length, color: hasCritical ? AppColors.red : AppColors.navy500),
        ));
      }
    }
    return pins;
  }

  MapPin _reportPin(Report r) => MapPin(
        id: r.id,
        point: r.location.point,
        semanticLabel: '${r.category.label}, ${r.status.label}',
        onTap: () => setState(() => _selected = r),
        child: PulseMarker(
          color: _statusColor(r),
          icon: r.category.icon,
          pulse: r.status.isOpen && r.severity == Severity.critical,
          selected: _selected?.id == r.id,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<ReportsController>();
    final ue = context.ue;
    final visible = _visible(rc.city);
    final loading = rc.state == LoadState.loading && rc.city.isEmpty;

    return Scaffold(
      body: Stack(children: [
        if (loading)
          const LoadingSkeleton(kind: SkeletonKind.map)
        else if (rc.state == LoadState.error && rc.city.isEmpty)
          SafeArea(child: ErrorState(kind: ErrorKind.mapFailed, onRetry: rc.refresh))
        else
          UeMap(
            controller: _map,
            center: _me,
            zoom: 14,
            pins: _pins(visible),
            onTap: (_) => setState(() => _selected = null),
            onMoved: (c, z, _) {
              if ((z - _zoom).abs() > 0.4) setState(() => _zoom = z);
            },
          ),

        // Header + filters
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GlassPanel(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Semantics(header: true, child: Text(context.t('UrbanEye Map'), style: AppText.h3(context))),
                      Text('${visible.length} ${context.t('issues shown')}', style: AppText.caption(context)),
                    ]),
                  ),
                  FilterChip(
                    label: Text(context.t('Nearby Issues')),
                    avatar: Icon(Icons.near_me_rounded, size: 16, color: _nearby ? Colors.white : ue.secondary),
                    selected: _nearby,
                    showCheckmark: false,
                    selectedColor: ue.secondary,
                    labelStyle: TextStyle(color: _nearby ? Colors.white : ue.text, fontWeight: FontWeight.w700, fontSize: 12),
                    onSelected: (v) {
                      setState(() => _nearby = v);
                      if (v) _map.move(_me, 15);
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final c in const [
                    ReportCategory.waste,
                    ReportCategory.parking,
                    ReportCategory.water,
                    ReportCategory.streetlight,
                    ReportCategory.road,
                    ReportCategory.infrastructure,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(c.icon, size: 16, color: _cats.contains(c) ? Colors.white : c.color),
                        label: Text(context.t(c.shortLabel)),
                        selected: _cats.contains(c),
                        showCheckmark: false,
                        selectedColor: c.color,
                        backgroundColor: ue.surface,
                        labelStyle: TextStyle(color: _cats.contains(c) ? Colors.white : ue.text, fontWeight: FontWeight.w700, fontSize: 12),
                        onSelected: (v) => setState(() => v ? _cats.add(c) : _cats.remove(c)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final s in _StatusFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _statusChip(s),
                    ),
                ]),
              ),
            ]),
          ),
        ),

        // Recenter
        Positioned(
          right: 16,
          bottom: (_selected != null ? 250 : 110) + MediaQuery.paddingOf(context).bottom,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            tooltip: context.t('Recenter'),
            backgroundColor: ue.surface,
            onPressed: () => _map.move(_me, 15),
            child: Icon(Icons.my_location_rounded, color: ue.secondary),
          ),
        ),

        if (!loading && visible.isEmpty)
          Positioned(
            left: 24,
            right: 24,
            bottom: 120 + MediaQuery.paddingOf(context).bottom,
            child: AppCard(
              child: Row(children: [
                Icon(Icons.travel_explore_rounded, color: ue.secondary),
                const SizedBox(width: 12),
                Expanded(child: Text(context.t('No issues match these filters nearby.'), style: AppText.label(context))),
                TextButton(
                  onPressed: () => setState(() {
                    _cats.clear();
                    _status.clear();
                    _nearby = false;
                  }),
                  child: Text(context.t('Clear')),
                ),
              ]),
            ),
          ),

        // Bottom sheet for the selected marker
        AnimatedPositioned(
          duration: Motion.d(context, 320),
          curve: Curves.easeOutCubic,
          left: 16,
          right: 16,
          bottom: _selected == null ? -260 : 100 + MediaQuery.paddingOf(context).bottom,
          child: _selected == null ? const SizedBox(height: 1) : _sheet(_selected!),
        ),
      ]),
    );
  }

  Widget _statusChip(_StatusFilter s) {
    final ue = context.ue;
    final (String label, Color c, IconData icon) = switch (s) {
      _StatusFilter.critical => ('Critical', AppColors.red, Icons.warning_amber_rounded),
      _StatusFilter.pending => ('Pending', AppColors.amber, Icons.schedule_rounded),
      _StatusFilter.inProgress => ('In Progress', AppColors.electric, Icons.autorenew_rounded),
      _StatusFilter.resolved => ('Resolved', AppColors.emerald, Icons.check_circle_rounded),
    };
    final sel = _status.contains(s);
    return FilterChip(
      avatar: Icon(icon, size: 15, color: sel ? Colors.white : c),
      label: Text(context.t(label)),
      selected: sel,
      showCheckmark: false,
      selectedColor: c,
      backgroundColor: ue.surface,
      labelStyle: TextStyle(color: sel ? Colors.white : ue.text, fontWeight: FontWeight.w700, fontSize: 12),
      onSelected: (v) => setState(() => v ? _status.add(s) : _status.remove(s)),
    );
  }

  Widget _sheet(Report r) {
    final ue = context.ue;
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 200) setState(() => _selected = null);
      },
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: ue.border, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(width: 84, height: 84, child: EvidenceImage(evidence: r.evidence.firstOrNull, category: r.category)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(r.category.icon, size: 16, color: r.category.color),
                  const SizedBox(width: 6),
                  Expanded(child: Text(context.t(r.category.label), style: AppText.title(context).copyWith(fontSize: 15), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 4),
                Text('${r.ticket} · ${Fmt.relative(r.createdAt)}', style: AppText.caption(context)),
                const SizedBox(height: 4),
                Text('${Fmt.distance(r.location.point.distanceTo(_me))} ${context.t('away')} · ${r.location.area}', style: AppText.caption(context)),
                const SizedBox(height: 8),
                StatusBadge(status: r.status, compact: true),
              ]),
            ),
            IconButton(tooltip: context.t('Close'), icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _selected = null)),
          ]),
          const SizedBox(height: 12),
          UeButton(label: 'View details', height: 46, icon: Icons.arrow_forward_rounded, trailingIcon: true, onPressed: () => context.push(ReportDetailScreen(reportId: r.id))),
        ]),
      ),
    );
  }
}
