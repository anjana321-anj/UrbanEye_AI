import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers.dart';
import 'screens/screens.dart';

/// US-02: role-based routing. Each role gets its own home; cross-role paths -> Access Denied.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(currentUserProvider, (_, __) => refresh.value++);
  ref.listen(authStateProvider, (_, __) => refresh.value++);
  String homeFor(String role) => switch (role) {
        'super_admin' => '/super',
        'department_admin' => '/admin',
        'field_worker' => '/worker',
        _ => '/citizen',
      };
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (ctx, state) {
      final auth = ref.read(authStateProvider);
      final user = ref.read(currentUserProvider);
      final loc = state.matchedLocation;
      if (auth.isLoading || (auth.value != null && user.isLoading)) return '/splash';
      if (auth.value == null) return loc == '/login' ? null : '/login';
      final u = user.value;
      if (u == null) return '/splash';
      if (!u.isActive) return '/denied';
      final home = homeFor(u.role);
      if (loc == '/splash' || loc == '/login') return home;
      const roleRoots = {'/citizen': 'citizen', '/admin': 'department_admin', '/super': 'super_admin', '/worker': 'field_worker'};
      for (final e in roleRoots.entries) {
        if (loc.startsWith(e.key) && e.value != u.role) return '/denied';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/denied', builder: (_, __) => const AccessDeniedScreen()),
      GoRoute(path: '/citizen', builder: (_, __) => const CitizenHome()),
      GoRoute(path: '/citizen/submit', builder: (_, __) => const SubmitReportScreen()),
      GoRoute(path: '/citizen/success/:id', builder: (_, s) => SuccessScreen(reportId: s.pathParameters['id']!)),
      GoRoute(path: '/report/:id', builder: (_, s) => ReportDetailScreen(reportId: s.pathParameters['id']!)),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboard()),
      GoRoute(path: '/worker', builder: (_, __) => const AdminDashboard(workerMode: true)),
      GoRoute(path: '/super', builder: (_, __) => const SuperAdminScreen()),
    ],
  );
});
