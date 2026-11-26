import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// US-07: map centered on detected location; tap or drag pin to adjust.
class MapPinPicker extends StatelessWidget {
  final LatLng position;
  final ValueChanged<LatLng> onChanged;
  const MapPinPicker({super.key, required this.position, required this.onChanged});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 220,
        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: GoogleMap(
          key: ValueKey(position),
          initialCameraPosition: CameraPosition(target: position, zoom: 16),
          markers: {Marker(markerId: const MarkerId('p'), position: position, draggable: true, onDragEnd: onChanged)},
          onTap: onChanged,
          myLocationButtonEnabled: false,
          gestureRecognizers: const {},
        )),
      );
}
