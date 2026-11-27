import 'package:flutter/material.dart';

import '../core/config/env.dart';
import '../core/di/service_locator.dart';

/// User preferences: theme, language, accessibility, privacy, notifications.
class SettingsController extends ChangeNotifier {
  final _s = Services.I.store;

  ThemeMode themeMode = ThemeMode.system;
  Locale locale = const Locale('en');
  bool reducedMotion = false;
  bool highContrast = false;
  double textScale = 1.0;
  bool onboardingDone = false;
  bool consentAccepted = false;
  DateTime? consentAt;

  // Privacy
  bool anonymousByDefault = false;
  bool approximateLocation = false;
  bool shareStatsPublicly = true;
  int retentionMonths = 24;

  // Notification preferences
  final Map<String, bool> notificationPrefs = {
    'Report updates': true,
    'Municipality questions': true,
    'Waste pickup & truck alerts': true,
    'Nearby issues': false,
    'City announcements': true,
  };

  void load() {
    themeMode = ThemeMode.values[(_s.getDouble('themeMode', 0)).toInt()];
    locale = Locale(_s.getString('locale') ?? 'en');
    reducedMotion = _s.getBool('reducedMotion');
    highContrast = _s.getBool('highContrast');
    textScale = _s.getDouble('textScale', 1.0);
    onboardingDone = _s.getBool('onboardingDone');
    consentAccepted = _s.getString('consentVersion') == Env.consentVersion;
    consentAt = DateTime.tryParse(_s.getString('consentAt') ?? '');
    anonymousByDefault = _s.getBool('anonymousByDefault');
    approximateLocation = _s.getBool('approximateLocation');
    shareStatsPublicly = _s.getBool('shareStatsPublicly', true);
    for (final k in notificationPrefs.keys.toList()) {
      notificationPrefs[k] = _s.getBool('notif:$k', notificationPrefs[k]!);
    }
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _s.setDouble('themeMode', m.index.toDouble());
    notifyListeners();
  }

  void setLocale(Locale l) {
    locale = l;
    _s.setString('locale', l.languageCode);
    notifyListeners();
  }

  void setReducedMotion(bool v) {
    reducedMotion = v;
    _s.setBool('reducedMotion', v);
    notifyListeners();
  }

  void setHighContrast(bool v) {
    highContrast = v;
    _s.setBool('highContrast', v);
    notifyListeners();
  }

  void setTextScale(double v) {
    textScale = v;
    _s.setDouble('textScale', v);
    notifyListeners();
  }

  void completeOnboarding() {
    onboardingDone = true;
    _s.setBool('onboardingDone', true);
    notifyListeners();
  }

  void acceptConsent() {
    consentAccepted = true;
    consentAt = DateTime.now();
    _s.setString('consentVersion', Env.consentVersion);
    _s.setString('consentAt', consentAt!.toIso8601String());
    notifyListeners();
  }

  void setAnonymousByDefault(bool v) {
    anonymousByDefault = v;
    _s.setBool('anonymousByDefault', v);
    notifyListeners();
  }

  void setApproximateLocation(bool v) {
    approximateLocation = v;
    _s.setBool('approximateLocation', v);
    notifyListeners();
  }

  void setShareStats(bool v) {
    shareStatsPublicly = v;
    _s.setBool('shareStatsPublicly', v);
    notifyListeners();
  }

  void setNotificationPref(String k, bool v) {
    notificationPrefs[k] = v;
    _s.setBool('notif:$k', v);
    notifyListeners();
  }

  /// Used by "Delete account": wipe local data but keep the device-level
  /// onboarding/consent so the app still opens sensibly.
  Future<void> clearPersonalData() async {
    for (final k in ['drafts', 'outbox', 'session_uid', 'anonymousByDefault', 'approximateLocation']) {
      await _s.remove(k);
    }
    anonymousByDefault = false;
    approximateLocation = false;
    notifyListeners();
  }
}
