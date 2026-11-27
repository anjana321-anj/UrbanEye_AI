import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/di/service_locator.dart';
import '../domain/models/enums.dart';
import '../domain/models/models.dart';
import '../domain/repositories/repositories.dart';

class NotificationsController extends ChangeNotifier {
  final NotificationRepository _repo = Services.I.notifications;
  StreamSubscription? _sub;
  String? _userId;
  List<AppNotification> items = [];
  bool loading = false;

  /// Most recent notification that arrived while the app was open (for toasts).
  AppNotification? incoming;

  NotificationsController() {
    _sub = _repo.changes.listen((_) => load(silent: true));
  }

  int get unread => items.where((n) => !n.read).length;

  void attach(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    items = [];
    if (userId != null) load();
  }

  Future<void> load({bool silent = false}) async {
    if (_userId == null) return;
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    final before = items.map((e) => e.id).toSet();
    try {
      items = await _repo.fetch(_userId!);
      final fresh = items.where((n) => !before.contains(n.id) && !n.read);
      if (silent && before.isNotEmpty && fresh.isNotEmpty) incoming = fresh.first;
    } catch (_) {}
    loading = false;
    notifyListeners();
  }

  void consumeIncoming() => incoming = null;

  Future<void> markRead(AppNotification n) async {
    n.read = true;
    notifyListeners();
    await _repo.markRead(n.id);
  }

  Future<void> markAllRead() async {
    for (final n in items) {
      n.read = true;
    }
    notifyListeners();
    if (_userId != null) await _repo.markAllRead(_userId!);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class WasteController extends ChangeNotifier {
  final WasteRepository _repo = Services.I.waste;
  StreamSubscription? _sub;
  String? _userId;
  List<WastePickup> mine = [];
  bool loading = false;

  WasteController() {
    _sub = _repo.changes.listen((_) => load(silent: true));
  }

  void attach(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    if (userId != null) load();
  }

  Future<void> load({bool silent = false}) async {
    if (_userId == null) return;
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    try {
      mine = await _repo.fetchPickups(citizenId: _userId);
    } catch (_) {}
    loading = false;
    notifyListeners();
  }

  WastePickup? get active => mine.where((p) => p.status != PickupStatus.collected && p.status != PickupStatus.cancelled).firstOrNull;

  Future<WastePickup> request({
    required AppUser user,
    required WasteType type,
    required PlaceLocation location,
    required String description,
    required String preference,
    Evidence? photo,
  }) async {
    final p = await _repo.requestPickup(
        user: user, type: type, location: location, description: description, preference: preference, photo: photo);
    await load(silent: true);
    return p;
  }

  WastePickup? byId(String id) => mine.where((p) => p.id == id).firstOrNull;

  Future<List<ServicePoint>> points(PointKind k) => _repo.fetchServicePoints(k);
  Future<Vehicle?> vehicle(String id) => _repo.vehicle(id);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
