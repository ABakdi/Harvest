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

  @override
  String get addCommitment => 'Plant a seed';

  @override
  String get typeHabit => 'Habit';

  @override
  String get typeProject => 'Project';

  @override
  String get typeTodo => 'To-Do';

  @override
  String get titleLabel => 'Title';

  @override
  String get titleHintHabit => 'e.g. Exercise, Practice Spanish';

  @override
  String get titleHintProject => 'e.g. Read Atomic Habits';

  @override
  String get titleHintTodo => 'e.g. Call the dentist';

  @override
  String get scheduleLabel => 'Schedule';

  @override
  String get scheduleDaily => 'Daily';

  @override
  String get scheduleWeekly => 'Weekdays';

  @override
  String get scheduleInterval => 'Every X days';

  @override
  String get scheduleTimesPerWeek => 'X per week';

  @override
  String everyDaysLabel(int count) {
    return 'Every $count days';
  }

  @override
  String timesPerWeekLabel(int count) {
    return '$count times per week';
  }

  @override
  String get totalTargetLabel => 'Total target (pages, minutes…)';

  @override
  String get dailyCommitmentLabel => 'Daily commitment';

  @override
  String get dueLabel => 'Planned for';

  @override
  String get dueToday => 'Today';

  @override
  String get dueTomorrow => 'Tomorrow';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get undoCheckInTitle => 'Undo today\'s check-in?';

  @override
  String undoCheckInBody(String title) {
    return 'This removes what you logged for \"$title\" today.';
  }

  @override
  String get undo => 'Undo';

  @override
  String get logProgressTitle => 'Water this crop';

  @override
  String get logQuantityLabel => 'How much did you get done?';

  @override
  String logRemainingToday(int count) {
    return 'You can log $count more today';
  }

  @override
  String get log => 'Log';

  @override
  String get cappedMessage => 'Daily cap reached — the field rests too.';

  @override
  String xpEarned(int count) {
    return '+$count XP';
  }

  @override
  String projectSubtitle(int done, int total, int today, int daily) {
    return '$done of $total · today $today/$daily';
  }

  @override
  String get todoOverdue => 'Overdue';

  @override
  String get rankSprout => 'Sprout';

  @override
  String get rankSeedling => 'Seedling';

  @override
  String get rankGardener => 'Gardener';

  @override
  String get rankHarvester => 'Harvester';

  @override
  String get rankMasterFarmer => 'Master Farmer';

  @override
  String get settingsHarvest => 'Harvest';

  @override
  String get settingsGoalTitle => 'Daily Harvest Goal';

  @override
  String get settingsGoalBody =>
      'Productive actions needed each day to keep your streak alive.';

  @override
  String goalActions(int count) {
    return '$count actions a day';
  }

  @override
  String get questsTitle => 'Today\'s quests';

  @override
  String get questHabits2 => 'Complete 2 habits';

  @override
  String get questHabitsEarly => 'Complete 2 habits before 9 AM';

  @override
  String get questProjectUnits20 => 'Water your projects with 20 units';

  @override
  String get questTodos2 => 'Finish 2 to-dos';

  @override
  String get questActions4 => 'Make 4 productive actions';

  @override
  String get claim => 'Claim';

  @override
  String rewardCoins(int count) {
    return '+$count coins';
  }

  @override
  String get streakSheetTitle => 'Your streak';

  @override
  String streakCurrent(int count) {
    return '$count days';
  }

  @override
  String streakBest(int count) {
    return 'Best: $count';
  }

  @override
  String freezesStored(int count, int max) {
    return 'Streak freezes: $count of $max';
  }

  @override
  String get freezeExplainer =>
      'A freeze protects your streak for one missed day. It\'s used automatically.';

  @override
  String buyFreeze(int cost) {
    return 'Buy a freeze · $cost coins';
  }

  @override
  String get freezeBought => 'Freeze stored. Rest easy. ❄️';

  @override
  String get freezeUnavailable => 'Not enough coins, or the shed is full.';

  @override
  String coinBalance(int count) {
    return '$count';
  }

  @override
  String get pomodoroTitle => 'Focus';

  @override
  String get phaseFocus => 'Focus';

  @override
  String get phaseShortBreak => 'Short break';

  @override
  String get phaseLongBreak => 'Long break';

  @override
  String get startFocus => 'Start focus';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get finishSession => 'Finish session';

  @override
  String get abandonSession => 'Abandon';

  @override
  String get abandonBody => 'The field will wait.';

  @override
  String get freeSession => 'Free focus';

  @override
  String blocksDone(int count) {
    return '$count blocks done';
  }

  @override
  String get breakOverReady => 'Break over — ready for the next block';

  @override
  String get pomodoroLogPrompt => 'Nice work! Log your progress on the field.';

  @override
  String get plannerTitle => 'Tomorrow\'s plan';

  @override
  String get plannerHabitsDue => 'Habits due tomorrow';

  @override
  String get plannerTodos => 'To-dos for tomorrow';

  @override
  String get plannerAddHint => 'Plant a to-do for tomorrow…';

  @override
  String get plannerEmpty =>
      'Nothing planned yet. Add tomorrow\'s seeds tonight and wake up ready.';

  @override
  String get notifMorningTitle => 'Good morning! ☀️';

  @override
  String get notifMorningBody =>
      'Check today\'s harvest plan and log your first seed.';

  @override
  String get notifEveningTitle => 'The sun is setting 🌙';

  @override
  String get notifEveningBody => 'Wind down and plant tomorrow\'s plan.';

  @override
  String get notifPrimeTitle => 'Your crops are waiting 🌾';

  @override
  String get notifPrimeBody =>
      'This is usually your logging time — a quick check-in keeps the field green.';

  @override
  String get notifStreakTitle => 'Your crops are thirsty! 🔥';

  @override
  String get notifStreakBody =>
      'Log your remaining tasks before 3 AM to save your streak.';

  @override
  String get settingsReminders => 'Reminders';

  @override
  String get remindersMaster => 'Allow reminders';

  @override
  String get remindersMorning => 'Morning review';

  @override
  String get remindersEvening => 'Evening plan ritual';

  @override
  String get remindersStreak => 'Streak-risk nudge';

  @override
  String get obWelcomeTitle => 'Welcome to Harvest';

  @override
  String get obWelcomeBody =>
      'Your goals are seeds. Your effort is water. Distractions are weeds.\n\nShow up a little every day, keep your streak alive, and harvest the life you\'re growing.';

  @override
  String get obTemplatesTitle => 'Plant your first seeds';

  @override
  String get obTemplatesBody =>
      'Pick a few to start with — you can always plant more.';

  @override
  String get tmplRead => 'Read a book (300 pages)';

  @override
  String get tmplFit => 'Exercise';

  @override
  String get tmplLanguage => 'Practice a language';

  @override
  String get tmplMeditate => 'Meditate (3× a week)';

  @override
  String get tmplJournal => 'Journal before bed';

  @override
  String get obGoalTitle => 'Your daily commitment';

  @override
  String get obRemindersTitle => 'Gentle reminders';

  @override
  String get obRemindersBody =>
      'Harvest nudges, never nags: a morning review, an evening planning ritual, and a heads-up when your streak is at risk.';

  @override
  String get next => 'Next';

  @override
  String get skip => 'Skip';

  @override
  String get startGrowing => 'Start growing 🌱';

  @override
  String get statsLifetimeXp => 'Lifetime XP';

  @override
  String get statsBestStreak => 'Best streak';

  @override
  String get statsCheckIns => 'Check-ins';

  @override
  String get statsActivity => 'Activity';

  @override
  String get statsProjects => 'Projects';

  @override
  String get statsHabitStreaks => 'Habit streaks';

  @override
  String statsStreakOf(int current, int best) {
    return '$current now · best $best';
  }
}
