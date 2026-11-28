import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'enums.dart';

// ---------------------------------------------------------------------------
// Location
// ---------------------------------------------------------------------------

class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);

  /// Haversine distance in metres.
  double distanceTo(GeoPoint o) {
    const r = 6371000.0;
    final dLat = _rad(o.lat - lat);
    final dLng = _rad(o.lng - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat)) * math.cos(_rad(o.lat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double d) => d * math.pi / 180;

  /// Reduces precision (~110 m) for location-privacy mode.
  GeoPoint coarse() => GeoPoint((lat * 1000).roundToDouble() / 1000, (lng * 1000).roundToDouble() / 1000);

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
  factory GeoPoint.fromJson(Map<String, dynamic> j) => GeoPoint((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble());

  @override
  String toString() => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

class PlaceLocation {
  final GeoPoint point;
  final String address;
  final String area; // ward / neighbourhood
  final double? accuracyMeters;
  const PlaceLocation({required this.point, required this.address, required this.area, this.accuracyMeters});

  Map<String, dynamic> toJson() =>
      {'point': point.toJson(), 'address': address, 'area': area, 'accuracy': accuracyMeters};
  factory PlaceLocation.fromJson(Map<String, dynamic> j) => PlaceLocation(
        point: GeoPoint.fromJson(Map<String, dynamic>.from(j['point'] as Map)),
        address: j['address'] as String? ?? '',
        area: j['area'] as String? ?? '',
        accuracyMeters: (j['accuracy'] as num?)?.toDouble(),
      );
}

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

class Municipality {
  final String id;
  final String name;
  final GeoPoint center;
  final String emergencyNumbers;
  const Municipality({required this.id, required this.name, required this.center, required this.emergencyNumbers});
}

class AppUser {
  final String id;
  String name;
  String email;
  String phone;
  String city;
  final UserRole role;
  final String municipalityId;
  final DateTime joinedAt;
  bool anonymousByDefault;
  String? teamId;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.role,
    required this.municipalityId,
    required this.joinedAt,
    this.anonymousByDefault = false,
    this.teamId,
  });

  String get firstName => name.split(' ').first;
  String get initials {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.length == 1) return p.first.isEmpty ? '?' : p.first[0].toUpperCase();
    return (p.first[0] + p.last[0]).toUpperCase();
  }
}

class Contribution {
  final int submitted;
  final int verified;
  final int resolved;
  final int supported;
  const Contribution({required this.submitted, required this.verified, required this.resolved, required this.supported});

  /// Score only rewards *useful* reports: verification and resolution weigh most.
  int get score => submitted * 2 + verified * 10 + resolved * 15 + supported * 3;

  CivicBadge get badge {
    if (score >= 400) return CivicBadge.champion;
    if (score >= 120) return CivicBadge.helper;
    return CivicBadge.observer;
  }

  int get nextThreshold => switch (badge) {
        CivicBadge.observer => 120,
        CivicBadge.helper => 400,
        CivicBadge.champion => 400,
      };
}

enum CivicBadge { observer, helper, champion }

extension CivicBadgeX on CivicBadge {
  String get label => switch (this) {
        CivicBadge.observer => 'City Observer',
        CivicBadge.helper => 'Community Helper',
        CivicBadge.champion => 'Civic Champion',
      };
}

class SavedLocation {
  final String id;
  final String label; // Home, Work, University, Other
  final PlaceLocation location;
  const SavedLocation({required this.id, required this.label, required this.location});

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'location': location.toJson()};
  factory SavedLocation.fromJson(Map<String, dynamic> j) => SavedLocation(
        id: j['id'] as String,
        label: j['label'] as String,
        location: PlaceLocation.fromJson(Map<String, dynamic>.from(j['location'] as Map)),
      );
}

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

class Evidence {
  final String id;
  final EvidenceKind kind;

  /// Compressed bytes of user-captured media (null for seeded demo data).
  final Uint8List? bytes;

  /// For seeded demo data we render an illustrated scene instead of a photo.
  final int sceneSeed;
  final DateTime capturedAt;
  final bool isAfter;

  const Evidence({
    required this.id,
    required this.kind,
    this.bytes,
    this.sceneSeed = 0,
    required this.capturedAt,
    this.isAfter = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'bytes': bytes == null ? null : base64Encode(bytes!),
        'seed': sceneSeed,
        'at': capturedAt.toIso8601String(),
        'after': isAfter,
      };

  factory Evidence.fromJson(Map<String, dynamic> j) => Evidence(
        id: j['id'] as String,
        kind: EvidenceKind.values.byName(j['kind'] as String),
        bytes: j['bytes'] == null ? null : base64Decode(j['bytes'] as String),
        sceneSeed: j['seed'] as int? ?? 0,
        capturedAt: DateTime.parse(j['at'] as String),
        isAfter: j['after'] as bool? ?? false,
      );
}

class StatusHistory {
  final ReportStatus status;
  final DateTime at;
  final String actor;
  final String? note;
  const StatusHistory({required this.status, required this.at, required this.actor, this.note});
}

class Comment {
  final String id;
  final String authorName;
  final bool fromMunicipality;
  final String body;
  final DateTime at;
  final bool isQuestion;
  const Comment({
    required this.id,
    required this.authorName,
    required this.fromMunicipality,
    required this.body,
    required this.at,
    this.isQuestion = false,
  });
}

class Assignment {
  final String teamId;
  final String? teamName;
  final String assignedBy;
  final DateTime at;
  final DateTime? eta;
  const Assignment({required this.teamId, this.teamName, required this.assignedBy, required this.at, this.eta});
}

class Report {
  final String id;
  final String ticket; // UE-10284
  final ReportCategory category;
  final String? subtype;
  String description;
  Severity severity;
  ReportStatus status;
  final PlaceLocation location;
  final DateTime createdAt;
  DateTime updatedAt;
  final String citizenId;
  final String citizenName;
  final bool anonymous;
  final List<Evidence> evidence;
  final List<Evidence> afterEvidence;
  final List<StatusHistory> history;
  final List<Comment> comments;
  Assignment? assignment;
  final String? vehicleNumber;
  String? notes;
  int supporters;
  final bool aiAssisted;
  final double? aiConfidence;
  String? resolutionNote;
  DateTime? resolvedAt;
  CitizenFeedback? feedback;
  bool escalated;
  final bool isEmergency;

  Report({
    required this.id,
    required this.ticket,
    required this.category,
    this.subtype,
    required this.description,
    required this.severity,
    required this.status,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
    required this.citizenId,
    required this.citizenName,
    this.anonymous = false,
    List<Evidence>? evidence,
    List<Evidence>? afterEvidence,
    List<StatusHistory>? history,
    List<Comment>? comments,
    this.assignment,
    this.vehicleNumber,
    this.notes,
    this.supporters = 0,
    this.aiAssisted = false,
    this.aiConfidence,
    this.resolutionNote,
    this.resolvedAt,
    this.feedback,
    this.escalated = false,
    this.isEmergency = false,
  })  : evidence = evidence ?? [],
        afterEvidence = afterEvidence ?? [],
        history = history ?? [],
        comments = comments ?? [];

  String get title => subtype ?? category.label;
  String get publicCitizenName => anonymous ? 'Anonymous citizen' : citizenName;
  bool get hasOpenQuestion => comments.isNotEmpty && comments.last.isQuestion;
}

/// What the citizen builds in the report flow before submitting.
class ReportDraft {
  String localId;
  ReportCategory? category;
  String? subtype;
  List<Evidence> evidence;
  PlaceLocation? location;
  String description;
  Severity severity;
  String? vehicleNumber;
  String? notes;
  bool anonymous;
  bool isEmergency;
  bool aiAssisted;
  double? aiConfidence;
  DateTime createdAt;

  ReportDraft({
    required this.localId,
    this.category,
    this.subtype,
    List<Evidence>? evidence,
    this.location,
    this.description = '',
    this.severity = Severity.medium,
    this.vehicleNumber,
    this.notes,
    this.anonymous = false,
    this.isEmergency = false,
    this.aiAssisted = false,
    this.aiConfidence,
    DateTime? createdAt,
  })  : evidence = evidence ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get isComplete => category != null && location != null && description.trim().length >= 8;

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'category': category?.name,
        'subtype': subtype,
        'evidence': evidence.map((e) => e.toJson()).toList(),
        'location': location?.toJson(),
        'description': description,
        'severity': severity.name,
        'vehicle': vehicleNumber,
        'notes': notes,
        'anonymous': anonymous,
        'emergency': isEmergency,
        'ai': aiAssisted,
        'aiConf': aiConfidence,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReportDraft.fromJson(Map<String, dynamic> j) => ReportDraft(
        localId: j['localId'] as String,
        category: j['category'] == null ? null : ReportCategory.values.byName(j['category'] as String),
        subtype: j['subtype'] as String?,
        evidence: ((j['evidence'] as List?) ?? [])
            .map((e) => Evidence.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        location: j['location'] == null ? null : PlaceLocation.fromJson(Map<String, dynamic>.from(j['location'] as Map)),
        description: j['description'] as String? ?? '',
        severity: Severity.values.byName(j['severity'] as String? ?? 'medium'),
        vehicleNumber: j['vehicle'] as String?,
        notes: j['notes'] as String?,
        anonymous: j['anonymous'] as bool? ?? false,
        isEmergency: j['emergency'] as bool? ?? false,
        aiAssisted: j['ai'] as bool? ?? false,
        aiConfidence: (j['aiConf'] as num?)?.toDouble(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

class NearbyMatch {
  final Report report;
  final double distanceMeters;
  final double similarity;
  const NearbyMatch({required this.report, required this.distanceMeters, required this.similarity});
}

// ---------------------------------------------------------------------------
// Municipality operations
// ---------------------------------------------------------------------------

class TeamMember {
  final String id;
  final String name;
  final String role;
  final bool onDuty;
  const TeamMember({required this.id, required this.name, required this.role, this.onDuty = true});
}

class Team {
  final String id;
  final String name;
  final ReportCategory primaryCategory;
  final List<TeamMember> members;
  TeamStatus status;
  GeoPoint location;
  String locationLabel;
  int activeTasks;
  int completedTasks;
  final int capacity;

  Team({
    required this.id,
    required this.name,
    required this.primaryCategory,
    required this.members,
    required this.status,
    required this.location,
    required this.locationLabel,
    required this.activeTasks,
    required this.completedTasks,
    required this.capacity,
  });

  double get workload => capacity == 0 ? 0 : (activeTasks / capacity).clamp(0, 1).toDouble();
}

class Vehicle {
  final String id; // WM-204
  final String teamId;
  final String driver;
  GeoPoint position;
  String status; // On Route, Idle, Collecting
  final List<GeoPoint> route;
  final double loadPercent;
  Vehicle({
    required this.id,
    required this.teamId,
    required this.driver,
    required this.position,
    required this.status,
    required this.route,
    required this.loadPercent,
  });
}

class WastePickup {
  final String id;
  final String ticket;
  final String citizenId;
  final WasteType wasteType;
  final PlaceLocation location;
  final String description;
  final String preference; // e.g. Morning (6–10 AM)
  final DateTime createdAt;
  PickupStatus status;
  String? vehicleId;
  String? teamId;
  DateTime? eta;
  final Evidence? photo;

  WastePickup({
    required this.id,
    required this.ticket,
    required this.citizenId,
    required this.wasteType,
    required this.location,
    required this.description,
    required this.preference,
    required this.createdAt,
    required this.status,
    this.vehicleId,
    this.teamId,
    this.eta,
    this.photo,
  });
}

class ServicePoint {
  final String id;
  final PointKind kind;
  final String name;
  final GeoPoint point;
  final String address;
  final String hours;
  final bool open;
  final String availability; // e.g. "High", "Limited"
  const ServicePoint({
    required this.id,
    required this.kind,
    required this.name,
    required this.point,
    required this.address,
    required this.hours,
    required this.open,
    required this.availability,
  });
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime at;
  final String? reportId;
  bool read;
  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.at,
    this.reportId,
    this.read = false,
  });
}

class AuditLog {
  final String id;
  final String actor;
  final UserRole actorRole;
  final String action;
  final DateTime at;
  final String? reportId;
  final ReportStatus? previous;
  final ReportStatus? next;
  final String? note;
  const AuditLog({
    required this.id,
    required this.actor,
    required this.actorRole,
    required this.action,
    required this.at,
    this.reportId,
    this.previous,
    this.next,
    this.note,
  });
}

// ---------------------------------------------------------------------------
// Analytics
// ---------------------------------------------------------------------------

class CityStats {
  final int resolved;
  final int reported;
  final double resolutionRate;
  final int wastePickups;
  final int activeMaintenance;
  final double avgResolutionHours;
  final int pending;
  final int inProgress;
  final int critical;
  const CityStats({
    required this.resolved,
    required this.reported,
    required this.resolutionRate,
    required this.wastePickups,
    required this.activeMaintenance,
    required this.avgResolutionHours,
    required this.pending,
    required this.inProgress,
    required this.critical,
  });
}

class SeriesPoint {
  final String label;
  final double value;
  const SeriesPoint(this.label, this.value);
}

class TeamPerformance {
  final String teamName;
  final int completed;
  final double avgHours;
  final double slaCompliance;
  const TeamPerformance(this.teamName, this.completed, this.avgHours, this.slaCompliance);
}

class AnalyticsSnapshot {
  final List<SeriesPoint> daily; // last 14 days
  final Map<ReportCategory, int> byCategory;
  final List<SeriesPoint> byArea;
  final List<SeriesPoint> resolutionHoursByCategory;
  final List<SeriesPoint> monthlyResolutionRate;
  final List<TeamPerformance> teams;
  final double slaCompliance;
  final List<SeriesPoint> wastePickupPerformance;
  final List<SeriesPoint> roadTrend;
  final List<String> insights; // AI-generated, human-reviewed
  const AnalyticsSnapshot({
    required this.daily,
    required this.byCategory,
    required this.byArea,
    required this.resolutionHoursByCategory,
    required this.monthlyResolutionRate,
    required this.teams,
    required this.slaCompliance,
    required this.wastePickupPerformance,
    required this.roadTrend,
    required this.insights,
  });
}
