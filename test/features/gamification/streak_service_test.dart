import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';

void main() {
  late HarvestDatabase db;
  late StreakService streaks;
  late CheckInService checkIns;
  final day = HarvestDay.parse('2026-09-02');

  Future<Commitment> habit(String id) async {
    await db
        .into(db.commitments)
        .insertOnConflictUpdate(
          CommitmentsCompanion.insert(
            uuid: id,
            type: 'habit',
            title: id,
            scheduleJson: const Value('{"type":"daily"}'),
            // Planted before the days these tests judge: nothing is due
            // on a day that ended before the seed existed.
            createdAt: Value(DateTime(2026)),
          ),
        );
    return Commitment(
      uuid: id,
      type: CommitmentType.habit,
      title: id,
      createdAt: DateTime(2026),
      schedule: const DailySchedule(),
    );
  }

  setUp(() async {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    streaks = StreakService(db);
    checkIns = CheckInService(db, streaks);
    // Goal of 2 keeps tests compact.
    await db
        .into(db.kvSettings)
        .insertOnConflictUpdate(
          KvSettingsCompanion.insert(
            key: StreakService.goalKey,
            valueJson: '2',
          ),
        );
  });

  tearDown(() => db.close());

  Future<StreakRow?> row(String scope) => (db.select(
    db.streaks,
  )..where((s) => s.scope.equals(scope))).getSingleOrNull();

  Future<void> seedGlobal({
    required int current,
    required String lastEarnedDay,
    int freezes = 0,
  }) => db
      .into(db.streaks)
      .insertOnConflictUpdate(
        StreaksCompanion.insert(
          scope: StreakService.globalScope,
          current: Value(current),
          best: Value(current),
          lastEarnedDay: Value(lastEarnedDay),
          freezesStored: Value(freezes),
        ),
      );

  Future<void> setLastJudged(String dayKey) => db
      .into(db.kvSettings)
      .insertOnConflictUpdate(
        KvSettingsCompanion.insert(
          key: 'streak.lastJudgedDay',
          valueJson: '"$dayKey"',
        ),
      );

  group('live global streak', () {
    test('extends once the daily goal is met, not before', () async {
      await checkIns.checkIn(await habit('a'), day: day);
      expect((await row('global'))?.current ?? 0, 0);

      await checkIns.checkIn(await habit('b'), day: day);
      final global = await row('global');
      expect(global!.current, 1);
      expect(global.lastEarnedDay, day.key);
    });

    test('does not double-extend on extra actions the same day', () async {
      for (final id in ['a', 'b', 'c']) {
        await checkIns.checkIn(await habit(id), day: day);
      }
      expect((await row('global'))!.current, 1);
    });

    test('undo below the goal retracts the day', () async {
      final a = await habit('a');
      await checkIns.checkIn(a, day: day);
      await checkIns.checkIn(await habit('b'), day: day);
      expect((await row('global'))!.current, 1);

      await checkIns.undoToday(a, day: day);
      expect((await row('global'))!.current, 0);
    });
  });

  group('individual habit streaks', () {
    test('each completed day adds one', () async {
      final a = await habit('a');
      await checkIns.checkIn(a, day: day);
      await checkIns.checkIn(a, day: day.next);
      final streak = await row('a');
      expect(streak!.current, 2);
      expect(streak.best, 2);
    });
  });

  group('reconcile', () {
    test('first run only marks the baseline', () async {
      await streaks.reconcile(now: day.next.startsAt);
      expect(await row('global'), isNull);
    });

    test('a missed day breaks the streak when no freeze is stored', () async {
      await seedGlobal(current: 5, lastEarnedDay: '2026-09-01');
      await setLastJudged('2026-09-01');
      // 2026-09-02 passes with no actions; reconcile on the 3rd.
      await streaks.reconcile(now: HarvestDay.parse('2026-09-03').startsAt);
      final global = await row('global');
      expect(global!.current, 0);
      expect(global.best, 5);
    });

    test('a stored freeze is consumed instead of breaking', () async {
      await seedGlobal(current: 5, lastEarnedDay: '2026-09-01', freezes: 2);
      await setLastJudged('2026-09-01');
      await streaks.reconcile(now: HarvestDay.parse('2026-09-03').startsAt);
      final global = await row('global');
      expect(global!.current, 5);
      expect(global.freezesStored, 1);
    });

    test('a met day found during reconcile extends the streak', () async {
      await seedGlobal(current: 5, lastEarnedDay: '2026-09-01');
      await setLastJudged('2026-09-01');
      // Two actions happened on the 2nd but the app never re-opened.
      await checkIns.checkIn(await habit('a'), day: day);
      await checkIns.checkIn(await habit('b'), day: day);
      // The live path already extended to 6; reconcile must not double it.
      await streaks.reconcile(now: HarvestDay.parse('2026-09-03').startsAt);
      expect((await row('global'))!.current, 6);
    });

    test('is idempotent across repeated runs', () async {
      await seedGlobal(current: 5, lastEarnedDay: '2026-09-01', freezes: 1);
      await setLastJudged('2026-09-01');
      final at = HarvestDay.parse('2026-09-03').startsAt;
      await streaks.reconcile(now: at);
      await streaks.reconcile(now: at);
      final global = await row('global');
      expect(global!.freezesStored, 1 - 1);
      expect(global.current, 5);
    });

    test('a habit missing a due day loses its streak', () async {
      final a = await habit('a');
      await checkIns.checkIn(a, day: HarvestDay.parse('2026-09-01'));
      expect((await row('a'))!.current, 1);
      await setLastJudged('2026-09-01');
      // Missed the 2nd entirely.
      await streaks.reconcile(now: HarvestDay.parse('2026-09-03').startsAt);
      final streak = await row('a');
      expect(streak!.current, 0);
      expect(streak.best, 1);
    });
  });

  group('scheduled albums (Audit 2, B-01)', () {
    Future<void> album(String id, {String schedule = '{"type":"daily"}'}) => db
        .into(db.albums)
        .insertOnConflictUpdate(
          AlbumsCompanion.insert(
            uuid: id,
            name: id,
            scheduleJson: Value(schedule),
            createdAt: Value(DateTime(2026)),
          ),
        );

    Future<void> picture(String albumId, HarvestDay on) => db
        .into(db.memories)
        .insert(
          MemoriesCompanion.insert(
            uuid: '$albumId-${on.key}',
            albumUuid: albumId,
            harvestDay: on.key,
            path: 'x.jpg',
          ),
        );

    test('a missed due day breaks the album streak', () async {
      await album('gym');
      await picture('gym', HarvestDay.parse('2026-09-01'));
      await streaks.onAlbumMemory('gym', HarvestDay.parse('2026-09-01'));
      expect((await row('gym'))!.current, 1);

      await setLastJudged('2026-09-01');
      // A check-in elsewhere keeps the day from being "idle"; the album
      // itself got nothing on the 2nd.
      await checkIns.checkIn(
        await habit('a'),
        day: HarvestDay.parse('2026-09-02'),
      );
      await streaks.reconcile(now: HarvestDay.parse('2026-09-03').startsAt);

      final streak = await row('gym');
      expect(streak!.current, 0);
      expect(streak.best, 1);
    });

    test('an idle stretch breaks it too', () async {
      await album('gym');
      await streaks.onAlbumMemory('gym', HarvestDay.parse('2026-09-01'));
      await setLastJudged('2026-09-01');
      await streaks.reconcile(now: HarvestDay.parse('2026-09-05').startsAt);
      expect((await row('gym'))!.current, 0);
    });

    test('a picture on the due day keeps it', () async {
      await album('gym');
      await picture('gym', HarvestDay.parse('2026-09-01'));
      await streaks.onAlbumMemory('gym', HarvestDay.parse('2026-09-01'));
      await picture('gym', HarvestDay.parse('2026-09-02'));
      await streaks.onAlbumMemory('gym', HarvestDay.parse('2026-09-02'));
      await setLastJudged('2026-09-01');
      await streaks.reconcile(now: HarvestDay.parse('2026-09-03').startsAt);
      expect((await row('gym'))!.current, 2);
    });
  });

  group('a flexible habit through an idle stretch (Audit 2, B-03)', () {
    Future<Commitment> flexible(String id, int times) async {
      await db
          .into(db.commitments)
          .insertOnConflictUpdate(
            CommitmentsCompanion.insert(
              uuid: id,
              type: 'habit',
              title: id,
              scheduleJson: Value('{"type":"timesPerWeek","times":$times}'),
              createdAt: Value(DateTime(2026)),
            ),
          );
      return Commitment(
        uuid: id,
        type: CommitmentType.habit,
        title: id,
        createdAt: DateTime(2026),
        schedule: TimesPerWeekSchedule(times: times),
      );
    }

    // 2026-08-31 is a Monday; the 6th a Sunday.
    test('a quiet weekend does not break a quota the week met', () async {
      final gym = await flexible('gym', 3);
      for (final d in ['2026-08-31', '2026-09-01', '2026-09-02']) {
        await checkIns.checkIn(gym, day: HarvestDay.parse(d));
      }
      expect((await row('gym'))!.current, 3);
      await setLastJudged('2026-09-02');

      // Thursday to Sunday: nothing at all.
      await streaks.reconcile(now: HarvestDay.parse('2026-09-07').startsAt);
      expect((await row('gym'))!.current, 3, reason: 'the week was met');
    });

    test('a week that fell short still breaks when it closes', () async {
      final gym = await flexible('gym', 3);
      await checkIns.checkIn(gym, day: HarvestDay.parse('2026-08-31'));
      await setLastJudged('2026-08-31');
      await streaks.reconcile(now: HarvestDay.parse('2026-09-07').startsAt);
      expect((await row('gym'))!.current, 0);
    });
  });

  group('what counts as activity (Audit 2, B-04)', () {
    test('a night written down keeps the stretch from being idle', () async {
      // A daily habit checked on the 1st, then only sleep logged on the
      // 2nd: the fast path must not run, and the habit is judged
      // day by day — it still breaks, for its own missed day, but the
      // global streak is not thrown away wholesale.
      final a = await habit('a');
      await checkIns.checkIn(a, day: HarvestDay.parse('2026-09-01'));
      await seedGlobal(current: 4, lastEarnedDay: '2026-09-01', freezes: 1);
      await setLastJudged('2026-09-01');
      await db
          .into(db.sleepSessions)
          .insert(
            SleepSessionsCompanion.insert(
              uuid: 'n1',
              harvestDay: '2026-09-02',
              fellAsleepAt: DateTime(2026, 9, 1, 23),
              wokeAt: DateTime(2026, 9, 2, 7),
              targetMinutes: 480,
            ),
          );
      await streaks.reconcile(now: HarvestDay.parse('2026-09-03').startsAt);
      // One missed day, one freeze: spent, streak kept.
      final global = await row('global');
      expect(global!.current, 4);
      expect(global.freezesStored, 0);
    });
  });

  group('the last-judged setting (Audit 2, B-08)', () {
    test('a value that lost its quotes still reads', () async {
      await seedGlobal(current: 5, lastEarnedDay: '2026-09-01');
      await db
          .into(db.kvSettings)
          .insertOnConflictUpdate(
            KvSettingsCompanion.insert(
              key: 'streak.lastJudgedDay',
              valueJson: '2026-09-01',
            ),
          );
      await streaks.reconcile(now: HarvestDay.parse('2026-09-03').startsAt);
      expect((await row('global'))!.current, 0, reason: 'the 2nd was judged');
    });
  });

  group('milestones', () {
    test('reaching 7 days grants coins', () async {
      await seedGlobal(current: 6, lastEarnedDay: '2026-09-01');
      await checkIns.checkIn(await habit('a'), day: day);
      await checkIns.checkIn(await habit('b'), day: day);
      expect((await row('global'))!.current, 7);

      final coins = await (db.select(
        db.ledger,
      )..where((l) => l.kind.equals('coin'))).get();
      expect(coins.single.delta, streakMilestoneCoins[7]);
      expect(coins.single.reason, 'streak:7');
    });
  });
}
