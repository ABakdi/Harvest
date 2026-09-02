// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Harvest';

  @override
  String get navField => 'Field';

  @override
  String get navStats => 'Stats';

  @override
  String get navSettings => 'Settings';

  @override
  String get fieldEmptyTitle => 'Your field is ready';

  @override
  String get fieldEmptyBody =>
      'Plant your first seed — a habit, a project, or a simple to-do.';

  @override
  String get statsEmptyTitle => 'Nothing to count yet';

  @override
  String get statsEmptyBody =>
      'Your harvest numbers will grow here as you log your days.';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get langSystem => 'System';

  @override
  String get langEnglish => 'English';

  @override
  String get langArabic => 'العربية';
}
