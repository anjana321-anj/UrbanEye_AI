import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../state/admin_controller.dart';
import '../../widgets/map_view.dart';
import '../../widgets/scene_image.dart';
import '../../widgets/ue_widgets.dart';
import 'admin_dashboard.dart';
import 'admin_shell.dart';

// ===========================================================================
// Report management
// ===========================================================================

class AdminReportsPage extends StatefulWidget {
  final ReportCategory? category;
  const AdminReportsPage({super.key, this.category});
  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  String _q = '';
  StatusBucket? _bucket;
  Severity? _priority;
  bool _escalatedOnly = false;
  int _page = 0;
  static const _pageSize = 12;

  List<Report> _filtered(AdminController ac) {
    var l = ac.reports.where((r) => widget.category == null || r.category == widget.category);
    if (_bucket != null) l = l.where((r) => r.status.bucket == _bucket);
    if (_priority != null) l = l.where((r) => r.severity == _priority);
    if (_escalatedOnly) l = l.where((r) => r.escalated || ac.overdue(r));
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      l = l.where((r) => r.ticket.toLowerCase().contains(q) || r.location.address.toLowerCase().contains(q) || r.description.toLowerCase().contains(q));
    }
    final list = l.toList()
      ..sort((a, b) {
        final s = b.severity.index.compareTo(a.severity.index);
        if (a.status.isOpen != b.status.isOpen) return a.status.isOpen ? -1 : 1;
        return s != 0 ? s : b.createdAt.compareTo(a.createdAt);
      });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AdminController>();
    final nav = context.watch<AdminNav>();
    final w = MediaQuery.sizeOf(context).width;
    final split = w >= 1280;
    final openId = nav.openReportId;
    final open = openId == null ? null : ac.reports.where((r) => r.id == openId).firstOrNull;

    if (open != null && !split) {
      return AdminReportDetail(report: open, onClose: nav.closeReport);
    }

    final all = _filtered(ac);
    final pages = (all.length / _pageSize).ceil().clamp(1, 999).toInt();
    final page = _page.clamp(0, pages - 1).toInt();
    final rows = all.skip(page * _pageSize).take(_pageSize).toList();

    final list = AdminPage(
      title: widget.category == null ? 'Reports' : widget.category!.label,
      subtitle: '${all.length} ${context.t('reports')} · ${all.where((r) => r.status.isOpen).length} ${context.t('open')}',
      onRefresh: ac.refresh,
      actions: [
        UeButton(label: 'Export CSV', icon: Icons.download_rounded, variant: ButtonVariant.outline, expand: false, height: 44, onPressed: () => showToast(context, 'Export queued — anonymised CSV will be emailed', kind: ToastKind.success)),
      ],
      children: [
        _filters(context),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(8),
          child: ac.loading && ac.reports.isEmpty
              ? const Padding(padding: EdgeInsets.all(12), child: LoadingSkeleton())
              : rows.isEmpty
                  ? const SizedBox(height: 320, child: EmptyState(kind: EmptyKind.search))
                  : AdminTable(
                      columns: const ['Ticket ID', 'Category', 'Citizen', 'Location', 'Date', 'Priority', 'Assigned Team', 'Status', 'SLA', ''],
                      flex: const [10, 13, 11, 13, 10, 9, 13, 11, 11, 4],
                      selectedIndex: open == null ? null : rows.indexOf(open),
                      onRowTap: (i) => nav.openReport(rows[i].id),
                      rows: [for (final r in rows) _row(context, ac, r)],
                    ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('${context.t('Page')} ${page + 1} / $pages', style: AppText.caption(context)),
          IconButton(tooltip: context.t('Previous'), onPressed: page > 0 ? () => setState(() => _page = page - 1) : null, icon: const Icon(Icons.chevron_left_rounded)),
          IconButton(tooltip: context.t('Next'), onPressed: page < pages - 1 ? () => setState(() => _page = page + 1) : null, icon: const Icon(Icons.chevron_right_rounded)),
        ]),
      ],
    );

    if (!split) return list;
    return Row(children: [
      Expanded(child: list),
      AnimatedContainer(
        duration: Motion.d(context, 300),
        curve: Curves.easeOutCubic,
        width: open == null ? 0 : 500,
        decoration: BoxDecoration(border: Border(left: BorderSide(color: context.ue.border))),
        child: open == null ? const SizedBox() : AdminReportDetail(key: ValueKey(open.id), report: open, onClose: nav.closeReport, panel: true),
      ),
    ]);
  }

  Widget _filters(BuildContext context) {
    final ue = context.ue;
    return Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      SizedBox(
        width: 280,
        child: TextField(
          onChanged: (v) => setState(() {
            _q = v;
            _page = 0;
          }),
          decoration: InputDecoration(isDense: true, hintText: context.t('Search ticket, address, text'), prefixIcon: const Icon(Icons.search_rounded, size: 20)),
        ),
      ),
      _drop<StatusBucket>(context, 'Status', _bucket, StatusBucket.values, (b) => b.label, (v) => setState(() {
            _bucket = v;
            _page = 0;
          })),
      _drop<Severity>(context, 'Priority', _priority, Severity.values, (s) => s.label, (v) => setState(() {
            _priority = v;
            _page = 0;
          })),
      FilterChip(
        avatar: Icon(Icons.priority_high_rounded, size: 16, color: _escalatedOnly ? Colors.white : ue.error),
        label: Text(context.t('Overdue / escalated')),
        selected: _escalatedOnly,
        showCheckmark: false,
        selectedColor: ue.error,
        labelStyle: TextStyle(color: _escalatedOnly ? Colors.white : ue.text, fontWeight: FontWeight.w700, fontSize: 12.5),
        onSelected: (v) => setState(() => _escalatedOnly = v),
      ),
    ]);
  }

  Widget _drop<T>(BuildContext context, String label, T? value, List<T> items, String Function(T) text, ValueChanged<T?> onChanged) {
    final ue = context.ue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: ue.surface, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: ue.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          hint: Text(context.t(label), style: AppText.label(context)),
          items: [
            DropdownMenuItem<T?>(value: null, child: Text('${context.t('All')} ${context.t(label).toLowerCase()}')),
            for (final i in items) DropdownMenuItem<T?>(value: i, child: Text(context.t(text(i)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<Widget> _row(BuildContext context, AdminController ac, Report r) {
    final cap = AppText.caption(context).copyWith(color: context.ue.text, fontWeight: FontWeight.w600);
    final team = ac.team(r.assignment?.teamId);
    final showName = ac.can(Perm.viewCitizenIdentity);
    return [
      Row(children: [
        if (r.escalated) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.priority_high_rounded, size: 14, color: context.ue.error)),
        Flexible(child: Text(r.ticket, style: AppText.label(context).copyWith(fontSize: 12.5))),
      ]),
      Row(children: [
        Icon(r.category.icon, size: 15, color: r.category.color),
        const SizedBox(width: 6),
        Flexible(child: Text(context.t(r.category.shortLabel), style: cap, overflow: TextOverflow.ellipsis)),
      ]),
      Text(r.anonymous ? context.t('Anonymous') : (showName ? r.citizenName : Fmt.maskName(r.citizenName)), style: cap, overflow: TextOverflow.ellipsis),
      Text(r.location.area, style: cap, overflow: TextOverflow.ellipsis),
      Text(Fmt.date(r.createdAt), style: cap),
      SeverityBadge(severity: r.severity),
      Text(team?.name ?? '—', style: cap, maxLines: 2, overflow: TextOverflow.ellipsis),
      StatusBadge(status: r.status, compact: true),
      r.status.isOpen ? SlaChip(remaining: ac.remaining(r)) : Text('—', style: cap),
      ReportActionsMenu(report: r),
    ];
  }
}

/// Row action menu: View, Assign, Update Status, Contact Citizen, Reject, Verify.
class ReportActionsMenu extends StatelessWidget {
  final Report report;
  const ReportActionsMenu({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final ac = context.read<AdminController>();
    final r = report;
    PopupMenuItem<String> item(String v, IconData i, String l, bool enabled) => PopupMenuItem(
          value: v,
          enabled: enabled,
          child: Row(children: [Icon(i, size: 18), const SizedBox(width: 10), Text(context.t(l))]),
        );
    return PopupMenuButton<String>(
      tooltip: context.t('Actions'),
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      onSelected: (v) => runAdminAction(context, v, r),
      itemBuilder: (_) => [
        item('view', Icons.open_in_new_rounded, 'View', true),
        item('assign', Icons.groups_2_outlined, 'Assign', ac.can(Perm.assignTeam) && r.status.isOpen),
        item('status', Icons.sync_alt_rounded, 'Update Status', ac.can(Perm.updateStatus) && r.status.nextAllowed.isNotEmpty),
        item('contact', Icons.forum_outlined, 'Contact Citizen', ac.can(Perm.contactCitizen)),
        item('verify', Icons.verified_outlined, 'Verify', ac.can(Perm.verifyReport) && r.status.canTransitionTo(ReportStatus.verified)),
        item('reject', Icons.block_rounded, 'Reject', ac.can(Perm.rejectReport) && r.status.canTransitionTo(ReportStatus.rejected)),
      ],
    );
  }
}

/// Executes an admin action with confirmation dialogs and result toasts.
Future<void> runAdminAction(BuildContext context, String action, Report r) async {
  final ac = context.read<AdminController>();
  String? err;
  String ok = 'Done';
  switch (action) {
    case 'view':
      context.read<AdminNav>().openReport(r.id);
      return;
    case 'verify':
      err = await ac.transition(r, ReportStatus.verified, note: 'Verified by municipality');
      ok = '${r.ticket} verified';
    case 'reject':
      final reason = await _textDialog(context, 'Reject report', 'Reason shared with the citizen', required: true);
      if (reason == null) return;
      err = await ac.transition(r, ReportStatus.rejected, note: reason);
      ok = '${r.ticket} rejected';
    case 'assign':
      final teamId = await _assignDialog(context, r);
      if (teamId == null) return;
      err = await ac.assign(r, teamId);
      ok = 'Team assigned';
    case 'status':
      final to = await _statusDialog(context, r);
      if (to == null) return;
      if (to == ReportStatus.resolved) {
        return runAdminAction(context, 'resolve', r);
      }
      err = await ac.transition(r, to);
      ok = 'Status updated to ${to.label}';
    case 'resolve':
      final note = await _textDialog(context, 'Mark resolved', 'Resolution note (visible to citizen)', required: true, initial: 'Issue fixed and site inspected.');
      if (note == null) return;
      err = await ac.resolve(r, note);
      ok = '${r.ticket} resolved — citizen asked to confirm';
    case 'contact':
      final msg = await _textDialog(context, 'Message citizen', 'Secure in-app message (no phone numbers shared)', required: true);
      if (msg == null) return;
      err = await ac.message(r, msg);
      ok = 'Message sent';
    case 'info':
      final msg = await _textDialog(context, 'Request more information', 'What do you need from the citizen?', required: true,
          initial: 'Could you share a closer photo of the issue?');
      if (msg == null) return;
      err = await ac.message(r, msg, question: true);
      ok = 'Request sent to citizen';
    case 'note':
      final msg = await _textDialog(context, 'Add internal note', 'Visible to the citizen as a status explanation', required: true);
      if (msg == null) return;
      err = await ac.message(r, msg);
      ok = 'Note added';
  }
  if (!context.mounted) return;
  showToast(context, err ?? ok, kind: err == null ? ToastKind.success : ToastKind.error);
}

Future<String?> _textDialog(BuildContext context, String title, String hint, {bool required = false, String? initial}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.t(title), style: AppText.h3(ctx)),
      content: SizedBox(
        width: 420,
        child: TextField(controller: c, autofocus: true, maxLines: 4, decoration: InputDecoration(hintText: ctx.t(hint))),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('Cancel'))),
        FilledButton(
          onPressed: () {
            if (required && c.text.trim().isEmpty) return;
            Navigator.pop(ctx, Validators.sanitize(c.text));
          },
          child: Text(ctx.t('Confirm')),
        ),
      ],
    ),
  );
}

Future<String?> _assignDialog(BuildContext context, Report r) {
  final ac = context.read<AdminController>();
  final teams = [...ac.teams]..sort((a, b) {
      final pa = a.primaryCategory == r.category || a.id == r.category.teamId ? 0 : 1;
      final pb = b.primaryCategory == r.category || b.id == r.category.teamId ? 0 : 1;
      return pa != pb ? pa.compareTo(pb) : a.workload.compareTo(b.workload);
    });
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${ctx.t('Assign team')} · ${r.ticket}', style: AppText.h3(ctx)),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final t in teams)
            ListTile(
              onTap: () => Navigator.pop(ctx, t.id),
              leading: IconTile(icon: t.primaryCategory.icon, color: t.primaryCategory.color, size: 40),
              title: Row(children: [
                Flexible(child: Text(t.name, style: AppText.label(ctx))),
                if (t.id == r.category.teamId) ...[const SizedBox(width: 6), Pill('Recommended', color: ctx.ue.success)],
              ]),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Expanded(child: UeProgressBar(value: t.workload, height: 6, color: t.workload > 0.8 ? ctx.ue.error : ctx.ue.secondary)),
                  const SizedBox(width: 8),
                  Text('${t.activeTasks}/${t.capacity}', style: AppText.caption(ctx)),
                ]),
              ),
            ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('Cancel')))],
    ),
  );
}

Future<ReportStatus?> _statusDialog(BuildContext context, Report r) {
  final options = r.status.nextAllowed.toList();
  return showDialog<ReportStatus>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.t('Update status'), style: AppText.h3(ctx)),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text('${ctx.t('Current')}: ', style: AppText.caption(ctx)), StatusBadge(status: r.status, compact: true)]),
          const SizedBox(height: 14),
          Text(ctx.t('Allowed next steps (validated workflow)'), style: AppText.caption(ctx)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in options)
              ActionChip(
                avatar: Icon(s.bucket.icon, size: 16, color: s.bucket.color),
                label: Text(ctx.t(s.label)),
                onPressed: () => Navigator.pop(ctx, s),
              ),
          ]),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('Cancel')))],
    ),
  );
}

// ===========================================================================
// Report detail (panel or full page)
// ===========================================================================

class AdminReportDetail extends StatefulWidget {
  final Report report;
  final VoidCallback onClose;
  final bool panel;
  const AdminReportDetail({super.key, required this.report, required this.onClose, this.panel = false});
  @override
  State<AdminReportDetail> createState() => _AdminReportDetailState();
}

class _AdminReportDetailState extends State<AdminReportDetail> {
  List<AuditLog>? _audit;
  int _photo = 0;

  @override
  void initState() {
    super.initState();
    _loadAudit();
  }

  @override
  void didUpdateWidget(covariant AdminReportDetail old) {
    super.didUpdateWidget(old);
    _loadAudit();
  }

  Future<void> _loadAudit() async {
    final a = await context.read<AdminController>().auditFor(widget.report.id);
    if (mounted) setState(() => _audit = a);
  }

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AdminController>();
    final r = widget.report;
    final ue = context.ue;
    final team = ac.team(r.assignment?.teamId);
    Widget action(String id, IconData icon, String label, Perm perm, {bool enabled = true, ButtonVariant v = ButtonVariant.outline}) {
      final allowed = ac.can(perm) && enabled;
      return Tooltip(
        message: ac.can(perm) ? '' : '${context.t('Not permitted for')} ${ac.role.label}',
        child: SizedBox(
          width: widget.panel ? 210 : 220,
          child: UeButton(label: label, icon: icon, variant: v, height: 44, onPressed: allowed ? () => runAdminAction(context, id, r) : null),
        ),
      );
    }

    return Container(
      color: ue.background,
      child: ListView(padding: EdgeInsets.all(widget.panel ? 20 : 24), children: [
        Row(children: [
          IconButton(tooltip: context.t('Close'), onPressed: widget.onClose, icon: Icon(widget.panel ? Icons.close_rounded : Icons.arrow_back_rounded)),
          const SizedBox(width: 4),
          Expanded(child: Text('${context.t('Report')} #${r.ticket}', style: AppText.h2(context))),
          StatusBadge(status: r.status),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: SizedBox(
            height: 230,
            child: Stack(children: [
              PageView(
                onPageChanged: (i) => setState(() => _photo = i),
                children: [
                  for (final e in r.evidence) EvidenceImage(evidence: e, category: r.category),
                  for (final e in r.afterEvidence) EvidenceImage(evidence: e, category: r.category),
                  if (r.evidence.isEmpty && r.afterEvidence.isEmpty) SceneImage(category: r.category, seed: r.ticket.hashCode),
                ],
              ),
              Positioned(
                left: 10,
                top: 10,
                child: Pill(
                  _photo < r.evidence.length ? 'Citizen evidence ${_photo + 1}/${r.evidence.length}' : 'After (resolution)',
                  icon: Icons.photo_outlined,
                  color: Colors.white,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill(r.title, icon: r.category.icon, color: r.category.color),
          SeverityBadge(severity: r.severity),
          if (r.escalated) Pill('Escalated', icon: Icons.priority_high_rounded, color: ue.error),
          if (r.isEmergency) Pill('Emergency', icon: Icons.emergency_outlined, color: ue.error),
          if (r.aiAssisted) Pill('AI-assisted ${((r.aiConfidence ?? 0) * 100).round()}%', icon: Icons.auto_awesome, color: ue.secondary),
          if (r.supporters > 0) Pill('${r.supporters} supporters', icon: Icons.people_alt_outlined),
          if (r.feedback != null) Pill('Citizen: ${r.feedback!.name}', icon: Icons.rate_review_outlined, color: r.feedback == CitizenFeedback.resolved ? ue.success : ue.warning),
        ]),
        const SizedBox(height: 14),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.description, style: AppText.body(context)),
            if (r.notes != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.notes!, style: AppText.bodySm(context))),
            const SizedBox(height: 8),
            KeyValueRow(icon: Icons.calendar_today_outlined, label: 'Date', value: Fmt.dateTime(r.createdAt)),
            KeyValueRow(
              icon: Icons.person_outline_rounded,
              label: 'Citizen',
              value: r.anonymous ? 'Anonymous (identity protected)' : (ac.can(Perm.viewCitizenIdentity) ? r.citizenName : '${Fmt.maskName(r.citizenName)} · identity restricted'),
            ),
            if (r.vehicleNumber != null) KeyValueRow(icon: Icons.directions_car_outlined, label: 'Vehicle', value: r.vehicleNumber!),
            KeyValueRow(icon: Icons.groups_2_outlined, label: 'Assigned team', value: team?.name ?? 'Unassigned'),
            KeyValueRow(icon: Icons.timer_outlined, label: 'SLA (${r.severity.label})', value: 'Due ${Fmt.dateTime(ac.dueAt(r))}', trailing: r.status.isOpen ? SlaChip(remaining: ac.remaining(r)) : null),
          ]),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: SizedBox(
            height: 150,
            child: UeMap(center: r.location.point, zoom: 16, interactive: false, pins: [
              MapPin(id: 'p', point: r.location.point, child: PulseMarker(color: r.category.color, icon: r.category.icon, pulse: true)),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text(r.location.address, style: AppText.caption(context)),
        const SizedBox(height: 18),
        Text(context.t('Priority'), style: AppText.label(context)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final s in Severity.values)
            ChoiceChip(
              label: Text(context.t(s.label)),
              selected: r.severity == s,
              selectedColor: s.color.withValues(alpha: 0.2),
              onSelected: ac.can(Perm.updateStatus)
                  ? (_) async {
                      final err = await ac.setPriority(r, s);
                      if (context.mounted) showToast(context, err ?? 'Priority set to ${s.label}', kind: err == null ? ToastKind.success : ToastKind.error);
                    }
                  : null,
            ),
        ]),
        const SizedBox(height: 18),
        Text(context.t('Actions'), style: AppText.label(context)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          action('verify', Icons.verified_outlined, 'Verify', Perm.verifyReport, enabled: r.status.canTransitionTo(ReportStatus.verified), v: ButtonVariant.primary),
          action('assign', Icons.groups_2_outlined, 'Assign Team', Perm.assignTeam, enabled: r.status.isOpen),
          action('status', Icons.sync_alt_rounded, 'Change Status', Perm.updateStatus, enabled: r.status.nextAllowed.isNotEmpty),
          action('resolve', Icons.task_alt_rounded, 'Mark Resolved', Perm.resolveReport, enabled: r.status.canTransitionTo(ReportStatus.resolved), v: ButtonVariant.success),
          action('info', Icons.help_outline_rounded, 'Request More Info', Perm.contactCitizen),
          action('note', Icons.sticky_note_2_outlined, 'Add Note', Perm.contactCitizen),
          action('reject', Icons.block_rounded, 'Reject', Perm.rejectReport, enabled: r.status.canTransitionTo(ReportStatus.rejected), v: ButtonVariant.danger),
        ]),
        if (!ac.can(Perm.resolveReport) || !ac.can(Perm.assignTeam))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${context.t('Some actions are disabled for your role')} (${ac.role.label}).', style: AppText.caption(context)),
          ),
        const SizedBox(height: 22),
        Text(context.t('Conversation'), style: AppText.label(context)),
        const SizedBox(height: 8),
        if (r.comments.isEmpty)
          Text(context.t('No messages yet.'), style: AppText.caption(context))
        else
          for (final c in r.comments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                color: c.fromMunicipality ? null : ue.surfaceAlt,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(c.fromMunicipality ? Icons.account_balance_rounded : Icons.person_outline_rounded, size: 14, color: ue.secondary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(c.fromMunicipality ? c.authorName : (r.anonymous ? 'Citizen' : Fmt.maskName(c.authorName)), style: AppText.caption(context).copyWith(fontWeight: FontWeight.w800))),
                    Text(Fmt.relative(c.at), style: AppText.caption(context)),
                  ]),
                  const SizedBox(height: 4),
                  Text(c.body, style: AppText.bodySm(context).copyWith(color: ue.text)),
                ]),
              ),
            ),
        const SizedBox(height: 18),
        Text(context.t('Status history & audit trail'), style: AppText.label(context)),
        const SizedBox(height: 8),
        if (_audit == null)
          const Shimmer(child: SkeletonBox(height: 80))
        else
          for (final h in r.history.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(h.status.bucket.icon, size: 16, color: h.status.bucket.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${h.status.label} · ${h.actor}${h.note != null ? ' — ${h.note}' : ''}', style: AppText.caption(context).copyWith(color: ue.text)),
                ),
                Text(Fmt.relative(h.at), style: AppText.caption(context)),
              ]),
            ),
        if (_audit != null && _audit!.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final a in _audit!.take(8))
            Text('• ${Fmt.dateTime(a.at)} — ${a.actor} (${a.actorRole.label}): ${a.action}', style: AppText.caption(context)),
        ],
      ]),
    );
  }
}
