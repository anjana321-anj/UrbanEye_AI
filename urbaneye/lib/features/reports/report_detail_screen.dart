import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../data/services/media_service.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../state/auth_controller.dart';
import '../../state/reports_controller.dart';
import '../../widgets/map_view.dart';
import '../../widgets/scene_image.dart';
import '../../widgets/ue_widgets.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;
  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  Report? _fetched;
  bool _error = false;
  int _photo = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final r = await context.read<ReportsController>().fetch(widget.reportId);
      if (mounted) setState(() => _fetched = r);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  String _teamName(Assignment? a) => a?.teamName ?? 'Municipal team';

  Future<void> _addEvidence(Report r) async {
    final choice = await showUeSheet<String>(context, builder: (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(ctx.t('Upload Additional Evidence'), style: AppText.h3(ctx)),
        const SizedBox(height: 14),
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(ctx.t('Take Photo')), onTap: () => Navigator.pop(ctx, 'camera')),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(ctx.t('Upload Photo')), onTap: () => Navigator.pop(ctx, 'gallery')),
      ]);
    });
    if (choice == null) return;
    try {
      final e = await MediaService.pickSinglePhoto(camera: choice == 'camera');
      if (e == null || !mounted) return;
      setState(() => _busy = true);
      await context.read<ReportsController>().addEvidence(r.id, e);
      if (mounted) showToast(context, 'Evidence uploaded', kind: ToastKind.success);
    } catch (_) {
      if (mounted) showToast(context, 'Upload failed. Please try again.', kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _message(Report r, {String title = 'Contact Municipality', String hint = 'Write a message…'}) async {
    final ctrl = TextEditingController();
    final sent = await showUeSheet<bool>(context, builder: (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(ctx.t(title), style: AppText.h3(ctx)),
        const SizedBox(height: 4),
        Text(ctx.t('Secure in-app message. Your phone number is never shared.'), style: AppText.caption(ctx)),
        const SizedBox(height: 14),
        TextField(controller: ctrl, autofocus: true, maxLines: 4, maxLength: 500, decoration: InputDecoration(hintText: ctx.t(hint))),
        const SizedBox(height: 10),
        UeButton(
          label: 'Send',
          icon: Icons.send_rounded,
          onPressed: () {
            if (ctrl.text.trim().isEmpty) return;
            Navigator.pop(ctx, true);
          },
        ),
      ]);
    });
    if (sent != true || !mounted) return;
    await context.read<ReportsController>().reply(r.id, Validators.sanitize(ctrl.text));
    if (mounted) showToast(context, 'Message sent to the municipality', kind: ToastKind.success);
  }

  Future<void> _feedback(Report r, CitizenFeedback f) async {
    if (f != CitizenFeedback.resolved) {
      final ok = await confirmDialog(
        context,
        title: 'Reopen Report',
        message: 'We\'ll reopen ${r.ticket} and send it back to the municipality with priority. Add a photo afterwards to help the team.',
        confirm: 'Reopen Report',
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      await context.read<ReportsController>().feedback(r.id, f);
      if (!mounted) return;
      showToast(
        context,
        f == CitizenFeedback.resolved ? 'Thanks for confirming! Report closed.' : 'Report reopened and sent back to the municipality',
        kind: f == CitizenFeedback.resolved ? ToastKind.success : ToastKind.warning,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<ReportsController>();
    final r = rc.byId(widget.reportId) ?? _fetched;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error
            ? ErrorState(kind: ErrorKind.server, onRetry: _load)
            : const Padding(padding: EdgeInsets.all(20), child: LoadingSkeleton(kind: SkeletonKind.detail)),
      );
    }
    final ue = context.ue;
    final mine = r.citizenId == context.read<AuthController>().user?.id;
    final photos = r.evidence;

    return Scaffold(
      body: Stack(children: [
        CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            backgroundColor: ue.background,
            leading: _circleBtn(Icons.arrow_back_rounded, 'Back', () => context.pop()),
            actions: [
              _circleBtn(Icons.share_outlined, 'Share', () => showToast(context, 'Public link copied: urbaneye.app/r/${r.ticket}', kind: ToastKind.success)),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                SizedBox.expand(
                  child: photos.isEmpty
                      ? SceneImage(category: r.category, seed: r.id.hashCode)
                      : PageView.builder(
                          itemCount: photos.length,
                          onPageChanged: (i) => setState(() => _photo = i),
                          itemBuilder: (_, i) => EvidenceImage(evidence: photos[i], category: r.category),
                        ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent, Colors.black.withValues(alpha: 0.45)],
                        stops: const [0, 0.4, 1],
                      ),
                    ),
                  ),
                ),
                if (photos.length > 1)
                  Positioned(
                    bottom: 14,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        photos.length,
                        (i) => AnimatedContainer(
                          duration: Motion.d(context, 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _photo ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: i == _photo ? 1 : 0.5), borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ),
                Positioned(left: 16, bottom: 14, child: StatusBadge(status: r.status)),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
            sliver: SliverList.list(children: [
              // Header
              Row(children: [
                Expanded(child: Semantics(header: true, child: Text('${context.t('Report')} #${r.ticket}', style: AppText.h2(context)))),
                if (r.category.asksSeverity) SeverityBadge(severity: r.severity),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill(r.title, icon: r.category.icon, color: r.category.color),
                if (r.escalated) Pill('Escalated to supervisor', icon: Icons.priority_high_rounded, color: ue.error),
                if (r.isEmergency) Pill('Critical', icon: Icons.emergency_outlined, color: ue.error),
                if (r.aiAssisted) Pill('AI-assisted', icon: Icons.auto_awesome, color: ue.secondary),
                if (r.supporters > 0) Pill('${r.supporters} ${context.t('supporters')}', icon: Icons.people_alt_outlined),
              ]),

              if (r.hasOpenQuestion && mine) ...[
                const SizedBox(height: 16),
                _QuestionBanner(question: r.comments.last, onReply: () => _message(r, title: 'Reply to municipality', hint: 'Your answer…'), onPhoto: () => _addEvidence(r)),
              ],

              if (r.status == ReportStatus.rejected) ...[
                const SizedBox(height: 16),
                _note(ue.textMuted, Icons.block_rounded, 'Report rejected', r.history.lastWhere((h) => h.status == ReportStatus.rejected, orElse: () => r.history.last).note ?? 'The municipality could not act on this report.'),
              ],

              // Before / After
              if (r.status == ReportStatus.resolved || r.status == ReportStatus.closed || r.afterEvidence.isNotEmpty) ...[
                const SizedBox(height: 22),
                _BeforeAfter(report: r),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(children: [
                    KeyValueRow(icon: Icons.task_alt_rounded, label: 'Resolution note', value: r.resolutionNote ?? '—'),
                    KeyValueRow(icon: Icons.event_available_outlined, label: 'Resolution date', value: r.resolvedAt == null ? '—' : Fmt.dateTime(r.resolvedAt!)),
                    KeyValueRow(icon: Icons.groups_2_outlined, label: 'Assigned team', value: _teamName(r.assignment)),
                  ]),
                ),
                if (mine && r.status == ReportStatus.resolved && r.feedback == null) ...[
                  const SizedBox(height: 12),
                  _FeedbackCard(busy: _busy, onAnswer: (f) => _feedback(r, f)),
                ],
                if (r.feedback != null) ...[
                  const SizedBox(height: 10),
                  _note(r.feedback == CitizenFeedback.resolved ? ue.success : ue.warning, Icons.rate_review_outlined, 'Your feedback',
                      switch (r.feedback!) {
                        CitizenFeedback.resolved => 'You confirmed this issue was resolved. Thank you!',
                        CitizenFeedback.partial => 'You said it was not fully resolved. The report was reopened.',
                        CitizenFeedback.remains => 'You said the issue remains. The report was reopened.',
                      }),
                ],
              ],

              const SizedBox(height: 22),
              const SectionHeader(title: 'Progress'),
              const SizedBox(height: 12),
              AppCard(padding: const EdgeInsets.all(18), child: _timeline(r)),

              const SizedBox(height: 22),
              const SectionHeader(title: 'Details'),
              const SizedBox(height: 12),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.description, style: AppText.body(context)),
                  if (r.notes != null) ...[const SizedBox(height: 8), Text(r.notes!, style: AppText.bodySm(context))],
                  const SizedBox(height: 10),
                  Divider(color: ue.border),
                  KeyValueRow(icon: r.category.icon, label: 'Category', value: '${context.t(r.category.label)}${r.subtype != null ? ' · ${context.t(r.subtype!)}' : ''}'),
                  KeyValueRow(icon: Icons.calendar_today_outlined, label: 'Date', value: Fmt.dateTime(r.createdAt)),
                  if (r.vehicleNumber != null) KeyValueRow(icon: Icons.directions_car_outlined, label: 'Vehicle number', value: r.vehicleNumber!),
                  if (r.assignment != null)
                    KeyValueRow(
                      icon: Icons.groups_2_outlined,
                      label: 'Assigned team',
                      value: '${_teamName(r.assignment)}${r.assignment!.eta != null && r.status.isOpen ? ' · ETA ${Fmt.time(r.assignment!.eta!)}' : ''}',
                    ),
                  KeyValueRow(icon: Icons.person_outline_rounded, label: 'Reported by', value: mine ? '${context.t('You')}${r.anonymous ? ' (${context.t('anonymous')})' : ''}' : r.publicCitizenName),
                ]),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
                    child: SizedBox(
                      height: 160,
                      child: UeMap(
                        center: r.location.point,
                        zoom: 16,
                        interactive: false,
                        pins: [MapPin(id: r.id, point: r.location.point, child: PulseMarker(color: r.status.bucket.color, icon: r.category.icon, pulse: r.status.isOpen))],
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.place_outlined, color: ue.secondary),
                    title: Text(r.location.address, style: AppText.label(context)),
                    subtitle: Text(r.location.point.toString(), style: AppText.caption(context)),
                  ),
                ]),
              ),

              const SizedBox(height: 22),
              SectionHeader(title: 'Municipality response', action: mine ? 'Message' : null, onAction: () => _message(r)),
              const SizedBox(height: 12),
              if (r.comments.isEmpty)
                AppCard(child: Text(context.t('No messages yet. You\'ll be notified when the municipality responds.'), style: AppText.bodySm(context)))
              else
                for (final c in r.comments) _Bubble(comment: c),

              if (mine && r.status.isOpen) ...[
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: UeButton(label: 'Add Information', icon: Icons.edit_note_rounded, variant: ButtonVariant.outline, height: 48, onPressed: () => _message(r, title: 'Add Information', hint: 'More details about the issue…'))),
                  const SizedBox(width: 10),
                  Expanded(child: UeButton(label: 'Add Evidence', icon: Icons.add_photo_alternate_outlined, variant: ButtonVariant.outline, height: 48, loading: _busy, onPressed: () => _addEvidence(r))),
                ]),
                const SizedBox(height: 10),
                UeButton(label: 'Contact Municipality', icon: Icons.forum_outlined, variant: ButtonVariant.secondary, onPressed: () => _message(r)),
              ],
              if (!mine && r.status.isOpen) ...[
                const SizedBox(height: 18),
                UeButton(
                  label: 'I see this too — Support',
                  icon: Icons.thumb_up_alt_outlined,
                  variant: ButtonVariant.secondary,
                  onPressed: () async {
                    await context.read<ReportsController>().support(r.id);
                    if (context.mounted) showToast(context, 'Thanks! Your support was added.', kind: ToastKind.success);
                  },
                ),
              ],
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _circleBtn(IconData icon, String tip, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Colors.black.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          child: IconButton(tooltip: context.t(tip), icon: Icon(icon, color: Colors.white, size: 20), onPressed: onTap),
        ),
      );

  Widget _note(Color color, IconData icon, String title, String body) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadii.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.t(title), style: AppText.label(context)),
              const SizedBox(height: 2),
              Text(context.t(body), style: AppText.bodySm(context)),
            ]),
          ),
        ]),
      );

  Widget _timeline(Report r) {
    DateTime? at(Set<ReportStatus> s) => r.history.where((h) => s.contains(h.status)).map((h) => h.at).firstOrNull;
    String? sub(Set<ReportStatus> s) {
      final d = at(s);
      return d == null ? null : Fmt.dateTime(d);
    }

    final rejected = r.status == ReportStatus.rejected;
    final steps = [
      TimelineStep('Reported', subtitle: sub({ReportStatus.submitted})),
      TimelineStep(rejected ? 'Rejected' : 'Verified', subtitle: sub(rejected ? {ReportStatus.rejected} : {ReportStatus.verified})),
      TimelineStep('Assigned', subtitle: sub({ReportStatus.assigned})),
      TimelineStep('Team On The Way', subtitle: sub({ReportStatus.onTheWay, ReportStatus.inProgress})),
      TimelineStep('Resolved', subtitle: sub({ReportStatus.resolved})),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (r.status == ReportStatus.reopened)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Pill('Reopened — back in review', icon: Icons.replay_rounded, color: context.ue.warning),
        ),
      ReportTimeline(steps: steps, current: rejected ? 1 : r.status.citizenStep, failed: rejected),
    ]);
  }
}

class _QuestionBanner extends StatelessWidget {
  final Comment question;
  final VoidCallback onReply;
  final VoidCallback onPhoto;
  const _QuestionBanner({required this.question, required this.onReply, required this.onPhoto});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return FadeSlideIn(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ue.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: ue.warning.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.help_outline_rounded, color: ue.warning),
            const SizedBox(width: 8),
            Expanded(child: Text(context.t('Municipality requested more information'), style: AppText.label(context))),
          ]),
          const SizedBox(height: 8),
          Text('"${question.body}"', style: AppText.bodySm(context).copyWith(color: ue.text)),
          const SizedBox(height: 4),
          Text('— ${question.authorName}, ${Fmt.relative(question.at)}', style: AppText.caption(context)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: UeButton(label: 'Reply', icon: Icons.reply_rounded, height: 44, onPressed: onReply)),
            const SizedBox(width: 10),
            Expanded(child: UeButton(label: 'Add Photo', icon: Icons.add_a_photo_outlined, variant: ButtonVariant.outline, height: 44, onPressed: onPhoto)),
          ]),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Comment comment;
  const _Bubble({required this.comment});
  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final muni = comment.fromMunicipality;
    return Align(
      alignment: muni ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: muni ? ue.surface : (context.isDark ? AppColors.electric.withValues(alpha: 0.25) : AppColors.navy),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(muni ? 4 : 16),
              bottomRight: Radius.circular(muni ? 16 : 4),
            ),
            border: muni ? Border.all(color: ue.border) : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (muni) ...[Icon(Icons.account_balance_rounded, size: 13, color: ue.secondary), const SizedBox(width: 4)],
              Flexible(
                child: Text(comment.authorName,
                    style: AppText.caption(context).copyWith(fontWeight: FontWeight.w800, color: muni ? ue.secondary : Colors.white70)),
              ),
              if (comment.isQuestion) ...[const SizedBox(width: 6), Pill('Question', color: ue.warning)],
            ]),
            const SizedBox(height: 4),
            Text(comment.body, style: AppText.bodySm(context).copyWith(color: muni ? ue.text : Colors.white)),
            const SizedBox(height: 4),
            Text(Fmt.relative(comment.at), style: AppText.caption(context).copyWith(fontSize: 10.5, color: muni ? ue.textSubtle : Colors.white60)),
          ]),
        ),
      ),
    );
  }
}

/// Before / After comparison with a draggable divider.
class _BeforeAfter extends StatefulWidget {
  final Report report;
  const _BeforeAfter({required this.report});
  @override
  State<_BeforeAfter> createState() => _BeforeAfterState();
}

class _BeforeAfterState extends State<_BeforeAfter> {
  double _split = 0.5;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final before = r.evidence.firstOrNull;
    final after = r.afterEvidence.firstOrNull ?? Evidence(id: 'a', kind: EvidenceKind.photo, sceneSeed: 1, capturedAt: DateTime.now(), isAfter: true);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Before / After'),
      const SizedBox(height: 10),
      Semantics(
        label: 'Before and after comparison. Drag to compare.',
        slider: true,
        value: '${(_split * 100).round()}%',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: SizedBox(
            height: 220,
            child: LayoutBuilder(builder: (context, c) {
              return GestureDetector(
                onHorizontalDragUpdate: (d) => setState(() => _split = (d.localPosition.dx / c.maxWidth).clamp(0.05, 0.95)),
                onTapDown: (d) => setState(() => _split = (d.localPosition.dx / c.maxWidth).clamp(0.05, 0.95)),
                child: Stack(fit: StackFit.expand, children: [
                  EvidenceImage(evidence: after, category: r.category),
                  ClipRect(
                    clipper: _LeftClipper(_split),
                    child: EvidenceImage(evidence: before, category: r.category),
                  ),
                  Positioned(
                    left: c.maxWidth * _split - 1.5,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 3, color: Colors.white),
                  ),
                  Positioned(
                    left: c.maxWidth * _split - 18,
                    top: 220 / 2 - 18,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppShadows.glow(Colors.black)),
                      child: const Icon(Icons.compare_arrows_rounded, color: AppColors.navy, size: 20),
                    ),
                  ),
                  Positioned(left: 10, top: 10, child: _tag('BEFORE', AppColors.red)),
                  Positioned(right: 10, top: 10, child: _tag('AFTER', AppColors.emerald)),
                ]),
              );
            }),
          ),
        ),
      ),
    ]);
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5, letterSpacing: 0.8)),
      );
}

class _LeftClipper extends CustomClipper<Rect> {
  final double f;
  _LeftClipper(this.f);
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * f, size.height);
  @override
  bool shouldReclip(covariant _LeftClipper old) => old.f != f;
}

class _FeedbackCard extends StatelessWidget {
  final bool busy;
  final ValueChanged<CitizenFeedback> onAnswer;
  const _FeedbackCard({required this.busy, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    Widget opt(CitizenFeedback f, IconData icon, String label, Color c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PressableScale(
            onTap: busy ? null : () => onAnswer(f),
            semanticLabel: context.t(label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: c.withValues(alpha: 0.5)),
                color: c.withValues(alpha: 0.06),
              ),
              child: Row(children: [
                Icon(icon, color: c),
                const SizedBox(width: 12),
                Expanded(child: Text(context.t(label), style: AppText.label(context))),
                Icon(Icons.chevron_right_rounded, color: ue.textSubtle),
              ]),
            ),
          ),
        );
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.t('Was this issue actually resolved?'), style: AppText.title(context)),
        const SizedBox(height: 4),
        Text(context.t('Your answer goes straight back to the municipality.'), style: AppText.caption(context)),
        const SizedBox(height: 14),
        opt(CitizenFeedback.resolved, Icons.check_circle_rounded, 'Yes, resolved', ue.success),
        opt(CitizenFeedback.partial, Icons.timelapse_rounded, 'Not fully resolved', ue.warning),
        opt(CitizenFeedback.remains, Icons.report_problem_outlined, 'Issue remains', ue.error),
      ]),
    );
  }
}
