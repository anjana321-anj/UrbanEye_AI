import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../../core/di/service_locator.dart';
import 'mock_db.dart';

/// Simulated network latency so loading states are visible in development.
Future<void> _latency([int ms = 450]) => Future.delayed(Duration(milliseconds: ms + math.Random().nextInt(250)));

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

class MockAuthRepository implements AuthRepository {
  final db = MockDb.instance;
  final _otps = <String, String>{};
  bool _signedIn = false;
  String? _sessionUserId;

  /// Persisted token lookup is handled by AuthController (secure storage in prod).
  void restoreFromToken(String userId) {
    _signedIn = true;
    _sessionUserId = userId;
    Services.I.store.setString('session_uid', userId);
  }

  @override
  Future<AppUser?> restoreSession() async {
    await _latency(150);
    final uid = Services.I.store.getString('session_uid');
    if (uid != null && db.users.containsKey(uid)) {
      _signedIn = true;
      _sessionUserId = uid;
    }
    return _signedIn ? db.users[_sessionUserId] : null;
  }

  @override
  Future<AppUser> login(String phoneOrEmail, String password) async {
    await _latency(700);
    if (phoneOrEmail.toLowerCase().contains('fail') || password == 'wrongpass1') {
      throw const AuthException('Incorrect phone/email or password.');
    }
    final existing = db.users.values.where((u) =>
        u.role == UserRole.citizen &&
        (u.email.toLowerCase() == phoneOrEmail.toLowerCase() || u.phone == phoneOrEmail));
    final user = existing.isNotEmpty ? existing.first : db.users['u-alex']!;
    restoreFromToken(user.id);
    return user;
  }

  @override
  Future<AppUser> loginWithProvider(String provider) async {
    await _latency(900);
    restoreFromToken('u-alex');
    return db.users['u-alex']!;
  }

  @override
  Future<AppUser> loginStaff(String email, String password) async {
    await _latency(700);
    if (!email.toLowerCase().endsWith('.gov.np') && !email.toLowerCase().contains('admin')) {
      throw const AuthException('Use your municipal staff email (e.g. sita.maharjan@kathmandu.gov.np).');
    }
    final match = db.users.values.where((u) => u.role.isStaff && u.email.toLowerCase() == email.toLowerCase());
    final user = match.isNotEmpty ? match.first : db.users['u-admin']!;
    restoreFromToken(user.id);
    return user;
  }

  @override
  Future<AppUser> signUp({required String name, required String phone, required String email, required String password}) async {
    await _latency(900);
    if (db.users.values.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      throw const AuthException('An account with this email already exists.');
    }
    final u = AppUser(
      id: db.nextId('u'),
      name: name,
      email: email,
      phone: phone,
      city: 'Kathmandu',
      role: UserRole.citizen,
      municipalityId: MockDb.municipality.id,
      joinedAt: DateTime.now(),
    );
    db.users[u.id] = u;
    restoreFromToken(u.id);
    return u;
  }

  @override
  Future<void> sendOtp(String destination) async {
    await _latency(600);
    _otps[destination] = '123456'; // Demo code. Real API sends SMS/email.
  }

  @override
  Future<bool> verifyOtp(String destination, String code) async {
    await _latency(500);
    return code == (_otps[destination] ?? '123456');
  }

  @override
  Future<void> resetPassword(String destination, String newPassword) async => _latency(600);

  @override
  Future<AppUser> updateProfile(AppUser user) async {
    await _latency(500);
    db.users[user.id] = user;
    return user;
  }

  @override
  Future<void> logout() async {
    _signedIn = false;
    _sessionUserId = null;
    await Services.I.store.remove('session_uid');
  }

  @override
  Future<void> deleteAccount(String userId) async {
    await _latency(800);
    // Reports are retained for municipal records but de-identified.
    for (final r in db.reports.values.where((r) => r.citizenId == userId).toList()) {
      db.reports[r.id] = Report(
        id: r.id,
        ticket: r.ticket,
        category: r.category,
        subtype: r.subtype,
        description: r.description,
        severity: r.severity,
        status: r.status,
        location: r.location,
        createdAt: r.createdAt,
        updatedAt: DateTime.now(),
        citizenId: 'deleted',
        citizenName: 'Deleted user',
        anonymous: true,
        evidence: r.evidence,
        afterEvidence: r.afterEvidence,
        history: r.history,
        comments: r.comments,
        assignment: r.assignment,
      );
    }
    db.users.remove(userId);
    db.notifications.removeWhere((n) => n.userId == userId);
    await logout();
  }
}

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

class MockReportRepository implements ReportRepository {
  final db = MockDb.instance;

  @override
  Stream<void> get changes => db.changes.stream.where((e) => e == 'reports');

  @override
  Future<List<Report>> fetchReports(ReportQuery q) async {
    await _latency(500);
    var list = db.reports.values.toList();
    if (q.citizenId != null) list = list.where((r) => r.citizenId == q.citizenId).toList();
    if (q.category != null) list = list.where((r) => r.category == q.category).toList();
    if (q.bucket != null) list = list.where((r) => r.status.bucket == q.bucket).toList();
    if (q.search != null && q.search!.trim().isNotEmpty) {
      final s = q.search!.toLowerCase();
      list = list
          .where((r) =>
              r.ticket.toLowerCase().contains(s) ||
              r.location.address.toLowerCase().contains(s) ||
              r.description.toLowerCase().contains(s))
          .toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final start = q.page * q.pageSize;
    if (start >= list.length) return [];
    return list.sublist(start, math.min(list.length, start + q.pageSize));
  }

  @override
  Future<Report> getReport(String id) async {
    await _latency(300);
    final r = db.reports[id] ?? db.reports.values.where((r) => r.ticket == id).firstOrNull;
    if (r == null) throw const ApiException('Report not found', code: 404);
    return r;
  }

  @override
  Future<Report> submit(ReportDraft d, AppUser user, {void Function(double progress)? onProgress}) async {
    // Simulated chunked, compressed upload of evidence.
    final steps = 10 + d.evidence.length * 4;
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 90));
      onProgress?.call(i / steps);
    }
    final now = DateTime.now();
    final r = Report(
      id: db.nextId('r'),
      ticket: db.nextTicket(),
      category: d.category ?? ReportCategory.other,
      subtype: d.subtype,
      description: d.description.trim(),
      severity: d.severity,
      status: ReportStatus.submitted,
      location: d.location!,
      createdAt: now,
      updatedAt: now,
      citizenId: user.id,
      citizenName: user.name,
      anonymous: d.anonymous,
      evidence: d.evidence,
      vehicleNumber: d.vehicleNumber,
      notes: d.notes,
      aiAssisted: d.aiAssisted,
      aiConfidence: d.aiConfidence,
      isEmergency: d.isEmergency || d.severity == Severity.critical,
    );
    r.history.add(StatusHistory(status: ReportStatus.submitted, at: now, actor: r.publicCitizenName));
    db.reports[r.id] = r;
    _notify(user.id, NotificationType.submitted, 'Report submitted', '${r.ticket} was sent to ${MockDb.municipality.name}.', r.id);
    _audit('System', UserRole.systemAdmin, 'Report created', r.id, null, ReportStatus.submitted,
        r.isEmergency ? 'Critical issue flagged — emergency escalation queue' : null);
    db.emit('reports');

    // Simulate the municipality picking it up so the citizen sees live progress.
    Timer(const Duration(seconds: 8), () {
      if (r.status == ReportStatus.submitted) {
        _apply(r, ReportStatus.underReview, 'Hari Prasad Joshi', UserRole.operator, null);
      }
    });
    return r;
  }

  @override
  Future<List<NearbyMatch>> findNearbyDuplicates(ReportCategory category, GeoPoint point, {double radiusMeters = 250}) async {
    await _latency(400);
    final out = <NearbyMatch>[];
    for (final r in db.reports.values) {
      if (r.category != category || !r.status.isOpen) continue;
      final d = r.location.point.distanceTo(point);
      if (d <= radiusMeters) out.add(NearbyMatch(report: r, distanceMeters: d, similarity: 1 - d / radiusMeters * 0.4));
    }
    out.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return out.take(3).toList();
  }

  @override
  Future<Report> support(String reportId, String userId) async {
    await _latency(400);
    final r = await getReport(reportId);
    r.supporters++;
    r.comments.add(Comment(
        id: db.nextId('c'),
        authorName: 'UrbanEye',
        fromMunicipality: false,
        body: 'Another citizen confirmed this issue.',
        at: DateTime.now()));
    db.emit('reports');
    return r;
  }

  void _apply(Report r, ReportStatus to, String actor, UserRole role, String? note) {
    if (!r.status.canTransitionTo(to)) {
      throw ApiException('Cannot move a report from ${r.status.label} to ${to.label}.', code: 409);
    }
    final prev = r.status;
    r.status = to;
    r.updatedAt = DateTime.now();
    r.history.add(StatusHistory(status: to, at: r.updatedAt, actor: actor, note: note));
    _audit(actor, role, 'Status changed', r.id, prev, to, note);
    final (type, title) = switch (to) {
      ReportStatus.verified => (NotificationType.verified, 'Report verified'),
      ReportStatus.rejected => (NotificationType.rejected, 'Report rejected'),
      ReportStatus.assigned => (NotificationType.assigned, 'Team assigned'),
      ReportStatus.resolved => (NotificationType.resolved, 'Issue resolved'),
      ReportStatus.reopened => (NotificationType.reopened, 'Report reopened'),
      _ => (NotificationType.statusChanged, 'Status updated: ${to.label}'),
    };
    _notify(r.citizenId, type, title, '${r.ticket} · ${note ?? to.label}', r.id);
    db.emit('reports');
  }

  @override
  Future<Report> transition(String reportId, ReportStatus to, {required AppUser actor, String? note}) async {
    await _latency(400);
    final r = await getReport(reportId);
    _apply(r, to, actor.name, actor.role, note);
    return r;
  }

  @override
  Future<Report> assignTeam(String reportId, String teamId, {required AppUser actor, DateTime? eta}) async {
    await _latency(400);
    final r = await getReport(reportId);
    if (r.status == ReportStatus.submitted || r.status == ReportStatus.underReview || r.status == ReportStatus.reopened) {
      _apply(r, ReportStatus.verified, actor.name, actor.role, 'Verified during assignment');
    }
    final team = db.teams.firstWhere((t) => t.id == teamId);
    r.assignment = Assignment(
        teamId: teamId, teamName: team.name, assignedBy: actor.name, at: DateTime.now(), eta: eta ?? DateTime.now().add(const Duration(hours: 4)));
    team.activeTasks++;
    if (r.status.canTransitionTo(ReportStatus.assigned)) {
      _apply(r, ReportStatus.assigned, actor.name, actor.role, 'Assigned to ${team.name}');
    } else {
      _audit(actor.name, actor.role, 'Reassigned to ${team.name}', r.id, r.status, r.status, null);
      db.emit('reports');
    }
    return r;
  }

  @override
  Future<Report> setPriority(String reportId, Severity severity, {required AppUser actor}) async {
    await _latency(300);
    final r = await getReport(reportId);
    final old = r.severity;
    r.severity = severity;
    _audit(actor.name, actor.role, 'Priority changed ${old.label} → ${severity.label}', r.id, r.status, r.status, null);
    db.emit('reports');
    return r;
  }

  @override
  Future<Report> addComment(String reportId, Comment comment, {AppUser? actor}) async {
    await _latency(350);
    final r = await getReport(reportId);
    r.comments.add(comment);
    r.updatedAt = DateTime.now();
    if (comment.fromMunicipality) {
      _notify(r.citizenId, comment.isQuestion ? NotificationType.question : NotificationType.statusChanged,
          comment.isQuestion ? 'Municipality requested more information' : 'New message from municipality',
          '${r.ticket}: ${comment.body}', r.id);
      if (actor != null) {
        _audit(actor.name, actor.role, comment.isQuestion ? 'Requested more information' : 'Added note', r.id, r.status, r.status, comment.body);
      }
    }
    db.emit('reports');
    return r;
  }

  @override
  Future<Report> addEvidence(String reportId, Evidence evidence, {bool after = false}) async {
    await _latency(700);
    final r = await getReport(reportId);
    (after ? r.afterEvidence : r.evidence).add(evidence);
    db.emit('reports');
    return r;
  }

  @override
  Future<Report> resolve(String reportId, {required AppUser actor, required String note, Evidence? after}) async {
    await _latency(500);
    final r = await getReport(reportId);
    if (after != null) r.afterEvidence.add(after);
    if (r.afterEvidence.isEmpty) {
      r.afterEvidence.add(Evidence(id: db.nextId('e'), kind: EvidenceKind.photo, sceneSeed: 3000 + r.ticket.hashCode % 50, capturedAt: DateTime.now(), isAfter: true));
    }
    r.resolutionNote = note;
    r.resolvedAt = DateTime.now();
    if (r.assignment != null) {
      final t = db.teams.where((t) => t.id == r.assignment!.teamId).firstOrNull;
      if (t != null) {
        t.activeTasks = math.max(0, t.activeTasks - 1);
        t.completedTasks++;
      }
    }
    _apply(r, ReportStatus.resolved, actor.name, actor.role, note);
    return r;
  }

  @override
  Future<Report> submitFeedback(String reportId, CitizenFeedback feedback, AppUser citizen) async {
    await _latency(500);
    final r = await getReport(reportId);
    r.feedback = feedback;
    if (feedback == CitizenFeedback.resolved) {
      _apply(r, ReportStatus.closed, r.publicCitizenName, UserRole.citizen, 'Citizen confirmed the fix');
    } else {
      final note = feedback == CitizenFeedback.partial ? 'Citizen: not fully resolved' : 'Citizen: issue remains';
      _apply(r, ReportStatus.reopened, r.publicCitizenName, UserRole.citizen, note);
      r.escalated = true;
    }
    return r;
  }

  @override
  Future<List<AuditLog>> auditLog({String? reportId}) async {
    await _latency(250);
    final l = db.audit.where((a) => reportId == null || a.reportId == reportId).toList();
    l.sort((a, b) => b.at.compareTo(a.at));
    return l;
  }

  @override
  Future<int> escalateOverdue(Map<Severity, Duration> sla) async {
    var count = 0;
    final now = DateTime.now();
    for (final r in db.reports.values) {
      if (!r.status.isOpen || r.escalated) continue;
      final due = r.createdAt.add(sla[r.severity]!);
      if (now.isAfter(due)) {
        r.escalated = true;
        count++;
        _audit('SLA Engine', UserRole.systemAdmin, 'Auto-escalated to supervisor', r.id, r.status, r.status,
            'Overdue by ${now.difference(due).inHours}h (${r.severity.label} SLA)');
        _notify(r.citizenId, NotificationType.slaEscalation, 'Report escalated',
            '${r.ticket} is taking longer than expected and was escalated to a supervisor.', r.id);
      }
    }
    if (count > 0) db.emit('reports');
    return count;
  }

  void _notify(String userId, NotificationType type, String title, String body, String? reportId) {
    db.notifications.insert(
        0,
        AppNotification(
            id: db.nextId('n'), userId: userId, type: type, title: title, body: body, at: DateTime.now(), reportId: reportId));
    db.emit('notifications');
  }

  void _audit(String actor, UserRole role, String action, String? reportId, ReportStatus? prev, ReportStatus? next, String? note) {
    db.audit.add(AuditLog(
      id: db.nextId('a'),
      actor: actor,
      actorRole: role,
      action: action,
      at: DateTime.now(),
      reportId: reportId,
      previous: prev,
      next: next,
      note: note,
    ));
  }
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

class MockNotificationRepository implements NotificationRepository {
  final db = MockDb.instance;
  @override
  Stream<void> get changes => db.changes.stream.where((e) => e == 'notifications');

  @override
  Future<List<AppNotification>> fetch(String userId) async {
    await _latency(300);
    final l = db.notifications.where((n) => n.userId == userId).toList();
    l.sort((a, b) => b.at.compareTo(a.at));
    return l;
  }

  @override
  Future<void> markRead(String id) async {
    for (final n in db.notifications) {
      if (n.id == id) n.read = true;
    }
    db.emit('notifications');
  }

  @override
  Future<void> markAllRead(String userId) async {
    for (final n in db.notifications.where((n) => n.userId == userId)) {
      n.read = true;
    }
    db.emit('notifications');
  }
}

// ---------------------------------------------------------------------------
// Teams
// ---------------------------------------------------------------------------

class MockTeamRepository implements TeamRepository {
  final db = MockDb.instance;
  @override
  Future<List<Team>> fetchTeams() async {
    await _latency(350);
    return List.of(db.teams);
  }

  @override
  Future<List<Vehicle>> fetchVehicles() async {
    await _latency(300);
    return List.of(db.vehicles);
  }

  @override
  Future<List<AppUser>> fetchUsers() async {
    await _latency(350);
    return db.users.values.toList();
  }
}

// ---------------------------------------------------------------------------
// Waste
// ---------------------------------------------------------------------------

class MockWasteRepository implements WasteRepository {
  final db = MockDb.instance;
  @override
  Stream<void> get changes => db.changes.stream.where((e) => e == 'pickups');

  @override
  Future<WastePickup> requestPickup({
    required AppUser user,
    required WasteType type,
    required PlaceLocation location,
    required String description,
    required String preference,
    Evidence? photo,
  }) async {
    await _latency(900);
    final p = WastePickup(
      id: db.nextId('p'),
      ticket: db.nextTicket(),
      citizenId: user.id,
      wasteType: type,
      location: location,
      description: description,
      preference: preference,
      createdAt: DateTime.now(),
      status: PickupStatus.submitted,
      photo: photo,
    );
    db.pickups.insert(0, p);
    db.emit('pickups');
    // Simulated municipality workflow.
    Timer(const Duration(seconds: 4), () {
      p.status = PickupStatus.notified;
      db.emit('pickups');
    });
    Timer(const Duration(seconds: 10), () {
      p.status = PickupStatus.assigned;
      p.vehicleId = 'WM-204';
      p.teamId = 'team-waste';
      p.eta = DateTime.now().add(const Duration(minutes: 18));
      db.notifications.insert(
          0,
          AppNotification(
              id: db.nextId('n'),
              userId: user.id,
              type: NotificationType.pickupScheduled,
              title: 'Waste pickup assigned',
              body: '${p.ticket}: Truck WM-204 assigned, arriving in ~18 min.',
              at: DateTime.now()));
      db.emit('pickups');
      db.emit('notifications');
    });
    return p;
  }

  @override
  Future<List<WastePickup>> fetchPickups({String? citizenId}) async {
    await _latency(350);
    return db.pickups.where((p) => citizenId == null || p.citizenId == citizenId).toList();
  }

  @override
  Future<WastePickup> updatePickup(String id, PickupStatus status, {String? vehicleId, String? teamId, AppUser? actor}) async {
    await _latency(350);
    final p = db.pickups.firstWhere((p) => p.id == id);
    p.status = status;
    if (vehicleId != null) p.vehicleId = vehicleId;
    if (teamId != null) p.teamId = teamId;
    if (status == PickupStatus.assigned || status == PickupStatus.enRoute) {
      p.eta ??= DateTime.now().add(const Duration(minutes: 25));
    }
    db.audit.add(AuditLog(
        id: db.nextId('a'),
        actor: actor?.name ?? 'System',
        actorRole: actor?.role ?? UserRole.systemAdmin,
        action: 'Pickup ${p.ticket} → ${status.label}${vehicleId != null ? ' ($vehicleId)' : ''}',
        at: DateTime.now()));
    db.notifications.insert(
        0,
        AppNotification(
            id: db.nextId('n'),
            userId: p.citizenId,
            type: status == PickupStatus.enRoute ? NotificationType.truckApproaching : NotificationType.pickupScheduled,
            title: status.label,
            body: '${p.ticket}: ${status.label}',
            at: DateTime.now()));
    db.emit('pickups');
    db.emit('notifications');
    return p;
  }

  @override
  Future<List<ServicePoint>> fetchServicePoints(PointKind kind) async {
    await _latency(400);
    return db.servicePoints.where((p) => p.kind == kind).toList();
  }

  @override
  Future<Vehicle?> vehicle(String id) async {
    await _latency(200);
    return db.vehicles.where((v) => v.id == id).firstOrNull;
  }
}

// ---------------------------------------------------------------------------
// Analytics
// ---------------------------------------------------------------------------

class MockAnalyticsRepository implements AnalyticsRepository {
  final db = MockDb.instance;

  @override
  Future<CityStats> cityStats() async {
    await _latency(450);
    final rs = db.reports.values;
    final resolvedLive = rs.where((r) => r.status.bucket == StatusBucket.resolved).length;
    final pending = rs.where((r) => r.status.bucket == StatusBucket.pending).length;
    final inProg = rs.where((r) => r.status.bucket == StatusBucket.inProgress).length;
    final critical = rs.where((r) => r.status.isOpen && r.severity == Severity.critical).length;
    // Historical baseline + live data.
    final resolved = 1267 + resolvedLive;
    final reported = 1314 + rs.length;
    return CityStats(
      resolved: resolved,
      reported: reported,
      resolutionRate: resolved / reported,
      wastePickups: 318 + db.pickups.where((p) => p.status == PickupStatus.collected).length,
      activeMaintenance: inProg + 14,
      avgResolutionHours: 26.4,
      pending: pending,
      inProgress: inProg,
      critical: critical,
    );
  }

  @override
  Future<AnalyticsSnapshot> snapshot() async {
    await _latency(600);
    final rnd = math.Random(7);
    final now = DateTime.now();
    final days = List.generate(14, (i) {
      final d = now.subtract(Duration(days: 13 - i));
      final live = db.reports.values.where((r) => r.createdAt.year == d.year && r.createdAt.month == d.month && r.createdAt.day == d.day).length;
      return SeriesPoint('${d.day}/${d.month}', (28 + rnd.nextInt(22) + live).toDouble());
    });
    final byCat = <ReportCategory, int>{};
    for (final c in ReportCategory.values) {
      byCat[c] = db.reports.values.where((r) => r.category == c).length * 21 + rnd.nextInt(30);
    }
    final areaCount = <String, int>{};
    for (final r in db.reports.values) {
      areaCount[r.location.area] = (areaCount[r.location.area] ?? 0) + 1;
    }
    final byArea = areaCount.entries.map((e) => SeriesPoint(e.key, e.value * 17.0 + rnd.nextInt(12))).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const months = ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'];
    final teamPerf = db.teams
        .map((t) => TeamPerformance(t.name, t.completedTasks, 12 + rnd.nextDouble() * 30, 0.78 + rnd.nextDouble() * 0.2))
        .toList();
    return AnalyticsSnapshot(
      daily: days,
      byCategory: byCat,
      byArea: byArea.take(8).toList(),
      resolutionHoursByCategory: [
        const SeriesPoint('Waste', 9.5),
        const SeriesPoint('Parking', 2.1),
        const SeriesPoint('Water', 14.8),
        const SeriesPoint('Light', 31.2),
        const SeriesPoint('Infra', 52.4),
        const SeriesPoint('Road', 46.0),
      ],
      monthlyResolutionRate: [for (var i = 0; i < months.length; i++) SeriesPoint(months[i], 0.81 + i * 0.024 + rnd.nextDouble() * 0.01)],
      teams: teamPerf,
      slaCompliance: 0.91,
      wastePickupPerformance: [for (final m in months) SeriesPoint(m, 220 + rnd.nextInt(120).toDouble())],
      roadTrend: [for (final m in months) SeriesPoint(m, 40 + rnd.nextInt(60).toDouble())],
      insights: [
        'Road reports in Kalanki rose 32% after last week\'s rain — consider pre-monsoon drainage checks.',
        'Parking complaints peak 8–10 AM near schools in Putalisadak and Naxal.',
        'Streetlight resolution time improved 18% since the Electrical Team added a night shift.',
        'Anomaly: 5 water-leak reports within 300 m in Sundhara in 24 h — possible main line fault.',
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Locations
// ---------------------------------------------------------------------------

class MockLocationRepository implements LocationRepository {
  final db = MockDb.instance;

  @override
  Future<List<SavedLocation>> savedLocations(String userId) async {
    await _latency(250);
    return List.of(db.savedLocations[userId] ?? const []);
  }

  @override
  Future<void> saveLocation(String userId, SavedLocation loc) async {
    await _latency(300);
    final l = db.savedLocations.putIfAbsent(userId, () => []);
    l.removeWhere((e) => e.id == loc.id);
    l.add(loc);
  }

  @override
  Future<void> deleteLocation(String userId, String id) async {
    db.savedLocations[userId]?.removeWhere((e) => e.id == id);
  }

  @override
  Future<PlaceLocation> reverseGeocode(GeoPoint p) async {
    await _latency(250);
    String best = MockDb.areas.keys.first;
    var bestD = double.infinity;
    MockDb.areas.forEach((name, c) {
      final d = c.distanceTo(p);
      if (d < bestD) {
        bestD = d;
        best = name;
      }
    });
    if (bestD > 20000) {
      return PlaceLocation(point: p, address: 'Pinned location (${p.lat.toStringAsFixed(4)}, ${p.lng.toStringAsFixed(4)})', area: 'Current area');
    }
    return PlaceLocation(point: p, address: '${MockDb.streets[best]}, $best, Kathmandu', area: best);
  }

  @override
  Future<List<PlaceLocation>> search(String query) async {
    await _latency(300);
    final q = query.toLowerCase().trim();
    return MockDb.areas.entries
        .where((e) => q.isEmpty || e.key.toLowerCase().contains(q) || MockDb.streets[e.key]!.toLowerCase().contains(q))
        .map((e) => PlaceLocation(point: e.value, address: '${MockDb.streets[e.key]}, ${e.key}, Kathmandu', area: e.key))
        .take(8)
        .toList();
  }
}

// ---------------------------------------------------------------------------
// AI
// ---------------------------------------------------------------------------

class MockAiService implements AiService {
  int _hash(Uint8List b) {
    var h = b.length;
    final step = math.max(1, b.length ~/ 64);
    for (var i = 0; i < b.length; i += step) {
      h = (h * 31 + b[i]) & 0x7fffffff;
    }
    return h;
  }

  static const _suggest = <ReportCategory, (String, String, Severity)>{
    ReportCategory.road: ('Pothole', 'Large pothole affecting the left side of the roadway.', Severity.high),
    ReportCategory.waste: ('Overflowing bin', 'Overflowing waste container with litter spreading onto the footpath.', Severity.medium),
    ReportCategory.water: ('Burst pipe', 'Water leaking continuously from a damaged pipe onto the road.', Severity.high),
    ReportCategory.streetlight: ('Broken Streetlight', 'Streetlight appears non-functional; area likely unlit at night.', Severity.medium),
    ReportCategory.parking: ('On footpath', 'Vehicle parked on the footpath, obstructing pedestrians.', Severity.low),
    ReportCategory.infrastructure: ('Damaged public property', 'Damaged public infrastructure that may pose a safety risk.', Severity.medium),
    ReportCategory.other: ('General issue', 'Municipal issue requiring inspection.', Severity.low),
  };

  @override
  Future<AiReportAnalysis> analyzeReportImage(Uint8List image, {ReportCategory? hint}) async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (image.length < 64) throw const AiException('We couldn\'t read this image. Try a clearer photo.');
    final h = _hash(image);
    const pool = [ReportCategory.road, ReportCategory.waste, ReportCategory.water, ReportCategory.streetlight, ReportCategory.parking, ReportCategory.infrastructure];
    final cat = hint ?? pool[h % pool.length];
    final s = _suggest[cat]!;
    final quality = 0.62 + (h % 37) / 100;
    return AiReportAnalysis(
      category: cat,
      subtype: s.$1,
      confidence: 0.84 + (h % 13) / 100,
      suggestedSeverity: s.$3,
      suggestedDescription: s.$2,
      evidenceQuality: quality,
      qualityNote: quality > 0.8 ? 'Clear, well-lit photo' : 'Usable — a closer shot would help the team',
      duplicateLikelihood: (h % 50) / 100,
    );
  }

  @override
  Future<WasteClassification> classifyWaste(Uint8List image) async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (image.length < 64) throw const AiException('Analysis failed. Please try another photo.');
    final h = _hash(image);
    final organic = h.isEven;
    return WasteClassification(
      type: organic ? WasteType.organic : WasteType.nonOrganic,
      confidence: 0.86 + (h % 12) / 100,
      instructions: organic
          ? 'Place this waste in the green waste collection category. Keep it free of plastic bags so it can be composted.'
          : 'Place this waste in the blue (dry/recyclable) category. Rinse containers and flatten cardboard before disposal.',
      detectedItems: organic ? ['Food scraps', 'Vegetable peels', 'Leaves'] : ['Plastic bottle', 'Packaging', 'Paper'],
    );
  }
}
