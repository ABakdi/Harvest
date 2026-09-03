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
  /// **'Specific days'**
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
  /// **'Log progress'**
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

  /// No description provided for @settingsHarvest.
  ///
  /// In en, this message translates to:
  /// **'Harvest'**
  String get settingsHarvest;

  /// No description provided for @settingsGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Harvest Goal'**
  String get settingsGoalTitle;

  /// No description provided for @settingsGoalBody.
  ///
  /// In en, this message translates to:
  /// **'Productive actions needed each day to keep your streak alive.'**
  String get settingsGoalBody;

  /// No description provided for @goalActions.
  ///
  /// In en, this message translates to:
  /// **'{count} actions a day'**
  String goalActions(int count);

  /// No description provided for @streakSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Your streak'**
  String get streakSheetTitle;

  /// No description provided for @streakCurrent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String streakCurrent(int count);

  /// No description provided for @streakBest.
  ///
  /// In en, this message translates to:
  /// **'Best: {count}'**
  String streakBest(int count);

  /// No description provided for @freezesStored.
  ///
  /// In en, this message translates to:
  /// **'Streak freezes: {count} of {max}'**
  String freezesStored(int count, int max);

  /// No description provided for @freezeExplainer.
  ///
  /// In en, this message translates to:
  /// **'A freeze protects your streak for one missed day. It\'s used automatically.'**
  String get freezeExplainer;

  /// No description provided for @buyFreeze.
  ///
  /// In en, this message translates to:
  /// **'Buy a freeze · {cost} coins'**
  String buyFreeze(int cost);

  /// No description provided for @freezeBought.
  ///
  /// In en, this message translates to:
  /// **'Freeze stored. Rest easy. ❄️'**
  String get freezeBought;

  /// No description provided for @freezeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins, or the shed is full.'**
  String get freezeUnavailable;

  /// No description provided for @coinBalance.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 coin} other{{count} coins}}'**
  String coinBalance(int count);

  /// No description provided for @pomodoroTitle.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get pomodoroTitle;

  /// No description provided for @phaseFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get phaseFocus;

  /// No description provided for @phaseShortBreak.
  ///
  /// In en, this message translates to:
  /// **'Short break'**
  String get phaseShortBreak;

  /// No description provided for @phaseLongBreak.
  ///
  /// In en, this message translates to:
  /// **'Long break'**
  String get phaseLongBreak;

  /// No description provided for @startFocus.
  ///
  /// In en, this message translates to:
  /// **'Start focus'**
  String get startFocus;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @finishSession.
  ///
  /// In en, this message translates to:
  /// **'Finish session'**
  String get finishSession;

  /// No description provided for @abandonSession.
  ///
  /// In en, this message translates to:
  /// **'Abandon'**
  String get abandonSession;

  /// No description provided for @abandonBody.
  ///
  /// In en, this message translates to:
  /// **'The field will wait.'**
  String get abandonBody;

  /// No description provided for @freeSession.
  ///
  /// In en, this message translates to:
  /// **'Free focus'**
  String get freeSession;

  /// No description provided for @blocksDone.
  ///
  /// In en, this message translates to:
  /// **'{count} blocks done'**
  String blocksDone(int count);

  /// No description provided for @breakOverReady.
  ///
  /// In en, this message translates to:
  /// **'Break over — ready for the next block'**
  String get breakOverReady;

  /// No description provided for @plannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow\'s plan'**
  String get plannerTitle;

  /// No description provided for @plannerHabitsDue.
  ///
  /// In en, this message translates to:
  /// **'Habits due tomorrow'**
  String get plannerHabitsDue;

  /// No description provided for @plannerTodos.
  ///
  /// In en, this message translates to:
  /// **'To-dos for tomorrow'**
  String get plannerTodos;

  /// No description provided for @plannerAddHint.
  ///
  /// In en, this message translates to:
  /// **'Plant a to-do for tomorrow…'**
  String get plannerAddHint;

  /// No description provided for @plannerEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned yet. Add tomorrow\'s seeds tonight and wake up ready.'**
  String get plannerEmpty;

  /// No description provided for @notifMorningTitle.
  ///
  /// In en, this message translates to:
  /// **'Good morning! ☀️'**
  String get notifMorningTitle;

  /// No description provided for @notifMorningBody.
  ///
  /// In en, this message translates to:
  /// **'Check today\'s harvest plan and log your first seed.'**
  String get notifMorningBody;

  /// No description provided for @notifEveningTitle.
  ///
  /// In en, this message translates to:
  /// **'The sun is setting 🌙'**
  String get notifEveningTitle;

  /// No description provided for @notifEveningBody.
  ///
  /// In en, this message translates to:
  /// **'Wind down and plant tomorrow\'s plan.'**
  String get notifEveningBody;

  /// No description provided for @notifStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'Your crops are thirsty! 🔥'**
  String get notifStreakTitle;

  /// No description provided for @notifStreakBody.
  ///
  /// In en, this message translates to:
  /// **'Log your remaining tasks before 3 AM to save your streak.'**
  String get notifStreakBody;

  /// No description provided for @settingsReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsReminders;

  /// No description provided for @remindersMaster.
  ///
  /// In en, this message translates to:
  /// **'Allow reminders'**
  String get remindersMaster;

  /// No description provided for @remindersMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning: today\'s plan'**
  String get remindersMorning;

  /// No description provided for @remindersEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening: plan tomorrow'**
  String get remindersEvening;

  /// No description provided for @remindersStreak.
  ///
  /// In en, this message translates to:
  /// **'Late streak warning'**
  String get remindersStreak;

  /// No description provided for @obWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Harvest'**
  String get obWelcomeTitle;

  /// No description provided for @obWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Your goals are seeds. Your effort is water. Distractions are weeds.\n\nShow up a little every day, keep your streak alive, and harvest the life you\'re growing.'**
  String get obWelcomeBody;

  /// No description provided for @obTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Plant your first seeds'**
  String get obTemplatesTitle;

  /// No description provided for @obTemplatesBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a few to start with — you can always plant more.'**
  String get obTemplatesBody;

  /// No description provided for @tmplRead.
  ///
  /// In en, this message translates to:
  /// **'Read a book (300 pages)'**
  String get tmplRead;

  /// No description provided for @tmplFit.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get tmplFit;

  /// No description provided for @tmplLanguage.
  ///
  /// In en, this message translates to:
  /// **'Practice a language'**
  String get tmplLanguage;

  /// No description provided for @tmplMeditate.
  ///
  /// In en, this message translates to:
  /// **'Meditate (3× a week)'**
  String get tmplMeditate;

  /// No description provided for @tmplJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal before bed'**
  String get tmplJournal;

  /// No description provided for @obGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Harvest Goal'**
  String get obGoalTitle;

  /// No description provided for @obRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Gentle reminders'**
  String get obRemindersTitle;

  /// No description provided for @obRemindersBody.
  ///
  /// In en, this message translates to:
  /// **'Harvest nudges, never nags: a morning review, an evening planning ritual, and a heads-up when your streak is at risk.'**
  String get obRemindersBody;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @startGrowing.
  ///
  /// In en, this message translates to:
  /// **'Start growing 🌱'**
  String get startGrowing;

  /// No description provided for @statsBestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best streak'**
  String get statsBestStreak;

  /// No description provided for @statsCheckIns.
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get statsCheckIns;

  /// No description provided for @statsActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get statsActivity;

  /// No description provided for @statsProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get statsProjects;

  /// No description provided for @statsHabitStreaks.
  ///
  /// In en, this message translates to:
  /// **'Habit streaks'**
  String get statsHabitStreaks;

  /// No description provided for @statsStreakOf.
  ///
  /// In en, this message translates to:
  /// **'{current} now · best {best}'**
  String statsStreakOf(int current, int best);

  /// No description provided for @navGranary.
  ///
  /// In en, this message translates to:
  /// **'Granary'**
  String get navGranary;

  /// No description provided for @granaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Granary'**
  String get granaryTitle;

  /// No description provided for @logExpense.
  ///
  /// In en, this message translates to:
  /// **'Log an expense'**
  String get logExpense;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteLabel;

  /// No description provided for @catFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get catFood;

  /// No description provided for @catTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get catTransport;

  /// No description provided for @catBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get catBills;

  /// No description provided for @catShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get catShopping;

  /// No description provided for @catHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get catHealth;

  /// No description provided for @catEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Fun'**
  String get catEntertainment;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @todaySpending.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todaySpending;

  /// No description provided for @budgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly budget'**
  String get budgetTitle;

  /// No description provided for @budgetSpentOf.
  ///
  /// In en, this message translates to:
  /// **'{spent} of {budget} this month'**
  String budgetSpentOf(String spent, String budget);

  /// No description provided for @budgetFloating.
  ///
  /// In en, this message translates to:
  /// **'{spent} / {limit} today'**
  String budgetFloating(String spent, String limit);

  /// No description provided for @budgetSet.
  ///
  /// In en, this message translates to:
  /// **'Set a monthly budget'**
  String get budgetSet;

  /// No description provided for @budgetAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget for the month'**
  String get budgetAmountLabel;

  /// No description provided for @currencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency symbol'**
  String get currencyLabel;

  /// No description provided for @granaryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged today. What did you spend?'**
  String get granaryEmpty;

  /// No description provided for @repeatSuggestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Same as the last 3 days?'**
  String get repeatSuggestionTitle;

  /// No description provided for @logIt.
  ///
  /// In en, this message translates to:
  /// **'Log it'**
  String get logIt;

  /// No description provided for @notifExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'What did you spend today? 💰'**
  String get notifExpenseTitle;

  /// No description provided for @notifExpenseBody.
  ///
  /// In en, this message translates to:
  /// **'Log it in two taps and keep the granary honest.'**
  String get notifExpenseBody;

  /// No description provided for @remindersExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense check-in'**
  String get remindersExpense;

  /// No description provided for @statsSpending.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get statsSpending;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get deleted;

  /// No description provided for @editSeed.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editSeed;

  /// No description provided for @focusTimer.
  ///
  /// In en, this message translates to:
  /// **'Focus timer'**
  String get focusTimer;

  /// No description provided for @pauseHabit.
  ///
  /// In en, this message translates to:
  /// **'Pause (vacation)'**
  String get pauseHabit;

  /// No description provided for @resumeHabit.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeHabit;

  /// No description provided for @pausedLabel.
  ///
  /// In en, this message translates to:
  /// **'Paused — resting'**
  String get pausedLabel;

  /// No description provided for @archiveAction.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveAction;

  /// No description provided for @archiveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this seed?'**
  String get archiveConfirmTitle;

  /// No description provided for @archiveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" is archived. Its history stays.'**
  String archiveConfirmBody(String title);

  /// No description provided for @projectDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Harvest complete! 🎉'**
  String get projectDoneTitle;

  /// No description provided for @projectDoneBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" is fully grown — {total} logged. It is archived with pride.'**
  String projectDoneBody(String title, int total);

  /// No description provided for @toTheBarn.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get toTheBarn;

  /// No description provided for @weeklyReport.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get weeklyReport;

  /// No description provided for @weeklyXp.
  ///
  /// In en, this message translates to:
  /// **'{count} XP'**
  String weeklyXp(int count);

  /// No description provided for @weeklyBestDay.
  ///
  /// In en, this message translates to:
  /// **'Best: {day}'**
  String weeklyBestDay(String day);

  /// No description provided for @weeklyWorstDay.
  ///
  /// In en, this message translates to:
  /// **'Quietest: {day}'**
  String weeklyWorstDay(String day);

  /// No description provided for @weeklyTopSpending.
  ///
  /// In en, this message translates to:
  /// **'Top spending: {category}'**
  String weeklyTopSpending(String category);

  /// No description provided for @settingsPomodoro.
  ///
  /// In en, this message translates to:
  /// **'Focus timer'**
  String get settingsPomodoro;

  /// No description provided for @pomodoroFocusLen.
  ///
  /// In en, this message translates to:
  /// **'Focus length'**
  String get pomodoroFocusLen;

  /// No description provided for @pomodoroShortLen.
  ///
  /// In en, this message translates to:
  /// **'Short break'**
  String get pomodoroShortLen;

  /// No description provided for @pomodoroLongLen.
  ///
  /// In en, this message translates to:
  /// **'Long break'**
  String get pomodoroLongLen;

  /// No description provided for @pomodoroBlocks.
  ///
  /// In en, this message translates to:
  /// **'Blocks before a long break'**
  String get pomodoroBlocks;

  /// No description provided for @minutesValue.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minutesValue(int count);

  /// No description provided for @settingsStyle.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get settingsStyle;

  /// No description provided for @presetHarvest.
  ///
  /// In en, this message translates to:
  /// **'Harvest'**
  String get presetHarvest;

  /// No description provided for @presetSunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get presetSunrise;

  /// No description provided for @presetOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get presetOcean;

  /// No description provided for @presetOrchard.
  ///
  /// In en, this message translates to:
  /// **'Orchard'**
  String get presetOrchard;

  /// No description provided for @presetDusk.
  ///
  /// In en, this message translates to:
  /// **'Dusk'**
  String get presetDusk;

  /// No description provided for @advancedOptions.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedOptions;

  /// No description provided for @seedNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get seedNoteLabel;

  /// No description provided for @remindMeAt.
  ///
  /// In en, this message translates to:
  /// **'Remind me at'**
  String get remindMeAt;

  /// No description provided for @deadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Accomplish before'**
  String get deadlineLabel;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @pickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get pickDate;

  /// No description provided for @dueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dueOn(String date);

  /// No description provided for @overdueBy.
  ///
  /// In en, this message translates to:
  /// **'Overdue — was due {date}'**
  String overdueBy(String date);

  /// No description provided for @taskReminderBody.
  ///
  /// In en, this message translates to:
  /// **'A seed is waiting to be watered.'**
  String get taskReminderBody;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// No description provided for @manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Custom categories'**
  String get manageCategories;

  /// No description provided for @todayTab.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTab;

  /// No description provided for @insightsTab.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTab;

  /// No description provided for @savingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get savingsLabel;

  /// No description provided for @expectedDailyLabel.
  ///
  /// In en, this message translates to:
  /// **'Expected daily spend'**
  String get expectedDailyLabel;

  /// No description provided for @savingsLow.
  ///
  /// In en, this message translates to:
  /// **'Savings running low'**
  String get savingsLow;

  /// No description provided for @rangeWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get rangeWeek;

  /// No description provided for @rangeMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get rangeMonth;

  /// No description provided for @totalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalSpent;

  /// No description provided for @avgPerDay.
  ///
  /// In en, this message translates to:
  /// **'{amount} / day'**
  String avgPerDay(String amount);

  /// No description provided for @noSpendingYet.
  ///
  /// In en, this message translates to:
  /// **'No spending in this range yet.'**
  String get noSpendingYet;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @calNothingDue.
  ///
  /// In en, this message translates to:
  /// **'Nothing planted for this day.'**
  String get calNothingDue;

  /// No description provided for @calDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline: {title}'**
  String calDeadline(String title);

  /// No description provided for @calAddForDay.
  ///
  /// In en, this message translates to:
  /// **'Plant a to-do for this day…'**
  String get calAddForDay;

  /// No description provided for @defaultCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Default currency'**
  String get defaultCurrencyLabel;

  /// No description provided for @expenseCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get expenseCurrencyLabel;

  /// No description provided for @exchangeRates.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates'**
  String get exchangeRates;

  /// No description provided for @ratesDzdUsd.
  ///
  /// In en, this message translates to:
  /// **'DZD per 1 USD'**
  String get ratesDzdUsd;

  /// No description provided for @ratesDzdEur.
  ///
  /// In en, this message translates to:
  /// **'DZD per 1 EUR'**
  String get ratesDzdEur;

  /// No description provided for @ratesEurUsd.
  ///
  /// In en, this message translates to:
  /// **'EUR → USD (fetched)'**
  String get ratesEurUsd;

  /// No description provided for @fetchNow.
  ///
  /// In en, this message translates to:
  /// **'Fetch'**
  String get fetchNow;

  /// No description provided for @ratesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {when}'**
  String ratesUpdated(String when);

  /// No description provided for @ratesFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t fetch — check the connection.'**
  String get ratesFetchFailed;

  /// No description provided for @savingsIn.
  ///
  /// In en, this message translates to:
  /// **'Savings · {code}'**
  String savingsIn(String code);

  /// No description provided for @vaultTab.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get vaultTab;

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletTitle;

  /// No description provided for @walletAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get walletAdd;

  /// No description provided for @walletTake.
  ///
  /// In en, this message translates to:
  /// **'Take'**
  String get walletTake;

  /// No description provided for @savingsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get savingsSectionTitle;

  /// No description provided for @savingsDeposit.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get savingsDeposit;

  /// No description provided for @savingsWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get savingsWithdraw;

  /// No description provided for @amountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountPrompt;

  /// No description provided for @withdrawDestination.
  ///
  /// In en, this message translates to:
  /// **'Where does it go?'**
  String get withdrawDestination;

  /// No description provided for @toWallet.
  ///
  /// In en, this message translates to:
  /// **'To the wallet'**
  String get toWallet;

  /// No description provided for @asExpense.
  ///
  /// In en, this message translates to:
  /// **'Log as expense'**
  String get asExpense;

  /// No description provided for @takeFromWallet.
  ///
  /// In en, this message translates to:
  /// **'Take it from the wallet?'**
  String get takeFromWallet;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @debtsTitle.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get debtsTitle;

  /// No description provided for @addDebt.
  ///
  /// In en, this message translates to:
  /// **'Log a debt'**
  String get addDebt;

  /// No description provided for @debtPerson.
  ///
  /// In en, this message translates to:
  /// **'Owed to'**
  String get debtPerson;

  /// No description provided for @debtPayOffBy.
  ///
  /// In en, this message translates to:
  /// **'Pay off by'**
  String get debtPayOffBy;

  /// No description provided for @debtRemindAt.
  ///
  /// In en, this message translates to:
  /// **'Remind me at'**
  String get debtRemindAt;

  /// No description provided for @debtPay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get debtPay;

  /// No description provided for @debtPayAmount.
  ///
  /// In en, this message translates to:
  /// **'Payment amount'**
  String get debtPayAmount;

  /// No description provided for @debtSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled 🎉'**
  String get debtSettled;

  /// No description provided for @debtRemaining.
  ///
  /// In en, this message translates to:
  /// **'{amount} left · {person}'**
  String debtRemaining(String amount, String person);

  /// No description provided for @notifDebtTitle.
  ///
  /// In en, this message translates to:
  /// **'Debt to {person}'**
  String notifDebtTitle(String person);

  /// No description provided for @notifDebtBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} still owed. A settled debt sleeps better.'**
  String notifDebtBody(String amount);

  /// No description provided for @recentMoves.
  ///
  /// In en, this message translates to:
  /// **'Recent moves'**
  String get recentMoves;

  /// No description provided for @txnWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get txnWallet;

  /// No description provided for @txnSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get txnSavings;

  /// No description provided for @nothingInVault.
  ///
  /// In en, this message translates to:
  /// **'The vault is empty — add to the wallet or save something.'**
  String get nothingInVault;

  /// No description provided for @dayToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dayToday;

  /// No description provided for @dayYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dayYesterday;

  /// No description provided for @vaultOwed.
  ///
  /// In en, this message translates to:
  /// **'Owed'**
  String get vaultOwed;

  /// No description provided for @vaultOpenDebts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no open debts} =1{1 open debt} other{{count} open debts}}'**
  String vaultOpenDebts(int count);

  /// No description provided for @walletEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'The wallet is empty'**
  String get walletEmptyTitle;

  /// No description provided for @walletEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add what you carry to spend. Expenses can come straight out of it.'**
  String get walletEmptyBody;

  /// No description provided for @savingsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get savingsEmptyTitle;

  /// No description provided for @savingsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Put something aside — one pot per currency.'**
  String get savingsEmptyBody;

  /// No description provided for @debtsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No debts'**
  String get debtsEmptyTitle;

  /// No description provided for @debtsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing owed to anyone. Sleep well.'**
  String get debtsEmptyBody;

  /// No description provided for @movesTitle.
  ///
  /// In en, this message translates to:
  /// **'Moves'**
  String get movesTitle;

  /// No description provided for @noMovesYet.
  ///
  /// In en, this message translates to:
  /// **'No moves yet'**
  String get noMovesYet;

  /// No description provided for @txnAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get txnAdded;

  /// No description provided for @txnTaken.
  ///
  /// In en, this message translates to:
  /// **'Taken out'**
  String get txnTaken;

  /// No description provided for @txnSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get txnSaved;

  /// No description provided for @txnWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get txnWithdrawn;

  /// No description provided for @txnFromSavings.
  ///
  /// In en, this message translates to:
  /// **'From savings'**
  String get txnFromSavings;

  /// No description provided for @txnToSavings.
  ///
  /// In en, this message translates to:
  /// **'To savings'**
  String get txnToSavings;

  /// No description provided for @txnFromWallet.
  ///
  /// In en, this message translates to:
  /// **'From the wallet'**
  String get txnFromWallet;

  /// No description provided for @txnToWallet.
  ///
  /// In en, this message translates to:
  /// **'To the wallet'**
  String get txnToWallet;

  /// No description provided for @txnExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get txnExpense;

  /// No description provided for @txnDebtPayment.
  ///
  /// In en, this message translates to:
  /// **'Paid {person}'**
  String txnDebtPayment(String person);

  /// No description provided for @debtPaidOf.
  ///
  /// In en, this message translates to:
  /// **'{paid} of {total} paid'**
  String debtPaidOf(String paid, String total);

  /// No description provided for @debtPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get debtPayments;

  /// No description provided for @debtOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get debtOpen;

  /// No description provided for @debtSettledSection.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get debtSettledSection;

  /// No description provided for @payFromWallet.
  ///
  /// In en, this message translates to:
  /// **'Pay from the wallet?'**
  String get payFromWallet;

  /// No description provided for @depositSource.
  ///
  /// In en, this message translates to:
  /// **'Where does it come from?'**
  String get depositSource;

  /// No description provided for @fromWalletOption.
  ///
  /// In en, this message translates to:
  /// **'From the wallet'**
  String get fromWalletOption;

  /// No description provided for @newMoneyOption.
  ///
  /// In en, this message translates to:
  /// **'New money'**
  String get newMoneyOption;

  /// No description provided for @walletYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, from the wallet'**
  String get walletYes;

  /// No description provided for @walletNo.
  ///
  /// In en, this message translates to:
  /// **'No, just log it'**
  String get walletNo;

  /// No description provided for @budgetSpentToday.
  ///
  /// In en, this message translates to:
  /// **'Spent today'**
  String get budgetSpentToday;

  /// No description provided for @budgetDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'Daily limit'**
  String get budgetDailyLimit;

  /// No description provided for @budgetLeftToday.
  ///
  /// In en, this message translates to:
  /// **'{amount} left today'**
  String budgetLeftToday(String amount);

  /// No description provided for @budgetOverToday.
  ///
  /// In en, this message translates to:
  /// **'{amount} over today'**
  String budgetOverToday(String amount);

  /// No description provided for @budgetLeftMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount} left this month'**
  String budgetLeftMonth(String amount);

  /// No description provided for @budgetOverMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount} over budget this month'**
  String budgetOverMonth(String amount);

  /// No description provided for @expensesToday.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing logged} =1{1 expense} other{{count} expenses}}'**
  String expensesToday(int count);

  /// No description provided for @swipeToRemove.
  ///
  /// In en, this message translates to:
  /// **'Swipe to remove'**
  String get swipeToRemove;

  /// No description provided for @snooze10.
  ///
  /// In en, this message translates to:
  /// **'In 10 min'**
  String get snooze10;

  /// No description provided for @snooze60.
  ///
  /// In en, this message translates to:
  /// **'In 1 hour'**
  String get snooze60;

  /// No description provided for @snooze180.
  ///
  /// In en, this message translates to:
  /// **'In 3 hours'**
  String get snooze180;

  /// No description provided for @tomorrowTitle.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrowTitle;

  /// No description provided for @tomorrowNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned yet — plant tonight\'s seeds.'**
  String get tomorrowNothing;

  /// No description provided for @tomorrowHabits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no habits due} =1{1 habit due} other{{count} habits due}}'**
  String tomorrowHabits(int count);

  /// No description provided for @tomorrowTodos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no to-dos} =1{1 to-do planned} other{{count} to-dos planned}}'**
  String tomorrowTodos(int count);

  /// No description provided for @planTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get planTomorrow;

  /// No description provided for @rateSaved.
  ///
  /// In en, this message translates to:
  /// **'Rate saved'**
  String get rateSaved;

  /// No description provided for @rateCleared.
  ///
  /// In en, this message translates to:
  /// **'Rate cleared'**
  String get rateCleared;

  /// No description provided for @rateInvalid.
  ///
  /// In en, this message translates to:
  /// **'That is not a usable rate'**
  String get rateInvalid;

  /// No description provided for @ratesExplainer.
  ///
  /// In en, this message translates to:
  /// **'Used to show \$ and € amounts in your default currency.'**
  String get ratesExplainer;

  /// No description provided for @settingsMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get settingsMoney;

  /// No description provided for @startupProblem.
  ///
  /// In en, this message translates to:
  /// **'A startup step failed: {error}. Restart the app; if it keeps happening, back up and reinstall.'**
  String startupProblem(String error);

  /// No description provided for @channelReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get channelReminders;

  /// No description provided for @channelStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get channelStreak;

  /// No description provided for @channelPomodoro.
  ///
  /// In en, this message translates to:
  /// **'Focus timer'**
  String get channelPomodoro;

  /// No description provided for @remindersStreakHint.
  ///
  /// In en, this message translates to:
  /// **'At {time}, only when the day is not yet earned'**
  String remindersStreakHint(String time);

  /// No description provided for @decrease.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get decrease;

  /// No description provided for @increase.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get increase;

  /// No description provided for @remindersDenied.
  ///
  /// In en, this message translates to:
  /// **'Reminders are blocked for Harvest in system settings.'**
  String get remindersDenied;

  /// No description provided for @freezeEarnHint.
  ///
  /// In en, this message translates to:
  /// **'Earn {coins} coins at a {days}-day streak.'**
  String freezeEarnHint(int coins, int days);

  /// No description provided for @streakSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Streak: 1 day} other{Streak: {count} days}}'**
  String streakSemantics(int count);

  /// No description provided for @xpAmount.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP'**
  String xpAmount(int xp);

  /// No description provided for @unitDays.
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get unitDays;

  /// No description provided for @unitHours.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get unitHours;

  /// No description provided for @unitMinutes.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get unitMinutes;

  /// No description provided for @projectProgressOf.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String projectProgressOf(int done, int total);

  /// No description provided for @cropOptions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get cropOptions;

  /// No description provided for @clearValue.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearValue;

  /// No description provided for @scheduleDailyShort.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get scheduleDailyShort;

  /// No description provided for @scheduleEveryDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every day} other{Every {count} days}}'**
  String scheduleEveryDays(int count);

  /// No description provided for @scheduleTimesShort.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Once a week} =2{Twice a week} other{{count}× a week}} · {done} done'**
  String scheduleTimesShort(int count, int done);

  /// No description provided for @plannedFor.
  ///
  /// In en, this message translates to:
  /// **'Planned {date}'**
  String plannedFor(String date);

  /// No description provided for @removeAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAction;

  /// No description provided for @checkInFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not save. Try again.'**
  String get checkInFailed;

  /// No description provided for @activitySemantics.
  ///
  /// In en, this message translates to:
  /// **'{days} active days in the last {weeks} weeks'**
  String activitySemantics(int days, int weeks);

  /// No description provided for @cropDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get cropDone;

  /// No description provided for @cropPending.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get cropPending;
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
