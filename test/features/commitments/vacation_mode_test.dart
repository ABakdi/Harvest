import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';

void main() {
  late HarvestDatabase db;
  late CommitmentsRepository repo;
  late StreakService streaks;
  late CheckInService checkIns;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    repo = CommitmentsRepository(db);
    streaks = StreakService(db);
    checkIns = CheckInService(db, streaks);
  });

  tearDown(() => db.close());

  Future<void> setLastJudged(String dayKey) => db
      .into(db.kvSettings)
      .insertOnConflictUpdate(
        KvSettingsCompanion.insert(
          key: StreakService.lastJudgedKey,
          valueJson: '"$dayKey"',
        ),
      );

  test('pausing survives a missed due day; resuming judges again', () async {
    final habit = await repo.create(
      type: CommitmentType.habit,
      title: 'Exercise',
      schedule: const DailySchedule(),
      createdAt: DateTime(2026),
    );
    // Build a 1-day streak on the 1st.
    await checkIns.checkIn(habit, day: HarvestDay.parse('2026-09-01'));
    await setLastJudged('2026-09-01');

    // Vacation starts on the 1st: the 2nd passes unlogged while paused.
    await repo.setPaused(
      habit.uuid,
      paused: true,
      at: HarvestDay.parse('2026-09-01').startsAt,
    );
    await streaks.reconcile(now: HarvestDay.parse('2026-09-03').startsAt);

    final row = await (db.select(
      db.streaks,
    )..where((s) => s.scope.equals(habit.uuid))).getSingle();
    expect(row.current, 1, reason: 'paused habit must not break');

    // Back from vacation: the 3rd passes unlogged while active.
    await repo.setPaused(
      habit.uuid,
      paused: false,
      at: HarvestDay.parse('2026-09-03').startsAt,
    );
    await streaks.reconcile(now: HarvestDay.parse('2026-09-04').startsAt);
    final after = await (db.select(
      db.streaks,
    )..where((s) => s.scope.equals(habit.uuid))).getSingle();
    expect(after.current, 0, reason: 'active habit is judged again');
  });

  test('pausing after the miss does not rescue the streak', () async {
    final habit = await repo.create(
      type: CommitmentType.habit,
      title: 'Exercise',
      schedule: const DailySchedule(),
      createdAt: DateTime(2026),
    );
    await checkIns.checkIn(habit, day: HarvestDay.parse('2026-09-01'));
    await setLastJudged('2026-09-01');

    // The 2nd is missed, and only then does vacation begin.
    await repo.setPaused(
      habit.uuid,
      paused: true,
      at: HarvestDay.parse('2026-09-03').startsAt,
    );
    await streaks.reconcile(now: HarvestDay.parse('2026-09-03').startsAt);

    final row = await (db.select(
      db.streaks,
    )..where((s) => s.scope.equals(habit.uuid))).getSingle();
    expect(row.current, 0, reason: 'the miss already happened');
  });

  test('editing a commitment updates fields and the outbox', () async {
    final habit = await repo.create(
      type: CommitmentType.habit,
      title: 'Read',
      schedule: const DailySchedule(),
    );
    await repo.update(
      habit.copyWith(
        title: 'Read more',
        schedule: const TimesPerWeekSchedule(times: 3),
      ),
    );
    final all = await repo.watchActive().first;
    expect(all.single.title, 'Read more');
    expect(all.single.schedule, const TimesPerWeekSchedule(times: 3));

    final ops = await db.select(db.outbox).get();
    expect(ops.map((o) => o.op), containsAll(['insert', 'update']));
  });
}
