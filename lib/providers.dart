import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/app_user.dart';
import 'services/services.dart';

final authServiceProvider = Provider((_) => AuthService());
final reportServiceProvider = Provider((_) => ReportService());
final adminServiceProvider = Provider((_) => AdminService());
final authStateProvider = StreamProvider<User?>((_) => FirebaseAuth.instance.authStateChanges());
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final u = ref.watch(authStateProvider).value;
  return u == null ? Stream.value(null) : UserService().watch(u.uid);
});
