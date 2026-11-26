import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/config/env.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../core/utils/utils.dart';
import '../domain/models/models.dart';

/// Map provider abstraction. Screens only use [UeMap], [MapPin], [MapLine]
/// and [UeMapController]; swapping flutter_map for Google/Mapbox later only
/// touches this file.

class MapPin {
  final String id;
  final GeoPoint point;
  final Widget child;
  final double size;
  final VoidCallback? onTap;
  final String? semanticLabel;
  const MapPin({required this.id, required this.point, required this.child, this.size = 44, this.onTap, this.semanticLabel});
}

class MapLine {
  final List<GeoPoint> points;
  final Color color;
  final double width;
  const MapLine({required this.points, required this.color, this.width = 5});
}

class UeMapController {
  final MapController _c = MapController();
  bool _ready = false;

  void move(GeoPoint p, [double? zoom]) {
    if (!_ready) return;
    try {
      _c.move(LatLng(p.lat, p.lng), zoom ?? _c.camera.zoom);
    } catch (_) {}
  }

  double get zoom => _ready ? _c.camera.zoom : 14;
  GeoPoint? get center => _ready ? GeoPoint(_c.camera.center.latitude, _c.camera.center.longitude) : null;
}

class UeMap extends StatelessWidget {
  final UeMapController? controller;
  final GeoPoint center;
  final double zoom;
  final List<MapPin> pins;
  final List<MapLine> lines;
  final void Function(GeoPoint)? onTap;
  final void Function(GeoPoint center, double zoom, bool byUser)? onMoved;
  final bool interactive;
  final VoidCallback? onReady;

  const UeMap({
    super.key,
    this.controller,
    required this.center,
    this.zoom = 14.5,
    this.pins = const [],
    this.lines = const [],
    this.onTap,
    this.onMoved,
    this.interactive = true,
    this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Semantics(
      label: 'Map',
      child: Stack(children: [
        FlutterMap(
          mapController: controller?._c,
          options: MapOptions(
            initialCenter: LatLng(center.lat, center.lng),
            initialZoom: zoom,
            minZoom: 10,
            maxZoom: 19,
            backgroundColor: dark ? AppColors.darkBackground : const Color(0xFFEFF3F9),
            interactionOptions: InteractionOptions(
              flags: interactive ? (InteractiveFlag.all & ~InteractiveFlag.rotate) : InteractiveFlag.none,
            ),
            onMapReady: () {
              controller?._ready = true;
              onReady?.call();
            },
            onTap: onTap == null ? null : (_, ll) => onTap!(GeoPoint(ll.latitude, ll.longitude)),
            onPositionChanged: onMoved == null
                ? null
                : (camera, hasGesture) => onMoved!(GeoPoint(camera.center.latitude, camera.center.longitude), camera.zoom, hasGesture),
          ),
          children: [
            TileLayer(
              urlTemplate: dark ? Env.mapTilesDark : Env.mapTilesLight,
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.urbaneye.urbaneye',
              maxNativeZoom: 19,
            ),
            if (lines.isNotEmpty)
              PolylineLayer(
                polylines: [
                  for (final l in lines)
                    Polyline(
                      points: l.points.map((p) => LatLng(p.lat, p.lng)).toList(),
                      color: l.color,
                      strokeWidth: l.width,
                      borderColor: Colors.white.withValues(alpha: dark ? 0.15 : 0.9),
                      borderStrokeWidth: 2,
                    ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final p in pins)
                  Marker(
                    key: ValueKey(p.id),
                    point: LatLng(p.point.lat, p.point.lng),
                    width: p.size,
                    height: p.size,
                    child: Semantics(
                      button: p.onTap != null,
                      label: p.semanticLabel,
                      child: GestureDetector(
                        onTap: p.onTap == null
                            ? null
                            : () {
                                Haptics.tap();
                                p.onTap!();
                              },
                        child: p.child,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          right: 6,
          bottom: 4,
          child: IgnorePointer(
            child: Text(Env.mapAttribution,
                style: TextStyle(fontSize: 9, color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.45))),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Marker visuals
// ---------------------------------------------------------------------------

/// Status/category marker with an optional pulsing halo (critical / live).
class PulseMarker extends StatefulWidget {
  final Color color;
  final IconData icon;
  final bool pulse;
  final bool selected;
  final String? label;
  const PulseMarker({super.key, required this.color, required this.icon, this.pulse = false, this.selected = false, this.label});

  @override
  State<PulseMarker> createState() => _PulseMarkerState();
}

class _PulseMarkerState extends State<PulseMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant PulseMarker old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_c.isAnimating) _c.repeat();
    if (!widget.pulse && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final s = widget.selected ? 1.18 : 1.0;
    return AnimatedScale(
      scale: s,
      duration: Motion.d(context, 220),
      curve: Curves.easeOutBack,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          if (widget.pulse && !reduced)
            Container(
              width: 22 + 22 * _c.value,
              height: 22 + 22 * _c.value,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.35 * (1 - _c.value))),
            ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Icon(widget.icon, size: 16, color: Colors.white),
          ),
        ]),
      ),
    );
  }
}

class ClusterMarker extends StatelessWidget {
  final int count;
  final Color color;
  const ClusterMarker({super.key, required this.count, this.color = AppColors.navy});
  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.9),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14)],
        ),
        child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
      );
}

class UserDot extends StatelessWidget {
  const UserDot({super.key});
  @override
  Widget build(BuildContext context) =>
      const PulseMarker(color: AppColors.electric, icon: Icons.person_rounded, pulse: true, label: 'You are here');
}

/// Map pin used by the location picker — lifts while the map is dragged.
class DropPin extends StatelessWidget {
  final bool lifted;
  const DropPin({super.key, this.lifted = false});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedSlide(
        offset: Offset(0, lifted ? -0.18 : 0),
        duration: Motion.d(context, 180),
        curve: Curves.easeOut,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: AppShadows.glow(AppColors.electric),
          ),
          child: const Icon(Icons.visibility_rounded, color: Colors.white, size: 22),
        ),
      ),
      Container(width: 3, height: 14, color: AppColors.navy),
      AnimatedContainer(
        duration: Motion.d(context, 180),
        width: lifted ? 8 : 14,
        height: 5,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: lifted ? 0.15 : 0.3), borderRadius: BorderRadius.circular(10)),
      ),
    ]);
  }
}
