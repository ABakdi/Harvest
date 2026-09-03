import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/l10n_loader.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/core/platform/reminder_actions.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/due.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_planner.g.dart';

/// Reserved notification ids for the daily rituals, and the ranges the
/// per-item reminders live in. Snoozed copies sit above all of them
/// (see [SnoozeStore.idBase]).
abstract final class ReminderIds {
  static const morning = 101;
  static const eveningPlan = 102;
  static const streakRisk = 104;
  static const expenses = 105;

  static const List<int> rituals = [morning, eveningPlan, streakRisk, expenses];

  static const taskBase = 2100;
  static const debtBase = 3100;

  /// How many per-item reminders a range holds before it would run
  /// into the next one.
  static const rangeSize = 1000;
}

/// Settings keys for reminder configuration. Times are stored as
/// "HH:mm" strings; switches as JSON booleans.
abstract final class ReminderKeys {
  static const enabled = 'reminders.enabled';
  static const morningTime = 'reminders.morningTime';
  static const eveningTime = 'reminders.eveningTime';
  static const expenseTime = 'reminders.expenseTime';
  static const streakNudge = 'reminders.streakNudge';

  static const taskIds = 'reminders.taskIds';
  static const debtIds = 'reminders.debtIds';
}

/// The defaults the rituals fall back to.
abstract final class ReminderDefaults {
  static const (int, int) morning = (7, 0);
  static const (int, int) evening = (21, 30);
  static const (int, int) expense = (20, 0);
  static const (int, int) streakRisk = (23, 0);
  static const (int, int) debt = (19, 0);
}

/// Plans the day's reminder notifications (anti-spam rules):
/// everything is scheduled at the 3 AM reset or app open, and
/// [reevaluate] silences what is no longer needed the moment the
/// Daily Harvest Goal is met. The daily rituals obey the master switch;
/// a time the user put on a seed or a debt always fires. Snoozed
/// reminders are re-applied after every plan so they outlive it.
///
/// Every reminder is judged against the Harvest Day its fire time
/// belongs to, so planning at 01:30 (still yesterday's Harvest Day)
/// schedules today's rituals against today's state, not yesterday's.
class NotificationPlanner {
  NotificationPlanner(this._db, this._notifications, this._streaks)
    : _settings = SettingsRepository(_db),
      _commitments = CommitmentsRepository(_db);

  final HarvestDatabase _db;
  final NotificationGateway _notifications;
  final StreakService _streaks;
  final SettingsRepository _settings;
  final CommitmentsRepository _commitments;

  /// (Re)schedules today's reminders. Idempotent: cancels the reserved
  /// ids first, then schedules only what still lies ahead.
  Future<void> planToday({DateTime? now}) async {
    final at = now ?? DateTime.now();
    for (final id in ReminderIds.rituals) {
      await _notifications.cancel(id);
    }
    final l10n = await _l10n();
    _notifications
      ..snoozeLabels = _snoozeLabels(l10n)
      ..channelNames = {
        NotificationChannels.reminders: l10n.channelReminders,
        NotificationChannels.streak: l10n.channelStreak,
        NotificationChannels.pomodoro: l10n.channelPomodoro,
      };

    if (await _settings.getBool(ReminderKeys.enabled) ?? false) {
      await _planRituals(at, l10n);
    }
    await _planTaskReminders(at, l10n);
    await _planDebtReminders(at, l10n);
    await SnoozeStore(_db).reapply(_notifications, now: at);
  }

  /// Called after every check-in, expense log or seed edit: whatever is
  /// already done today has nothing left to nag about.
  Future<void> reevaluate({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final l10n = await _l10n();
    _notifications.snoozeLabels = _snoozeLabels(l10n);
    if (await _goalMet(_dayOf(_todayAt(ReminderDefaults.streakRisk, at)))) {
      await _notifications.cancel(ReminderIds.streakRisk);
    }
    if (await _expensesLogged(_dayOf(_todayAt(ReminderDefaults.expense, at)))) {
      await _notifications.cancel(ReminderIds.expenses);
    }
    await _planTaskReminders(at, l10n);
  }

  /// The localized "remind me in…" actions every reminder carries.
  static List<(String, String)> _snoozeLabels(AppLocalizations l10n) => [
    (SnoozeActions.id(10), l10n.snooze10),
    (SnoozeActions.id(60), l10n.snooze60),
    (SnoozeActions.id(180), l10n.snooze180),
  ];

  /// Morning review, evening plan, expense check-in and the streak-risk
  /// nudge — the daily rituals behind the master switch.
  Future<void> _planRituals(DateTime at, AppLocalizations l10n) async {
    final morning = _todayAt(
      await _settings.getTime(ReminderKeys.morningTime) ??
          ReminderDefaults.morning,
      at,
    );
    if (morning.isAfter(at)) {
      await _notifications.schedule(
        id: ReminderIds.morning,
        channelId: NotificationChannels.reminders,
        title: l10n.notifMorningTitle,
        body: l10n.notifMorningBody,
        when: morning,
        route: ReminderRoutes.field,
      );
    }

    final evening = _todayAt(
      await _settings.getTime(ReminderKeys.eveningTime) ??
          ReminderDefaults.evening,
      at,
    );
    if (evening.isAfter(at)) {
      await _notifications.schedule(
        id: ReminderIds.eveningPlan,
        channelId: NotificationChannels.reminders,
        title: l10n.notifEveningTitle,
        body: l10n.notifEveningBody,
        when: evening,
        route: ReminderRoutes.planner,
      );
    }

    final expenseAt = _todayAt(
      await _settings.getTime(ReminderKeys.expenseTime) ??
          ReminderDefaults.expense,
      at,
    );
    if (expenseAt.isAfter(at) && !await _expensesLogged(_dayOf(expenseAt))) {
      await _notifications.schedule(
        id: ReminderIds.expenses,
        channelId: NotificationChannels.reminders,
        title: l10n.notifExpenseTitle,
        body: l10n.notifExpenseBody,
        when: expenseAt,
        route: ReminderRoutes.finances,
      );
    }

    final lateCheck = _todayAt(ReminderDefaults.streakRisk, at);
    final nudge = await _settings.getBool(ReminderKeys.streakNudge) ?? true;
    if (nudge &&
        lateCheck.isAfter(at) &&
        !await _goalMet(_dayOf(lateCheck)) &&
        await _streaks.currentGlobal() > 0) {
      await _notifications.schedule(
        id: ReminderIds.streakRisk,
        channelId: NotificationChannels.streak,
        title: l10n.notifStreakTitle,
        body: l10n.notifStreakBody,
        when: lateCheck,
        alarm: false,
        route: ReminderRoutes.field,
      );
    }
  }

  /// Unsettled debts nag daily at their remind-at time (default 19:00)
  /// until paid off, quoting what is still owed.
  Future<void> _planDebtReminders(DateTime at, AppLocalizations l10n) async {
    await _cancelStored(ReminderKeys.debtIds);

    final rows =
        await (_db.select(_db.debts)
              ..where((d) => d.settledAt.isNull() & d.deletedAt.isNull())
              ..orderBy([(d) => OrderingTerm.asc(d.createdAt)]))
            .get();
    final paid = await _paidByDebt();

    final scheduled = <int>[];
    for (final row in rows) {
      if (scheduled.length >= ReminderIds.rangeSize) break;
      final when = _todayAt(
        SettingsRepository.parseTime(row.remindAt) ?? ReminderDefaults.debt,
        at,
      );
      if (!when.isAfter(at)) continue;

      final remaining = (row.amountMinor - (paid[row.uuid] ?? 0)).clamp(
        0,
        row.amountMinor,
      );
      final id = ReminderIds.debtBase + scheduled.length;
      await _notifications.schedule(
        id: id,
        channelId: NotificationChannels.reminders,
        title: l10n.notifDebtTitle(row.person),
        body: l10n.notifDebtBody(
          formatAmount(remaining, Currency.fromCode(row.currency)),
        ),
        when: when,
        route: ReminderRoutes.finances,
      );
      scheduled.add(id);
    }
    await _storeIds(ReminderKeys.debtIds, scheduled);
  }

  /// Per-seed reminders (checkpoint gap G4): every commitment due on the
  /// day its reminder fires, and not yet done, gets its own nudge.
  Future<void> _planTaskReminders(DateTime at, AppLocalizations l10n) async {
    await _cancelStored(ReminderKeys.taskIds);

    final commitments = (await _commitments.activeOnce())
        .where((c) => c.remindAt != null)
        .toList();
    if (commitments.isEmpty) {
      await _storeIds(ReminderKeys.taskIds, const []);
      return;
    }

    final scheduled = <int>[];
    for (final commitment in commitments) {
      if (scheduled.length >= ReminderIds.rangeSize) break;
      final time = SettingsRepository.parseTime(commitment.remindAt);
      if (time == null) continue;
      final when = _todayAt(time, at);
      if (!when.isAfter(at)) continue;

      final day = _dayOf(when);
      final loggedThatDay = await _commitments.loggedOnOnce(
        commitment.uuid,
        day,
      );
      if (loggedThatDay > 0) continue;
      final due = isDueOn(
        commitment,
        day,
        doneDaysThisWeek: await _commitments.doneDaysInWeekOnce(
          commitment.uuid,
          day,
        ),
        totalLogged: await _commitments.totalOnce(commitment.uuid),
      );
      if (!due) continue;

      final id = ReminderIds.taskBase + scheduled.length;
      await _notifications.schedule(
        id: id,
        channelId: NotificationChannels.reminders,
        title: commitment.title,
        body: l10n.taskReminderBody,
        when: when,
        route: ReminderRoutes.field,
      );
      scheduled.add(id);
    }
    await _storeIds(ReminderKeys.taskIds, scheduled);
  }

  // --------------------------------------------------------------- helpers

  Future<bool> _expensesLogged(HarvestDay day) async {
    final row =
        await (_db.select(_db.expenses)
              ..where(
                (e) => e.harvestDay.equals(day.key) & e.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<bool> _goalMet(HarvestDay day) async {
    final goal = await _streaks.dailyGoal();
    final actions = await _streaks.productiveActions(day);
    return actions >= goal;
  }

  Future<Map<String, int>> _paidByDebt() async {
    final sum = _db.debtPayments.amountMinor.sum();
    final query = _db.selectOnly(_db.debtPayments)
      ..addColumns([_db.debtPayments.debtUuid, sum])
      ..where(_db.debtPayments.deletedAt.isNull())
      ..groupBy([_db.debtPayments.debtUuid]);
    return {
      for (final row in await query.get())
        row.read(_db.debtPayments.debtUuid)!: row.read(sum) ?? 0,
    };
  }

  Future<void> _cancelStored(String key) async {
    final row = await (_db.select(
      _db.kvSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    if (row == null) return;
    final ids = jsonDecode(row.valueJson);
    if (ids is! List) return;
    for (final id in ids) {
      if (id is int) await _notifications.cancel(id);
    }
  }

  Future<void> _storeIds(String key, List<int> ids) => _db
      .into(_db.kvSettings)
      .insertOnConflictUpdate(
        KvSettingsCompanion.insert(
          key: key,
          valueJson: jsonEncode(ids),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<AppLocalizations> _l10n() => localizationsFromSettings(_db);

  /// [time] on the calendar day of [now].
  DateTime _todayAt((int, int) time, DateTime now) =>
      DateTime(now.year, now.month, now.day, time.$1, time.$2);

  /// The Harvest Day a fire time belongs to.
  HarvestDay _dayOf(DateTime when) => HarvestDay.of(when);
}

@Riverpod(keepAlive: true)
NotificationPlanner notificationPlanner(Ref ref) => NotificationPlanner(
  ref.watch(databaseProvider),
  ref.watch(notificationServiceProvider),
  ref.watch(streakServiceProvider),
);
