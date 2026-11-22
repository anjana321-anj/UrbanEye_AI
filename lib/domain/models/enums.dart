import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';

// ---------------------------------------------------------------------------
// Categories
// ---------------------------------------------------------------------------

enum ReportCategory { waste, parking, water, streetlight, infrastructure, road, other }

extension ReportCategoryX on ReportCategory {
  String get label => switch (this) {
    ReportCategory.waste => 'Waste',
    ReportCategory.parking => 'Illegal Parking',
    ReportCategory.water => 'Water Leakage',
    ReportCategory.streetlight => 'Streetlight',
    ReportCategory.infrastructure => 'Infrastructure',
    ReportCategory.road => 'Road Condition',
    ReportCategory.other => 'Other',
  };

  String get shortLabel => switch (this) {
    ReportCategory.waste => 'Waste',
    ReportCategory.parking => 'Parking',
    ReportCategory.water => 'Water',
    ReportCategory.streetlight => 'Streetlight',
    ReportCategory.infrastructure => 'Infrastructure',
    ReportCategory.road => 'Road',
    ReportCategory.other => 'Other',
  };

  String get blurb => switch (this) {
    ReportCategory.waste => 'Overflowing bins, dumping, missed pickups',
    ReportCategory.parking => 'Blocked roads, footpaths or entrances',
    ReportCategory.water => 'Burst pipes, leaks, wastage',
    ReportCategory.streetlight => 'Broken or flickering lights',
    ReportCategory.infrastructure => 'Damaged poles, drains, public assets',
    ReportCategory.road => 'Potholes, cracks, flooding',
    ReportCategory.other => 'Anything else the city should know',
  };

  IconData get icon => switch (this) {
    ReportCategory.waste => Icons.delete_outline_rounded,
    ReportCategory.parking => Icons.local_parking_rounded,
    ReportCategory.water => Icons.water_drop_outlined,
    ReportCategory.streetlight => Icons.lightbulb_outline_rounded,
    ReportCategory.infrastructure => Icons.foundation_rounded,
    ReportCategory.road => Icons.add_road_rounded,
    ReportCategory.other => Icons.more_horiz_rounded,
  };

  Color get color => switch (this) {
    ReportCategory.waste => AppColors.emerald,
    ReportCategory.parking => AppColors.violet,
    ReportCategory.water => AppColors.sky,
    ReportCategory.streetlight => AppColors.amber,
    ReportCategory.infrastructure => AppColors.teal,
    ReportCategory.road => AppColors.electric,
    ReportCategory.other => const Color(0xFF64748B),
  };

  Severity get defaultSeverity => switch (this) {
    ReportCategory.water => Severity.high,
    ReportCategory.road => Severity.medium,
    ReportCategory.streetlight => Severity.medium,
    ReportCategory.infrastructure => Severity.medium,
    ReportCategory.parking => Severity.low,
    ReportCategory.waste => Severity.medium,
    ReportCategory.other => Severity.low,
  };

  /// Sub-types shown in each category hub.
  List<String> get subtypes => switch (this) {
    ReportCategory.waste => ['Overflowing bin', 'Illegal dumping', 'Missed pickup', 'Burning waste'],
    ReportCategory.parking => ['Blocking road', 'On footpath', 'Blocking entrance', 'No-parking zone'],
    ReportCategory.water => ['Burst pipe', 'Leaking tap / valve', 'Sewage overflow', 'Water wastage'],
    ReportCategory.streetlight => [
      'Broken Streetlight',
      'Damaged Streetlight Pole',
      'Poor / Unmanaged Infrastructure',
      'Other Infrastructure Damage'
    ],
    ReportCategory.infrastructure => [
      'Damaged footpath',
      'Open drain / manhole',
      'Damaged public property',
      'Other Infrastructure Damage'
    ],
    ReportCategory.road => ['Pothole', 'Cracked Road', 'Damaged Road', 'Flooded Road', 'Unmanaged Road', 'Other'],
    ReportCategory.other => ['General issue'],
  };

  bool get asksVehicleNumber => this == ReportCategory.parking;
  bool get asksSeverity => this != ReportCategory.parking;

  String get teamId => switch (this) {
    ReportCategory.waste => 'team-waste',
    ReportCategory.parking => 'team-parking',
    ReportCategory.water => 'team-water',
    ReportCategory.streetlight => 'team-electric',
    ReportCategory.infrastructure => 'team-road',
    ReportCategory.road => 'team-road',
    ReportCategory.other => 'team-road',
  };
}

// ---------------------------------------------------------------------------
// Severity
// ---------------------------------------------------------------------------

enum Severity { low, medium, high, critical }

extension SeverityX on Severity {
  String get label => switch (this) {
    Severity.low => 'Low',
    Severity.medium => 'Medium',
    Severity.high => 'High',
    Severity.critical => 'Critical',
  };
  Color get color => switch (this) {
    Severity.low => AppColors.emerald,
    Severity.medium => AppColors.amber,
    Severity.high => const Color(0xFFF97316),
    Severity.critical => AppColors.red,
  };
  IconData get icon => switch (this) {
    Severity.low => Icons.signal_cellular_alt_1_bar_rounded,
    Severity.medium => Icons.signal_cellular_alt_2_bar_rounded,
    Severity.high => Icons.signal_cellular_alt_rounded,
    Severity.critical => Icons.warning_amber_rounded,
  };
  String get hint => switch (this) {
    Severity.low => 'Minor inconvenience',
    Severity.medium => 'Needs attention soon',
    Severity.high => 'Affects many people',
    Severity.critical => 'Immediate danger',
  };
}

// ---------------------------------------------------------------------------
// Report status — validated state machine
// ---------------------------------------------------------------------------

enum StatusBucket { pending, inProgress, resolved, rejected }

enum ReportStatus {
  draft,
  submitted,
  underReview,
  verified,
  rejected,
  assigned,
  inProgress,
  onTheWay,
  resolved,
  reopened,
  closed,
}

const Map<ReportStatus, Set<ReportStatus>> _transitions = {
  ReportStatus.draft: {ReportStatus.submitted},
  ReportStatus.submitted: {ReportStatus.underReview, ReportStatus.verified, ReportStatus.rejected},
  ReportStatus.underReview: {ReportStatus.verified, ReportStatus.rejected},
  ReportStatus.verified: {ReportStatus.assigned, ReportStatus.rejected},
  ReportStatus.assigned: {ReportStatus.onTheWay, ReportStatus.inProgress, ReportStatus.resolved},
  ReportStatus.onTheWay: {ReportStatus.inProgress, ReportStatus.resolved},
  ReportStatus.inProgress: {ReportStatus.onTheWay, ReportStatus.resolved},
  ReportStatus.resolved: {ReportStatus.closed, ReportStatus.reopened},
  ReportStatus.reopened: {ReportStatus.underReview, ReportStatus.verified, ReportStatus.assigned},
  ReportStatus.rejected: {ReportStatus.closed, ReportStatus.reopened},
  ReportStatus.closed: {ReportStatus.reopened},
};

extension ReportStatusX on ReportStatus {
  Set<ReportStatus> get nextAllowed => _transitions[this] ?? const {};
  bool canTransitionTo(ReportStatus to) => nextAllowed.contains(to);

  String get label => switch (this) {
    ReportStatus.draft => 'Draft',
    ReportStatus.submitted => 'Submitted',
    ReportStatus.underReview => 'Under Review',
    ReportStatus.verified => 'Verified',
    ReportStatus.rejected => 'Rejected',
    ReportStatus.assigned => 'Assigned',
    ReportStatus.inProgress => 'In Progress',
    ReportStatus.onTheWay => 'On The Way',
    ReportStatus.resolved => 'Resolved',
    ReportStatus.reopened => 'Reopened',
    ReportStatus.closed => 'Closed',
  };

  StatusBucket get bucket => switch (this) {
    ReportStatus.draft ||
    ReportStatus.submitted ||
    ReportStatus.underReview ||
    ReportStatus.reopened =>
    StatusBucket.pending,
    ReportStatus.verified ||
    ReportStatus.assigned ||
    ReportStatus.inProgress ||
    ReportStatus.onTheWay =>
    StatusBucket.inProgress,
    ReportStatus.resolved || ReportStatus.closed => StatusBucket.resolved,
    ReportStatus.rejected => StatusBucket.rejected,
  };

  bool get isOpen => bucket == StatusBucket.pending || bucket == StatusBucket.inProgress;

  /// Citizen-facing timeline step: 0 Reported, 1 Verified, 2 Assigned, 3 On the way, 4 Resolved.
  int get citizenStep => switch (this) {
    ReportStatus.draft || ReportStatus.submitted || ReportStatus.underReview || ReportStatus.reopened => 0,
    ReportStatus.verified => 1,
    ReportStatus.assigned => 2,
    ReportStatus.onTheWay || ReportStatus.inProgress => 3,
    ReportStatus.resolved || ReportStatus.closed => 4,
    ReportStatus.rejected => 0,
  };
}

extension StatusBucketX on StatusBucket {
  String get label => switch (this) {
    StatusBucket.pending => 'Pending',
    StatusBucket.inProgress => 'In Progress',
    StatusBucket.resolved => 'Resolved',
    StatusBucket.rejected => 'Rejected',
  };
  Color get color => switch (this) {
    StatusBucket.pending => AppColors.amber,
    StatusBucket.inProgress => AppColors.electric,
    StatusBucket.resolved => AppColors.emerald,
    StatusBucket.rejected => const Color(0xFF64748B),
  };
  IconData get icon => switch (this) {
    StatusBucket.pending => Icons.schedule_rounded,
    StatusBucket.inProgress => Icons.autorenew_rounded,
    StatusBucket.resolved => Icons.check_circle_rounded,
    StatusBucket.rejected => Icons.block_rounded,
  };
}

// ---------------------------------------------------------------------------
// Roles & permissions (RBAC)
// ---------------------------------------------------------------------------

enum UserRole { citizen, operator, teamMember, supervisor, municipalAdmin, systemAdmin }

enum Perm {
  submitReport,
  viewOwnReports,
  viewAllReports,
  verifyReport,
  rejectReport,
  assignTeam,
  updateStatus,
  resolveReport,
  contactCitizen,
  viewCitizenIdentity,
  manageTeams,
  manageUsers,
  configureSla,
  viewAudit,
  viewAnalytics,
  systemConfig,
}

final Map<UserRole, Set<Perm>> rolePermissions = {
  UserRole.citizen: {Perm.submitReport, Perm.viewOwnReports},
  UserRole.teamMember: {Perm.viewAllReports, Perm.updateStatus, Perm.resolveReport},
  UserRole.operator: {
    Perm.viewAllReports,
    Perm.verifyReport,
    Perm.rejectReport,
    Perm.assignTeam,
    Perm.updateStatus,
    Perm.contactCitizen,
    Perm.viewAnalytics,
  },
  UserRole.supervisor: {
    Perm.viewAllReports,
    Perm.verifyReport,
    Perm.rejectReport,
    Perm.assignTeam,
    Perm.updateStatus,
    Perm.resolveReport,
    Perm.contactCitizen,
    Perm.viewCitizenIdentity,
    Perm.manageTeams,
    Perm.viewAudit,
    Perm.viewAnalytics,
  },
  UserRole.municipalAdmin: {
    Perm.viewAllReports,
    Perm.verifyReport,
    Perm.rejectReport,
    Perm.assignTeam,
    Perm.updateStatus,
    Perm.resolveReport,
    Perm.contactCitizen,
    Perm.viewCitizenIdentity,
    Perm.manageTeams,
    Perm.manageUsers,
    Perm.configureSla,
    Perm.viewAudit,
    Perm.viewAnalytics,
  },
  UserRole.systemAdmin: {...Perm.values},
};

extension UserRoleX on UserRole {
  bool can(Perm p) => rolePermissions[this]?.contains(p) ?? false;
  bool get isStaff => this != UserRole.citizen;
  String get label => switch (this) {
    UserRole.citizen => 'Citizen',
    UserRole.operator => 'Municipal Operator',
    UserRole.teamMember => 'Team Member',
    UserRole.supervisor => 'Supervisor',
    UserRole.municipalAdmin => 'Municipal Administrator',
    UserRole.systemAdmin => 'System Administrator',
  };
}

// ---------------------------------------------------------------------------
// Misc enums
// ---------------------------------------------------------------------------

enum EvidenceKind { photo, video }

enum CitizenFeedback { resolved, partial, remains }

enum NotificationType {
  submitted,
  verified,
  rejected,
  assigned,
  statusChanged,
  question,
  pickupScheduled,
  truckApproaching,
  resolved,
  reopened,
  slaEscalation,
  pickupDelayed,
}

extension NotificationTypeX on NotificationType {
  IconData get icon => switch (this) {
    NotificationType.submitted => Icons.outbox_rounded,
    NotificationType.verified => Icons.verified_rounded,
    NotificationType.rejected => Icons.block_rounded,
    NotificationType.assigned => Icons.groups_rounded,
    NotificationType.statusChanged => Icons.sync_rounded,
    NotificationType.question => Icons.help_outline_rounded,
    NotificationType.pickupScheduled => Icons.event_available_rounded,
    NotificationType.truckApproaching => Icons.local_shipping_rounded,
    NotificationType.resolved => Icons.check_circle_rounded,
    NotificationType.reopened => Icons.replay_rounded,
    NotificationType.slaEscalation => Icons.priority_high_rounded,
    NotificationType.pickupDelayed => Icons.timer_off_rounded,
  };
  Color get color => switch (this) {
    NotificationType.resolved || NotificationType.verified => AppColors.emerald,
    NotificationType.rejected || NotificationType.slaEscalation => AppColors.red,
    NotificationType.question || NotificationType.pickupDelayed || NotificationType.reopened =>
    AppColors.amber,
    _ => AppColors.electric,
  };
}

enum PickupStatus { submitted, notified, assigned, enRoute, collected, cancelled }

extension PickupStatusX on PickupStatus {
  String get label => switch (this) {
    PickupStatus.submitted => 'Report Submitted',
    PickupStatus.notified => 'Municipality Notified',
    PickupStatus.assigned => 'Pickup Assigned',
    PickupStatus.enRoute => 'Truck En Route',
    PickupStatus.collected => 'Waste Collected',
    PickupStatus.cancelled => 'Cancelled',
  };
}

enum WasteType { organic, nonOrganic, mixed, hazardous }

extension WasteTypeX on WasteType {
  String get label => switch (this) {
    WasteType.organic => 'Organic Waste',
    WasteType.nonOrganic => 'Non-Organic Waste',
    WasteType.mixed => 'Mixed Waste',
    WasteType.hazardous => 'Hazardous Waste',
  };
  Color get color => switch (this) {
    WasteType.organic => AppColors.emerald,
    WasteType.nonOrganic => AppColors.electric,
    WasteType.mixed => AppColors.amber,
    WasteType.hazardous => AppColors.red,
  };
  IconData get icon => switch (this) {
    WasteType.organic => Icons.eco_rounded,
    WasteType.nonOrganic => Icons.recycling_rounded,
    WasteType.mixed => Icons.delete_sweep_rounded,
    WasteType.hazardous => Icons.dangerous_rounded,
  };
}

enum TeamStatus { available, busy, offDuty }

enum PointKind { water, wasteCollection }
