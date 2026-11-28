import 'package:flutter/widgets.dart';
import 'strings_ne.dart';

/// Lightweight, dependency-free i18n layer.
///
/// Message ids are the English source strings (gettext style), so English
/// never needs a table and any missing translation falls back gracefully.
/// To add a language: create `strings_xx.dart` with a `Map<String, String>`
/// and register it in [_tables] + [supportedLocales].
class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static const supportedLocales = [Locale('en'), Locale('ne')];

  static const Map<String, Map<String, String>> _tables = {
    'ne': neStrings,
  };

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ?? const AppLocalizations(Locale('en'));

  String t(String id, [Map<String, Object?> args = const {}]) {
    var s = _tables[locale.languageCode]?[id] ?? id;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
    return s;
  }

  static const delegate = _Delegate();
}

class _Delegate extends LocalizationsDelegate<AppLocalizations> {
  const _Delegate();
  @override
  bool isSupported(Locale locale) => ['en', 'ne'].contains(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);
  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

extension L10nX on BuildContext {
  /// Translate a user-facing string: `context.t('Report a City Issue')`.
  String t(String id, [Map<String, Object?> args = const {}]) => AppLocalizations.of(this).t(id, args);
}
