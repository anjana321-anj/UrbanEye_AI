import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../state/admin_controller.dart';
import '../../widgets/ue_widgets.dart';
import 'admin_dashboard.dart';
import 'admin_shell.dart';

// ===========================================================================
// Team management
// ===========================================================================

class AdminTeamsPage extends StatelessWidget {
  const AdminTeamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AdminController>();
    if (ac.loading && ac.teams.isEmpty) return const Padding(padding: EdgeInsets.all(28), child: LoadingSkeleton());
    final active = ac.teams.fold<int>(0, (a, t) => a + t.activeTasks);
    final done = ac.teams.fold<int>(0, (a, t) => a + t.completedTasks);
    final members = ac.teams.fold<int>(0, (a, t) => a + t.members.length);
    return AdminPage(
      title: 'Municipality Teams',
      subtitle: '${ac.teams.length} teams · $members members',
      onRefresh: ac.refresh,
      actions: [
        UeButton(
          label: 'New team',
          icon: Icons.group_add_outlined,
          expand: false,
          height: 44,
          onPressed: ac.can(Perm.manageTeams) ? () => showToast(context, 'Team creation form (connect to HR directory)', kind: ToastKind.info) : null,
        ),
      ],
      children: [
        ResponsiveGrid(minItemWidth: 220, children: [
          KpiCard(label: 'Active tasks', value: active, icon: Icons.assignment_outlined, color: AppColors.electric),
          KpiCard(label: 'Completed tasks', value: done, icon: Icons.task_alt_rounded, color: AppColors.emerald),
          KpiCard(label: 'Members on duty', value: ac.teams.fold<int>(0, (a, t) => a + t.members.where((m) => m.onDuty).length), icon: Icons.badge_outlined, color: AppColors.violet),
        ]),
        const SizedBox(height: 14),
        PanelCard(
          title: 'Team locations',
          child: SizedBox(height: 300, child: ClipRRect(borderRadius: BorderRadius.circular(AppRadii.md), child: AdminCityMap(teams: ac.teams, vehicles: ac.vehicles))),
        ),
        const SizedBox(height: 14),
        ResponsiveGrid(minItemWidth: 340, children: [for (var i = 0; i < ac.teams.length; i++) FadeSlideIn(index: i, child: TeamCard(team: ac.teams[i]))]),
      ],
    );
  }
}

class TeamCard extends StatelessWidget {
  final Team team;
  const TeamCard({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final t = team;
    final (String status, Color sc) = switch (t.status) {
      TeamStatus.available => ('Available', ue.success),
      TeamStatus.busy => ('Busy', ue.warning),
      TeamStatus.offDuty => ('Off duty', ue.textSubtle),
    };
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconTile(icon: t.primaryCategory.icon, color: t.primaryCategory.color, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, style: AppText.title(context)),
              Row(children: [
                Icon(Icons.place_outlined, size: 13, color: ue.textSubtle),
                const SizedBox(width: 3),
                Expanded(child: Text(t.locationLabel, style: AppText.caption(context), overflow: TextOverflow.ellipsis)),
              ]),
            ]),
          ),
          Pill(status, icon: Icons.circle, color: sc),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          SizedBox(
            height: 34,
            width: 34.0 + (t.members.length - 1).clamp(0, 4).toDouble() * 22,
            child: Stack(children: [
              for (var i = 0; i < t.members.length && i < 5; i++)
                Positioned(
                  left: i * 22.0,
                  child: Tooltip(
                    message: '${t.members[i].name} · ${t.members[i].role}',
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ue.surface, width: 2)),
                      child: UeAvatar(
                        initials: t.members[i].name.split(' ').map((p) => p.isEmpty ? '' : p[0]).take(2).join(),
                        size: 30,
                        color: [AppColors.electric, AppColors.emerald, AppColors.violet, AppColors.amber, AppColors.teal][i % 5],
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 10),
          Text('${t.members.length} ${context.t('members')}', style: AppText.caption(context)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _metric(context, 'Active', '${t.activeTasks}'),
          _metric(context, 'Completed', '${t.completedTasks}'),
          _metric(context, 'Capacity', '${t.capacity}'),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Text(context.t('Workload'), style: AppText.caption(context)),
          const Spacer(),
          Text('${(t.workload * 100).round()}%', style: AppText.caption(context).copyWith(fontWeight: FontWeight.w800, color: ue.text)),
        ]),
        const SizedBox(height: 6),
        UeProgressBar(value: t.workload, color: t.workload > 0.85 ? ue.error : (t.workload > 0.6 ? ue.warning : ue.success)),
      ]),
    );
  }

  Widget _metric(BuildContext context, String label, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: AppText.h3(context)),
          Text(context.t(label), style: AppText.caption(context)),
        ]),
      );
}

// ===========================================================================
// Waste admin
// ===========================================================================

class AdminWastePage extends StatelessWidget {
  const AdminWastePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AdminController>();
    final ue = context.ue;
    final pending = ac.pickups.where((p) => p.status == PickupStatus.submitted || p.status == PickupStatus.notified).toList();
    final assigned = ac.pickups.where((p) => p.status == PickupStatus.assigned || p.status == PickupStatus.enRoute).toList();
    final completed = ac.pickups.where((p) => p.status == PickupStatus.collected).toList();
    final activeTrucks = ac.vehicles.where((v) => v.status != 'Idle').toList();
    final wasteReports = ac.reports.where((r) => r.category == ReportCategory.waste && r.status.isOpen).toList();

    return AdminPage(
      title: 'Waste Management',
      subtitle: 'Pickups, trucks and collection routes',
      onRefresh: ac.refresh,
      actions: [
        UeButton(label: 'Waste reports', icon: Icons.inbox_rounded, variant: ButtonVariant.outline, expand: false, height: 44, onPressed: () => context.read<AdminNav>().go('reports', cat: ReportCategory.waste)),
      ],
      children: [
        ResponsiveGrid(minItemWidth: 210, children: [
          KpiCard(label: 'Pending pickup requests', value: pending.length, icon: Icons.pending_actions_rounded, color: AppColors.amber),
          KpiCard(label: 'Assigned pickups', value: assigned.length, icon: Icons.assignment_ind_outlined, color: AppColors.electric),
          KpiCard(label: 'Active trucks', value: activeTrucks.length, icon: Icons.local_shipping_outlined, color: AppColors.violet),
          KpiCard(label: 'Completed pickups', value: 318 + completed.length, icon: Icons.task_alt_rounded, color: AppColors.emerald),
        ]),
        const SizedBox(height: 14),
        PanelCard(
          title: 'Collection routes',
          subtitle: 'Trucks, routes, pickup requests and open waste reports',
          trailing: Wrap(spacing: 6, children: [
            Pill('Truck', icon: Icons.local_shipping_rounded, color: AppColors.navy500),
            Pill('Pickup', icon: Icons.delete_outline_rounded, color: AppColors.emerald),
          ]),
          child: SizedBox(
            height: 380,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: AdminCityMap(vehicles: ac.vehicles, pickups: [...pending, ...assigned], reports: wasteReports),
            ),
          ),
        ),
        const SizedBox(height: 14),
        PanelCard(
          title: 'Trucks',
          child: ac.vehicles.isEmpty
              ? const SizedBox(height: 260, child: EmptyState(kind: EmptyKind.trucks))
              : AdminTable(
                  columns: const ['Truck', 'Driver', 'Status', 'Load', 'Route stops'],
                  flex: const [8, 12, 9, 12, 8],
                  rows: [
                    for (final v in ac.vehicles)
                      [
                        Text(v.id, style: AppText.label(context)),
                        Text(v.driver, style: AppText.caption(context).copyWith(color: ue.text)),
                        Pill(v.status, icon: Icons.circle, color: v.status == 'Idle' ? ue.textSubtle : ue.success),
                        Row(children: [Expanded(child: UeProgressBar(value: v.loadPercent, height: 6)), const SizedBox(width: 8), Text('${(v.loadPercent * 100).round()}%', style: AppText.caption(context))]),
                        Text('${v.route.length}', style: AppText.caption(context).copyWith(color: ue.text)),
                      ],
                  ],
                ),
        ),
        const SizedBox(height: 14),
        PanelCard(
          title: 'Pickup requests',
          child: ac.pickups.isEmpty
              ? const SizedBox(height: 260, child: EmptyState(kind: EmptyKind.pickups))
              : AdminTable(
                  columns: const ['Ticket', 'Type', 'Location', 'Requested', 'Preference', 'Truck', 'Status', 'Actions'],
                  flex: const [9, 10, 13, 10, 12, 8, 12, 16],
                  rows: [for (final p in ac.pickups) _pickupRow(context, ac, p)],
                ),
        ),
      ],
    );
  }

  List<Widget> _pickupRow(BuildContext context, AdminController ac, WastePickup p) {
    final ue = context.ue;
    final cap = AppText.caption(context).copyWith(color: ue.text);
    final next = switch (p.status) {
      PickupStatus.submitted || PickupStatus.notified => PickupStatus.assigned,
      PickupStatus.assigned => PickupStatus.enRoute,
      PickupStatus.enRoute => PickupStatus.collected,
      _ => null,
    };
    return [
      Text(p.ticket, style: AppText.label(context).copyWith(fontSize: 12.5)),
      Row(children: [Icon(p.wasteType.icon, size: 14, color: p.wasteType.color), const SizedBox(width: 4), Flexible(child: Text(context.t(p.wasteType.label), style: cap, overflow: TextOverflow.ellipsis))]),
      Text(p.location.area, style: cap, overflow: TextOverflow.ellipsis),
      Text(Fmt.relative(p.createdAt), style: cap),
      Text(p.preference, style: cap, maxLines: 2),
      Text(p.vehicleId ?? '—', style: cap),
      Pill(p.status.label, color: p.status == PickupStatus.collected ? ue.success : (p.status.index >= 2 ? ue.secondary : ue.warning)),
      Wrap(spacing: 4, children: [
        if (p.vehicleId == null && p.status != PickupStatus.collected)
          PopupMenuButton<String>(
            tooltip: context.t('Assign Truck'),
            onSelected: (v) async {
              final err = await ac.updatePickup(p, PickupStatus.assigned, vehicleId: v);
              if (context.mounted) showToast(context, err ?? 'Truck $v assigned to ${p.ticket}', kind: err == null ? ToastKind.success : ToastKind.error);
            },
            itemBuilder: (_) => [for (final v in ac.vehicles) PopupMenuItem(value: v.id, child: Text('${v.id} · ${v.status}'))],
            child: Pill('Assign Truck', icon: Icons.local_shipping_outlined, color: ue.secondary),
          ),
        if (next != null && p.vehicleId != null)
          InkWell(
            onTap: () async {
              final err = await ac.updatePickup(p, next);
              if (context.mounted) showToast(context, err ?? '${p.ticket}: ${next.label}', kind: err == null ? ToastKind.success : ToastKind.error);
            },
            child: Pill(next == PickupStatus.enRoute ? 'Mark en route' : 'Mark collected', icon: Icons.arrow_forward_rounded, color: ue.success),
          ),
      ]),
    ];
  }
}
