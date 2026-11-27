import 'package:flutter_test/flutter_test.dart';
import 'package:urbaneye/domain/models/enums.dart';
<<<<<<< HEAD
=======
import 'package:urbaneye/domain/models/models.dart';
>>>>>>> origin/lakpa-sherpa

void main() {
  test('report status transitions are validated', () {
    expect(ReportStatus.submitted.canTransitionTo(ReportStatus.verified), isTrue);
    expect(ReportStatus.submitted.canTransitionTo(ReportStatus.resolved), isFalse);
    expect(ReportStatus.resolved.canTransitionTo(ReportStatus.reopened), isTrue);
  });

  test('role permissions', () {
    expect(UserRole.citizen.can(Perm.assignTeam), isFalse);
    expect(UserRole.supervisor.can(Perm.assignTeam), isTrue);
    expect(UserRole.operator.can(Perm.configureSla), isFalse);
  });
<<<<<<< HEAD
=======

  test('GeoPoint equality and distance calculation', () {
    const p1 = GeoPoint(27.7040, 85.3200);
    const p2 = GeoPoint(27.7040, 85.3200);
    const p3 = GeoPoint(27.7154, 85.3123);

    expect(p1, equals(p2));
    expect(p1.hashCode, equals(p2.hashCode));
    expect(p1.distanceTo(p3), greaterThan(0));
  });

  test('PlaceLocation serialization and equality', () {
    const loc = PlaceLocation(
      point: GeoPoint(27.7040, 85.3200),
      address: 'Putalisadak Marg',
      area: 'Putalisadak',
      accuracyMeters: 10.0,
    );

    final json = loc.toJson();
    final parsed = PlaceLocation.fromJson(json);
    expect(parsed, equals(loc));
  });

  test('Evidence and ReportDraft serialization resilience', () {
    final draft = ReportDraft(
      localId: 'draft-test-1',
      category: ReportCategory.waste,
      description: 'Overflowing bin near main road',
      severity: Severity.high,
    );

    final json = draft.toJson();
    final parsed = ReportDraft.fromJson(json);

    expect(parsed.localId, equals(draft.localId));
    expect(parsed.category, equals(ReportCategory.waste));
    expect(parsed.description, equals(draft.description));
    expect(parsed.severity, equals(Severity.high));
  });
>>>>>>> origin/lakpa-sherpa
}
