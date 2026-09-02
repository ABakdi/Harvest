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
}
