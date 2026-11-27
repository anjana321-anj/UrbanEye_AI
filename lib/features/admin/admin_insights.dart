import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/env.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../data/mock/mock_db.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../state/admin_controller.dart';
import '../../state/auth_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/charts.dart';
import '../../widgets/ue_widgets.dart';
import 'admin_dashboard.dart';
import 'admin_shell.dart';

// ===========================================================================
// Analytics
// ===========================================================================

class AdminAnalyticsPage extends StatelessWidget {
  const AdminAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AdminController>();
    final a = ac.snapshot;
    final s = ac.stats;
    if (a == null || s == null) return const Padding(padding: EdgeInsets.all(28), child: SingleChildScrollView(child: LoadingSkeleton(kind: SkeletonKind.dashboard)));
    final ue = context.ue;
    final wide = MediaQuery.sizeOf(context).width > 1100;
    Widget pair(Widget x, Widget y) => wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: x), const SizedBox(width: 14), Expanded(child: y)])
        : Column(children: [x, const SizedBox(height: 14), y]);

    final most = a.byCategory.entries.map((e) => SeriesPoint(e.key.shortLabel, e.value.toDouble())).toList()..sort((x, y) => y.value.compareTo(x.value));

    return AdminPage(
      title: 'Smart Analytics',
      subtitle: 'Trends, performance and SLA compliance',
      onRefresh: () async {
        await ac.refresh();
        await ac.loadAnalytics();
      },
      actions: [
        UeButton(label: 'Download report', icon: Icons.picture_as_pdf_outlined, variant: ButtonVariant.outline, expand: false, height: 44, onPressed: () => showToast(context, 'Monthly report generated', kind: ToastKind.success)),
      ],
      children: [
        ResponsiveGrid(minItemWidth: 220, children: [
          KpiCard(label: 'Resolution Rate', value: (s.resolutionRate * 100).round(), icon: Icons.percent_rounded, color: AppColors.emerald, delta: '+2.4 pts'),
          KpiCard(label: 'Avg. Resolution Time (h)', value: s.avgResolutionHours.round(), icon: Icons.timer_outlined, color: AppColors.amber, delta: '-18%'),
          KpiCard(label: 'SLA Compliance %', value: (a.slaCompliance * 100).round(), icon: Icons.verified_outlined, color: AppColors.electric),
          KpiCard(label: 'Area With Most Complaints', value: a.byArea.isEmpty ? 0 : a.byArea.first.value.round(), icon: Icons.location_city_rounded, color: AppColors.red, delta: a.byArea.isEmpty ? null : a.byArea.first.label, deltaGood: false),
        ]),
        const SizedBox(height: 14),
        pair(
          PanelCard(title: 'Issue Trends', subtitle: 'Daily reports, last 14 days', child: LineChart(data: a.daily, color: AppColors.electric, height: 220)),
          PanelCard(title: 'Most Reported Problems', child: RankBars(data: most, color: AppColors.violet)),
        ),
        const SizedBox(height: 14),
        pair(
          PanelCard(title: 'Resolution Rate', subtitle: 'Monthly', child: LineChart(data: a.monthlyResolutionRate, color: AppColors.emerald, height: 200, percent: true)),
          PanelCard(title: 'Average Resolution Time', subtitle: 'Hours by category', child: BarChart(data: a.resolutionHoursByCategory, color: AppColors.amber, height: 200, format: (v) => '${v.round()}h')),
        ),
        const SizedBox(height: 14),
        pair(
          PanelCard(title: 'Area With Most Complaints', child: RankBars(data: a.byArea, color: AppColors.red)),
          PanelCard(title: 'Waste Pickup Performance', subtitle: 'Pickups completed per month', child: BarChart(data: a.wastePickupPerformance, color: AppColors.emerald, height: 200)),
        ),
        const SizedBox(height: 14),
        pair(
          PanelCard(title: 'Road Maintenance Trends', subtitle: 'Road issues resolved per month', child: LineChart(data: a.roadTrend, color: AppColors.electric, height: 200)),
          PanelCard(
            title: 'SLA Compliance',
            child: Row(children: [
              ProgressRing(
                value: a.slaCompliance,
                size: 130,
                stroke: 12,
                color: ue.success,
                center: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(a.slaCompliance * 100).round()}%', style: AppText.h2(context)),
                  Text(context.t('on time'), style: AppText.caption(context)),
                ]),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final sv in Severity.values.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        SeverityBadge(severity: sv),
                        const Spacer(),
                        Text('${context.t('target')} ${Fmt.duration(ac.sla[sv]!)}', style: AppText.caption(context)),
                      ]),
                    ),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        PanelCard(
          title: 'Team Performance',
          child: AdminTable(
            columns: const ['Team', 'Completed', 'Avg hours', 'SLA compliance'],
            flex: const [16, 8, 8, 14],
            rows: [
              for (final t in a.teams)
                [
                  Text(t.teamName, style: AppText.label(context)),
                  Text(Fmt.number(t.completed), style: AppText.caption(context).copyWith(color: ue.text)),
                  Text(t.avgHours.toStringAsFixed(1), style: AppText.caption(context).copyWith(color: ue.text)),
                  Row(children: [
                    Expanded(child: UeProgressBar(value: t.slaCompliance, height: 6, color: t.slaCompliance > 0.9 ? ue.success : ue.warning)),
                    const SizedBox(width: 8),
                    Text('${(t.slaCompliance * 100).round()}%', style: AppText.caption(context)),
                  ]),
                ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        AiInsightsCard(insights: a.insights),
      ],
    );
  }
}

// ===========================================================================
// SLA management
// ===========================================================================

class AdminSlaPage extends StatelessWidget {
  const AdminSlaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AdminController>();
    final ue = context.ue;
    final open = ac.reports.where((r) => r.status.isOpen).toList()..sort((a, b) => ac.remaining(a).compareTo(ac.remaining(b)));
    final overdue = open.where(ac.overdue).length;
    final atRisk = open.where((r) => !ac.overdue(r) && ac.remaining(r).inHours < 6).length;
    final canEdit = ac.can(Perm.configureSla);

    return AdminPage(
      title: 'SLA & Escalation',
      subtitle: 'Response targets by priority. Overdue reports are escalated to supervisors automatically.',
      onRefresh: ac.refresh,
      actions: [
        UeButton(
          label: 'Run escalation now',
          icon: Icons.bolt_rounded,
          expand: false,
          height: 44,
          onPressed: () async {
            await ac.runEscalation();
            if (context.mounted) showToast(context, '${ac.lastEscalated} report(s) escalated', kind: ToastKind.success);
          },
        ),
      ],
      children: [
        ResponsiveGrid(minItemWidth: 220, children: [
          KpiCard(label: 'Open reports', value: open.length, icon: Icons.inbox_outlined, color: AppColors.electric),
          KpiCard(label: 'At risk (< 6 h)', value: atRisk, icon: Icons.hourglass_bottom_rounded, color: AppColors.amber),
          KpiCard(label: 'Overdue', value: overdue, icon: Icons.alarm_off_rounded, color: AppColors.red),
          KpiCard(label: 'Escalated to supervisors', value: open.where((r) => r.escalated).length, icon: Icons.supervisor_account_outlined, color: AppColors.violet),
        ]),
        const SizedBox(height: 14),
        PanelCard(
          title: 'Response targets',
          subtitle: canEdit ? 'Drag to adjust. Changes apply immediately.' : 'Only Municipal Administrators can change targets.',
          child: Column(children: [
            for (final s in Severity.values.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  SizedBox(width: 100, child: SeverityBadge(severity: s)),
                  Expanded(
                    child: Slider(
                      value: ac.sla[s]!.inHours.toDouble().clamp(1, 336),
                      min: 1,
                      max: 336,
                      divisions: 335,
                      label: Fmt.duration(ac.sla[s]!),
                      onChanged: canEdit ? (v) => ac.setSla(s, Duration(hours: v.round())) : null,
                    ),
                  ),
                  SizedBox(width: 70, child: Text(Fmt.duration(ac.sla[s]!), textAlign: TextAlign.right, style: AppText.label(context))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        PanelCard(
          title: 'Open reports by SLA',
          child: open.isEmpty
              ? const SizedBox(height: 240, child: EmptyState(kind: EmptyKind.reports, title: 'No open reports'))
              : AdminTable(
                  columns: const ['Ticket', 'Category', 'Priority', 'Status', 'Due', 'Time remaining', 'Escalation'],
                  flex: const [9, 12, 9, 11, 14, 12, 12],
                  onRowTap: (i) => context.read<AdminNav>().openReport(open[i].id),
                  rows: [
                    for (final r in open.take(40))
                      [
                        Text(r.ticket, style: AppText.label(context).copyWith(fontSize: 12.5)),
                        Text(context.t(r.category.shortLabel), style: AppText.caption(context).copyWith(color: ue.text)),
                        SeverityBadge(severity: r.severity),
                        StatusBadge(status: r.status, compact: true),
                        Text(Fmt.dateTime(ac.dueAt(r)), style: AppText.caption(context).copyWith(color: ue.text)),
                        SlaChip(remaining: ac.remaining(r)),
                        r.escalated
                            ? Pill('Supervisor', icon: Icons.supervisor_account_outlined, color: ue.error)
                            : Text('—', style: AppText.caption(context)),
                      ],
                  ],
                ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Audit log
// ===========================================================================

class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key});
  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AdminController>();
    final ue = context.ue;
    final tickets = {for (final r in ac.reports) r.id: r.ticket};
    final logs = ac.audit.where((a) {
      if (_q.isEmpty) return true;
      final q = _q.toLowerCase();
      return a.actor.toLowerCase().contains(q) || a.action.toLowerCase().contains(q) || (tickets[a.reportId] ?? '').toLowerCase().contains(q);
    }).toList();
    if (!ac.can(Perm.viewAudit)) {
      return const EmptyIllustrationLayout(icon: Icons.lock_outline_rounded, color: AppColors.red, title: 'Restricted', message: 'The audit log is visible to supervisors and administrators.');
    }
    return AdminPage(
      title: 'Audit Log',
      subtitle: 'Every administrative action is recorded and immutable.',
      onRefresh: ac.refresh,
      actions: [
        SizedBox(
          width: 280,
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(isDense: true, hintText: context.t('Filter by admin, action, ticket'), prefixIcon: const Icon(Icons.filter_list_rounded, size: 20)),
          ),
        ),
      ],
      children: [
        AppCard(
          padding: const EdgeInsets.all(8),
          child: logs.isEmpty
              ? SizedBox(
                  height: 300,
                  child: EmptyIllustrationLayout(
                    icon: Icons.receipt_long_outlined,
                    color: ue.secondary,
                    title: 'No audit entries yet',
                    message: 'Verify, assign or resolve a report and the action will appear here.',
                  ),
                )
              : AdminTable(
                  columns: const ['Timestamp', 'Admin', 'Action', 'Report ID', 'Previous', 'New', 'Notes'],
                  flex: const [12, 13, 16, 9, 10, 10, 18],
                  rows: [
                    for (final a in logs)
                      [
                        Text(Fmt.dateTime(a.at), style: AppText.caption(context).copyWith(color: ue.text)),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.actor, style: AppText.label(context).copyWith(fontSize: 12.5)),
                          Text(a.actorRole.label, style: AppText.caption(context).copyWith(fontSize: 10.5)),
                        ]),
                        Text(a.action, style: AppText.caption(context).copyWith(color: ue.text, fontWeight: FontWeight.w600)),
                        Text(tickets[a.reportId] ?? '—', style: AppText.caption(context).copyWith(color: ue.text)),
                        a.previous == null ? const Text('—') : StatusBadge(status: a.previous!, compact: true),
                        a.next == null ? const Text('—') : StatusBadge(status: a.next!, compact: true),
                        Text(a.note ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption(context)),
                      ],
                  ],
                ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Users & roles
// ===========================================================================

class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AdminController>();
    final ue = context.ue;
    final identity = ac.can(Perm.viewCitizenIdentity);
    final users = [...ac.users]..sort((a, b) => b.role.index.compareTo(a.role.index));
    return AdminPage(
      title: 'Users',
      subtitle: '${users.where((u) => u.role == UserRole.citizen).length} citizens · ${users.where((u) => u.role.isStaff).length} staff',
      onRefresh: ac.refresh,
      children: [
        PanelCard(
          title: 'Accounts',
          subtitle: identity ? null : 'Citizen identities are masked for your role',
          child: AdminTable(
            columns: const ['Name', 'Role', 'Email', 'Phone', 'Reports', 'Joined'],
            flex: const [14, 13, 16, 11, 7, 10],
            rows: [
              for (final u in users)
                [
                  Row(children: [
                    UeAvatar(initials: u.initials, size: 30, color: u.role.isStaff ? AppColors.navy500 : AppColors.electric),
                    const SizedBox(width: 8),
                    Flexible(child: Text(u.role.isStaff || identity ? u.name : Fmt.maskName(u.name), style: AppText.label(context).copyWith(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                  ]),
                  Pill(u.role.label, color: u.role.isStaff ? ue.secondary : ue.textMuted),
                  Text(u.role.isStaff || identity ? u.email : '••••@${u.email.split('@').last}', style: AppText.caption(context).copyWith(color: ue.text), overflow: TextOverflow.ellipsis),
                  Text(Fmt.maskPhone(u.phone), style: AppText.caption(context).copyWith(color: ue.text)),
                  Text('${ac.reports.where((r) => r.citizenId == u.id).length}', style: AppText.caption(context).copyWith(color: ue.text)),
                  Text(Fmt.date(u.joinedAt), style: AppText.caption(context)),
                ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        PanelCard(
          title: 'Role-based access control',
          subtitle: 'Permissions enforced in the console and on the API',
          child: AdminTable(
            columns: ['Permission', for (final r in UserRole.values) r.label.split(' ').last],
            flex: [16, for (final _ in UserRole.values) 8],
            rows: [
              for (final p in Perm.values)
                [
                  Text(_permLabel(p), style: AppText.caption(context).copyWith(color: ue.text, fontWeight: FontWeight.w600)),
                  for (final r in UserRole.values)
                    Icon(r.can(p) ? Icons.check_circle_rounded : Icons.remove_rounded,
                        size: 18, color: r.can(p) ? ue.success : ue.textSubtle, semanticLabel: r.can(p) ? 'Allowed' : 'Not allowed'),
                ],
            ],
          ),
        ),
      ],
    );
  }

  static String _permLabel(Perm p) {
    final n = p.name.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]!.toLowerCase()}');
    return n[0].toUpperCase() + n.substring(1);
  }
}

// ===========================================================================
// Settings
// ===========================================================================

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final ue = context.ue;
    const m = MockDb.municipality;
    return AdminPage(
      title: 'Settings',
      subtitle: 'Municipality configuration and console preferences',
      children: [
        PanelCard(
          title: 'Municipality',
          child: Column(children: [
            KeyValueRow(icon: Icons.account_balance_outlined, label: 'Name', value: m.name),
            KeyValueRow(icon: Icons.tag_rounded, label: 'Tenant ID', value: Env.municipalityId),
            KeyValueRow(icon: Icons.emergency_outlined, label: 'Emergency numbers', value: m.emergencyNumbers),
            KeyValueRow(icon: Icons.cloud_outlined, label: 'API endpoint', value: Env.useMockBackend ? 'Mock backend (development)' : Env.apiBaseUrl),
            KeyValueRow(icon: Icons.history_toggle_off_rounded, label: 'Data retention', value: '${s.retentionMonths} months, then anonymised'),
          ]),
        ),
        const SizedBox(height: 14),
        PanelCard(
          title: 'Console preferences',
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('Dark Mode'), style: AppText.label(context)),
              value: context.isDark,
              onChanged: (v) => s.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('Language'), style: AppText.label(context)),
              trailing: DropdownButton<String>(
                value: s.locale.languageCode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ne', child: Text('नेपाली')),
                ],
                onChanged: (v) => s.setLocale(Locale(v ?? 'en')),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('Reduce motion'), style: AppText.label(context)),
              value: s.reducedMotion,
              onChanged: s.setReducedMotion,
            ),
          ]),
        ),
        const SizedBox(height: 14),
        PanelCard(
          title: 'Security',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final line in const [
              'Role-based access control enforced on every action',
              'All administrative actions are audit-logged',
              'Citizen identities masked unless your role requires them',
              'Evidence uploads scanned and EXIF-stripped server-side',
              'API keys live on the server — never in the app',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(Icons.check_circle_outline_rounded, size: 18, color: ue.success),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.t(line), style: AppText.bodySm(context))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: UeButton(label: 'Logout', icon: Icons.logout_rounded, variant: ButtonVariant.outline, expand: false, onPressed: () => context.read<AuthController>().logout()),
        ),
      ],
    );
  }
}
