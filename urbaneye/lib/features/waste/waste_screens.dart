import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/di/service_locator.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../data/services/media_service.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../../state/auth_controller.dart';
import '../../state/notifications_controller.dart';
import '../../state/place_resolver.dart';
import '../../widgets/map_view.dart';
import '../../widgets/scene_image.dart';
import '../../widgets/ue_widgets.dart';
import '../report/camera_capture_screen.dart';
import '../report/report_components.dart';
import '../report/report_flow_screen.dart';

// ===========================================================================
// Waste hub
// ===========================================================================

class WasteHubScreen extends StatelessWidget {
  const WasteHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final waste = context.watch<WasteController>();
    final options = <(IconData, String, String, Color, Widget)>[
      (Icons.report_gmailerrorred_rounded, 'Report Waste', 'Overflowing bins, illegal dumping', AppColors.red, const ReportFlowScreen(category: ReportCategory.waste)),
      (Icons.document_scanner_outlined, 'Pre-Disposal Check', 'AI tells you organic vs non-organic', AppColors.violet, const WasteClassifyScreen()),
      (Icons.local_shipping_outlined, 'Waste Pickup', 'Request a municipal pickup', AppColors.emerald, const PickupRequestScreen()),
      (Icons.location_on_outlined, 'Nearby Collection Points', 'Drop-off & recycling hubs', AppColors.electric, const ServicePointsScreen(kind: PointKind.wasteCollection)),
      (Icons.route_rounded, 'Collection Truck Tracker', 'See trucks near you live', AppColors.amber, const TruckTrackerScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Waste Management'))),
      body: RefreshIndicator(
        onRefresh: waste.load,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.xl),
                gradient: const LinearGradient(colors: [Color(0xFF065F46), AppColors.emerald]),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.t('Cleaner streets start with you'), style: AppText.h3(context).copyWith(color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(context.t('Segregate at source: green for organic, blue for dry waste.'),
                        style: AppText.bodySm(context).copyWith(color: Colors.white.withValues(alpha: 0.85))),
                  ]),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.recycling_rounded, color: Colors.white, size: 56),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < options.length; i++)
            FadeSlideIn(
              index: i + 1,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => context.push(options[i].$5),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    IconTile(icon: options[i].$1, color: options[i].$4, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(context.t(options[i].$2), style: AppText.title(context).copyWith(fontSize: 15)),
                        Text(context.t(options[i].$3), style: AppText.caption(context)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: ue.textSubtle),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'My pickup requests'),
          const SizedBox(height: 10),
          if (waste.loading && waste.mine.isEmpty)
            const LoadingSkeleton()
          else if (waste.mine.isEmpty)
            SizedBox(
              height: 320,
              child: EmptyState(kind: EmptyKind.pickups, actionLabel: 'Request Pickup', onAction: () => context.push(const PickupRequestScreen())),
            )
          else
            for (final p in waste.mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => context.push(PickupTrackingScreen(pickupId: p.id)),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    IconTile(icon: p.wasteType.icon, color: p.wasteType.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${context.t('Waste Pickup')} #${p.ticket}', style: AppText.label(context)),
                        Text('${context.t(p.wasteType.label)} · ${Fmt.relative(p.createdAt)}', style: AppText.caption(context)),
                      ]),
                    ),
                    Pill(p.status.label,
                        icon: p.status == PickupStatus.collected ? Icons.check_circle_rounded : Icons.schedule_rounded,
                        color: p.status == PickupStatus.collected ? ue.success : (p.status.index >= 2 ? ue.secondary : ue.warning)),
                  ]),
                ),
              ),
        ]),
      ),
    );
  }
}

// ===========================================================================
// AI waste classification
// ===========================================================================

class WasteClassifyScreen extends StatefulWidget {
  const WasteClassifyScreen({super.key});
  @override
  State<WasteClassifyScreen> createState() => _WasteClassifyScreenState();
}

class _WasteClassifyScreenState extends State<WasteClassifyScreen> with SingleTickerProviderStateMixin {
  Evidence? _photo;
  WasteClassification? _result;
  bool _analyzing = false;
  bool _failed = false;
  late final _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  Future<void> _pick(bool camera) async {
    Evidence? e;
    try {
      e = camera ? await context.push<Evidence>(const CameraCaptureScreen(hint: 'Fit the waste inside the frame')) : await MediaService.pickSinglePhoto();
    } catch (_) {
      if (mounted) showToast(context, 'Photo access was denied', kind: ToastKind.error);
      return;
    }
    if (e == null || !mounted) return;
    setState(() {
      _photo = e;
      _result = null;
      _failed = false;
    });
    _analyze();
  }

  Future<void> _analyze() async {
    final b = _photo?.bytes;
    if (b == null) return;
    setState(() {
      _analyzing = true;
      _failed = false;
    });
    try {
      final r = await Services.I.ai.classifyWaste(b);
      if (!mounted) return;
      Haptics.success();
      setState(() => _result = r);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _reset() => setState(() {
        _photo = null;
        _result = null;
        _failed = false;
      });

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Pre-Disposal Check'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        Semantics(header: true, child: Text(context.t('What type of waste is it?'), style: AppText.h1(context).copyWith(fontSize: 28))),
        const SizedBox(height: 6),
        Text(context.t('Snap a photo and our AI will tell you how to dispose of it correctly.'), style: AppText.bodySm(context)),
        const SizedBox(height: 20),
        if (_photo == null) ...[
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const _BinIllustration(),
              const SizedBox(height: 18),
              UeButton(label: 'Take Photo', icon: Icons.photo_camera_rounded, onPressed: () => _pick(true)),
              const SizedBox(height: 10),
              UeButton(label: 'Upload Photo', icon: Icons.photo_library_outlined, variant: ButtonVariant.secondary, onPressed: () => _pick(false)),
            ]),
          ),
        ] else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            child: SizedBox(
              height: 260,
              child: Stack(fit: StackFit.expand, children: [
                EvidenceImage(evidence: _photo, category: ReportCategory.waste),
                if (_analyzing)
                  AnimatedBuilder(
                    animation: _scan,
                    builder: (_, __) => CustomPaint(painter: _ScanPainter(_scan.value)),
                  ),
                if (_analyzing)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Center(
                      child: GlassPanel(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 10),
                          Text(context.t('Analyzing your waste...'), style: AppText.label(context)),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          if (_failed)
            AppCard(child: ErrorState(kind: ErrorKind.aiFailed, onRetry: _analyze, secondaryLabel: 'Choose another photo', onSecondary: _reset)),
          if (_result != null) _resultCard(_result!, ue),
        ],
      ]),
    );
  }

  Widget _resultCard(WasteClassification r, UeColors ue) {
    final c = r.type.color;
    return FadeSlideIn(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Motion.d(context, 700),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: IconTile(icon: r.type.icon, color: c, size: 60, iconSize: 32, radius: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.t('Classification'), style: AppText.caption(context)),
                  Text(context.t(r.type.label).toUpperCase(), style: AppText.h2(context).copyWith(color: c, letterSpacing: 0.5)),
                ]),
              ),
              ProgressRing(
                value: r.confidence,
                size: 62,
                stroke: 6,
                color: c,
                center: Text('${(r.confidence * 100).round()}%', style: AppText.label(context).copyWith(fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final i in r.detectedItems) Pill(i, icon: Icons.label_outline_rounded, color: c)]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadii.md)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.tips_and_updates_outlined, color: c),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.t('Disposal instructions'), style: AppText.label(context)),
                    const SizedBox(height: 4),
                    Text(context.t(r.instructions), style: AppText.bodySm(context).copyWith(color: ue.text)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Text(context.t('AI results can be wrong. When unsure, keep the waste separate and ask the collection team.'), style: AppText.caption(context)),
          ]),
        ),
        const SizedBox(height: 16),
        UeButton(
          label: 'Report / Request Pickup',
          icon: Icons.local_shipping_rounded,
          onPressed: () => context.push(PickupRequestScreen(type: r.type, photo: _photo)),
        ),
        const SizedBox(height: 10),
        UeButton(label: 'Try Again', icon: Icons.refresh_rounded, variant: ButtonVariant.outline, onPressed: _reset),
      ]),
    );
  }
}

class _BinIllustration extends StatelessWidget {
  const _BinIllustration();
  @override
  Widget build(BuildContext context) {
    Widget bin(Color c, IconData i, String label) => Column(children: [
          Container(
            width: 70,
            height: 86,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10), bottom: Radius.circular(16)),
              border: Border.all(color: c, width: 2),
            ),
            child: Icon(i, color: c, size: 32),
          ),
          const SizedBox(height: 6),
          Text(context.t(label), style: AppText.caption(context).copyWith(fontWeight: FontWeight.w700)),
        ]);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      bin(AppColors.emerald, Icons.eco_rounded, 'Organic'),
      bin(AppColors.electric, Icons.recycling_rounded, 'Non-organic'),
      bin(AppColors.red, Icons.dangerous_outlined, 'Hazardous'),
    ]);
  }
}

class _ScanPainter extends CustomPainter {
  final double t;
  _ScanPainter(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = AppColors.navy.withValues(alpha: 0.25));
    final y = s.height * t;
    final r = Rect.fromLTWH(0, y - 60, s.width, 60);
    canvas.drawRect(r, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppColors.emerald.withValues(alpha: 0.45)]).createShader(r));
    canvas.drawLine(Offset(0, y), Offset(s.width, y), Paint()
      ..color = const Color(0xFF6EE7B7)
      ..strokeWidth = 2.5);
    // detection boxes
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (t > 0.3) canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.18, s.height * 0.3, s.width * 0.28, s.height * 0.3), const Radius.circular(8)), p);
    if (t > 0.6) canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.55, s.height * 0.45, s.width * 0.25, s.height * 0.28), const Radius.circular(8)), p);
  }

  @override
  bool shouldRepaint(covariant _ScanPainter old) => old.t != t;
}

// ===========================================================================
// Pickup request
// ===========================================================================

class PickupRequestScreen extends StatefulWidget {
  final WasteType? type;
  final Evidence? photo;
  const PickupRequestScreen({super.key, this.type, this.photo});
  @override
  State<PickupRequestScreen> createState() => _PickupRequestScreenState();
}

class _PickupRequestScreenState extends State<PickupRequestScreen> {
  static const _prefs = ['Morning (6–10 AM)', 'Afternoon (12–4 PM)', 'Evening (4–7 PM)', 'Any time'];
  late WasteType _type = widget.type ?? WasteType.organic;
  late List<Evidence> _photos = widget.photo == null ? [] : [widget.photo!];
  PlaceLocation? _location;
  String _pref = _prefs.first;
  final _desc = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  WastePickup? _done;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_location == null) {
      showToast(context, 'Please confirm the pickup location', kind: ToastKind.warning);
      return;
    }
    if (!Services.I.connectivity.isOnline) {
      showToast(context, 'You\'re offline. Pickup requests need a connection.', kind: ToastKind.error);
      return;
    }
    setState(() => _busy = true);
    try {
      final p = await context.read<WasteController>().request(
            user: context.read<AuthController>().user!,
            type: _type,
            location: _location!,
            description: Validators.sanitize(_desc.text.isEmpty ? _type.label : _desc.text),
            preference: _pref,
            photo: _photos.firstOrNull,
          );
      if (mounted) setState(() => _done = p);
    } catch (_) {
      if (mounted) showToast(context, 'Request failed. Please try again.', kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done != null) return _success(_done!);
    final ue = context.ue;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Request Waste Pickup'))),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
          LabeledField(
            label: 'Waste Type',
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in WasteType.values)
                ChoiceChip(
                  avatar: Icon(t.icon, size: 16, color: _type == t ? Colors.white : t.color),
                  label: Text(context.t(t.label)),
                  selected: _type == t,
                  showCheckmark: false,
                  selectedColor: t.color,
                  labelStyle: TextStyle(color: _type == t ? Colors.white : ue.text, fontWeight: FontWeight.w700),
                  onSelected: (_) => setState(() => _type = t),
                ),
            ]),
          ),
          if (_type == WasteType.hazardous)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ue.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadii.md)),
              child: Text(context.t('Hazardous waste (batteries, chemicals, medical) needs special handling. Keep it sealed and away from children.'),
                  style: AppText.caption(context).copyWith(color: ue.text)),
            ),
          LabeledField(
            label: 'Photo',
            child: PhotoUploader(evidence: _photos, max: 1, allowVideo: false, onChanged: (v) => setState(() => _photos = v)),
          ),
          LabeledField(label: 'Pickup Location', child: LocationPicker(height: 220, onChanged: (p) => _location = p)),
          LabeledField(
            label: 'Description',
            child: TextFormField(
              controller: _desc,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(hintText: context.t('e.g. 3 sacks of garden waste near the gate')),
            ),
          ),
          LabeledField(
            label: 'Pickup Preference',
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in _prefs)
                ChoiceChip(label: Text(context.t(p)), selected: _pref == p, onSelected: (_) => setState(() => _pref = p)),
            ]),
          ),
          const SizedBox(height: 8),
          UeButton(label: 'Request Pickup', icon: Icons.local_shipping_rounded, loading: _busy, onPressed: _submit),
        ]),
      ),
    );
  }

  Widget _success(WastePickup p) {
    final ue = context.ue;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            const SuccessCheck(size: 150),
            const SizedBox(height: 20),
            Text(context.t('Pickup Request Submitted'), style: AppText.h2(context), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(context.t('Municipality has received your request.'), style: AppText.bodySm(context), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(color: ue.surface, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: ue.border)),
              child: Column(children: [
                Text(context.t('TICKET'), style: AppText.overline(context)),
                SelectableText(p.ticket, style: AppText.h1(context).copyWith(fontSize: 28, letterSpacing: 1.5)),
              ]),
            ),
            const Spacer(),
            UeButton(label: 'Track Pickup', icon: Icons.near_me_rounded, onPressed: () => context.replace(PickupTrackingScreen(pickupId: p.id))),
            const SizedBox(height: 10),
            UeButton(label: 'Back to Home', variant: ButtonVariant.outline, onPressed: () => context.popToRoot()),
          ]),
        ),
      ),
    );
  }
}

// ===========================================================================
// Pickup tracking (ticket timeline)
// ===========================================================================

class PickupTrackingScreen extends StatelessWidget {
  final String pickupId;
  const PickupTrackingScreen({super.key, required this.pickupId});

  @override
  Widget build(BuildContext context) {
    final waste = context.watch<WasteController>();
    final p = waste.byId(pickupId);
    final ue = context.ue;
    if (p == null) {
      return Scaffold(appBar: AppBar(), body: const LoadingSkeleton(kind: SkeletonKind.detail));
    }
    final stepIndex = switch (p.status) {
      PickupStatus.submitted => 0,
      PickupStatus.notified => 1,
      PickupStatus.assigned => 2,
      PickupStatus.enRoute => 3,
      PickupStatus.collected => 4,
      PickupStatus.cancelled => 0,
    };
    final steps = [
      TimelineStep(PickupStatus.submitted.label, subtitle: Fmt.dateTime(p.createdAt)),
      TimelineStep(PickupStatus.notified.label),
      TimelineStep(PickupStatus.assigned.label, subtitle: p.vehicleId == null ? null : 'Truck ${p.vehicleId}'),
      TimelineStep(PickupStatus.enRoute.label, subtitle: p.eta == null ? null : 'ETA ${Fmt.time(p.eta!)}'),
      TimelineStep(PickupStatus.collected.label),
    ];
    final truck = p.vehicleId;
    return Scaffold(
      appBar: AppBar(title: Text('${context.t('Waste Pickup')} #${p.ticket}')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        if (truck != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: SizedBox(
              height: 200,
              child: _LiveTruckMap(vehicleId: truck, destination: p.location, compact: true),
            ),
          ),
        if (truck != null) const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: ReportTimeline(steps: steps, current: stepIndex),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(children: [
            KeyValueRow(icon: Icons.groups_2_outlined, label: 'Assigned Team', value: p.teamId == null ? context.t('Awaiting assignment') : 'Waste Collection Team'),
            KeyValueRow(icon: Icons.schedule_rounded, label: 'Estimated Pickup', value: p.eta == null ? p.preference : '${Fmt.time(p.eta!)} · ${p.preference}'),
            KeyValueRow(icon: Icons.local_shipping_outlined, label: 'Truck', value: truck ?? '—'),
            KeyValueRow(icon: p.wasteType.icon, label: 'Waste Type', value: context.t(p.wasteType.label)),
            KeyValueRow(icon: Icons.place_outlined, label: 'Pickup Location', value: p.location.address),
          ]),
        ),
        const SizedBox(height: 16),
        UeButton(
          label: 'Track Pickup',
          icon: Icons.near_me_rounded,
          onPressed: truck == null ? null : () => context.push(TruckTrackerScreen(vehicleId: truck, destination: p.location)),
        ),
        if (truck == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(context.t('Live tracking starts once a truck is assigned.'), textAlign: TextAlign.center, style: AppText.caption(context).copyWith(color: ue.textMuted)),
          ),
      ]),
    );
  }
}

// ===========================================================================
// Truck tracker
// ===========================================================================

class TruckTrackerScreen extends StatelessWidget {
  final String vehicleId;
  final PlaceLocation? destination;
  const TruckTrackerScreen({super.key, this.vehicleId = 'WM-204', this.destination});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          radius: 20,
          child: Text(context.t('Waste Collection Truck'), style: AppText.title(context)),
        ),
      ),
      body: _LiveTruckMap(vehicleId: vehicleId, destination: destination),
    );
  }
}

/// Animated truck moving along its route toward the pickup point.
class _LiveTruckMap extends StatefulWidget {
  final String vehicleId;
  final PlaceLocation? destination;
  final bool compact;
  const _LiveTruckMap({required this.vehicleId, this.destination, this.compact = false});
  @override
  State<_LiveTruckMap> createState() => _LiveTruckMapState();
}

class _LiveTruckMapState extends State<_LiveTruckMap> with SingleTickerProviderStateMixin {
  Vehicle? _v;
  List<GeoPoint> _route = [];
  bool _error = false;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 90));
  bool _notifiedNear = false;
  late GeoPoint _dest;

  @override
  void initState() {
    super.initState();
    _dest = widget.destination?.point ?? PlaceResolver.mapCenter();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await Services.I.waste.vehicle(widget.vehicleId);
      if (!mounted) return;
      if (v == null) throw const ApiException('not found');
      // Build a plausible street route from the truck to the destination.
      final start = v.position;
      final mid1 = GeoPoint(start.lat + (_dest.lat - start.lat) * 0.35, start.lng + 0.004);
      final mid2 = GeoPoint(start.lat + (_dest.lat - start.lat) * 0.7, _dest.lng - 0.003);
      setState(() {
        _v = v;
        _route = [start, mid1, mid2, _dest];
      });
      _c.addListener(_tick);
      _c.forward(from: 0.15);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _tick() {
    if (!_notifiedNear && _c.value > 0.85 && mounted) {
      _notifiedNear = true;
      if (!widget.compact) showToast(context, 'Truck is approaching your location', kind: ToastKind.success);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _routeLength(List<GeoPoint> pts) {
    var d = 0.0;
    for (var i = 1; i < pts.length; i++) {
      d += pts[i - 1].distanceTo(pts[i]);
    }
    return d;
  }

  /// Position along the polyline at fraction t (0..1).
  GeoPoint _at(double t) {
    final total = _routeLength(_route);
    var target = total * t;
    for (var i = 1; i < _route.length; i++) {
      final seg = _route[i - 1].distanceTo(_route[i]);
      if (target <= seg) {
        final f = seg == 0 ? 0 : target / seg;
        return GeoPoint(
          _route[i - 1].lat + (_route[i].lat - _route[i - 1].lat) * f,
          _route[i - 1].lng + (_route[i].lng - _route[i - 1].lng) * f,
        );
      }
      target -= seg;
    }
    return _route.last;
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return ErrorState(kind: ErrorKind.mapFailed, onRetry: _load);
    final v = _v;
    if (v == null) return const LoadingSkeleton(kind: SkeletonKind.map);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Motion.reduced(context) ? 0.5 : _c.value;
        final pos = _at(t);
        final remainingPts = [pos, ..._route.where((p) => _route.indexOf(p) > (_route.length - 1) * t)];
        final remaining = _routeLength(remainingPts);
        final minutes = math.max(1, (remaining / 1000 / 18 * 60).round()); // ~18 km/h city speed
        final arrived = t >= 0.999;
        final map = UeMap(
          center: GeoPoint((pos.lat + _dest.lat) / 2, (pos.lng + _dest.lng) / 2),
          zoom: widget.compact ? 13.6 : 14.2,
          interactive: !widget.compact,
          lines: [
            MapLine(points: _route, color: AppColors.electric.withValues(alpha: 0.35), width: 6),
            MapLine(points: remainingPts, color: AppColors.electric, width: 6),
          ],
          pins: [
            MapPin(id: 'dest', point: _dest, child: const PulseMarker(color: AppColors.emerald, icon: Icons.home_rounded, pulse: true), semanticLabel: 'Pickup location'),
            MapPin(
              id: 'truck',
              point: pos,
              size: 50,
              semanticLabel: 'Truck ${v.id}',
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: AppShadows.glow(AppColors.electric),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        );
        if (widget.compact) return map;
        final ue = context.ue;
        return Stack(children: [
          map,
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          arrived ? context.t('Truck has arrived') : context.t('Truck arriving in {m} min', {'m': minutes}),
                          style: AppText.h3(context),
                        ),
                      ),
                    ),
                    Pill(arrived ? 'Arrived' : v.status, icon: Icons.circle, color: arrived ? ue.success : ue.secondary),
                  ]),
                  const SizedBox(height: 4),
                  Text('${Fmt.distance(remaining)} ${context.t('away')}', style: AppText.bodySm(context)),
                  const SizedBox(height: 12),
                  UeProgressBar(value: t, color: ue.success),
                  const SizedBox(height: 14),
                  Row(children: [
                    const IconTile(icon: Icons.local_shipping_rounded, color: AppColors.navy500),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${context.t('Truck')} #${v.id}', style: AppText.label(context)),
                        Text('${context.t('Driver')}: ${v.driver} · ${context.t('Load')} ${(v.loadPercent * 100).round()}%', style: AppText.caption(context)),
                      ]),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

// ===========================================================================
// Water / collection points
// ===========================================================================

class ServicePointsScreen extends StatefulWidget {
  final PointKind kind;
  const ServicePointsScreen({super.key, required this.kind});
  @override
  State<ServicePointsScreen> createState() => _ServicePointsScreenState();
}

class _ServicePointsScreenState extends State<ServicePointsScreen> {
  final _map = UeMapController();
  List<ServicePoint>? _points;
  bool _error = false;
  ServicePoint? _selected;
  bool _directions = false;
  GeoPoint _me = PlaceResolver.mapCenter();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      await PlaceResolver.current();
      _me = PlaceResolver.mapCenter();
      final pts = await Services.I.waste.fetchServicePoints(widget.kind);
      pts.sort((a, b) => a.point.distanceTo(_me).compareTo(b.point.distanceTo(_me)));
      if (mounted) setState(() => _points = pts);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _select(ServicePoint p) {
    setState(() {
      _selected = p;
      _directions = false;
    });
    _map.move(p.point, 15.5);
  }

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final water = widget.kind == PointKind.water;
    final title = water ? 'Nearby Water Collection Points' : 'Nearby Collection Points';
    final color = water ? AppColors.sky : AppColors.emerald;
    return Scaffold(
      appBar: AppBar(title: Text(context.t(title))),
      body: _error
          ? ErrorState(kind: ErrorKind.network, onRetry: _load)
          : _points == null
              ? const Padding(padding: EdgeInsets.all(20), child: LoadingSkeleton())
              : _points!.isEmpty
                  ? const EmptyState(kind: EmptyKind.nearby, title: 'No points nearby', message: 'There are no service points registered near you yet.')
                  : Column(children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.38,
                        child: UeMap(
                          controller: _map,
                          center: _me,
                          zoom: 14,
                          lines: _directions && _selected != null
                              ? [MapLine(points: [_me, GeoPoint(_me.lat, _selected!.point.lng), _selected!.point], color: AppColors.electric)]
                              : const [],
                          pins: [
                            MapPin(id: 'me', point: _me, child: const UserDot()),
                            for (final p in _points!)
                              MapPin(
                                id: p.id,
                                point: p.point,
                                onTap: () => _select(p),
                                semanticLabel: p.name,
                                child: PulseMarker(
                                  color: p.open ? color : const Color(0xFF94A3B8),
                                  icon: water ? Icons.water_drop_rounded : Icons.recycling_rounded,
                                  pulse: p.open && _selected?.id == p.id,
                                  selected: _selected?.id == p.id,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                          itemCount: _points!.length,
                          itemBuilder: (_, i) {
                            final p = _points![i];
                            final sel = _selected?.id == p.id;
                            return FadeSlideIn(
                              index: i,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: AnimatedContainer(
                                  duration: Motion.d(context, 200),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(AppRadii.lg),
                                    border: Border.all(color: sel ? color : Colors.transparent, width: 2),
                                  ),
                                  child: AppCard(
                                    onTap: () => _select(p),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        IconTile(icon: water ? Icons.water_drop_rounded : Icons.recycling_rounded, color: color),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(p.name, style: AppText.label(context)),
                                            Text('${Fmt.distance(p.point.distanceTo(_me))} ${context.t('away')} · ${p.hours}', style: AppText.caption(context)),
                                          ]),
                                        ),
                                        Pill(p.open ? 'Open' : 'Closed',
                                            icon: p.open ? Icons.check_circle_rounded : Icons.cancel_rounded, color: p.open ? ue.success : ue.error),
                                      ]),
                                      if (sel) ...[
                                        const SizedBox(height: 12),
                                        Row(children: [
                                          Pill('${context.t(water ? 'Availability' : 'Accepts')}: ${p.availability}', icon: Icons.info_outline_rounded),
                                          const Spacer(),
                                          UeButton(
                                            label: 'Get Directions',
                                            icon: Icons.directions_rounded,
                                            expand: false,
                                            height: 42,
                                            onPressed: () {
                                              setState(() => _directions = true);
                                              _map.move(GeoPoint((p.point.lat + _me.lat) / 2, (p.point.lng + _me.lng) / 2), 14.5);
                                            },
                                          ),
                                        ]),
                                      ],
                                    ]),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ]),
    );
  }
}


