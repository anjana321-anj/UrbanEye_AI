import '../core/di/service_locator.dart';
import '../data/mock/mock_db.dart';
import '../data/services/device_services.dart';
import '../domain/models/models.dart';

/// Resolves "where am I" once and caches it for the session.
class PlaceResolver {
  PlaceResolver._();
  static PlaceLocation? last;
  static LocationException? lastError;

  static GeoPoint get municipalityCenter => MockDb.municipality.center;

  /// Returns the device location (reverse geocoded). On failure falls back to
  /// the municipality default and exposes the failure in [lastError].
  static Future<PlaceLocation> current({bool approximate = false, bool refresh = false}) async {
    if (last != null && !refresh) return last!;
    GeoPoint point;
    double? accuracy;
    try {
      final fix = await Services.I.gps.current();
      point = fix.point;
      accuracy = fix.accuracy;
      lastError = null;
    } on LocationException catch (e) {
      lastError = e;
      point = MockDb.defaultUserPoint;
    } catch (_) {
      lastError = const LocationException(LocationFailure.timeout);
      point = MockDb.defaultUserPoint;
    }
    if (approximate) point = point.coarse();
    final place = await Services.I.locations.reverseGeocode(point);
    last = PlaceLocation(point: place.point, address: place.address, area: place.area, accuracyMeters: approximate ? 150 : accuracy);
    return last!;
  }

  /// Where maps should centre: the user if they are inside the municipality,
  /// otherwise the municipality centre (so demo data is visible).
  static GeoPoint mapCenter() {
    final p = last?.point;
    if (p != null && p.distanceTo(municipalityCenter) < 30000) return p;
    return MockDb.defaultUserPoint;
  }
}
