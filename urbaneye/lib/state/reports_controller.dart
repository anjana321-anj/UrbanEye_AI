import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/di/service_locator.dart';
import '../domain/models/enums.dart';
import '../domain/models/models.dart';
import '../domain/repositories/repositories.dart';

enum LoadState { idle, loading, ready, error }

/// Citizen-side report state: my reports, city reports, submission and
/// offline queue. Server pushes (repository `changes`) refresh silently.
class ReportsController extends ChangeNotifier {
  final ReportRepository _repo = Services.I.reports;
  final _conn = Services.I.connectivity;
  final _store = Services.I.store;

  AppUser? _user;
  StreamSubscription? _sub;
  StreamSubscription? _connSub;

  LoadState state = LoadState.idle;
  String? error;
  List<Report> mine = [];
  List<Report> city = [];

  // Offline support
  List<ReportDraft> drafts = [];
  List<ReportDraft> outbox = [];
  bool syncing = false;
  double syncProgress = 0;
  bool online = true;

  ReportsController() {
    online = _conn.isOnline;
    _sub = _repo.changes.listen((_) => refresh(silent: true));
    _connSub = _conn.onChange.listen((on) {
      online = on;
      notifyListeners();
      if (on) syncOutbox();
    });
    drafts = _store.getJsonList('drafts').map(ReportDraft.fromJson).toList();
    outbox = _store.getJsonList('outbox').map(ReportDraft.fromJson).toList();
  }

  void attach(AppUser? user) {
    if (user?.id == _user?.id) return;
    _user = user;
    mine = [];
    city = [];
    if (user != null) {
      refresh();
      if (online) syncOutbox();
    }
  }

  Future<void> refresh({bool silent = false}) async {
    final u = _user;
    if (u == null) return;
    if (!silent) {
      state = LoadState.loading;
      error = null;
      notifyListeners();
    }
    try {
      if (!_conn.isOnline) throw const ApiException('You are offline.', code: -1);
      final results = await Future.wait([
        _repo.fetchReports(ReportQuery(citizenId: u.id)),
        _repo.fetchReports(const ReportQuery()),
      ]);
      mine = results[0];
      city = results[1];
      state = LoadState.ready;
    } on ApiException catch (e) {
      if (!silent) {
        error = e.message;
        state = mine.isEmpty ? LoadState.error : LoadState.ready;
      }
    } catch (e) {
      if (!silent) {
        error = 'We couldn\'t load reports.';
        state = LoadState.error;
      }
    }
    notifyListeners();
  }

  Report? byId(String id) {
    for (final r in [...mine, ...city]) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<Report> fetch(String id) => _repo.getReport(id);

  Future<List<NearbyMatch>> duplicates(ReportCategory c, GeoPoint p) async {
    if (!_conn.isOnline) return [];
    try {
      return await _repo.findNearbyDuplicates(c, p);
    } catch (_) {
      return [];
    }
  }

  /// Returns the created report, or null when the draft was queued offline.
  Future<Report?> submit(ReportDraft d, {void Function(double)? onProgress}) async {
    final u = _user!;
    if (!_conn.isOnline) {
      outbox.add(d);
      _persist();
      notifyListeners();
      return null;
    }
    final r = await _repo.submit(d, u, onProgress: onProgress);
    drafts.removeWhere((x) => x.localId == d.localId);
    _persist();
    await refresh(silent: true);
    return r;
  }

  Future<void> syncOutbox() async {
    if (syncing || outbox.isEmpty || _user == null || !_conn.isOnline) return;
    syncing = true;
    syncProgress = 0;
    notifyListeners();
    final total = outbox.length;
    var done = 0;
    for (final d in List.of(outbox)) {
      try {
        await _repo.submit(d, _user!, onProgress: (p) {
          syncProgress = (done + p) / total;
          notifyListeners();
        });
        outbox.remove(d);
        done++;
        _persist();
      } catch (_) {
        break; // retry on next connectivity change
      }
    }
    syncing = false;
    notifyListeners();
    refresh(silent: true);
  }

  void saveDraft(ReportDraft d) {
    drafts.removeWhere((x) => x.localId == d.localId);
    drafts.insert(0, d);
    _persist();
    notifyListeners();
  }

  void deleteDraft(String localId) {
    drafts.removeWhere((x) => x.localId == localId);
    _persist();
    notifyListeners();
  }

  void _persist() {
    _store.setJson('drafts', drafts.map((d) => d.toJson()).toList());
    _store.setJson('outbox', outbox.map((d) => d.toJson()).toList());
  }

  Future<void> support(String id) async {
    await _repo.support(id, _user!.id);
  }

  Future<void> feedback(String id, CitizenFeedback f) async {
    await _repo.submitFeedback(id, f, _user!);
  }

  Future<void> reply(String id, String body) async {
    final u = _user!;
    await _repo.addComment(
        id,
        Comment(
          id: 'c-${DateTime.now().microsecondsSinceEpoch}',
          authorName: u.name,
          fromMunicipality: false,
          body: body,
          at: DateTime.now(),
        ));
  }

  Future<void> addEvidence(String id, Evidence e) => _repo.addEvidence(id, e);

  void setForcedOffline(bool v) => _conn.setForcedOffline(v);
  bool get forcedOffline => _conn.forcedOffline;

  Contribution get contribution {
    final verified = mine.where((r) => r.status.index >= ReportStatus.verified.index && r.status != ReportStatus.rejected).length;
    final resolved = mine.where((r) => r.status.bucket == StatusBucket.resolved).length;
    final supported = mine.fold<int>(0, (a, r) => a + r.supporters);
    return Contribution(submitted: mine.length + 12, verified: verified + 9, resolved: resolved + 7, supported: supported);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}
