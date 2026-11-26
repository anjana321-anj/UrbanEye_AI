import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../mock/mock_db.dart';

/// Firebase Firestore & Auth integration for UrbanEye (Project: urbaneye-14).
class FirestoreAuthRepository implements AuthRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;

  @override
  Future<AppUser?> restoreSession() async {
    final current = _auth.currentUser;
    if (current == null) return null;
    final doc = await _db.collection('users').doc(current.uid).get();
    if (!doc.exists || doc.data() == null) {
      return AppUser(
        id: current.uid,
        name: current.displayName ?? 'Citizen',
        email: current.email ?? '',
        phone: current.phoneNumber ?? '',
        city: 'Kathmandu',
        role: UserRole.citizen,
        municipalityId: MockDb.municipality.id,
        joinedAt: DateTime.now(),
      );
    }
    final d = doc.data()!;
    return AppUser(
      id: current.uid,
      name: d['name'] as String? ?? 'Citizen',
      email: d['email'] as String? ?? current.email ?? '',
      phone: d['phone'] as String? ?? current.phoneNumber ?? '',
      city: d['city'] as String? ?? 'Kathmandu',
      role: UserRole.values.byName(d['role'] as String? ?? 'citizen'),
      municipalityId: d['municipalityId'] as String? ?? MockDb.municipality.id,
      joinedAt: DateTime.tryParse(d['joinedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<AppUser> login(String phoneOrEmail, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: phoneOrEmail.contains('@') ? phoneOrEmail : '$phoneOrEmail@urbaneye.local',
      password: password,
    );
    return (await restoreSession())!;
  }

  @override
  Future<AppUser> loginWithProvider(String provider) async {
    final user = _auth.currentUser;
    if (user != null) return (await restoreSession())!;
    await _auth.signInAnonymously();
    return (await restoreSession())!;
  }

  @override
  Future<AppUser> loginStaff(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    return (await restoreSession())!;
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    final user = AppUser(
      id: uid,
      name: name,
      email: email,
      phone: phone,
      city: 'Kathmandu',
      role: UserRole.citizen,
      municipalityId: MockDb.municipality.id,
      joinedAt: DateTime.now(),
    );
    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'phone': phone,
      'city': 'Kathmandu',
      'role': UserRole.citizen.name,
      'municipalityId': MockDb.municipality.id,
      'joinedAt': user.joinedAt.toIso8601String(),
    });
    return user;
  }

  @override
  Future<void> sendOtp(String destination) async {}

  @override
  Future<bool> verifyOtp(String destination, String code) async => true;

  @override
  Future<void> resetPassword(String destination, String newPassword) async {
    await _auth.sendPasswordResetEmail(email: destination);
  }

  @override
  Future<AppUser> updateProfile(AppUser user) async {
    await _db.collection('users').doc(user.id).update({
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'city': user.city,
    });
    return user;
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount(String userId) async {
    await _db.collection('users').doc(userId).delete();
    await _auth.currentUser?.delete();
  }
}

class FirestoreReportRepository implements ReportRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  FirestoreReportRepository() {
    _db.collection('reports').snapshots().listen((_) {
      _changes.add(null);
    });
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<Report>> fetchReports(ReportQuery q) async {
    Query query = _db.collection('reports');
    if (q.citizenId != null) query = query.where('citizenId', isEqualTo: q.citizenId);
    if (q.category != null) query = query.where('category', isEqualTo: q.category!.name);
    final snap = await query.get();
    var list = snap.docs.map((doc) => Report.fromJson(Map<String, dynamic>.from(doc.data() as Map))).toList();
    if (q.search != null && q.search!.trim().isNotEmpty) {
      final s = q.search!.toLowerCase();
      list = list.where((r) =>
          r.ticket.toLowerCase().contains(s) ||
          r.location.address.toLowerCase().contains(s) ||
          r.description.toLowerCase().contains(s)).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<Report> getReport(String id) async {
    final doc = await _db.collection('reports').doc(id).get();
    if (!doc.exists) throw const ApiException('Report not found', code: 404);
    return Report.fromJson(Map<String, dynamic>.from(doc.data() as Map));
  }

  @override
  Future<Report> submit(ReportDraft d, AppUser user, {void Function(double progress)? onProgress}) async {
    onProgress?.call(0.5);
    final docRef = _db.collection('reports').doc();
    final now = DateTime.now();
    final r = Report(
      id: docRef.id,
      ticket: 'UE-${now.millisecondsSinceEpoch.toString().substring(7)}',
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
    await docRef.set(r.toJson());
    onProgress?.call(1.0);
    return r;
  }

  @override
  Future<List<NearbyMatch>> findNearbyDuplicates(ReportCategory category, GeoPoint point, {double radiusMeters = 250}) async {
    final reports = await fetchReports(ReportQuery(category: category));
    final out = <NearbyMatch>[];
    for (final r in reports) {
      if (!r.status.isOpen) continue;
      final d = r.location.point.distanceTo(point);
      if (d <= radiusMeters) {
        out.add(NearbyMatch(report: r, distanceMeters: d, similarity: 1 - d / radiusMeters * 0.4));
      }
    }
    out.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return out.take(3).toList();
  }

  @override
  Future<Report> support(String reportId, String userId) async {
    final r = await getReport(reportId);
    r.supporters++;
    await _db.collection('reports').doc(reportId).update({'supporters': r.supporters});
    return r;
  }

  @override
  Future<Report> transition(String reportId, ReportStatus to, {required AppUser actor, String? note}) async {
    final r = await getReport(reportId);
    r.status = to;
    r.updatedAt = DateTime.now();
    await _db.collection('reports').doc(reportId).update({
      'status': to.name,
      'updatedAt': r.updatedAt.toIso8601String(),
    });
    return r;
  }

  @override
  Future<Report> assignTeam(String reportId, String teamId, {required AppUser actor, DateTime? eta}) async {
    final r = await getReport(reportId);
    r.assignment = Assignment(
      teamId: teamId,
      assignedBy: actor.name,
      at: DateTime.now(),
      eta: eta ?? DateTime.now().add(const Duration(hours: 4)),
    );
    r.status = ReportStatus.assigned;
    await _db.collection('reports').doc(reportId).update({
      'status': ReportStatus.assigned.name,
      'assignment': {
        'teamId': teamId,
        'assignedBy': actor.name,
        'at': DateTime.now().toIso8601String(),
      },
    });
    return r;
  }

  @override
  Future<Report> setPriority(String reportId, Severity severity, {required AppUser actor}) async {
    final r = await getReport(reportId);
    r.severity = severity;
    await _db.collection('reports').doc(reportId).update({'severity': severity.name});
    return r;
  }

  @override
  Future<Report> addComment(String reportId, Comment comment, {AppUser? actor}) async {
    final r = await getReport(reportId);
    r.comments.add(comment);
    await _db.collection('reports').doc(reportId).update({
      'comments': r.comments.map((c) => {
        'id': c.id,
        'authorName': c.authorName,
        'fromMunicipality': c.fromMunicipality,
        'body': c.body,
        'at': c.at.toIso8601String(),
        'isQuestion': c.isQuestion,
      }).toList(),
    });
    return r;
  }

  @override
  Future<Report> addEvidence(String reportId, Evidence evidence, {bool after = false}) async {
    final r = await getReport(reportId);
    (after ? r.afterEvidence : r.evidence).add(evidence);
    await _db.collection('reports').doc(reportId).update({
      'evidence': r.evidence.map((e) => e.toJson()).toList(),
      'afterEvidence': r.afterEvidence.map((e) => e.toJson()).toList(),
    });
    return r;
  }

  @override
  Future<Report> resolve(String reportId, {required AppUser actor, required String note, Evidence? after}) async {
    final r = await getReport(reportId);
    if (after != null) r.afterEvidence.add(after);
    r.resolutionNote = note;
    r.resolvedAt = DateTime.now();
    r.status = ReportStatus.resolved;
    await _db.collection('reports').doc(reportId).update({
      'status': ReportStatus.resolved.name,
      'resolutionNote': note,
      'resolvedAt': r.resolvedAt?.toIso8601String(),
      'afterEvidence': r.afterEvidence.map((e) => e.toJson()).toList(),
    });
    return r;
  }

  @override
  Future<Report> submitFeedback(String reportId, CitizenFeedback feedback, AppUser citizen) async {
    final r = await getReport(reportId);
    r.feedback = feedback;
    r.status = feedback == CitizenFeedback.resolved ? ReportStatus.closed : ReportStatus.reopened;
    await _db.collection('reports').doc(reportId).update({
      'feedback': feedback.name,
      'status': r.status.name,
    });
    return r;
  }

  @override
  Future<List<AuditLog>> auditLog({String? reportId}) async {
    return [];
  }

  @override
  Future<int> escalateOverdue(Map<Severity, Duration> sla) async {
    return 0;
  }
}
