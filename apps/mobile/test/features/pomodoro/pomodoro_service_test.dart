import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/pomodoro/domain/pomodoro_service.dart';

void main() {
  late HarvestDatabase db;
  late PomodoroService service;
  const config = PomodoroConfig();

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    service = PomodoroService(db);
  });

  tearDown(() => db.close());

  test('snapshot json round-trips both running and paused forms', () {
    final running = PomodoroSnapshot(
      sessionUuid: 's1',
      phase: PomodoroPhase.focus,
      blocksDone: 2,
      commitmentUuid: 'c1',
      endsAt: DateTime(2026, 9, 2, 10, 25),
    );
    const paused = PomodoroSnapshot(
      sessionUuid: 's2',
      phase: PomodoroPhase.shortBreak,
      blocksDone: 1,
      pausedRemaining: Duration(minutes: 3),
    );
    for (final snapshot in [running, paused]) {
      final back = PomodoroSnapshot.fromJson(snapshot.toJson());
      expect(back.sessionUuid, snapshot.sessionUuid);
      expect(back.phase, snapshot.phase);
      expect(back.blocksDone, snapshot.blocksDone);
      expect(back.endsAt, snapshot.endsAt);
      expect(back.pausedRemaining, snapshot.pausedRemaining);
    }
  });

  test('start persists the session row and the active snapshot', () async {
    final at = DateTime(2026, 9, 2, 10);
    final snapshot = await service.startSession(
      config: config,
      commitmentUuid: 'c1',
      now: at,
    );
    expect(snapshot.endsAt, at.add(const Duration(minutes: 25)));

    final active = await service.loadActive();
    expect(active!.sessionUuid, snapshot.sessionUuid);

    final rows = await db.select(db.pomodoroSessions).get();
    expect(rows.single.commitmentUuid, 'c1');
    expect(rows.single.harvestDay, '2026-09-02');
  });

  test('completing a block pays XP and counts on the session', () async {
    final snapshot = await service.startSession(
      config: config,
      now: DateTime(2026, 9, 2, 10),
    );
    await service.completeBlock(snapshot, now: DateTime(2026, 9, 2, 10, 25));

    final session = (await db.select(db.pomodoroSessions).get()).single;
    expect(session.focusBlocks, 1);

    final xp = (await db.select(db.ledger).get()).single;
    expect(xp.delta, pomodoroBlockXp);
    expect(xp.kind, 'xp');
  });

  test('ending clears the active snapshot and stamps the row', () async {
    final snapshot = await service.startSession(
      config: config,
      now: DateTime(2026, 9, 2, 10),
    );
    await service.endSession(snapshot, now: DateTime(2026, 9, 2, 11));
    expect(await service.loadActive(), isNull);
    final session = (await db.select(db.pomodoroSessions).get()).single;
    expect(session.endedAt, DateTime(2026, 9, 2, 11));
  });

  group('Q5-40', () {
    Future<int> xp() async =>
        (await db
                .select(
                  db.ledger,
                )
                .get())
            .fold<int>(0, (sum, row) => sum + row.delta);

    test('a second start gives back the running timer', () async {
      final first = await service.startSession(config: config);
      final second = await service.startSession(config: config);
      expect(second.sessionUuid, first.sessionUuid);
      expect(await db.select(db.pomodoroSessions).get(), hasLength(1));
    });

    test('a block is paid with the timer saved beside it, and once', () async {
      final snapshot = await service.startSession(config: config);
      final next = snapshot.copyWith(
        phase: PomodoroPhase.shortBreak,
        blocksDone: 1,
      );
      await service.completeBlock(snapshot, then: next);
      expect((await service.loadActive())!.blocksDone, 1);
      expect(await xp(), pomodoroBlockXp);
      // The same block again, as a relaunch from a stale snapshot
      // would: nothing more is paid.
      await service.completeBlock(snapshot, then: next);
      expect(await xp(), pomodoroBlockXp);
      final row = (await db.select(db.pomodoroSessions).get()).single;
      expect(row.focusBlocks, 1);
    });
  });
}
