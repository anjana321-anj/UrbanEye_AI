import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/models.dart';

// ---------------------------------------------------------------------------
// Permissions
// ---------------------------------------------------------------------------

enum AppPermission { camera, location, photos, notifications, microphone }

enum PermState { granted, denied, permanentlyDenied, unavailable }

class PermissionService {
  Permission _map(AppPermission p) => switch (p) {
        AppPermission.camera => Permission.camera,
        AppPermission.location => Permission.locationWhenInUse,
        AppPermission.photos => Permission.photos,
        AppPermission.notifications => Permission.notification,
        AppPermission.microphone => Permission.microphone,
      };

  PermState _state(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return PermState.granted;
    if (s.isPermanentlyDenied || s.isRestricted) return PermState.permanentlyDenied;
    return PermState.denied;
  }

  Future<PermState> status(AppPermission p) async {
    try {
      return _state(await _map(p).status);
    } catch (_) {
      return PermState.unavailable; // e.g. web / unsupported platform
    }
  }

  Future<PermState> request(AppPermission p) async {
    try {
      return _state(await _map(p).request());
    } catch (_) {
      return PermState.unavailable;
    }
  }

  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Location
// ---------------------------------------------------------------------------

class LocationFix {
  final GeoPoint point;
  final double accuracy;
  const LocationFix(this.point, this.accuracy);
}

enum LocationFailure { serviceDisabled, permissionDenied, permanentlyDenied, timeout }

class LocationException implements Exception {
  final LocationFailure reason;
  const LocationException(this.reason);
  String get message => switch (reason) {
        LocationFailure.serviceDisabled => 'Location services are turned off.',
        LocationFailure.permissionDenied => 'Location permission was denied.',
        LocationFailure.permanentlyDenied => 'Location permission is blocked in settings.',
        LocationFailure.timeout => 'Could not get a GPS fix. Try again outdoors.',
      };
  @override
  String toString() => message;
}

class LocationService {
  Future<LocationFix> current() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw const LocationException(LocationFailure.serviceDisabled);
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) throw const LocationException(LocationFailure.permissionDenied);
    if (perm == LocationPermission.deniedForever) throw const LocationException(LocationFailure.permanentlyDenied);
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      return LocationFix(GeoPoint(p.latitude, p.longitude), p.accuracy);
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LocationFix(GeoPoint(last.latitude, last.longitude), last.accuracy);
      throw const LocationException(LocationFailure.timeout);
    }
  }
}

// ---------------------------------------------------------------------------
// Connectivity
// ---------------------------------------------------------------------------

class ConnectivityService {
  final _c = Connectivity();
  final _ctrl = StreamController<bool>.broadcast();
  bool _online = true;
  bool _forcedOffline = false; // developer toggle to demo offline mode
  StreamSubscription? _sub;

  bool get isOnline => _online && !_forcedOffline;
  bool get forcedOffline => _forcedOffline;
  Stream<bool> get onChange => _ctrl.stream;

  Future<void> init() async {
    try {
      final r = await _c.checkConnectivity();
      _online = !r.contains(ConnectivityResult.none) || r.isEmpty;
      _sub = _c.onConnectivityChanged.listen((r) {
        _online = !r.contains(ConnectivityResult.none);
        _ctrl.add(isOnline);
      });
    } catch (_) {
      _online = true;
    }
  }

  void setForcedOffline(bool v) {
    _forcedOffline = v;
    _ctrl.add(isOnline);
  }

  void dispose() {
    _sub?.cancel();
    _ctrl.close();
  }
}

// ---------------------------------------------------------------------------
// Local storage (drafts, preferences). Sensitive tokens would use platform
// secure storage (Keychain/Keystore) in production.
// ---------------------------------------------------------------------------

class LocalStore {
  late SharedPreferences _p;
  Future<void> init() async => _p = await SharedPreferences.getInstance();

  bool getBool(String k, [bool d = false]) => _p.getBool(k) ?? d;
  Future<void> setBool(String k, bool v) => _p.setBool(k, v);
  String? getString(String k) => _p.getString(k);
  Future<void> setString(String k, String v) => _p.setString(k, v);
  double getDouble(String k, double d) => _p.getDouble(k) ?? d;
  Future<void> setDouble(String k, double v) => _p.setDouble(k, v);
  Future<void> remove(String k) => _p.remove(k);

  Map<String, dynamic>? getJson(String k) {
    final s = _p.getString(k);
    if (s == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> setJson(String k, Object v) => _p.setString(k, jsonEncode(v));

  List<Map<String, dynamic>> getJsonList(String k) {
    final s = _p.getString(k);
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }
}
