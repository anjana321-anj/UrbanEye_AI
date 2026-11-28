import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/services/media_service.dart';
import '../../domain/models/enums.dart';
import '../../state/place_resolver.dart';
import '../../state/reports_controller.dart';
import '../../widgets/scene_image.dart';
import '../../widgets/ue_widgets.dart';
import '../reports/report_detail_screen.dart';
import 'report_flow_screen.dart';

// ===========================================================================
// Category hub (Parking, Water, Streetlight & Infrastructure, Road...)
// ===========================================================================

class CategoryHubScreen extends StatelessWidget {
  final ReportCategory category;
  const CategoryHubScreen({super.key, required this.category});

  String get _title => switch (category) {
        ReportCategory.streetlight => 'Streetlight & Infrastructure',
        _ => category.label,
      };

  String get _cta => switch (category) {
        ReportCategory.water => 'Report Water Leakage',
        ReportCategory.road => 'Report Road Issue',
        ReportCategory.parking => 'Report Illegal Parking',
        ReportCategory.streetlight => 'Report Streetlight Issue',
        _ => 'Submit Report',
      };

  IconData _subIcon(String s) {
    final l = s.toLowerCase();
    if (l.contains('pothole')) return Icons.trip_origin_rounded;
    if (l.contains('crack')) return Icons.texture_rounded;
    if (l.contains('flood')) return Icons.flood_rounded;
    if (l.contains('pole')) return Icons.vertical_align_top_rounded;
    if (l.contains('broken streetlight')) return Icons.lightbulb_outline_rounded;
    if (l.contains('pipe') || l.contains('leak')) return Icons.plumbing_rounded;
    if (l.contains('sewage')) return Icons.water_damage_outlined;
    if (l.contains('footpath')) return Icons.directions_walk_rounded;
    if (l.contains('entrance')) return Icons.door_front_door_outlined;
    if (l.contains('blocking road')) return Icons.block_rounded;
    if (l.contains('no-parking')) return Icons.do_not_disturb_on_outlined;
    if (l.contains('infrastructure')) return Icons.foundation_rounded;
    return category.icon;
  }

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final rc = context.watch<ReportsController>();
    final c = category;
    final nearby = rc.city
        .where((r) => r.category == c && r.status.isOpen)
        .where((r) => r.location.point.distanceTo(PlaceResolver.mapCenter()) < 3000)
        .take(3)
        .toList();
    final mine = rc.mine.where((r) => r.category == c).take(2).toList();

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 210,
          backgroundColor: ue.background,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14, end: 16),
            title: Text(context.t(_title), style: AppText.title(context).copyWith(color: Colors.white)),
            background: Stack(fit: StackFit.expand, children: [
              SceneImage(category: c, seed: 21),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.05), AppColors.navy.withValues(alpha: 0.85)],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 52,
                child: IconTile(icon: c.icon, color: Colors.white, size: 46, iconSize: 24),
              ),
            ]),
          ),
          leading: IconButton(
            tooltip: context.t('Back'),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          sliver: SliverList.list(children: [
            Text(context.t(c.blurb), style: AppText.bodySm(context)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.photo_camera_rounded,
                  label: 'Take Photo',
                  color: ue.secondary,
                  onTap: () => context.push(ReportFlowScreen(category: c)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Upload Photo',
                  color: AppColors.violet,
                  onTap: () async {
                    try {
                      final ev = await MediaService.pickPhotos();
                      if (ev.isNotEmpty && context.mounted) context.push(ReportFlowScreen(category: c, initialEvidence: ev));
                    } catch (_) {
                      if (context.mounted) showToast(context, 'Photo access was denied', kind: ToastKind.error);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickTile(
                  icon: Icons.my_location_rounded,
                  label: 'Current Location',
                  color: AppColors.emerald,
                  onTap: () => context.push(ReportFlowScreen(category: c)),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            SectionHeader(title: c == ReportCategory.streetlight ? 'Problem type' : 'What is the issue?'),
            const SizedBox(height: 10),
            for (var i = 0; i < c.subtypes.length; i++)
              FadeSlideIn(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => context.push(ReportFlowScreen(category: c, subtype: c.subtypes[i])),
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      IconTile(icon: _subIcon(c.subtypes[i]), color: c.color),
                      const SizedBox(width: 12),
                      Expanded(child: Text(context.t(c.subtypes[i]), style: AppText.label(context))),
                      Icon(Icons.chevron_right_rounded, color: ue.textSubtle),
                    ]),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            UeButton(label: _cta, icon: Icons.add_a_photo_rounded, onPressed: () => context.push(ReportFlowScreen(category: c))),
            if (mine.isNotEmpty) ...[
              const SizedBox(height: 28),
              const SectionHeader(title: 'Your reports'),
              const SizedBox(height: 10),
              for (final r in mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ReportCard(report: r, onTap: () => context.push(ReportDetailScreen(reportId: r.id))),
                ),
            ],
            const SizedBox(height: 18),
            const SectionHeader(title: 'Nearby open issues'),
            const SizedBox(height: 10),
            if (nearby.isEmpty)
              const SizedBox(height: 260, child: EmptyState(kind: EmptyKind.nearby))
            else
              for (final r in nearby)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ReportCard(report: r, onTap: () => context.push(ReportDetailScreen(reportId: r.id))),
                ),
          ]),
        ),
      ]),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        semanticLabel: context.t(label),
        child: Column(children: [
          IconTile(icon: icon, color: color),
          const SizedBox(height: 8),
          Text(context.t(label), textAlign: TextAlign.center, maxLines: 2, style: AppText.caption(context).copyWith(fontWeight: FontWeight.w700, color: context.ue.text)),
        ]),
      );
}
