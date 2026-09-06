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
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/planner/domain/comeback.dart';
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

  /// Scheduled albums, which are seeds and get an ordinary seed
  /// reminder (rule G3). Its own range so a new album never renumbers
  /// a task's pending notification.
  static const albumBase = 6100;

  /// The comeback ladder: at most one id per rung, well clear of the
  /// snoozed copies that start at 5000.
  static const comebackBase = 4100;

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
  static const albumIds = 'reminders.albumIds';
  static const debtIds = 'reminders.debtIds';
  static const comebackIds = 'reminders.comebackIds';
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
      _commitments = CommitmentsRepository(_db),
      _gallery = GalleryRepository(_db, GalleryStorage());

  final HarvestDatabase _db;
  final NotificationGateway _notifications;
  final StreakService _streaks;
  final SettingsRepository _settings;
  final CommitmentsRepository _commitments;

  /// Reminder planning only reads album rows, so the storage handed in
  /// here never has to resolve a directory.
  final GalleryRepository _gallery;

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

    final lastActive = await _lastActiveDay(at);
    final comebackToday =
        rungOn(lastActive, _dayOf(at)) != null && !await _activeOn(_dayOf(at));

    if (await _settings.getBool(ReminderKeys.enabled) ?? false) {
      await _planRituals(at, l10n, skipMorning: comebackToday);
    }
    await _planComebacks(at, l10n, lastActive);
    await _planTaskReminders(at, l10n);
    await _planAlbumReminders(at, l10n);
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
    await _planAlbumReminders(at, l10n);
    await _planComebacks(at, l10n, await _lastActiveDay(at));
  }

  /// The localized "remind me in…" actions every reminder carries.
  static List<(String, String)> _snoozeLabels(AppLocalizations l10n) => [
    (SnoozeActions.id(10), l10n.snooze10),
    (SnoozeActions.id(60), l10n.snooze60),
    (SnoozeActions.id(180), l10n.snooze180),
  ];

  /// Morning review, evening plan, expense check-in and the streak-risk
  /// nudge — the daily rituals behind the master switch.
  Future<void> _planRituals(
    DateTime at,
    AppLocalizations l10n, {
    bool skipMorning = false,
  }) async {
    final morning = _todayAt(
      await _settings.getTime(ReminderKeys.morningTime) ??
          ReminderDefaults.morning,
      at,
    );
    // A comeback nudge speaks at the same hour and says more; two
    // notifications in the same minute would only spend the day's cap.
    if (!skipMorning && morning.isAfter(at)) {
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

  /// A scheduled album is a seed, so it gets the same nudge a seed
  /// gets — same channel, same snooze, same silence once it is fed.
  Future<void> _planAlbumReminders(DateTime at, AppLocalizations l10n) async {
    await _cancelStored(ReminderKeys.albumIds);

    final albums = (await _gallery.albumsOnce())
        .where((album) => album.isScheduled && album.remindAt != null)
        .toList();
    if (albums.isEmpty) {
      await _storeIds(ReminderKeys.albumIds, const []);
      return;
    }

    final scheduled = <int>[];
    for (final album in albums) {
      if (scheduled.length >= ReminderIds.rangeSize) break;
      final time = SettingsRepository.parseTime(album.remindAt);
      if (time == null) continue;
      final when = _todayAt(time, at);
      if (!when.isAfter(at)) continue;

      final day = _dayOf(when);
      if (await _gallery.countOn(album.uuid, day) > 0) continue;
      final due = album.isDueOn(
        day,
        doneDaysThisWeek: await _gallery.doneDaysInWeekOnce(album.uuid, day),
      );
      if (!due) continue;

      final id = ReminderIds.albumBase + scheduled.length;
      await _notifications.schedule(
        id: id,
        channelId: NotificationChannels.reminders,
        title: album.name,
        body: l10n.albumReminderBody,
        when: when,
        route: ReminderRoutes.field,
      );
      scheduled.add(id);
    }
    await _storeIds(ReminderKeys.albumIds, scheduled);
  }

  /// The comeback ladder (checkpoint C3-8): one nudge per rung of
  /// absence, scheduled ahead so it fires whether or not the app is
  /// ever opened again, and wiped the moment anything is logged.
  ///
  /// It is deliberately outside the master reminder switch in only one
  /// direction: turning reminders off silences it too, because this is
  /// a ritual, not a time I asked for.
  Future<void> _planComebacks(
    DateTime at,
    AppLocalizations l10n,
    HarvestDay lastActive,
  ) async {
    await _cancelStored(ReminderKeys.comebackIds);
    if (!(await _settings.getBool(ReminderKeys.enabled) ?? false)) {
      await _storeIds(ReminderKeys.comebackIds, const []);
      return;
    }

    final time =
        await _settings.getTime(ReminderKeys.morningTime) ??
        ReminderDefaults.morning;
    final scheduled = <int>[];
    for (final (rung, day) in upcomingComebacks(lastActive, _dayOf(at))) {
      final when = DateTime(day.year, day.month, day.day, time.$1, time.$2);
      if (!when.isAfter(at)) continue;
      final id = ReminderIds.comebackBase + rung.index;
      await _notifications.schedule(
        id: id,
        channelId: NotificationChannels.reminders,
        title: _comebackTitle(l10n, rung),
        body: _comebackBody(l10n, rung),
        when: when,
        alarm: false,
        route: ReminderRoutes.field,
        snoozeLabels: const [],
      );
      scheduled.add(id);
    }
    await _storeIds(ReminderKeys.comebackIds, scheduled);
  }

  /// The rotation: one voice per rung, warm at the top and plainer as
  /// the silence grows. Never shame, per the notification spec.
  static String _comebackTitle(AppLocalizations l10n, ComebackRung rung) =>
      switch (rung) {
        ComebackRung.day1 => l10n.comebackDay1Title,
        ComebackRung.day3 => l10n.comebackDay3Title,
        ComebackRung.week1 => l10n.comebackWeek1Title,
        ComebackRung.week2 => l10n.comebackWeek2Title,
        ComebackRung.month1 => l10n.comebackMonth1Title,
        ComebackRung.month2 => l10n.comebackMonth2Title,
      };

  static String _comebackBody(AppLocalizations l10n, ComebackRung rung) =>
      switch (rung) {
        ComebackRung.day1 => l10n.comebackDay1Body,
        ComebackRung.day3 => l10n.comebackDay3Body,
        ComebackRung.week1 => l10n.comebackWeek1Body,
        ComebackRung.week2 => l10n.comebackWeek2Body,
        ComebackRung.month1 => l10n.comebackMonth1Body,
        ComebackRung.month2 => l10n.comebackMonth2Body,
      };

  /// The last Harvest Day I did anything at all — checked a seed in or
  /// logged an expense. With nothing on record the ladder starts from
  /// the day the first seed was planted, so an app installed and then
  /// forgotten still speaks up.
  Future<HarvestDay> _lastActiveDay(DateTime at) async {
    final today = _dayOf(at);
    final checkIn =
        await (_db.select(_db.checkIns)
              ..where((c) => c.deletedAt.isNull())
              ..orderBy([(c) => OrderingTerm.desc(c.harvestDay)])
              ..limit(1))
            .getSingleOrNull();
    final expense =
        await (_db.select(_db.expenses)
              ..where((e) => e.deletedAt.isNull())
              ..orderBy([(e) => OrderingTerm.desc(e.harvestDay)])
              ..limit(1))
            .getSingleOrNull();
    final days = [
      HarvestDay.tryParse(checkIn?.harvestDay),
      HarvestDay.tryParse(expense?.harvestDay),
    ].nonNulls.toList();
    if (days.isNotEmpty) {
      days.sort((a, b) => b.compareTo(a));
      return days.first.compareTo(today) > 0 ? today : days.first;
    }

    final firstSeed =
        await (_db.select(_db.commitments)
              ..where((c) => c.deletedAt.isNull())
              ..orderBy([(c) => OrderingTerm.asc(c.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    return firstSeed == null ? today : HarvestDay.of(firstSeed.createdAt);
  }

  /// Anything logged on [day]: the comeback ladder's silencer.
  Future<bool> _activeOn(HarvestDay day) async {
    final checkIn =
        await (_db.select(_db.checkIns)
              ..where(
                (c) => c.harvestDay.equals(day.key) & c.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (checkIn != null) return true;
    return _expensesLogged(day);
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
