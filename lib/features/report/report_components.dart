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
import '../../data/services/device_services.dart';
import '../../data/services/media_service.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../state/auth_controller.dart';
import '../../state/place_resolver.dart';
import '../../state/settings_controller.dart';
import '../../widgets/map_view.dart';
import '../../widgets/scene_image.dart';
import '../../widgets/ue_widgets.dart';
import 'camera_capture_screen.dart';

// ===========================================================================
// PhotoUploader
// ===========================================================================

/// Reusable evidence capture: in-app camera, gallery (multi), optional video,
/// previews with remove, and per-item processing/upload progress.
class PhotoUploader extends StatefulWidget {
  final List<Evidence> evidence;
  final ValueChanged<List<Evidence>> onChanged;
  final int max;
  final bool allowVideo;
  final String hint;
  const PhotoUploader({
    super.key,
    required this.evidence,
    required this.onChanged,
    this.max = 5,
    this.allowVideo = true,
    this.hint = 'Center the issue in the frame',
  });

  @override
  State<PhotoUploader> createState() => _PhotoUploaderState();
}

class _PhotoUploaderState extends State<PhotoUploader> {
  final Map<String, double> _progress = {};

  void _add(List<Evidence> items) {
    if (items.isEmpty) return;
    final room = widget.max - widget.evidence.length;
    final next = [...widget.evidence, ...items.take(room)];
    widget.onChanged(next);
    for (final e in items.take(room)) {
      _simulateProcessing(e.id);
    }
    if (items.length > room) showToast(context, 'Up to ${widget.max} items per report', kind: ToastKind.warning);
  }

  /// Visual feedback while the image is compressed & staged for upload.
  void _simulateProcessing(String id) {
    _progress[id] = 0;
    Timer.periodic(const Duration(milliseconds: 60), (t) {
      if (!mounted) return t.cancel();
      setState(() => _progress[id] = math.min(1.0, (_progress[id] ?? 0) + 0.08));
      if ((_progress[id] ?? 1) >= 1) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _progress.remove(id));
        });
      }
    });
  }

  Future<void> _camera() async {
    final e = await context.push<Evidence>(CameraCaptureScreen(hint: widget.hint));
    if (e != null) _add([e]);
  }

  Future<void> _gallery() async {
    try {
      final items = await MediaService.pickPhotos(max: widget.max - widget.evidence.length);
      _add(items);
    } catch (_) {
      if (mounted) {
        showToast(context, 'Photo access was denied. Enable it in Settings.', kind: ToastKind.error, action: 'Settings', onAction: Services.I.permissions.openSettings);
      }
    }
  }

  Future<void> _video() async {
    try {
      final e = await MediaService.recordVideo();
      if (e != null) _add([e]);
    } catch (_) {
      if (mounted) showToast(context, 'Could not record video', kind: ToastKind.error);
    }
  }

  void _remove(Evidence e) {
    Haptics.light();
    widget.onChanged(widget.evidence.where((x) => x.id != e.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    if (widget.evidence.isEmpty) {
      return Column(children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: ue.secondary.withValues(alpha: 0.35), width: 1.5),
                color: ue.secondary.withValues(alpha: 0.05),
              ),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_a_photo_outlined, size: 40, color: ue.secondary),
                  const SizedBox(height: 10),
                  Text(context.t('Add a clear photo of the issue'), style: AppText.label(context)),
                  const SizedBox(height: 2),
                  Text(context.t('Photos help teams fix problems faster'), style: AppText.caption(context)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: UeButton(label: 'Take Photo', icon: Icons.photo_camera_rounded, onPressed: _camera, height: 52)),
              const SizedBox(width: 10),
              Expanded(
                child: UeButton(label: 'Upload Photo', icon: Icons.photo_library_outlined, variant: ButtonVariant.secondary, onPressed: _gallery, height: 52),
              ),
            ]),
            if (widget.allowVideo) ...[
              const SizedBox(height: 6),
              TextButton.icon(onPressed: _video, icon: const Icon(Icons.videocam_outlined, size: 18), label: Text(context.t('Record a short video (optional)'))),
            ],
          ]),
        ),
      ]);
    }
    return SizedBox(
      height: 132,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final e in widget.evidence)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FadeSlideIn(
                child: _Thumb(evidence: e, progress: _progress[e.id], onRemove: () => _remove(e)),
              ),
            ),
          if (widget.evidence.length < widget.max) ...[
            _AddTile(icon: Icons.photo_camera_outlined, label: 'Camera', onTap: _camera),
            const SizedBox(width: 10),
            _AddTile(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: _gallery),
            if (widget.allowVideo) ...[
              const SizedBox(width: 10),
              _AddTile(icon: Icons.videocam_outlined, label: 'Video', onTap: _video),
            ],
          ],
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final Evidence evidence;
  final double? progress;
  final VoidCallback onRemove;
  const _Thumb({required this.evidence, required this.progress, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isVideo = evidence.kind == EvidenceKind.video;
    return SizedBox(
      width: 120,
      height: 132,
      child: Stack(children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: isVideo
                ? Container(
                    color: AppColors.navy,
                    child: const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40)),
                  )
                : EvidenceImage(evidence: evidence, category: ReportCategory.other),
          ),
        ),
        if (progress != null)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                alignment: Alignment.center,
                child: ProgressRing(
                  value: progress!,
                  size: 44,
                  stroke: 4,
                  color: Colors.white,
                  center: Text('${(progress! * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
        Positioned(
          top: 6,
          right: 6,
          child: Semantics(
            button: true,
            label: 'Remove ${isVideo ? 'video' : 'photo'}',
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 17, color: Colors.white),
              ),
            ),
          ),
        ),
        if (progress == null)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: AppColors.emerald, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                const SizedBox(width: 2),
                Text(isVideo ? 'Video' : 'Ready', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _AddTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AddTile({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return PressableScale(
      onTap: onTap,
      semanticLabel: context.t(label),
      child: Container(
        width: 92,
        decoration: BoxDecoration(
          color: ue.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: ue.border, width: 1.4),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: ue.secondary),
          const SizedBox(height: 6),
          Text(context.t(label), style: AppText.caption(context).copyWith(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ===========================================================================
// LocationPicker
// ===========================================================================

/// Map-centred pin picker: GPS, drag the map, search, saved locations and a
/// manual fallback when permission is denied.
class LocationPicker extends StatefulWidget {
  final PlaceLocation? initial;
  final ValueChanged<PlaceLocation> onChanged;
  final double height;
  const LocationPicker({super.key, this.initial, required this.onChanged, this.height = 300});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _map = UeMapController();
  PlaceLocation? _place;
  bool _locating = false;
  bool _lifted = false;
  bool _geocoding = false;
  LocationException? _error;
  Timer? _debounce;
  late GeoPoint _center;

  @override
  void initState() {
    super.initState();
    _place = widget.initial;
    _center = widget.initial?.point ?? PlaceResolver.mapCenter();
    if (widget.initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _useGps());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  bool get _approx => context.read<SettingsController>().approximateLocation;

  Future<void> _useGps() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final fix = await Services.I.gps.current();
      var p = fix.point;
      if (_approx) p = p.coarse();
      final place = await Services.I.locations.reverseGeocode(p);
      _set(PlaceLocation(point: p, address: place.address, area: place.area, accuracyMeters: _approx ? 150 : fix.accuracy));
      _map.move(p, 17);
    } on LocationException catch (e) {
      setState(() => _error = e);
      // Manual fallback: start from municipality centre so the user can drag.
      if (_place == null) {
        final place = await Services.I.locations.reverseGeocode(_center);
        _set(PlaceLocation(point: _center, address: place.address, area: place.area));
      }
    } catch (_) {
      setState(() => _error = const LocationException(LocationFailure.timeout));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _set(PlaceLocation p) {
    if (!mounted) return;
    setState(() => _place = p);
    widget.onChanged(p);
  }

  void _onMoved(GeoPoint c, double zoom, bool byUser) {
    if (!byUser) return;
    if (!_lifted) setState(() => _lifted = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() {
        _lifted = false;
        _geocoding = true;
      });
      Haptics.tap();
      final place = await Services.I.locations.reverseGeocode(c);
      _set(PlaceLocation(point: c, address: place.address, area: place.area, accuracyMeters: null));
      if (mounted) setState(() => _geocoding = false);
    });
  }

  Future<void> _search() async {
    final userId = context.read<AuthController>().user?.id;
    final saved = userId == null ? <SavedLocation>[] : await Services.I.locations.savedLocations(userId);
    if (!mounted) return;
    final picked = await showUeSheet<PlaceLocation>(context, builder: (ctx) => _SearchSheet(saved: saved));
    if (picked != null) {
      _set(picked);
      _map.move(picked.point, 17);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: SizedBox(
          height: widget.height,
          child: Stack(children: [
            UeMap(controller: _map, center: _center, zoom: 16.5, onMoved: _onMoved),
            IgnorePointer(
              child: Center(
                child: Padding(padding: const EdgeInsets.only(bottom: 64), child: DropPin(lifted: _lifted)),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 16,
              child: FloatingActionButton.small(
                heroTag: 'gps',
                tooltip: context.t('Use Current Location'),
                backgroundColor: ue.surface,
                onPressed: _locating ? null : _useGps,
                child: _locating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.my_location_rounded, color: ue.secondary),
              ),
            ),
            Positioned(
              left: 10,
              right: 64,
              top: 10,
              child: GestureDetector(
                onTap: _search,
                child: GlassPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Icon(Icons.search_rounded, size: 18, color: ue.textMuted),
                    const SizedBox(width: 8),
                    Text(context.t('Search Location'), style: AppText.bodySm(context)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      if (_error != null)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: ue.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.md)),
          child: Row(children: [
            Icon(Icons.location_off_outlined, color: ue.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${context.t(_error!.message)} ${context.t('Move the map to place the pin manually or search an address.')}',
                  style: AppText.caption(context).copyWith(color: ue.text)),
            ),
            if (_error!.reason == LocationFailure.permanentlyDenied || _error!.reason == LocationFailure.serviceDisabled)
              TextButton(onPressed: Services.I.permissions.openSettings, child: Text(context.t('Settings'))),
          ]),
        ),
      AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          IconTile(icon: Icons.place_rounded, color: ue.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.d(context, 250),
              child: Column(
                key: ValueKey(_place?.address ?? '-'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_geocoding ? context.t('Finding address…') : (_place?.address ?? context.t('Locating…')), style: AppText.label(context)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (_place != null) Pill(_place!.point.toString(), icon: Icons.gps_fixed_rounded),
                    if (_place?.accuracyMeters != null)
                      Pill('±${_place!.accuracyMeters!.round()} m', icon: Icons.radar_rounded,
                          color: (_place!.accuracyMeters! < 30) ? ue.success : ue.warning),
                    if (_approx) Pill('Approximate', icon: Icons.privacy_tip_outlined, color: ue.secondary),
                  ]),
                ],
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _SearchSheet extends StatefulWidget {
  final List<SavedLocation> saved;
  const _SearchSheet({required this.saved});
  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  List<PlaceLocation> _results = [];
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _query('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _query(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _loading = true);
      final r = await Services.I.locations.search(q);
      if (mounted) {
        setState(() {
          _results = r;
          _loading = false;
        });
      }
    });
  }

  IconData _iconFor(String label) => switch (label) {
        'Home' => Icons.home_rounded,
        'Work' => Icons.work_rounded,
        'University' => Icons.school_rounded,
        _ => Icons.bookmark_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(context.t('Search Location'), style: AppText.h3(context)),
      const SizedBox(height: 12),
      TextField(
        autofocus: true,
        onChanged: _query,
        decoration: InputDecoration(hintText: context.t('Street, area or landmark'), prefixIcon: const Icon(Icons.search_rounded)),
      ),
      if (widget.saved.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(context.t('SAVED'), style: AppText.overline(context)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in widget.saved)
            ActionChip(
              avatar: Icon(_iconFor(s.label), size: 16),
              label: Text(context.t(s.label)),
              onPressed: () => Navigator.pop(context, s.location),
            ),
        ]),
      ],
      const SizedBox(height: 16),
      Text(context.t('RESULTS'), style: AppText.overline(context)),
      if (_loading)
        const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
      else if (_results.isEmpty)
        const SizedBox(height: 200, child: EmptyState(kind: EmptyKind.search))
      else
        for (final r in _results)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: Text(r.area, style: AppText.label(context)),
            subtitle: Text(r.address, style: AppText.caption(context)),
            onTap: () => Navigator.pop(context, r),
          ),
    ]);
  }
}

// ===========================================================================
// Severity selector
// ===========================================================================

class SeveritySelector extends StatelessWidget {
  final Severity value;
  final ValueChanged<Severity> onChanged;
  final Severity? aiSuggested;
  const SeveritySelector({super.key, required this.value, required this.onChanged, this.aiSuggested});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return Row(children: [
      for (final s in Severity.values)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Semantics(
              selected: s == value,
              button: true,
              label: '${s.label} severity. ${s.hint}',
              excludeSemantics: true,
              child: PressableScale(
                onTap: () => onChanged(s),
                child: AnimatedContainer(
                  duration: Motion.d(context, 220),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: s == value ? s.color.withValues(alpha: 0.14) : ue.surface,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: s == value ? s.color : ue.border, width: s == value ? 2 : 1),
                  ),
                  child: Column(children: [
                    Icon(s.icon, color: s.color, size: 20),
                    const SizedBox(height: 4),
                    Text(context.t(s.label), style: AppText.label(context).copyWith(fontSize: 12)),
                    if (aiSuggested == s)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.auto_awesome, size: 10, color: ue.secondary),
                          const SizedBox(width: 2),
                          Text('AI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: ue.secondary)),
                        ]),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
