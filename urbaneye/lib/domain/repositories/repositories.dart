import 'dart:typed_data';

import '../models/enums.dart';
import '../models/models.dart';

/// Repository contracts. The UI and state layer only depend on these
/// interfaces; `data/mock` implements them for development and
/// `data/api` is where the real HTTP implementations plug in.

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class ApiException implements Exception {
  final String message;
  final int? code;
  const ApiException(this.message, {this.code});
  bool get isSessionExpired => code == 401;
  bool get isNetwork => code == -1;
  @override
  String toString() => message;
}

abstract class AuthRepository {
  Future<AppUser?> restoreSession();
  Future<AppUser> login(String phoneOrEmail, String password);
  Future<AppUser> loginWithProvider(String provider); // google | apple
  Future<AppUser> loginStaff(String email, String password);
  Future<AppUser> signUp({required String name, required String phone, required String email, required String password});
  Future<void> sendOtp(String destination);
  Future<bool> verifyOtp(String destination, String code);
  Future<void> resetPassword(String destination, String newPassword);
  Future<AppUser> updateProfile(AppUser user);
  Future<void> logout();
  Future<void> deleteAccount(String userId);
}

class ReportQuery {
  final String? citizenId;
  final ReportCategory? category;
  final StatusBucket? bucket;
  final String? search;
  final int page;
  final int pageSize;
  const ReportQuery({this.citizenId, this.category, this.bucket, this.search, this.page = 0, this.pageSize = 200});
}

abstract class ReportRepository {
  /// Emits whenever server-side report data changes (websocket in production).
  Stream<void> get changes;
  Future<List<Report>> fetchReports(ReportQuery query);
  Future<Report> getReport(String id);
  Future<Report> submit(ReportDraft draft, AppUser user, {void Function(double progress)? onProgress});
  Future<List<NearbyMatch>> findNearbyDuplicates(ReportCategory category, GeoPoint point, {double radiusMeters = 250});
  Future<Report> support(String reportId, String userId);
  Future<Report> transition(String reportId, ReportStatus to, {required AppUser actor, String? note});
  Future<Report> assignTeam(String reportId, String teamId, {required AppUser actor, DateTime? eta});
  Future<Report> setPriority(String reportId, Severity severity, {required AppUser actor});
  Future<Report> addComment(String reportId, Comment comment, {AppUser? actor});
  Future<Report> addEvidence(String reportId, Evidence evidence, {bool after = false});
  Future<Report> resolve(String reportId, {required AppUser actor, required String note, Evidence? after});
  Future<Report> submitFeedback(String reportId, CitizenFeedback feedback, AppUser citizen);
  Future<List<AuditLog>> auditLog({String? reportId});
  Future<int> escalateOverdue(Map<Severity, Duration> sla);
}

abstract class NotificationRepository {
  Stream<void> get changes;
  Future<List<AppNotification>> fetch(String userId);
  Future<void> markRead(String id);
  Future<void> markAllRead(String userId);
}

abstract class TeamRepository {
  Future<List<Team>> fetchTeams();
  Future<List<Vehicle>> fetchVehicles();
  Future<List<AppUser>> fetchUsers();
}

abstract class WasteRepository {
  Stream<void> get changes;
  Future<WastePickup> requestPickup({
    required AppUser user,
    required WasteType type,
    required PlaceLocation location,
    required String description,
    required String preference,
    Evidence? photo,
  });
  Future<List<WastePickup>> fetchPickups({String? citizenId});
  Future<WastePickup> updatePickup(String id, PickupStatus status, {String? vehicleId, String? teamId, AppUser? actor});
  Future<List<ServicePoint>> fetchServicePoints(PointKind kind);
  Future<Vehicle?> vehicle(String id);
}

abstract class AnalyticsRepository {
  Future<CityStats> cityStats();
  Future<AnalyticsSnapshot> snapshot();
}

abstract class LocationRepository {
  Future<List<SavedLocation>> savedLocations(String userId);
  Future<void> saveLocation(String userId, SavedLocation loc);
  Future<void> deleteLocation(String userId, String id);
  Future<PlaceLocation> reverseGeocode(GeoPoint p);
  Future<List<PlaceLocation>> search(String query);
}

// ---------------------------------------------------------------------------
// AI (modular, human-in-the-loop)
// ---------------------------------------------------------------------------

class AiReportAnalysis {
  final ReportCategory category;
  final String? subtype;
  final double confidence; // 0..1
  final Severity suggestedSeverity;
  final String suggestedDescription;
  final double evidenceQuality; // 0..1
  final String qualityNote;
  final double duplicateLikelihood; // 0..1
  const AiReportAnalysis({
    required this.category,
    this.subtype,
    required this.confidence,
    required this.suggestedSeverity,
    required this.suggestedDescription,
    required this.evidenceQuality,
    required this.qualityNote,
    required this.duplicateLikelihood,
  });
}

class WasteClassification {
  final WasteType type;
  final double confidence;
  final String instructions;
  final List<String> detectedItems;
  const WasteClassification({required this.type, required this.confidence, required this.instructions, required this.detectedItems});
}

/// AI suggestions are ALWAYS advisory. Nothing produced here is submitted or
/// acted upon without explicit confirmation by a citizen or staff member.
abstract class AiService {
  Future<AiReportAnalysis> analyzeReportImage(Uint8List image, {ReportCategory? hint});
  Future<WasteClassification> classifyWaste(Uint8List image);
}

class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}
