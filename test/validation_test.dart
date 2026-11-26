import 'package:flutter_test/flutter_test.dart';
import 'package:urbaneye/core/constants/app_constants.dart';
import 'package:urbaneye/services/services.dart';

void main() {
  test('Nepali mobile validation', () {
    expect(AuthService.validNepaliNumber('9841234567'), true);
    expect(AuthService.validNepaliNumber('9741234567'), true);
    expect(AuthService.validNepaliNumber('1234567890'), false);
    expect(AuthService.validNepaliNumber('98412'), false);
  });
  test('Email validation', () {
    expect(AdminService.validEmail('a@b.com'), true);
    expect(AdminService.validEmail('bad@'), false);
  });
  test('6 categories, street light has exposed wire', () {
    expect(AppConstants.categories.length, 6);
    expect(AppConstants.byName('Street Light').subs, contains('exposed wire'));
  });
  test('Municipality bounds', () {
    expect(LocationService.insideMunicipality(27.7172, 85.3240), true);
    expect(LocationService.insideMunicipality(28.5, 84.0), false);
  });
}
