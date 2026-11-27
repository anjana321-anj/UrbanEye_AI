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
import '../../domain/repositories/repositories.dart';
import '../../state/reports_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/map_view.dart';
import '../../widgets/scene_image.dart';
import '../../widgets/ue_widgets.dart';
import '../citizen/citizen_shell.dart';
import '../reports/report_detail_screen.dart';
import 'report_components.dart';

/// THE universal report flow. Every category uses this same component:
/// Capture Evidence → Confirm Location → Add Details → Review → Submit.
class ReportFlowScreen extends StatefulWidget {
  final ReportCategory? category;
  final String? subtype;
  final ReportDraft? draft;
  final List<Evidence>? initialEvidence;
  final AiReportAnalysis? initialAnalysis;
  final bool startWithCamera;

  const ReportFlowScreen({
    super.key,
    this.category,
    this.subtype,
    this.draft,
    this.initialEvidence,
    this.initialAnalysis,
    this.startWithCamera = false,
  });

  @override
  State<ReportFlowScreen> createState() => _ReportFlowScreenState();
}

enum _AiState { idle, analyzing, ready, failed, applied, dismissed }

class _ReportFlowScreenState extends State<ReportFlowScreen> {
  static const _stepTitles = ['Capture Evidence', 'Confirm Location', 'Add Details', 'Review'];

  late ReportDraft d;
  int _step = 0;
  bool _forward = true;
  final _desc = TextEditingController();
  final _vehicle = TextEditingController();
  final _notes = TextEditingController();
  final _detailsForm = GlobalKey<FormState>();

  _AiState _ai = _AiState.idle;
  AiReportAnalysis? _analysis;

  // Review / duplicates
  bool _checkingDupes = false;
  List<NearbyMatch> _dupes = [];
  bool _dupesDismissed = false;

  // Submission
  bool _submitting = false;
  double _progress = 0;
  Report? _submitted;
  bool _queuedOffline = false;
  Report? _supported;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsController>();
    d = widget.draft ??
        ReportDraft(
          localId: 'draft-${DateTime.now().microsecondsSinceEpoch}',
          category: widget.category,
          subtype: widget.subtype,
          severity: widget.category?.defaultSeverity ?? Severity.medium,
          anonymous: s.anonymousByDefault,
          evidence: widget.initialEvidence,
        );
    _desc.text = d.description;
    _vehicle.text = d.vehicleNumber ?? '';
    _notes.text = d.notes ?? '';
    if (widget.initialAnalysis != null) {
      _analysis = widget.initialAnalysis;
      _ai = _AiState.ready;
      _applyAi(silent: true);
    }
  }

  @override
  void dispose() {
    _desc.dispose();
    _vehicle.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ AI ----

  Future<void> _runAi() async {
    final photo = d.evidence.where((e) => e.bytes != null && e.kind == EvidenceKind.photo).firstOrNull;
    if (photo == null) return;
    setState(() => _ai = _AiState.analyzing);
    try {
      final a = await Services.I.ai.analyzeReportImage(photo.bytes!, hint: widget.category);
      if (!mounted) return;
      setState(() {
        _analysis = a;
        _ai = _AiState.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _ai = _AiState.failed);
    }
  }

  /// Only ever applied after an explicit tap. Everything stays editable.
  void _applyAi({bool silent = false}) {
    final a = _analysis;
    if (a == null) return;
    void apply() {
      d.category ??= a.category;
      d.subtype ??= a.subtype;
      d.severity = a.suggestedSeverity;
      if (_desc.text.trim().isEmpty) _desc.text = a.suggestedDescription;
      d.aiAssisted = true;
      d.aiConfidence = a.confidence;
      _ai = _AiState.applied;
    }

    if (silent) {
      apply();
      return;
    }
    setState(apply);
    Haptics.light();
    showToast(context, 'AI suggestions applied — you can edit everything', kind: ToastKind.success);
  }

  void _onEvidence(List<Evidence> ev) {
    final hadPhoto = d.evidence.any((e) => e.bytes != null);
    setState(() => d.evidence = ev);
    final hasPhoto = ev.any((e) => e.bytes != null && e.kind == EvidenceKind.photo);
    if (!hadPhoto && hasPhoto && (_ai == _AiState.idle || _ai == _AiState.dismissed)) _runAi();
    if (!hasPhoto && _ai != _AiState.applied) setState(() => _ai = _AiState.idle);
  }

  // ---------------------------------------------------------- Navigation ----

  bool get _canNext => switch (_step) {
        0 => true,
        1 => d.location != null,
        2 => true,
        _ => !_submitting,
      };

  void _syncFields() {
    d.description = Validators.sanitize(_desc.text);
    d.vehicleNumber = _vehicle.text.trim().isEmpty ? null : _vehicle.text.trim().toUpperCase();
    d.notes = _notes.text.trim().isEmpty ? null : Validators.sanitize(_notes.text);
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_step == 2) {
      _syncFields();
      if (d.category == null) {
        showToast(context, 'Please choose a category', kind: ToastKind.warning);
        return;
      }
      if (!(_detailsForm.currentState?.validate() ?? true)) return;
    }
    if (_step == 3) return _submit();
    setState(() {
      _forward = true;
      _step++;
    });
    Haptics.tap();
    if (_step == 3) _checkDuplicates();
  }

  void _back() {
    if (_step == 0) {
      _confirmExit();
      return;
    }
    _syncFields();
    setState(() {
      _forward = false;
      _step--;
    });
  }

  void _goTo(int step) {
    _syncFields();
    setState(() {
      _forward = step > _step;
      _step = step;
    });
  }

  bool get _hasContent => d.evidence.isNotEmpty || _desc.text.trim().isNotEmpty || d.location != null;

  Future<void> _confirmExit() async {
    if (!_hasContent || _submitted != null) {
      context.pop();
      return;
    }
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('Leave this report?'), style: AppText.h3(context)),
        content: Text(context.t('Save it as a draft to finish later, or discard it.'), style: AppText.bodySm(context)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: Text(context.t('Discard'), style: TextStyle(color: context.ue.error))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(context.t('Save as Draft'))),
        ],
      ),
    );
    if (!mounted) return;
    if (r == 'save') _saveDraft(close: true);
    if (r == 'discard') context.pop();
  }

  void _saveDraft({bool close = false}) {
    _syncFields();
    context.read<ReportsController>().saveDraft(d);
    showToast(context, 'Saved as draft', kind: ToastKind.success);
    if (close) context.pop();
  }

  // ---------------------------------------------------------- Duplicates ----

  Future<void> _checkDuplicates() async {
    final c = d.category, l = d.location;
    if (c == null || l == null || _dupesDismissed) return;
    setState(() => _checkingDupes = true);
    final r = await context.read<ReportsController>().duplicates(c, l.point);
    if (mounted) {
      setState(() {
        _dupes = r;
        _checkingDupes = false;
      });
    }
  }

  Future<void> _supportExisting(Report r) async {
    setState(() => _submitting = true);
    try {
      await context.read<ReportsController>().support(r.id);
      context.read<ReportsController>().deleteDraft(d.localId);
      if (mounted) {
        setState(() {
          _supported = r;
          _submitting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        showToast(context, 'Could not add your support. Try again.', kind: ToastKind.error);
      }
    }
  }

  // -------------------------------------------------------------- Submit ----

  Future<void> _submit() async {
    _syncFields();
    if (!d.isComplete) {
      showToast(context, 'Please complete the location and description', kind: ToastKind.warning);
      return;
    }
    setState(() {
      _submitting = true;
      _progress = 0;
    });
    try {
      final r = await context.read<ReportsController>().submit(d, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() {
        _submitted = r;
        _queuedOffline = r == null;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      context.read<ReportsController>().saveDraft(d);
      showToast(context, 'Upload failed — saved as draft. We\'ll retry when connection improves.', kind: ToastKind.error);
    }
  }

  // --------------------------------------------------------------- Build ----

  @override
  Widget build(BuildContext context) {
    if (_submitted != null || _queuedOffline || _supported != null) return _successView();
    final ue = context.ue;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: context.t('Back'), icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.t(d.category?.label ?? 'New Report'), style: AppText.title(context)),
            Text('${context.t('Step')} ${_step + 1} ${context.t('of')} 4 · ${context.t(_stepTitles[_step])}', style: AppText.caption(context)),
          ]),
          actions: [
            if (_hasContent)
              TextButton(onPressed: () => _saveDraft(close: true), child: Text(context.t('Save draft'))),
          ],
          bottom: PreferredSize(preferredSize: const Size.fromHeight(10), child: _StepBar(step: _step)),
        ),
        body: Stack(children: [
          AnimatedSwitcher(
            duration: Motion.d(context, 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, a) {
              final incoming = child.key == ValueKey(_step);
              final dx = (_forward ? 1 : -1) * (incoming ? 0.08 : -0.08);
              return FadeTransition(
                opacity: a,
                child: SlideTransition(position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(a), child: child),
              );
            },
            child: KeyedSubtree(key: ValueKey(_step), child: _stepBody()),
          ),
          if (_submitting) _UploadOverlay(progress: _progress, offline: !context.read<ReportsController>().online),
        ]),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            decoration: BoxDecoration(color: ue.background, border: Border(top: BorderSide(color: ue.border))),
            child: Row(children: [
              if (_step == 0 && d.evidence.isEmpty)
                Expanded(
                  child: UeButton(label: 'Skip photo', variant: ButtonVariant.ghost, onPressed: _next),
                ),
              if (_step == 0 && d.evidence.isEmpty) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: UeButton(
                  label: _step == 3 ? 'Submit Report' : 'Continue',
                  icon: _step == 3 ? Icons.send_rounded : Icons.arrow_forward_rounded,
                  trailingIcon: true,
                  loading: _submitting,
                  onPressed: _canNext && (_step != 0 || d.evidence.isNotEmpty) ? _next : null,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _stepBody() => switch (_step) {
        0 => _evidenceStep(),
        1 => _locationStep(),
        2 => _detailsStep(),
        _ => _reviewStep(),
      };

  Widget _stepHeader(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text(context.t(title), style: AppText.h2(context))),
          const SizedBox(height: 4),
          Text(context.t(subtitle), style: AppText.bodySm(context)),
        ]),
      );

  // Step 1 ------------------------------------------------------------------
  Widget _evidenceStep() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      _stepHeader('Capture Evidence', 'Take or upload up to 5 photos. Our AI can suggest the category and details.'),
      PhotoUploader(evidence: d.evidence, onChanged: _onEvidence),
      const SizedBox(height: 16),
      _aiPanel(),
    ]);
  }

  Widget _aiPanel() {
    final ue = context.ue;
    switch (_ai) {
      case _AiState.idle:
      case _AiState.dismissed:
        return const SizedBox.shrink();
      case _AiState.analyzing:
        return AppCard(
          child: Row(children: [
            const _AiOrb(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.t('Analyzing your photo…'), style: AppText.title(context)),
                const SizedBox(height: 4),
                Text(context.t('Detecting issue type, severity and evidence quality'), style: AppText.caption(context)),
                const SizedBox(height: 10),
                const Shimmer(child: SkeletonBox(height: 8)),
              ]),
            ),
          ]),
        );
      case _AiState.failed:
        return AppCard(
          child: ErrorState(
            kind: ErrorKind.aiFailed,
            onRetry: _runAi,
            secondaryLabel: 'Continue manually',
            onSecondary: () => setState(() => _ai = _AiState.dismissed),
          ),
        );
      case _AiState.ready:
      case _AiState.applied:
        final a = _analysis!;
        final applied = _ai == _AiState.applied;
        return FadeSlideIn(
          child: AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.auto_awesome, color: ue.secondary, size: 20),
                const SizedBox(width: 8),
                Text(context.t('AI Smart Assistant'), style: AppText.title(context)),
                const Spacer(),
                if (applied) Pill('Applied', icon: Icons.check_rounded, color: ue.success),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                IconTile(icon: a.category.icon, color: a.category.color, size: 52, iconSize: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.t('Detected'), style: AppText.caption(context)),
                    Text(context.t(a.subtype ?? a.category.label), style: AppText.h3(context)),
                  ]),
                ),
                ProgressRing(
                  value: a.confidence,
                  size: 58,
                  stroke: 6,
                  color: ue.success,
                  center: Text('${(a.confidence * 100).round()}%', style: AppText.label(context).copyWith(fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 14),
              _aiRow(Icons.speed_rounded, 'Suggested severity', a.suggestedSeverity.label, a.suggestedSeverity.color),
              _aiRow(Icons.photo_size_select_actual_outlined, 'Evidence quality', '${(a.evidenceQuality * 100).round()}% · ${a.qualityNote}', null),
              _aiRow(Icons.copy_all_rounded, 'Duplicate likelihood',
                  a.duplicateLikelihood > 0.35 ? 'Possible — we\'ll check nearby reports' : 'Low', a.duplicateLikelihood > 0.35 ? ue.warning : ue.success),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ue.surfaceAlt, borderRadius: BorderRadius.circular(AppRadii.md)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.t('Suggested description'), style: AppText.caption(context)),
                  const SizedBox(height: 4),
                  Text('"${a.suggestedDescription}"', style: AppText.bodySm(context).copyWith(color: ue.text, fontStyle: FontStyle.italic)),
                ]),
              ),
              const SizedBox(height: 14),
              if (!applied)
                Row(children: [
                  Expanded(
                    child: UeButton(label: 'Ignore', variant: ButtonVariant.outline, height: 46, onPressed: () => setState(() => _ai = _AiState.dismissed)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: UeButton(label: 'Use suggestions', icon: Icons.auto_awesome, height: 46, onPressed: () => _applyAi())),
                ])
              else
                Text(context.t('You can review and edit every suggestion in the next steps. Nothing is sent without your confirmation.'),
                    style: AppText.caption(context)),
            ]),
          ),
        );
    }
  }

  Widget _aiRow(IconData icon, String label, String value, Color? color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 17, color: context.ue.textSubtle),
          const SizedBox(width: 8),
          Text(context.t(label), style: AppText.caption(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.t(value),
                textAlign: TextAlign.right,
                style: AppText.label(context).copyWith(fontSize: 12.5, color: color ?? context.ue.text)),
          ),
        ]),
      );

  // Step 2 ------------------------------------------------------------------
  Widget _locationStep() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      _stepHeader('Confirm Location', 'Drag the map to place the pin exactly where the issue is.'),
      LocationPicker(initial: d.location, onChanged: (p) => setState(() => d.location = p)),
    ]);
  }

  // Step 3 ------------------------------------------------------------------
  Widget _detailsStep() {
    final ue = context.ue;
    final cat = d.category;
    return Form(
      key: _detailsForm,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        _stepHeader('Add Details', 'A short description helps the team arrive prepared.'),
        LabeledField(
          label: 'Category',
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in ReportCategory.values)
              ChoiceChip(
                avatar: Icon(c.icon, size: 16, color: d.category == c ? Colors.white : c.color),
                label: Text(context.t(c.shortLabel)),
                selected: d.category == c,
                showCheckmark: false,
                selectedColor: c.color,
                labelStyle: TextStyle(color: d.category == c ? Colors.white : ue.text, fontWeight: FontWeight.w700),
                onSelected: (_) => setState(() {
                  d.category = c;
                  d.subtype = null;
                  if (!d.aiAssisted) d.severity = c.defaultSeverity;
                }),
              ),
          ]),
        ),
        if (cat != null && cat.subtypes.length > 1)
          LabeledField(
            label: 'Problem type',
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in cat.subtypes)
                ChoiceChip(
                  label: Text(context.t(s)),
                  selected: d.subtype == s,
                  onSelected: (_) => setState(() => d.subtype = d.subtype == s ? null : s),
                ),
            ]),
          ),
        LabeledField(
          label: 'Description',
          child: TextFormField(
            controller: _desc,
            minLines: 3,
            maxLines: 6,
            maxLength: 600,
            validator: Validators.description,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: context.t('What is the problem? How long has it been there?'),
              suffixIcon: _analysis == null
                  ? null
                  : IconButton(
                      tooltip: context.t('Insert AI suggestion'),
                      icon: Icon(Icons.auto_awesome, color: ue.secondary),
                      onPressed: () => setState(() => _desc.text = _analysis!.suggestedDescription),
                    ),
            ),
          ),
        ),
        if (cat == null || cat.asksSeverity)
          LabeledField(
            label: 'Severity',
            child: SeveritySelector(
              value: d.severity,
              aiSuggested: _analysis?.suggestedSeverity,
              onChanged: (s) => setState(() => d.severity = s),
            ),
          ),
        if (d.severity == Severity.critical) _EmergencyGuidance(isEmergency: d.isEmergency, onChanged: (v) => setState(() => d.isEmergency = v)),
        if (cat?.asksVehicleNumber ?? false)
          LabeledField(
            label: 'Vehicle number (optional)',
            hint: 'Only the plate — no photos of people needed',
            child: TextFormField(
              controller: _vehicle,
              validator: Validators.vehicle,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'BA 2 CHA 4521', prefixIcon: Icon(Icons.directions_car_outlined)),
            ),
          ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(context.t('Additional notes (optional)'), style: AppText.label(context)),
            children: [
              TextFormField(
                controller: _notes,
                maxLines: 3,
                maxLength: 300,
                decoration: InputDecoration(hintText: context.t('Landmarks, access info, best time to visit…')),
              ),
            ],
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: d.anonymous,
            onChanged: (v) => setState(() => d.anonymous = v),
            secondary: Icon(Icons.visibility_off_outlined, color: ue.secondary),
            title: Text(context.t('Report anonymously'), style: AppText.label(context)),
            subtitle: Text(context.t('Your name is hidden from public views. Authorised staff can still contact you in-app.'),
                style: AppText.caption(context)),
          ),
        ),
      ]),
    );
  }

  // Step 4 ------------------------------------------------------------------
  Widget _reviewStep() {
    final ue = context.ue;
    final cat = d.category ?? ReportCategory.other;
    return ListView(padding: const EdgeInsets.all(20), children: [
      _stepHeader('Review', 'Check everything before sending it to the municipality.'),
      if (_checkingDupes)
        const Padding(padding: EdgeInsets.only(bottom: 12), child: Shimmer(child: SkeletonBox(height: 90, radius: 20)))
      else if (_dupes.isNotEmpty && !_dupesDismissed)
        _DuplicateCard(
          match: _dupes.first,
          onSupport: () => _supportExisting(_dupes.first.report),
          onSubmitNew: () => setState(() => _dupesDismissed = true),
        ),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
            child: SizedBox(
              height: 190,
              child: d.evidence.isEmpty
                  ? Container(
                      color: ue.surfaceAlt,
                      child: Center(child: Text(context.t('No photo attached'), style: AppText.caption(context))),
                    )
                  : PageView(children: [for (final e in d.evidence) EvidenceImage(evidence: e, category: cat)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconTile(icon: cat.icon, color: cat.color, size: 40, iconSize: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.t(cat.label), style: AppText.title(context)),
                    if (d.subtype != null) Text(context.t(d.subtype!), style: AppText.caption(context)),
                  ]),
                ),
                if (cat.asksSeverity) SeverityBadge(severity: d.severity),
              ]),
              const SizedBox(height: 12),
              Text(d.description, style: AppText.body(context)),
              if (d.vehicleNumber != null) ...[
                const SizedBox(height: 8),
                Pill('Vehicle ${d.vehicleNumber}', icon: Icons.directions_car_outlined),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill('${d.evidence.length} evidence', icon: Icons.photo_library_outlined),
                if (d.aiAssisted) Pill('AI-assisted', icon: Icons.auto_awesome, color: ue.secondary),
                if (d.anonymous) Pill('Anonymous', icon: Icons.visibility_off_outlined),
                if (d.isEmergency) Pill('Emergency escalation', icon: Icons.emergency_outlined, color: ue.error),
              ]),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      if (d.location != null)
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
              child: SizedBox(
                height: 130,
                child: UeMap(
                  center: d.location!.point,
                  zoom: 16,
                  interactive: false,
                  pins: [MapPin(id: 'p', point: d.location!.point, child: PulseMarker(color: cat.color, icon: cat.icon, pulse: true))],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(children: [
                Expanded(child: Text(d.location!.address, style: AppText.label(context))),
                TextButton(onPressed: () => _goTo(1), child: Text(context.t('Edit'))),
              ]),
            ),
          ]),
        ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: UeButton(label: 'Edit photos', variant: ButtonVariant.outline, height: 46, onPressed: () => _goTo(0))),
        const SizedBox(width: 10),
        Expanded(child: UeButton(label: 'Edit details', variant: ButtonVariant.outline, height: 46, onPressed: () => _goTo(2))),
      ]),
      const SizedBox(height: 14),
      Text(
        context.t('By submitting, you confirm this report is accurate. Photos are shared only with municipal staff handling the issue.'),
        style: AppText.caption(context),
      ),
    ]);
  }

  // ------------------------------------------------------------- Success ----

  Widget _successView() {
    final ue = context.ue;
    final ticket = _submitted?.ticket ?? _supported?.ticket;
    final title = _supported != null
        ? 'Thanks — your support was added'
        : _queuedOffline
            ? 'Saved — will send when online'
            : 'Report Submitted Successfully';
    final body = _supported != null
        ? 'You confirmed an existing report. The team now knows more citizens are affected.'
        : _queuedOffline
            ? 'You\'re offline. Your report, photos and location are stored safely and will upload automatically.'
            : 'The municipality has received your report. You\'ll be notified at every step.';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Spacer(),
                SuccessCheck(size: 150, color: _queuedOffline ? ue.warning : null),
                const SizedBox(height: 20),
                FadeSlideIn(index: 3, child: Text(context.t(title), textAlign: TextAlign.center, style: AppText.h2(context))),
                const SizedBox(height: 10),
                FadeSlideIn(index: 4, child: Text(context.t(body), textAlign: TextAlign.center, style: AppText.bodySm(context))),
                const SizedBox(height: 22),
                if (ticket != null)
                  FadeSlideIn(
                    index: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      decoration: BoxDecoration(
                        color: ue.surface,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(color: ue.border),
                      ),
                      child: Column(children: [
                        Text(context.t('TICKET'), style: AppText.overline(context)),
                        const SizedBox(height: 4),
                        SelectableText(ticket, style: AppText.h1(context).copyWith(letterSpacing: 1.5, fontSize: 28)),
                      ]),
                    ),
                  ),
                const Spacer(),
                if (ticket != null)
                  UeButton(
                    label: 'Track Report',
                    icon: Icons.timeline_rounded,
                    onPressed: () => context.replace(ReportDetailScreen(reportId: (_submitted ?? _supported)!.id)),
                  ),
                const SizedBox(height: 10),
                UeButton(
                  label: 'Back to Home',
                  variant: ButtonVariant.outline,
                  onPressed: () {
                    context.read<ShellNav>().go(0);
                    context.popToRoot();
                  },
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  final int step;
  const _StepBar({required this.step});
  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Semantics(
        label: 'Step ${step + 1} of 4',
        child: Row(children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 4,
                decoration: BoxDecoration(color: ue.border, borderRadius: BorderRadius.circular(4)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedFractionallySizedBox(
                    duration: Motion.d(context, 450),
                    curve: Curves.easeOutCubic,
                    widthFactor: i <= step ? 1 : 0,
                    child: Container(decoration: BoxDecoration(color: i < step ? ue.success : ue.secondary, borderRadius: BorderRadius.circular(4))),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _AiOrb extends StatefulWidget {
  const _AiOrb();
  @override
  State<_AiOrb> createState() => _AiOrbState();
}

class _AiOrbState extends State<_AiOrb> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: [AppColors.electric, AppColors.emerald, AppColors.sky, AppColors.electric]),
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: context.ue.surface),
          child: Icon(Icons.auto_awesome, color: context.ue.secondary),
        ),
      ),
    );
  }
}

class _DuplicateCard extends StatelessWidget {
  final NearbyMatch match;
  final VoidCallback onSupport;
  final VoidCallback onSubmitNew;
  const _DuplicateCard({required this.match, required this.onSupport, required this.onSubmitNew});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final r = match.report;
    return FadeSlideIn(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ue.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: ue.warning.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.content_copy_rounded, color: ue.warning, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(context.t('Possible duplicate'), style: AppText.title(context))),
          ]),
          const SizedBox(height: 8),
          Text(
            context.t('An issue similar to this has already been reported {d} away.', {'d': Fmt.distance(match.distanceMeters)}),
            style: AppText.bodySm(context).copyWith(color: ue.text),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 54, height: 54, child: EvidenceImage(evidence: r.evidence.firstOrNull, category: r.category)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.ticket, style: AppText.label(context)),
                  Text('${Fmt.distance(match.distanceMeters)} · ${Fmt.relative(r.createdAt)} · ${r.supporters} ${context.t('supporters')}',
                      style: AppText.caption(context)),
                ]),
              ),
              StatusBadge(status: r.status, compact: true),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: UeButton(label: 'Submit New Report', variant: ButtonVariant.outline, height: 46, onPressed: onSubmitNew)),
            const SizedBox(width: 10),
            Expanded(child: UeButton(label: 'Support Existing Report', height: 46, onPressed: onSupport)),
          ]),
        ]),
      ),
    );
  }
}

class _EmergencyGuidance extends StatelessWidget {
  final bool isEmergency;
  final ValueChanged<bool> onChanged;
  const _EmergencyGuidance({required this.isEmergency, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return FadeSlideIn(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: ue.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: ue.error.withValues(alpha: 0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.emergency_rounded, color: ue.error),
            const SizedBox(width: 8),
            Expanded(child: Text(context.t('Critical issue'), style: AppText.title(context).copyWith(color: ue.error))),
          ]),
          const SizedBox(height: 6),
          Text(
            context.t('If anyone is in immediate danger, call 100 (Police), 101 (Fire) or 102 (Ambulance) first. UrbanEye is not a replacement for emergency services.'),
            style: AppText.bodySm(context).copyWith(color: ue.text),
          ),
          const SizedBox(height: 4),
          Text(context.t('• Keep a safe distance  • Warn others nearby  • Don\'t touch damaged electrical equipment'), style: AppText.caption(context)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: isEmergency,
            onChanged: onChanged,
            title: Text(context.t('Request municipal emergency escalation'), style: AppText.label(context)),
            subtitle: Text(context.t('Sends this report straight to the duty supervisor (4-hour response target).'), style: AppText.caption(context)),
          ),
        ]),
      ),
    );
  }
}

class _UploadOverlay extends StatelessWidget {
  final double progress;
  final bool offline;
  const _UploadOverlay({required this.progress, required this.offline});
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: context.ue.background.withValues(alpha: 0.85),
        alignment: Alignment.center,
        child: Semantics(
          liveRegion: true,
          label: 'Uploading ${(progress * 100).round()} percent',
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ProgressRing(
              value: progress,
              size: 110,
              stroke: 9,
              color: context.ue.secondary,
              center: Text('${(progress * 100).round()}%', style: AppText.h3(context)),
            ),
            const SizedBox(height: 16),
            Text(context.t(offline ? 'Saving securely…' : 'Uploading evidence securely…'), style: AppText.title(context)),
            const SizedBox(height: 4),
            Text(context.t('Compressing photos for faster upload'), style: AppText.caption(context)),
          ]),
        ),
      ),
    );
  }
}
