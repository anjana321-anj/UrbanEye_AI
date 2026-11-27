<<<<<<< HEAD
import '../../data/api/api_client.dart';
import '../../data/mock/mock_repositories.dart';
import '../../data/services/device_services.dart';
import '../../domain/repositories/repositories.dart';
import '../config/env.dart';

/// Composition root. The rest of the app only asks for interfaces.
/// To connect the real backend, provide HTTP implementations here when
=======
import 'package:firebase_core/firebase_core.dart';
import '../../data/api/api_client.dart';
import '../../data/firebase/firebase_repositories.dart';
import '../../data/mock/mock_repositories.dart';
import '../../data/services/device_services.dart';
import '../../domain/repositories/repositories.dart';
import '../../firebase_options.dart';
import '../config/env.dart';

/// Composition root. The rest of the app only asks for interfaces.
/// To connect the real backend, provide HTTP/Firebase implementations here when
>>>>>>> origin/lakpa-sherpa
/// `Env.useMockBackend` is false — no UI code changes required.
class Services {
  Services._();
  static late final Services I;

  late final ApiClient api;
  late final AuthRepository auth;
  late final ReportRepository reports;
  late final NotificationRepository notifications;
  late final TeamRepository teams;
  late final WasteRepository waste;
  late final AnalyticsRepository analytics;
  late final LocationRepository locations;
  late final AiService ai;

  late final PermissionService permissions;
  late final LocationService gps;
  late final ConnectivityService connectivity;
  late final LocalStore store;

  static Future<void> init() async {
    final s = Services._();
    s.api = ApiClient();
<<<<<<< HEAD
    // if (!Env.useMockBackend) { s.reports = HttpReportRepository(s.api); ... }
    // Env.useMockBackend == false → construct HTTP repositories here instead.
    if (!Env.useMockBackend) {
      // ignore: avoid_print
      print('USE_MOCK_BACKEND=false: HTTP repositories not wired yet, falling back to mocks.');
    }
    s.auth = MockAuthRepository();
    s.reports = MockReportRepository();
=======

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {}

    if (!Env.useMockBackend) {
      s.auth = FirestoreAuthRepository();
      s.reports = FirestoreReportRepository();
    } else {
      s.auth = MockAuthRepository();
      s.reports = MockReportRepository();
    }

>>>>>>> origin/lakpa-sherpa
    s.notifications = MockNotificationRepository();
    s.teams = MockTeamRepository();
    s.waste = MockWasteRepository();
    s.analytics = MockAnalyticsRepository();
    s.locations = MockLocationRepository();
    s.ai = MockAiService();

    s.permissions = PermissionService();
    s.gps = LocationService();
    s.connectivity = ConnectivityService();
    s.store = LocalStore();
    await s.store.init();
    await s.connectivity.init();
    I = s;
  }
}
