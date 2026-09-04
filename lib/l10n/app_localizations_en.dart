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
  String get scheduleWeekly => 'Specific days';

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
  String get logProgressTitle => 'Log progress';

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
  String get streakSheetTitle => 'Your streak';

  @override
  String streakCurrent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coins',
      one: '1 coin',
    );
    return '$_temp0';
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
  String get notifStreakTitle => 'Your crops are thirsty! 🔥';

  @override
  String get notifStreakBody =>
      'Log your remaining tasks before 3 AM to save your streak.';

  @override
  String get settingsReminders => 'Reminders';

  @override
  String get remindersMaster => 'Allow reminders';

  @override
  String get remindersMorning => 'Morning: today\'s plan';

  @override
  String get remindersEvening => 'Evening: plan tomorrow';

  @override
  String get remindersStreak => 'Late streak warning';

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
  String get obGoalTitle => 'Daily Harvest Goal';

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

  @override
  String get navGranary => 'Granary';

  @override
  String get granaryTitle => 'Granary';

  @override
  String get logExpense => 'Log an expense';

  @override
  String get amountLabel => 'Amount';

  @override
  String get noteLabel => 'Note (optional)';

  @override
  String get catFood => 'Food';

  @override
  String get catTransport => 'Transport';

  @override
  String get catBills => 'Bills';

  @override
  String get catShopping => 'Shopping';

  @override
  String get catHealth => 'Health';

  @override
  String get catEntertainment => 'Fun';

  @override
  String get catOther => 'Other';

  @override
  String get todaySpending => 'Today';

  @override
  String get budgetTitle => 'Monthly budget';

  @override
  String budgetSpentOf(String spent, String budget) {
    return '$spent of $budget this month';
  }

  @override
  String budgetFloating(String spent, String limit) {
    return '$spent / $limit today';
  }

  @override
  String get budgetSet => 'Set a monthly budget';

  @override
  String get budgetAmountLabel => 'Budget for the month';

  @override
  String get granaryEmpty => 'Nothing logged today. What did you spend?';

  @override
  String get repeatSuggestionTitle => 'Same as the last 3 days?';

  @override
  String get logIt => 'Log it';

  @override
  String get notifExpenseTitle => 'What did you spend today? 💰';

  @override
  String get notifExpenseBody =>
      'Log it in two taps and keep the granary honest.';

  @override
  String get remindersExpense => 'Expense check-in';

  @override
  String get statsSpending => 'Spending by category';

  @override
  String get deleted => 'Removed';

  @override
  String get editSeed => 'Edit';

  @override
  String get focusTimer => 'Focus timer';

  @override
  String get pauseHabit => 'Pause (vacation)';

  @override
  String get resumeHabit => 'Resume';

  @override
  String get pausedLabel => 'Paused — resting';

  @override
  String get archiveAction => 'Archive';

  @override
  String get archiveConfirmTitle => 'Archive this seed?';

  @override
  String archiveConfirmBody(String title) {
    return '\"$title\" is archived. Its history stays.';
  }

  @override
  String get projectDoneTitle => 'Harvest complete! 🎉';

  @override
  String projectDoneBody(String title, int total) {
    return '\"$title\" is fully grown — $total logged. It is archived with pride.';
  }

  @override
  String get toTheBarn => 'Archive';

  @override
  String get weeklyReport => 'This week';

  @override
  String weeklyXp(int count) {
    return '$count XP';
  }

  @override
  String weeklyBestDay(String day) {
    return 'Best: $day';
  }

  @override
  String weeklyWorstDay(String day) {
    return 'Quietest: $day';
  }

  @override
  String weeklyTopSpending(String category) {
    return 'Top spending: $category';
  }

  @override
  String get settingsPomodoro => 'Focus timer';

  @override
  String get pomodoroFocusLen => 'Focus length';

  @override
  String get pomodoroShortLen => 'Short break';

  @override
  String get pomodoroLongLen => 'Long break';

  @override
  String get pomodoroBlocks => 'Blocks before a long break';

  @override
  String minutesValue(int count) {
    return '$count min';
  }

  @override
  String get settingsStyle => 'Style';

  @override
  String get presetHarvest => 'Harvest';

  @override
  String get presetSunrise => 'Sunrise';

  @override
  String get presetOcean => 'Ocean';

  @override
  String get presetOrchard => 'Orchard';

  @override
  String get presetDusk => 'Dusk';

  @override
  String get advancedOptions => 'Advanced';

  @override
  String get seedNoteLabel => 'Note';

  @override
  String get remindMeAt => 'Remind me at';

  @override
  String get deadlineLabel => 'Accomplish before';

  @override
  String get notSet => 'Not set';

  @override
  String get clear => 'Clear';

  @override
  String get pickDate => 'Pick a date';

  @override
  String dueOn(String date) {
    return 'Due $date';
  }

  @override
  String overdueBy(String date) {
    return 'Overdue — was due $date';
  }

  @override
  String get taskReminderBody => 'A seed is waiting to be watered.';

  @override
  String get newCategory => 'New category';

  @override
  String get categoryName => 'Category name';

  @override
  String get manageCategories => 'Custom categories';

  @override
  String get todayTab => 'Today';

  @override
  String get insightsTab => 'Insights';

  @override
  String get savingsLow => 'Savings running low';

  @override
  String get rangeWeek => 'Week';

  @override
  String get rangeMonth => 'Month';

  @override
  String get totalSpent => 'Total';

  @override
  String avgPerDay(String amount) {
    return '$amount / day';
  }

  @override
  String get noSpendingYet => 'No spending in this range yet.';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calNothingDue => 'Nothing planted for this day.';

  @override
  String calDeadline(String title) {
    return 'Deadline: $title';
  }

  @override
  String get calAddForDay => 'Plant a to-do for this day…';

  @override
  String get defaultCurrencyLabel => 'Default currency';

  @override
  String get exchangeRates => 'Exchange rates';

  @override
  String get ratesDzdUsd => 'DZD per 1 USD';

  @override
  String get ratesDzdEur => 'DZD per 1 EUR';

  @override
  String get ratesEurUsd => 'EUR → USD (fetched)';

  @override
  String get fetchNow => 'Fetch';

  @override
  String ratesUpdated(String when) {
    return 'Updated $when';
  }

  @override
  String get ratesFetchFailed => 'Couldn\'t fetch — check the connection.';

  @override
  String get vaultTab => 'Balances';

  @override
  String get walletTitle => 'Wallet';

  @override
  String get walletAdd => 'Add';

  @override
  String get walletTake => 'Take';

  @override
  String get savingsSectionTitle => 'Savings';

  @override
  String get savingsDeposit => 'Save';

  @override
  String get savingsWithdraw => 'Withdraw';

  @override
  String get debtsTitle => 'Debts';

  @override
  String get addDebt => 'Log a debt';

  @override
  String get debtPerson => 'Owed to';

  @override
  String get debtPayOffBy => 'Pay off by';

  @override
  String get debtRemindAt => 'Daily reminder at';

  @override
  String get debtPay => 'Pay';

  @override
  String get debtSettled => 'Settled 🎉';

  @override
  String notifDebtTitle(String person) {
    return 'Debt to $person';
  }

  @override
  String notifDebtBody(String amount) {
    return '$amount still owed. A settled debt sleeps better.';
  }

  @override
  String get dayToday => 'Today';

  @override
  String get dayYesterday => 'Yesterday';

  @override
  String get vaultOwed => 'Debts';

  @override
  String vaultOpenDebts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open debts',
      one: '1 open debt',
      zero: 'no open debts',
    );
    return '$_temp0';
  }

  @override
  String get debtsEmptyTitle => 'No debts';

  @override
  String get debtsEmptyBody => 'Nothing owed to anyone. Sleep well.';

  @override
  String get movesTitle => 'Moves';

  @override
  String get noMovesYet => 'No moves yet';

  @override
  String get txnAdded => 'Added';

  @override
  String get txnTaken => 'Taken out';

  @override
  String get txnSaved => 'Saved';

  @override
  String get txnWithdrawn => 'Withdrawn';

  @override
  String get txnFromSavings => 'From savings';

  @override
  String get txnToSavings => 'To savings';

  @override
  String get txnFromWallet => 'From the wallet';

  @override
  String get txnToWallet => 'To the wallet';

  @override
  String get txnExpense => 'Expense';

  @override
  String txnDebtPayment(String person) {
    return 'Paid $person';
  }

  @override
  String debtPaidOf(String paid, String total) {
    return '$paid of $total paid';
  }

  @override
  String get debtPayments => 'Payments';

  @override
  String get debtOpen => 'Open';

  @override
  String get debtSettledSection => 'Settled';

  @override
  String get payFromWallet => 'Pay from the wallet?';

  @override
  String get budgetSpentToday => 'Spent today';

  @override
  String get budgetDailyLimit => 'Daily limit';

  @override
  String budgetLeftToday(String amount) {
    return '$amount left today';
  }

  @override
  String budgetOverToday(String amount) {
    return '$amount over today';
  }

  @override
  String budgetLeftMonth(String amount) {
    return '$amount left this month';
  }

  @override
  String budgetOverMonth(String amount) {
    return '$amount over budget this month';
  }

  @override
  String expensesToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
      zero: 'Nothing logged',
    );
    return '$_temp0';
  }

  @override
  String get snooze10 => 'In 10 min';

  @override
  String get snooze60 => 'In 1 hour';

  @override
  String get snooze180 => 'In 3 hours';

  @override
  String get tomorrowTitle => 'Tomorrow';

  @override
  String get tomorrowNothing => 'Nothing planned yet — plant tonight\'s seeds.';

  @override
  String tomorrowHabits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count habits due',
      one: '1 habit due',
      zero: 'no habits due',
    );
    return '$_temp0';
  }

  @override
  String tomorrowTodos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count to-dos planned',
      one: '1 to-do planned',
      zero: 'no to-dos',
    );
    return '$_temp0';
  }

  @override
  String get planTomorrow => 'Plan';

  @override
  String get rateSaved => 'Rate saved';

  @override
  String get rateCleared => 'Rate cleared';

  @override
  String get rateInvalid => 'That is not a usable rate';

  @override
  String get ratesExplainer =>
      'Used to show \$ and € amounts in your default currency.';

  @override
  String get settingsMoney => 'Money';

  @override
  String startupProblem(String error) {
    return 'A startup step failed: $error. Restart the app; if it keeps happening, back up and reinstall.';
  }

  @override
  String get channelReminders => 'Reminders';

  @override
  String get channelStreak => 'Streak';

  @override
  String get channelPomodoro => 'Focus timer';

  @override
  String remindersStreakHint(String time) {
    return 'At $time, only when the day is not yet earned';
  }

  @override
  String get decrease => 'Less';

  @override
  String get increase => 'More';

  @override
  String get remindersDenied =>
      'Reminders are blocked for Harvest in system settings.';

  @override
  String freezeEarnHint(int coins, int days) {
    return 'Earn $coins coins at a $days-day streak.';
  }

  @override
  String streakSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Streak: $count days',
      one: 'Streak: 1 day',
    );
    return '$_temp0';
  }

  @override
  String xpAmount(int xp) {
    return '$xp XP';
  }

  @override
  String get unitDays => 'd';

  @override
  String get unitHours => 'h';

  @override
  String get unitMinutes => 'm';

  @override
  String projectProgressOf(int done, int total) {
    return '$done of $total';
  }

  @override
  String get cropOptions => 'More';

  @override
  String get clearValue => 'Clear';

  @override
  String get scheduleDailyShort => 'Every day';

  @override
  String scheduleEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String scheduleTimesShort(int count, int done) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count× a week',
      two: 'Twice a week',
      one: 'Once a week',
    );
    return '$_temp0 · $done done';
  }

  @override
  String plannedFor(String date) {
    return 'Planned $date';
  }

  @override
  String get removeAction => 'Remove';

  @override
  String get checkInFailed => 'That did not save. Try again.';

  @override
  String activitySemantics(int days, int weeks) {
    return '$days active days in the last $weeks weeks';
  }

  @override
  String get cropDone => 'Done';

  @override
  String get cropPending => 'Not yet';

  @override
  String get fromWalletToggle => 'From the wallet';

  @override
  String walletHas(String amount) {
    return '$amount in the wallet';
  }

  @override
  String get walletShort => 'Not enough in the wallet';

  @override
  String budgetMonthLine(String spent, String budget, String left) {
    return '$spent of $budget · $left left';
  }

  @override
  String budgetMonthOver(String spent, String budget, String over) {
    return '$spent of $budget · $over over';
  }

  @override
  String get editBudget => 'Edit budget';

  @override
  String get perDay => 'Per day';

  @override
  String get todayEmptyBody => 'Tap Log an expense to add the first one.';

  @override
  String get debtRemindDefault => 'Every day at 7:00 PM until it is paid';

  @override
  String get undoAction => 'Undo';

  @override
  String get saveFailed => 'That did not save. Try again.';

  @override
  String get categoryExists => 'A category with that name already exists';

  @override
  String get withdrawToWallet => 'To the wallet';

  @override
  String get budgetExplainer =>
      'Your daily limit is what\'s left of the month divided by the days left in it.';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get appLockTitle => 'Lock Harvest';

  @override
  String get appLockBody =>
      'Ask for your fingerprint, PIN or password before opening the app.';

  @override
  String get appLockUnavailable =>
      'Set a fingerprint, PIN or password on this device first.';

  @override
  String get lockTitle => 'Harvest is locked';

  @override
  String get lockBody => 'Unlock to get back to your field.';

  @override
  String get lockReason => 'Unlock Harvest';

  @override
  String get lockUnlockAction => 'Unlock';

  @override
  String get lockRefused => 'That did not match. Try again.';

  @override
  String get lockTooManyTries =>
      'Too many tries. Wait a moment, then try again.';

  @override
  String get lockUnavailable => 'The device could not show the unlock prompt.';

  @override
  String get settingsData => 'My data';

  @override
  String get exportTitle => 'Export a spreadsheet';

  @override
  String get exportBody =>
      'Every seed, check-in, expense and movement in one .xlsx file, with the totals as live formulas.';

  @override
  String get exportAction => 'Export to Downloads';

  @override
  String get exportRunning => 'Building the workbook…';

  @override
  String exportSaved(String path) {
    return 'Saved to $path';
  }

  @override
  String get exportFailedPermission =>
      'Harvest was not allowed to write to Downloads.';

  @override
  String get exportFailedUnsupported =>
      'Exporting is only available on Android for now.';

  @override
  String get exportFailed => 'The export did not finish. Try again.';

  @override
  String get deleteAction => 'Delete';

  @override
  String get restoreAction => 'Restore';

  @override
  String reminderRingsIn(String time) {
    return 'rings in $time';
  }

  @override
  String get reminderNow => 'Ringing now';

  @override
  String get editExpense => 'Edit expense';

  @override
  String get deleteExpenseTitle => 'Delete this expense?';

  @override
  String deleteExpenseBody(String amount) {
    return '$amount will be removed from the day, and any wallet withdrawal it made will be refunded.';
  }

  @override
  String get archiveTitle => 'Archive';

  @override
  String get archiveEmpty => 'Nothing put away yet';

  @override
  String get archiveEmptyBody =>
      'Seeds you archive land here, with the note that says why.';

  @override
  String archiveSheetBody(String title) {
    return 'Put $title away. Its history stays.';
  }

  @override
  String get archiveNoteLabel => 'Why are you archiving it?';

  @override
  String get archiveNoteHint => 'Finished it — on to the next one';

  @override
  String get archiveKeepsHistory => 'Keeps every check-in';

  @override
  String archivedOn(String day) {
    return 'Archived $day';
  }

  @override
  String restoredToField(String title) {
    return '$title is back on the field';
  }

  @override
  String get deleteSeedTitle => 'Delete this seed?';

  @override
  String deleteSeedBody(String title) {
    return '$title, every check-in it ever logged and every note on it will be gone for good. This cannot be undone — archive it instead if you want to keep the history.';
  }

  @override
  String get deleteSeedSubtitle => 'Gone for good, history and all';

  @override
  String get seedNotesTitle => 'Notes';

  @override
  String get seedNotesSubtitle => 'Where you left off today';

  @override
  String get seedNotesSheetSubtitle => 'Today\'s note, and the last one';

  @override
  String get seedNotesExplainer =>
      'A fresh note every day. Yesterday\'s stays in the history.';

  @override
  String get seedNoteHint => 'Stopped on page 143';

  @override
  String noteForDay(String day) {
    return 'Note for $day';
  }

  @override
  String lastTimeOn(String day) {
    return 'Last time · $day';
  }

  @override
  String get seedHistoryTitle => 'History';

  @override
  String get seedHistorySheetSubtitle => 'Every day, and what you wrote';

  @override
  String seedHistorySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days on record',
      one: '1 day on record',
      zero: 'No days yet',
    );
    return '$_temp0';
  }

  @override
  String get seedHistoryEmpty => 'No history yet';

  @override
  String get seedHistoryEmptyBody => 'Check in once and this fills up.';

  @override
  String get seedGone => 'This seed is gone';

  @override
  String get seedGoneBody =>
      'It was deleted, so there is nothing left to show.';

  @override
  String get streakLabel => 'Streak';

  @override
  String get bestLabel => 'Best';

  @override
  String get daysLoggedLabel => 'Days';

  @override
  String get unitsLabel => 'Units';

  @override
  String get checkInsLabel => 'Check-ins';

  @override
  String dayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
      zero: 'no days',
    );
    return '$_temp0';
  }

  @override
  String unitsLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units logged',
      one: '1 unit logged',
    );
    return '$_temp0';
  }

  @override
  String get checkedIn => 'Checked in';

  @override
  String get noteOnlyDay => 'Note only';

  @override
  String runStripLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active days in the last eight weeks',
      one: '1 active day in the last eight weeks',
      zero: 'No active days in the last eight weeks',
    );
    return '$_temp0';
  }

  @override
  String get comebackDay1Title => 'Your field is waiting 🌱';

  @override
  String get comebackDay1Body =>
      'One quiet day, that\'s all. Water something and the streak keeps going.';

  @override
  String get comebackDay3Title => 'Three days without water';

  @override
  String get comebackDay3Body =>
      'The soil is still good. Pick the easiest seed and start there.';

  @override
  String get comebackWeek1Title => 'A week away 🌾';

  @override
  String get comebackWeek1Body =>
      'Your best streak is still on record. A single check-in starts the next one.';

  @override
  String get comebackWeek2Title => 'Two weeks quiet';

  @override
  String get comebackWeek2Body =>
      'Nothing here is lost — your history is exactly where you left it.';

  @override
  String get comebackMonth1Title => 'A month of fallow ground';

  @override
  String get comebackMonth1Body =>
      'No guilt, no catching up. Open Harvest and plant one thing for today.';

  @override
  String get comebackMonth2Title => 'Still here whenever you are';

  @override
  String get comebackMonth2Body =>
      'Every seed, every check-in and every number is still on your phone.';

  @override
  String get widgetTitle => 'Home-screen widget';

  @override
  String get widgetBody =>
      'Add it from the launcher\'s widget picker, then pick what it shows.';

  @override
  String get widgetStreakLabel => 'day streak';

  @override
  String get widgetTasksLabel => 'today';

  @override
  String get widgetEmpty => 'Nothing due today';

  @override
  String get loadingTagline => 'Cultivate your day.';

  @override
  String get widgetRefresh => 'Refresh it now';

  @override
  String widgetSpentToday(String amount) {
    return '$amount today';
  }

  @override
  String widgetWallet(String amount) {
    return '$amount in the wallet';
  }

  @override
  String get widgetActionExpense => 'Expense';

  @override
  String get widgetActionTask => 'Seed';

  @override
  String get widgetAllDone => 'The field is watered 🌾';

  @override
  String get widgetSections => 'What it shows';

  @override
  String get widgetSectionStreak => 'Streak';

  @override
  String get widgetSectionStreakBody => 'Always shown';

  @override
  String get widgetSectionMoney => 'Money';

  @override
  String get widgetSectionMoneyBody => 'Today\'s spend and your wallet balance';

  @override
  String get widgetSectionTasks => 'Today\'s field';

  @override
  String get widgetSectionTasksBody => 'What\'s still due, as a row of boxes';

  @override
  String get widgetSectionActions => 'Quick actions';

  @override
  String get widgetSectionActionsBody =>
      'Log an expense or plant a seed from the home screen';
}
