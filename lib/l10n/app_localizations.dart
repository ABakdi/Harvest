import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Harvest'**
  String get appTitle;

  /// No description provided for @navField.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get navField;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @fieldEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your field is ready'**
  String get fieldEmptyTitle;

  /// No description provided for @fieldEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Plant your first seed — a habit, a project, or a simple to-do.'**
  String get fieldEmptyBody;

  /// No description provided for @statsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to count yet'**
  String get statsEmptyTitle;

  /// No description provided for @statsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your harvest numbers will grow here as you log your days.'**
  String get statsEmptyBody;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get langSystem;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get langArabic;

  /// No description provided for @addCommitment.
  ///
  /// In en, this message translates to:
  /// **'Plant a seed'**
  String get addCommitment;

  /// No description provided for @typeHabit.
  ///
  /// In en, this message translates to:
  /// **'Habit'**
  String get typeHabit;

  /// No description provided for @typeProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get typeProject;

  /// No description provided for @typeTodo.
  ///
  /// In en, this message translates to:
  /// **'To-Do'**
  String get typeTodo;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @titleHintHabit.
  ///
  /// In en, this message translates to:
  /// **'e.g. Exercise, Practice Spanish'**
  String get titleHintHabit;

  /// No description provided for @titleHintProject.
  ///
  /// In en, this message translates to:
  /// **'e.g. Read Atomic Habits'**
  String get titleHintProject;

  /// No description provided for @titleHintTodo.
  ///
  /// In en, this message translates to:
  /// **'e.g. Call the dentist'**
  String get titleHintTodo;

  /// No description provided for @scheduleLabel.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleLabel;

  /// No description provided for @scheduleDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get scheduleDaily;

  /// No description provided for @scheduleWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get scheduleWeekly;

  /// No description provided for @scheduleInterval.
  ///
  /// In en, this message translates to:
  /// **'Every X days'**
  String get scheduleInterval;

  /// No description provided for @scheduleTimesPerWeek.
  ///
  /// In en, this message translates to:
  /// **'X per week'**
  String get scheduleTimesPerWeek;

  /// No description provided for @everyDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Every {count} days'**
  String everyDaysLabel(int count);

  /// No description provided for @timesPerWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} times per week'**
  String timesPerWeekLabel(int count);

  /// No description provided for @totalTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Total target (pages, minutes…)'**
  String get totalTargetLabel;

  /// No description provided for @dailyCommitmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Daily commitment'**
  String get dailyCommitmentLabel;

  /// No description provided for @dueLabel.
  ///
  /// In en, this message translates to:
  /// **'Planned for'**
  String get dueLabel;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dueToday;

  /// No description provided for @dueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get dueTomorrow;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @undoCheckInTitle.
  ///
  /// In en, this message translates to:
  /// **'Undo today\'s check-in?'**
  String get undoCheckInTitle;

  /// No description provided for @undoCheckInBody.
  ///
  /// In en, this message translates to:
  /// **'This removes what you logged for \"{title}\" today.'**
  String undoCheckInBody(String title);

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @logProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Water this crop'**
  String get logProgressTitle;

  /// No description provided for @logQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'How much did you get done?'**
  String get logQuantityLabel;

  /// No description provided for @logRemainingToday.
  ///
  /// In en, this message translates to:
  /// **'You can log {count} more today'**
  String logRemainingToday(int count);

  /// No description provided for @log.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get log;

  /// No description provided for @cappedMessage.
  ///
  /// In en, this message translates to:
  /// **'Daily cap reached — the field rests too.'**
  String get cappedMessage;

  /// No description provided for @xpEarned.
  ///
  /// In en, this message translates to:
  /// **'+{count} XP'**
  String xpEarned(int count);

  /// No description provided for @projectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} · today {today}/{daily}'**
  String projectSubtitle(int done, int total, int today, int daily);

  /// No description provided for @todoOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get todoOverdue;

  /// No description provided for @rankSprout.
  ///
  /// In en, this message translates to:
  /// **'Sprout'**
  String get rankSprout;

  /// No description provided for @rankSeedling.
  ///
  /// In en, this message translates to:
  /// **'Seedling'**
  String get rankSeedling;

  /// No description provided for @rankGardener.
  ///
  /// In en, this message translates to:
  /// **'Gardener'**
  String get rankGardener;

  /// No description provided for @rankHarvester.
  ///
  /// In en, this message translates to:
  /// **'Harvester'**
  String get rankHarvester;

  /// No description provided for @rankMasterFarmer.
  ///
  /// In en, this message translates to:
  /// **'Master Farmer'**
  String get rankMasterFarmer;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
