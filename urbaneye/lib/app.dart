import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'domain/models/enums.dart';
import 'features/admin/admin_shell.dart';
import 'features/auth/auth_screens.dart';
import 'features/citizen/citizen_shell.dart';
import 'features/onboarding/consent_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/splash_screen.dart';
import 'state/admin_controller.dart';
import 'state/auth_controller.dart';
import 'state/notifications_controller.dart';
import 'state/reports_controller.dart';
import 'state/settings_controller.dart';

class UrbanEyeApp extends StatelessWidget {
  const UrbanEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsController()..load()),
        ChangeNotifierProvider(create: (_) => AuthController()..restore()),
        ChangeNotifierProvider(create: (_) => ReportsController()),
        ChangeNotifierProvider(create: (_) => NotificationsController()),
        ChangeNotifierProvider(create: (_) => WasteController()),
        ChangeNotifierProvider(create: (_) => AdminController()),
        ChangeNotifierProvider(create: (_) => ShellNav()),
      ],
      child: const _SessionBinder(child: _App()),
    );
  }
}

/// Keeps data controllers in sync with the signed-in user.
class _SessionBinder extends StatelessWidget {
  final Widget child;
  const _SessionBinder({required this.child});

  @override
  Widget build(BuildContext context) {
    context.select<AuthController, String?>((a) => a.user?.id); // rebuild on user change
    final auth = context.read<AuthController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final u = auth.user;
      if (u != null && u.role.isStaff) {
        context.read<AdminController>().attach(u);
        context.read<ReportsController>().attach(null);
        context.read<NotificationsController>().attach(null);
        context.read<WasteController>().attach(null);
      } else {
        context.read<AdminController>().attach(null);
        context.read<ReportsController>().attach(u);
        context.read<NotificationsController>().attach(u?.id);
        context.read<WasteController>().attach(u?.id);
      }
    });
    return child;
  }
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    return MaterialApp(
      title: 'UrbanEye',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(dark: false, highContrast: s.highContrast),
      darkTheme: AppTheme.build(dark: true, highContrast: s.highContrast),
      themeMode: s.themeMode,
      locale: s.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scale = (mq.textScaler.scale(1) * s.textScale).clamp(0.85, 1.6);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale), disableAnimations: mq.disableAnimations || s.reducedMotion),
          child: child!,
        );
      },
      home: const SplashScreen(next: RootGate()),
    );
  }
}

/// Decides what the user sees after the splash.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final auth = context.watch<AuthController>();
    final Widget page;
    if (!s.onboardingDone) {
      page = const OnboardingScreen();
    } else if (!s.consentAccepted) {
      page = const ConsentScreen();
    } else if (auth.status == AuthStatus.unknown) {
      page = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (auth.status == AuthStatus.signedOut) {
      page = const LoginScreen();
    } else if (auth.isStaff) {
      page = const AdminShell();
    } else {
      page = const CitizenShell();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
      child: KeyedSubtree(key: ValueKey(page.runtimeType), child: page),
    );
  }
}
