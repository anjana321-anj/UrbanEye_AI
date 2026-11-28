import 'package:flutter/foundation.dart';

import '../core/di/service_locator.dart';
import '../domain/models/enums.dart';
import '../domain/models/models.dart';
import '../domain/repositories/repositories.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthController extends ChangeNotifier {
  final AuthRepository _repo = Services.I.auth;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  bool busy = false;
  String? error;
  bool sessionExpired = false;

  bool get isStaff => user?.role.isStaff ?? false;
  bool can(Perm p) => user?.role.can(p) ?? false;

  Future<void> restore() async {
    try {
      user = await _repo.restoreSession();
    } catch (_) {
      user = null;
    }
    status = user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }

  Future<bool> _run(Future<AppUser> Function() fn) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      user = await fn();
      status = AuthStatus.signedIn;
      sessionExpired = false;
      return true;
    } on AuthException catch (e) {
      error = e.message;
      return false;
    } catch (e) {
      error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> login(String id, String pw) => _run(() => _repo.login(id.trim(), pw));
  Future<bool> loginWith(String provider) => _run(() => _repo.loginWithProvider(provider));
  Future<bool> loginStaff(String email, String pw) => _run(() => _repo.loginStaff(email.trim(), pw));
  Future<bool> signUp({required String name, required String phone, required String email, required String password}) =>
      _run(() => _repo.signUp(name: name.trim(), phone: phone.trim(), email: email.trim(), password: password));

  Future<void> sendOtp(String dest) => _repo.sendOtp(dest);
  Future<bool> verifyOtp(String dest, String code) => _repo.verifyOtp(dest, code);
  Future<void> resetPassword(String dest, String pw) => _repo.resetPassword(dest, pw);

  Future<bool> updateProfile({String? name, String? email, String? phone, String? city}) async {
    final u = user;
    if (u == null) return false;
    if (name != null) u.name = name;
    if (email != null) u.email = email;
    if (phone != null) u.phone = phone;
    if (city != null) u.city = city;
    return _run(() => _repo.updateProfile(u));
  }

  void expireSession() {
    sessionExpired = true;
    logout();
  }

  Future<void> logout() async {
    await _repo.logout();
    user = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    final u = user;
    if (u == null) return;
    await _repo.deleteAccount(u.id);
    user = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
