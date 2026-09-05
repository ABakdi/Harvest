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

  /// No description provided for @vaultTab.
  ///
  /// In en, this message translates to:
  /// **'Balances'**
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
  /// **'Daily reminder at'**
  String get debtRemindAt;

  /// No description provided for @debtPay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get debtPay;

  /// No description provided for @debtSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled 🎉'**
  String get debtSettled;

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
  /// **'Debts'**
  String get vaultOwed;

  /// No description provided for @vaultOpenDebts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no open debts} =1{1 open debt} other{{count} open debts}}'**
  String vaultOpenDebts(int count);

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

  /// No description provided for @fromWalletToggle.
  ///
  /// In en, this message translates to:
  /// **'From the wallet'**
  String get fromWalletToggle;

  /// No description provided for @walletHas.
  ///
  /// In en, this message translates to:
  /// **'{amount} in the wallet'**
  String walletHas(String amount);

  /// No description provided for @walletShort.
  ///
  /// In en, this message translates to:
  /// **'Not enough in the wallet'**
  String get walletShort;

  /// No description provided for @budgetMonthLine.
  ///
  /// In en, this message translates to:
  /// **'{spent} of {budget} · {left} left'**
  String budgetMonthLine(String spent, String budget, String left);

  /// No description provided for @budgetMonthOver.
  ///
  /// In en, this message translates to:
  /// **'{spent} of {budget} · {over} over'**
  String budgetMonthOver(String spent, String budget, String over);

  /// No description provided for @editBudget.
  ///
  /// In en, this message translates to:
  /// **'Edit budget'**
  String get editBudget;

  /// No description provided for @perDay.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get perDay;

  /// No description provided for @todayEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap Log an expense to add the first one.'**
  String get todayEmptyBody;

  /// No description provided for @debtRemindDefault.
  ///
  /// In en, this message translates to:
  /// **'Every day at 7:00 PM until it is paid'**
  String get debtRemindDefault;

  /// No description provided for @undoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoAction;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not save. Try again.'**
  String get saveFailed;

  /// No description provided for @categoryExists.
  ///
  /// In en, this message translates to:
  /// **'A category with that name already exists'**
  String get categoryExists;

  /// No description provided for @withdrawToWallet.
  ///
  /// In en, this message translates to:
  /// **'To the wallet'**
  String get withdrawToWallet;

  /// No description provided for @budgetExplainer.
  ///
  /// In en, this message translates to:
  /// **'Your daily limit is what\'s left of the month divided by the days left in it.'**
  String get budgetExplainer;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @appLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock Harvest'**
  String get appLockTitle;

  /// No description provided for @appLockBody.
  ///
  /// In en, this message translates to:
  /// **'Ask for your fingerprint, PIN or password before opening the app.'**
  String get appLockBody;

  /// No description provided for @appLockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Set a fingerprint, PIN or password on this device first.'**
  String get appLockUnavailable;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Harvest is locked'**
  String get lockTitle;

  /// No description provided for @lockBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock to get back to your field.'**
  String get lockBody;

  /// No description provided for @lockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Harvest'**
  String get lockReason;

  /// No description provided for @lockUnlockAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get lockUnlockAction;

  /// No description provided for @lockRefused.
  ///
  /// In en, this message translates to:
  /// **'That did not match. Try again.'**
  String get lockRefused;

  /// No description provided for @lockTooManyTries.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait a moment, then try again.'**
  String get lockTooManyTries;

  /// No description provided for @lockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The device could not show the unlock prompt.'**
  String get lockUnavailable;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'My data'**
  String get settingsData;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Take an archive'**
  String get exportTitle;

  /// No description provided for @exportBody.
  ///
  /// In en, this message translates to:
  /// **'One .zip: the spreadsheet with its totals as live formulas, your notes as a folder of markdown, and every picture in its album.'**
  String get exportBody;

  /// No description provided for @exportAction.
  ///
  /// In en, this message translates to:
  /// **'Export to Downloads'**
  String get exportAction;

  /// No description provided for @exportRunning.
  ///
  /// In en, this message translates to:
  /// **'Building the workbook…'**
  String get exportRunning;

  /// No description provided for @exportSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String exportSaved(String path);

  /// No description provided for @exportFailedPermission.
  ///
  /// In en, this message translates to:
  /// **'Harvest was not allowed to write to Downloads.'**
  String get exportFailedPermission;

  /// No description provided for @exportFailedUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Exporting is only available on Android for now.'**
  String get exportFailedUnsupported;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'The export did not finish. Try again.'**
  String get exportFailed;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @restoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreAction;

  /// No description provided for @reminderRingsIn.
  ///
  /// In en, this message translates to:
  /// **'rings in {time}'**
  String reminderRingsIn(String time);

  /// No description provided for @reminderNow.
  ///
  /// In en, this message translates to:
  /// **'Ringing now'**
  String get reminderNow;

  /// No description provided for @editExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get editExpense;

  /// No description provided for @deleteExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this expense?'**
  String get deleteExpenseTitle;

  /// No description provided for @deleteExpenseBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} will be removed from the day, and any wallet withdrawal it made will be refunded.'**
  String deleteExpenseBody(String amount);

  /// No description provided for @archiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveTitle;

  /// No description provided for @archiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing put away yet'**
  String get archiveEmpty;

  /// No description provided for @archiveEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Seeds you archive land here, with the note that says why.'**
  String get archiveEmptyBody;

  /// No description provided for @archiveSheetBody.
  ///
  /// In en, this message translates to:
  /// **'Put {title} away. Its history stays.'**
  String archiveSheetBody(String title);

  /// No description provided for @archiveNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Why are you archiving it?'**
  String get archiveNoteLabel;

  /// No description provided for @archiveNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Finished it — on to the next one'**
  String get archiveNoteHint;

  /// No description provided for @archiveKeepsHistory.
  ///
  /// In en, this message translates to:
  /// **'Keeps every check-in'**
  String get archiveKeepsHistory;

  /// No description provided for @archivedOn.
  ///
  /// In en, this message translates to:
  /// **'Archived {day}'**
  String archivedOn(String day);

  /// No description provided for @restoredToField.
  ///
  /// In en, this message translates to:
  /// **'{title} is back on the field'**
  String restoredToField(String title);

  /// No description provided for @deleteSeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this seed?'**
  String get deleteSeedTitle;

  /// No description provided for @deleteSeedBody.
  ///
  /// In en, this message translates to:
  /// **'{title}, every check-in it ever logged and every note on it will be gone for good. This cannot be undone — archive it instead if you want to keep the history.'**
  String deleteSeedBody(String title);

  /// No description provided for @deleteSeedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Gone for good, history and all'**
  String get deleteSeedSubtitle;

  /// No description provided for @seedNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get seedNotesTitle;

  /// No description provided for @seedNotesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where you left off today'**
  String get seedNotesSubtitle;

  /// No description provided for @seedNotesSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s note, and the last one'**
  String get seedNotesSheetSubtitle;

  /// No description provided for @seedNotesExplainer.
  ///
  /// In en, this message translates to:
  /// **'A fresh note every day. Yesterday\'s stays in the history.'**
  String get seedNotesExplainer;

  /// No description provided for @seedNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Stopped on page 143'**
  String get seedNoteHint;

  /// No description provided for @noteForDay.
  ///
  /// In en, this message translates to:
  /// **'Note for {day}'**
  String noteForDay(String day);

  /// No description provided for @lastTimeOn.
  ///
  /// In en, this message translates to:
  /// **'Last time · {day}'**
  String lastTimeOn(String day);

  /// No description provided for @seedHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get seedHistoryTitle;

  /// No description provided for @seedHistorySheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every day, and what you wrote'**
  String get seedHistorySheetSubtitle;

  /// No description provided for @seedHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No days yet} =1{1 day on record} other{{count} days on record}}'**
  String seedHistorySubtitle(int count);

  /// No description provided for @seedHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get seedHistoryEmpty;

  /// No description provided for @seedHistoryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Check in once and this fills up.'**
  String get seedHistoryEmptyBody;

  /// No description provided for @seedGone.
  ///
  /// In en, this message translates to:
  /// **'This seed is gone'**
  String get seedGone;

  /// No description provided for @seedGoneBody.
  ///
  /// In en, this message translates to:
  /// **'It was deleted, so there is nothing left to show.'**
  String get seedGoneBody;

  /// No description provided for @streakLabel.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streakLabel;

  /// No description provided for @bestLabel.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get bestLabel;

  /// No description provided for @daysLoggedLabel.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get daysLoggedLabel;

  /// No description provided for @unitsLabel.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get unitsLabel;

  /// No description provided for @checkInsLabel.
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get checkInsLabel;

  /// No description provided for @dayCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no days} =1{1 day} other{{count} days}}'**
  String dayCount(int count);

  /// No description provided for @unitsLogged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit logged} other{{count} units logged}}'**
  String unitsLogged(int count);

  /// No description provided for @checkedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get checkedIn;

  /// No description provided for @noteOnlyDay.
  ///
  /// In en, this message translates to:
  /// **'Note only'**
  String get noteOnlyDay;

  /// No description provided for @runStripLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No active days in the last eight weeks} =1{1 active day in the last eight weeks} other{{count} active days in the last eight weeks}}'**
  String runStripLabel(int count);

  /// No description provided for @comebackDay1Title.
  ///
  /// In en, this message translates to:
  /// **'Your field is waiting 🌱'**
  String get comebackDay1Title;

  /// No description provided for @comebackDay1Body.
  ///
  /// In en, this message translates to:
  /// **'One quiet day, that\'s all. Water something and the streak keeps going.'**
  String get comebackDay1Body;

  /// No description provided for @comebackDay3Title.
  ///
  /// In en, this message translates to:
  /// **'Three days without water'**
  String get comebackDay3Title;

  /// No description provided for @comebackDay3Body.
  ///
  /// In en, this message translates to:
  /// **'The soil is still good. Pick the easiest seed and start there.'**
  String get comebackDay3Body;

  /// No description provided for @comebackWeek1Title.
  ///
  /// In en, this message translates to:
  /// **'A week away 🌾'**
  String get comebackWeek1Title;

  /// No description provided for @comebackWeek1Body.
  ///
  /// In en, this message translates to:
  /// **'Your best streak is still on record. A single check-in starts the next one.'**
  String get comebackWeek1Body;

  /// No description provided for @comebackWeek2Title.
  ///
  /// In en, this message translates to:
  /// **'Two weeks quiet'**
  String get comebackWeek2Title;

  /// No description provided for @comebackWeek2Body.
  ///
  /// In en, this message translates to:
  /// **'Nothing here is lost — your history is exactly where you left it.'**
  String get comebackWeek2Body;

  /// No description provided for @comebackMonth1Title.
  ///
  /// In en, this message translates to:
  /// **'A month of fallow ground'**
  String get comebackMonth1Title;

  /// No description provided for @comebackMonth1Body.
  ///
  /// In en, this message translates to:
  /// **'No guilt, no catching up. Open Harvest and plant one thing for today.'**
  String get comebackMonth1Body;

  /// No description provided for @comebackMonth2Title.
  ///
  /// In en, this message translates to:
  /// **'Still here whenever you are'**
  String get comebackMonth2Title;

  /// No description provided for @comebackMonth2Body.
  ///
  /// In en, this message translates to:
  /// **'Every seed, every check-in and every number is still on your phone.'**
  String get comebackMonth2Body;

  /// No description provided for @widgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Home-screen widget'**
  String get widgetTitle;

  /// No description provided for @widgetBody.
  ///
  /// In en, this message translates to:
  /// **'Add it from the launcher\'s widget picker, then pick what it shows.'**
  String get widgetBody;

  /// No description provided for @widgetStreakLabel.
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get widgetStreakLabel;

  /// No description provided for @widgetTasksLabel.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get widgetTasksLabel;

  /// No description provided for @widgetEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing due today'**
  String get widgetEmpty;

  /// No description provided for @loadingTagline.
  ///
  /// In en, this message translates to:
  /// **'Cultivate your day.'**
  String get loadingTagline;

  /// No description provided for @widgetRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh it now'**
  String get widgetRefresh;

  /// No description provided for @widgetSpentToday.
  ///
  /// In en, this message translates to:
  /// **'{amount} today'**
  String widgetSpentToday(String amount);

  /// No description provided for @widgetWallet.
  ///
  /// In en, this message translates to:
  /// **'{amount} in the wallet'**
  String widgetWallet(String amount);

  /// No description provided for @widgetActionExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get widgetActionExpense;

  /// No description provided for @widgetActionTask.
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get widgetActionTask;

  /// No description provided for @widgetAllDone.
  ///
  /// In en, this message translates to:
  /// **'The field is watered 🌾'**
  String get widgetAllDone;

  /// No description provided for @widgetSections.
  ///
  /// In en, this message translates to:
  /// **'What it shows'**
  String get widgetSections;

  /// No description provided for @widgetSectionStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get widgetSectionStreak;

  /// No description provided for @widgetSectionStreakBody.
  ///
  /// In en, this message translates to:
  /// **'Always shown'**
  String get widgetSectionStreakBody;

  /// No description provided for @widgetSectionMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get widgetSectionMoney;

  /// No description provided for @widgetSectionMoneyBody.
  ///
  /// In en, this message translates to:
  /// **'Today\'s spend and your wallet balance'**
  String get widgetSectionMoneyBody;

  /// No description provided for @widgetSectionTasks.
  ///
  /// In en, this message translates to:
  /// **'Today\'s field'**
  String get widgetSectionTasks;

  /// No description provided for @widgetSectionTasksBody.
  ///
  /// In en, this message translates to:
  /// **'What\'s still due, as a row of boxes'**
  String get widgetSectionTasksBody;

  /// No description provided for @widgetSectionActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get widgetSectionActions;

  /// No description provided for @widgetSectionActionsBody.
  ///
  /// In en, this message translates to:
  /// **'Log an expense or plant a seed from the home screen'**
  String get widgetSectionActionsBody;

  /// No description provided for @statsStreakSquares.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No streak running} =1{1 green square is your streak} other{{count} green squares are your streak}}'**
  String statsStreakSquares(int count);

  /// No description provided for @legendStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get legendStreak;

  /// No description provided for @legendActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get legendActive;

  /// No description provided for @legendQuiet.
  ///
  /// In en, this message translates to:
  /// **'Quiet'**
  String get legendQuiet;

  /// No description provided for @settingsCycle.
  ///
  /// In en, this message translates to:
  /// **'Daily cycle'**
  String get settingsCycle;

  /// No description provided for @settingsCycleHint.
  ///
  /// In en, this message translates to:
  /// **'The app bends to your hours, not the other way round'**
  String get settingsCycleHint;

  /// No description provided for @cycleBedTime.
  ///
  /// In en, this message translates to:
  /// **'I go to sleep at'**
  String get cycleBedTime;

  /// No description provided for @cycleWakeTime.
  ///
  /// In en, this message translates to:
  /// **'I wake up at'**
  String get cycleWakeTime;

  /// No description provided for @cycleGood.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours of sleep — that\'s the target'**
  String cycleGood(String hours);

  /// No description provided for @cycleBelowTarget.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours of sleep. Eight is the target.'**
  String cycleBelowTarget(String hours);

  /// No description provided for @cycleTooShort.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours is less than anyone should run on. Eight is the target, five the floor.'**
  String cycleTooShort(String hours);

  /// No description provided for @cycleClashTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One reminder is now in your sleep} other{{count} reminders are now in your sleep}}'**
  String cycleClashTitle(int count);

  /// No description provided for @cycleClashBody.
  ///
  /// In en, this message translates to:
  /// **'Move them with your new wake time? Each keeps the same distance from waking.'**
  String get cycleClashBody;

  /// No description provided for @cycleClashMove.
  ///
  /// In en, this message translates to:
  /// **'{title} · {from} → {to}'**
  String cycleClashMove(String title, String from, String to);

  /// No description provided for @cycleClashMore.
  ///
  /// In en, this message translates to:
  /// **'…and {count} more'**
  String cycleClashMore(int count);

  /// No description provided for @cycleClashKeep.
  ///
  /// In en, this message translates to:
  /// **'Leave them'**
  String get cycleClashKeep;

  /// No description provided for @cycleClashShift.
  ///
  /// In en, this message translates to:
  /// **'Move them'**
  String get cycleClashShift;

  /// No description provided for @movesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get movesSearchHint;

  /// No description provided for @movesFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get movesFilter;

  /// No description provided for @movesByKind.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get movesByKind;

  /// No description provided for @movesByCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get movesByCategory;

  /// No description provided for @movesShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing {matches} of {total}'**
  String movesShowing(int matches, int total);

  /// No description provided for @movesClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get movesClear;

  /// No description provided for @movesNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches that'**
  String get movesNoMatch;

  /// No description provided for @movesNoMatchBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different category, form or word.'**
  String get movesNoMatchBody;

  /// No description provided for @kindManual.
  ///
  /// In en, this message translates to:
  /// **'Added or taken'**
  String get kindManual;

  /// No description provided for @kindTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get kindTransfer;

  /// No description provided for @kindExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get kindExpense;

  /// No description provided for @kindDebt.
  ///
  /// In en, this message translates to:
  /// **'Debt payment'**
  String get kindDebt;

  /// No description provided for @rangeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get rangeCustom;

  /// No description provided for @rangePick.
  ///
  /// In en, this message translates to:
  /// **'Pick dates'**
  String get rangePick;

  /// No description provided for @rangeOf.
  ///
  /// In en, this message translates to:
  /// **'{from} — {to}'**
  String rangeOf(String from, String to);

  /// No description provided for @insightsMoves.
  ///
  /// In en, this message translates to:
  /// **'Moves in this range'**
  String get insightsMoves;

  /// No description provided for @insightsMovesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing moved} =1{1 movement} other{{count} movements}}'**
  String insightsMovesCount(int count);

  /// No description provided for @shareOfSpending.
  ///
  /// In en, this message translates to:
  /// **'{percent}% ({amount})'**
  String shareOfSpending(int percent, String amount);

  /// No description provided for @editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// No description provided for @navNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get navNotes;

  /// No description provided for @navGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get navGallery;

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesTitle;

  /// No description provided for @notesNew.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get notesNew;

  /// No description provided for @notesUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get notesUntitled;

  /// No description provided for @notesTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get notesTitleHint;

  /// No description provided for @notesBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Write. Markdown is rendered when you read; [[link]] to another note.'**
  String get notesBodyHint;

  /// No description provided for @notesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search titles and text'**
  String get notesSearchHint;

  /// No description provided for @notesAllFolders.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notesAllFolders;

  /// No description provided for @notesFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get notesFolder;

  /// No description provided for @notesFolderHint.
  ///
  /// In en, this message translates to:
  /// **'A path, nothing more. Nested folders are made by naming one.'**
  String get notesFolderHint;

  /// No description provided for @notesSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get notesSort;

  /// No description provided for @notesSortEdited.
  ///
  /// In en, this message translates to:
  /// **'Last edited'**
  String get notesSortEdited;

  /// No description provided for @notesSortCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get notesSortCreated;

  /// No description provided for @notesSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get notesSortTitle;

  /// No description provided for @notesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get notesEmpty;

  /// No description provided for @notesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'The app knows what you did. This is where you keep what you thought about it.'**
  String get notesEmptyBody;

  /// No description provided for @notesNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches that'**
  String get notesNoMatch;

  /// No description provided for @notesNoMatchBody.
  ///
  /// In en, this message translates to:
  /// **'Try another word, or a different folder.'**
  String get notesNoMatchBody;

  /// No description provided for @notesGone.
  ///
  /// In en, this message translates to:
  /// **'This note is gone'**
  String get notesGone;

  /// No description provided for @notesGoneBody.
  ///
  /// In en, this message translates to:
  /// **'It was deleted, or it never existed.'**
  String get notesGoneBody;

  /// No description provided for @notesRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get notesRead;

  /// No description provided for @notesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get notesEdit;

  /// No description provided for @notesCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get notesCreate;

  /// No description provided for @notesCreateLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Write \"{title}\"?'**
  String notesCreateLinkTitle(String title);

  /// No description provided for @notesCreateLinkBody.
  ///
  /// In en, this message translates to:
  /// **'That note does not exist yet. A link to a note you have not written is normal — this makes it.'**
  String get notesCreateLinkBody;

  /// No description provided for @notesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this note?'**
  String get notesDeleteTitle;

  /// No description provided for @notesDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It leaves the vault. You can undo this straight away.'**
  String get notesDeleteBody;

  /// No description provided for @notesBacklinks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note links here} other{{count} notes link here}}'**
  String notesBacklinks(int count);

  /// No description provided for @galleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryTitle;

  /// No description provided for @galleryNewAlbum.
  ///
  /// In en, this message translates to:
  /// **'New album'**
  String get galleryNewAlbum;

  /// No description provided for @galleryEditAlbum.
  ///
  /// In en, this message translates to:
  /// **'Edit album'**
  String get galleryEditAlbum;

  /// No description provided for @galleryCreateAlbum.
  ///
  /// In en, this message translates to:
  /// **'Create album'**
  String get galleryCreateAlbum;

  /// No description provided for @galleryAlbumHint.
  ///
  /// In en, this message translates to:
  /// **'A named run of pictures. Give it a schedule and it becomes a seed on your field.'**
  String get galleryAlbumHint;

  /// No description provided for @galleryAlbumName.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get galleryAlbumName;

  /// No description provided for @galleryAlbumNameHint.
  ///
  /// In en, this message translates to:
  /// **'Gym, Face, The flat'**
  String get galleryAlbumNameHint;

  /// No description provided for @gallerySchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get gallerySchedule;

  /// No description provided for @galleryScheduleNone.
  ///
  /// In en, this message translates to:
  /// **'No schedule'**
  String get galleryScheduleNone;

  /// No description provided for @gallerySeedHint.
  ///
  /// In en, this message translates to:
  /// **'A scheduled album is due like a habit, checked in by adding a picture, and feeds the same streak.'**
  String get gallerySeedHint;

  /// No description provided for @galleryIsSeed.
  ///
  /// In en, this message translates to:
  /// **'On your field'**
  String get galleryIsSeed;

  /// No description provided for @galleryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No albums yet'**
  String get galleryEmpty;

  /// No description provided for @galleryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'One picture a day, kept in order, playable as a run. Start with the thing you want to see change.'**
  String get galleryEmptyBody;

  /// No description provided for @galleryAlbumEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing in here yet'**
  String get galleryAlbumEmpty;

  /// No description provided for @galleryAlbumEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add the first picture. The comparison only gets interesting from the second one.'**
  String get galleryAlbumEmptyBody;

  /// No description provided for @galleryAlbumGone.
  ///
  /// In en, this message translates to:
  /// **'This album is gone'**
  String get galleryAlbumGone;

  /// No description provided for @galleryAlbumCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Empty} =1{1 memory} other{{count} memories}}'**
  String galleryAlbumCount(int count);

  /// No description provided for @galleryAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get galleryAdd;

  /// No description provided for @galleryAddTo.
  ///
  /// In en, this message translates to:
  /// **'Add to {album}'**
  String galleryAddTo(String album);

  /// No description provided for @galleryCheckInHint.
  ///
  /// In en, this message translates to:
  /// **'The first picture today checks this album in.'**
  String get galleryCheckInHint;

  /// No description provided for @galleryTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get galleryTakePhoto;

  /// No description provided for @galleryPickPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get galleryPickPhoto;

  /// No description provided for @galleryTakeVideo.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get galleryTakeVideo;

  /// No description provided for @galleryPickVideo.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get galleryPickVideo;

  /// No description provided for @galleryNoCapture.
  ///
  /// In en, this message translates to:
  /// **'Nothing was captured.'**
  String get galleryNoCapture;

  /// No description provided for @galleryMemoryNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get galleryMemoryNote;

  /// No description provided for @galleryMemoryNoteHint.
  ///
  /// In en, this message translates to:
  /// **'What changed, what you weighed, what you were trying'**
  String get galleryMemoryNoteHint;

  /// No description provided for @gallerySearchNotes.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get gallerySearchNotes;

  /// No description provided for @gallerySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search the notes on these pictures'**
  String get gallerySearchHint;

  /// No description provided for @galleryNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No picture has a note like that'**
  String get galleryNoMatch;

  /// No description provided for @galleryPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get galleryPlay;

  /// No description provided for @gallerySpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get gallerySpeed;

  /// No description provided for @galleryFps.
  ///
  /// In en, this message translates to:
  /// **'{fps}/s'**
  String galleryFps(int fps);

  /// No description provided for @galleryCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get galleryCompare;

  /// No description provided for @galleryCompareLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get galleryCompareLeft;

  /// No description provided for @galleryCompareRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get galleryCompareRight;

  /// No description provided for @galleryDeleteMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this memory?'**
  String get galleryDeleteMemoryTitle;

  /// No description provided for @galleryDeleteMemoryBody.
  ///
  /// In en, this message translates to:
  /// **'The file goes with it, for good. There is no undo behind this one.'**
  String get galleryDeleteMemoryBody;

  /// No description provided for @galleryDeleteAlbumTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {album}?'**
  String galleryDeleteAlbumTitle(String album);

  /// No description provided for @galleryDeleteAlbumBody.
  ///
  /// In en, this message translates to:
  /// **'Every picture in it is deleted with it, files and all. There is no undo.'**
  String get galleryDeleteAlbumBody;

  /// No description provided for @settingsFeatures.
  ///
  /// In en, this message translates to:
  /// **'Extras'**
  String get settingsFeatures;

  /// No description provided for @settingsFeaturesHint.
  ///
  /// In en, this message translates to:
  /// **'Two halves of the app that stay out of the way until you ask for them.'**
  String get settingsFeaturesHint;

  /// No description provided for @featureNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get featureNotes;

  /// No description provided for @featureNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Markdown notes in folders, linked to each other.'**
  String get featureNotesHint;

  /// No description provided for @featureGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get featureGallery;

  /// No description provided for @featureGalleryHint.
  ///
  /// In en, this message translates to:
  /// **'Albums of photos over time, playable as a run. A scheduled album becomes a seed on your field.'**
  String get featureGalleryHint;

  /// No description provided for @featureGallerySize.
  ///
  /// In en, this message translates to:
  /// **'Using {size}'**
  String featureGallerySize(String size);

  /// No description provided for @obExtrasTitle.
  ///
  /// In en, this message translates to:
  /// **'Two more, if you want them'**
  String get obExtrasTitle;

  /// No description provided for @obExtrasBody.
  ///
  /// In en, this message translates to:
  /// **'Both stay hidden unless you say yes. You can change your mind in Settings at any time.'**
  String get obExtrasBody;

  /// No description provided for @albumReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Today\'s picture is still missing.'**
  String get albumReminderBody;

  /// No description provided for @exportPreparing.
  ///
  /// In en, this message translates to:
  /// **'Reading everything…'**
  String get exportPreparing;

  /// No description provided for @exportProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String exportProgress(int done, int total);

  /// No description provided for @exportStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped. Nothing was written.'**
  String get exportStopped;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Bring an archive back'**
  String get importTitle;

  /// No description provided for @importBody.
  ///
  /// In en, this message translates to:
  /// **'Open a Harvest .zip. You will see exactly what it would change before anything happens, and nothing here is ever deleted for being missing from it.'**
  String get importBody;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Choose an archive'**
  String get importAction;

  /// No description provided for @importReading.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get importReading;

  /// No description provided for @importApplying.
  ///
  /// In en, this message translates to:
  /// **'Merging…'**
  String get importApplying;

  /// No description provided for @importConfirm.
  ///
  /// In en, this message translates to:
  /// **'Merge it in'**
  String get importConfirm;

  /// No description provided for @importSummary.
  ///
  /// In en, this message translates to:
  /// **'{added} new, {updated} to update'**
  String importSummary(int added, int updated);

  /// No description provided for @importRowCounts.
  ///
  /// In en, this message translates to:
  /// **'+{added} · ↻{updated}'**
  String importRowCounts(int added, int updated);

  /// No description provided for @importFiles.
  ///
  /// In en, this message translates to:
  /// **'{newFiles, plural, =0{No new files among the {files} in the archive} =1{1 new file of {files} in the archive} other{{newFiles} new files of {files} in the archive}}'**
  String importFiles(int newFiles, int files);

  /// No description provided for @importNothingToDo.
  ///
  /// In en, this message translates to:
  /// **'Everything in here is already on this phone.'**
  String get importNothingToDo;

  /// No description provided for @importNeverDeletes.
  ///
  /// In en, this message translates to:
  /// **'Nothing local is deleted. Rows already here are only touched if the archive\'s copy is newer.'**
  String get importNeverDeletes;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Done — {added} added, {updated} updated.'**
  String importDone(int added, int updated);

  /// No description provided for @importNotHarvest.
  ///
  /// In en, this message translates to:
  /// **'That zip is not a Harvest archive.'**
  String get importNotHarvest;

  /// No description provided for @importUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That file could not be opened.'**
  String get importUnreadable;

  /// No description provided for @importBadWorkbook.
  ///
  /// In en, this message translates to:
  /// **'The spreadsheet inside that archive could not be read.'**
  String get importBadWorkbook;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'The import did not finish.'**
  String get importFailed;

  /// No description provided for @sheetSeeds.
  ///
  /// In en, this message translates to:
  /// **'Seeds'**
  String get sheetSeeds;

  /// No description provided for @sheetCheckIns.
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get sheetCheckIns;

  /// No description provided for @sheetSeedNotes.
  ///
  /// In en, this message translates to:
  /// **'Day notes'**
  String get sheetSeedNotes;

  /// No description provided for @sheetExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get sheetExpenses;

  /// No description provided for @sheetMoney.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get sheetMoney;

  /// No description provided for @sheetDebts.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get sheetDebts;

  /// No description provided for @sheetDebtPayments.
  ///
  /// In en, this message translates to:
  /// **'Debt payments'**
  String get sheetDebtPayments;

  /// No description provided for @sheetFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus sessions'**
  String get sheetFocus;

  /// No description provided for @sheetLedger.
  ///
  /// In en, this message translates to:
  /// **'XP ledger'**
  String get sheetLedger;

  /// No description provided for @sheetSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get sheetSettings;

  /// No description provided for @sheetNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get sheetNotes;

  /// No description provided for @sheetAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get sheetAlbums;

  /// No description provided for @sheetMemories.
  ///
  /// In en, this message translates to:
  /// **'Memories'**
  String get sheetMemories;
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
