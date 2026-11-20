import 'package:flutter_test/flutter_test.dart';
import 'package:urbaneye/domain/models/enums.dart';

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
}
