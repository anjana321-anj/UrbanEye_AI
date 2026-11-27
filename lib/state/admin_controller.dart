import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/di/service_locator.dart';
import '../domain/models/enums.dart';
import '../domain/models/models.dart';
import '../domain/repositories/repositories.dart';

/// Municipality console state. All mutating actions go through the
/// repository (which validates transitions and writes the audit log) and are
/// gated by the acting user's role permissions.
class AdminController extends ChangeNotifier {
  final ReportRepository _reports = Services.I.reports;
  final TeamRepository _teams = Services.I.teams;
  final WasteRepository _waste = Services.I.waste;
  final AnalyticsRepository _analytics = Services.I.analytics;

  StreamSubscription? _s1;
  StreamSubscription? _s2;
  Timer? _slaTimer;

  AppUser? _actor;

  /// Demo: lets a reviewer preview the console as different roles.
  UserRole? roleOverride;

  bool loading = false;
  String? error;
  List<Report> reports = [];
  List<Team> teams = [];
  List<Vehicle> vehicles = [];
  List<WastePickup> pickups = [];
  List<AuditLog> audit = [];
  List<AppUser> users = [];
  CityStats? stats;
  AnalyticsSnapshot? snapshot;
  int lastEscalated = 0;

  final Map<Severity, Duration> sla = {
    Severity.critical: const Duration(hours: 4),
    Severity.high: const Duration(hours: 24),
    Severity.medium: const Duration(hours: 72),
    Severity.low: const Duration(hours: 168),
  };

  AdminController() {
    _s1 = _reports.changes.listen((_) => refresh(silent: true));
    _s2 = _waste.changes.listen((_) => refresh(silent: true));
  }

  UserRole get role => roleOverride ?? _actor?.role ?? UserRole.operator;
  AppUser get actor {
    final a = _actor!;
    if (roleOverride == null) return a;
    return AppUser(
      id: a.id,
      name: a.name,
      email: a.email,
      phone: a.phone,
      city: a.city,
      role: roleOverride!,
      municipalityId: a.municipalityId,
      joinedAt: a.joinedAt,
    );
  }

  bool can(Perm p) => role.can(p);

  void attach(AppUser? user) {
    if (user == null || !user.role.isStaff) {
      _actor = null;
      _slaTimer?.cancel();
      return;
    }
    if (_actor?.id == user.id) return;
    _actor = user;
    refresh();
    _slaTimer?.cancel();
    _slaTimer = Timer.periodic(const Duration(minutes: 1), (_) => runEscalation());
  }

  void setRoleOverride(UserRole? r) {
    roleOverride = r;
    notifyListeners();
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final r = await Future.wait([
        _reports.fetchReports(const ReportQuery()),
        _teams.fetchTeams(),
        _teams.fetchVehicles(),
        _waste.fetchPickups(),
        _reports.auditLog(),
        _analytics.cityStats(),
        _teams.fetchUsers(),
      ]);
      reports = r[0] as List<Report>;
      teams = r[1] as List<Team>;
      vehicles = r[2] as List<Vehicle>;
      pickups = r[3] as List<WastePickup>;
      audit = r[4] as List<AuditLog>;
      stats = r[5] as CityStats;
      users = r[6] as List<AppUser>;
      if (snapshot == null) loadAnalytics();
      if (!silent) runEscalation();
    } catch (e) {
      error = 'Could not load municipal data. Check your connection.';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadAnalytics() async {
    snapshot = await _analytics.snapshot();
    notifyListeners();
  }

  Future<void> runEscalation() async {
    lastEscalated = await _reports.escalateOverdue(sla);
    if (lastEscalated > 0) notifyListeners();
  }

  void setSla(Severity s, Duration d) {
    sla[s] = d;
    notifyListeners();
    runEscalation();
  }

  DateTime dueAt(Report r) => r.createdAt.add(sla[r.severity]!);
  Duration remaining(Report r) => dueAt(r).difference(DateTime.now());
  bool overdue(Report r) => r.status.isOpen && remaining(r).isNegative;

  Team? team(String? id) => teams.where((t) => t.id == id).firstOrNull;

  // ---- Guarded actions ----------------------------------------------------

  Future<String?> _guard(Perm p, Future<void> Function() fn) async {
    if (!can(p)) return 'Your role (${role.label}) is not allowed to do this.';
    try {
      await fn();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Action failed. Please retry.';
    }
  }

  Future<String?> transition(Report r, ReportStatus to, {String? note}) {
    final perm = switch (to) {
      ReportStatus.verified => Perm.verifyReport,
      ReportStatus.rejected => Perm.rejectReport,
      ReportStatus.resolved => Perm.resolveReport,
      _ => Perm.updateStatus,
    };
    return _guard(perm, () => _reports.transition(r.id, to, actor: actor, note: note));
  }

  Future<String?> assign(Report r, String teamId) =>
      _guard(Perm.assignTeam, () => _reports.assignTeam(r.id, teamId, actor: actor));

  Future<String?> setPriority(Report r, Severity s) =>
      _guard(Perm.updateStatus, () => _reports.setPriority(r.id, s, actor: actor));

  Future<String?> resolve(Report r, String note) =>
      _guard(Perm.resolveReport, () => _reports.resolve(r.id, actor: actor, note: note));

  Future<String?> message(Report r, String body, {bool question = false}) => _guard(
      Perm.contactCitizen,
      () => _reports.addComment(
          r.id,
          Comment(
            id: 'c-${DateTime.now().microsecondsSinceEpoch}',
            authorName: actor.name,
            fromMunicipality: true,
            body: body,
            at: DateTime.now(),
            isQuestion: question,
          ),
          actor: actor));

  Future<String?> updatePickup(WastePickup p, PickupStatus s, {String? vehicleId}) => _guard(
      Perm.updateStatus, () => _waste.updatePickup(p.id, s, vehicleId: vehicleId, teamId: 'team-waste', actor: actor));

  Future<List<AuditLog>> auditFor(String reportId) => _reports.auditLog(reportId: reportId);

  @override
  void dispose() {
    _s1?.cancel();
    _s2?.cancel();
    _slaTimer?.cancel();
    super.dispose();
  }
}
