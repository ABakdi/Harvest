import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/goals/data/goals_repository.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/sync/domain/sync_service.dart';

import '../../support/fake_remote.dart';

/// Phase 6, M6.4: two phones and one server converge ([[Sync-API]]).
void main() {
  late HarvestDatabase a;
  late HarvestDatabase b;
  late FakeRemote remote;
  late SyncService syncA;
  late SyncService syncB;

  setUp(() {
    a = HarvestDatabase.forTesting(NativeDatabase.memory());
    b = HarvestDatabase.forTesting(NativeDatabase.memory());
    remote = FakeRemote();
    syncA = SyncService(a, remote);
    syncB = SyncService(b, remote);
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  test(
    'a seed, its check-in, its XP and a goal travel to the other phone',
    () async {
      final seed = await CommitmentsRepository(a).create(
        type: CommitmentType.habit,
        title: 'Read',
        schedule: const DailySchedule(),
      );
      await CheckInService(a, StreakService(a)).checkIn(seed);
      final goal = await GoalsRepository(a).create(title: 'Read 20 books');
      await GoalsRepository(a).addItem(goal.uuid, body: 'Library card');

      await syncA.run();
      await syncB.run();

      final seeds = await CommitmentsRepository(b).activeOnce();
      expect(seeds.single.title, 'Read');
      expect(await b.select(b.checkIns).get(), hasLength(1));
      final xp = (await b.select(b.ledger).get()).fold<int>(
        0,
        (sum, row) => sum + row.delta,
      );
      expect(xp, 10);
      final goals = await GoalsRepository(b).watchAll().first;
      expect(goals.single.items.single.body, 'Library card');
    },
  );

  test('pulled rows never go back into the outbox', () async {
    await NotesRepository(a).create(title: 'Log');
    await syncA.run();
    await syncB.run();
    expect(await b.select(b.outbox).get(), isEmpty);
    expect(await b.select(b.notes).get(), hasLength(1));
  });

  test('the newer edit wins, whichever phone made it', () async {
    final note = await NotesRepository(a).create(title: 'Draft');
    await syncA.run();
    await syncB.run();

    await NotesRepository(b).update(note.uuid, body: 'from b');
    await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 100));
    await NotesRepository(a).update(note.uuid, body: 'from a, later');
    await syncB.run();
    await syncA.run();
    await syncB.run();

    for (final db in [a, b]) {
      final row = await (db.select(
        db.notes,
      )..where((n) => n.uuid.equals(note.uuid))).getSingle();
      expect(row.body, 'from a, later');
    }
  });

  test('a hard delete travels as a tombstone', () async {
    final notes = NotesRepository(a);
    final note = await notes.create(title: 'Gone');
    await syncA.run();
    await syncB.run();
    await notes.purge(note.uuid);
    await syncA.run();
    await syncB.run();
    expect(await b.select(b.notes).get(), isEmpty);
  });

  test('bookkeeping settings stay home, preferences travel', () async {
    final settings = SettingsRepository(a);
    await settings.setString('themeMode', 'dark');
    await settings.setString('streak.lastJudgedDay', '2026-09-01');
    await syncA.run();
    await syncB.run();
    final other = SettingsRepository(b);
    expect(await other.getString('themeMode'), 'dark');
    expect(await other.getString('streak.lastJudgedDay'), isNull);
  });

  test('money waits for the passphrase; refused rows stay queued', () async {
    await FinancesRepository(a).log(
      amountMinor: 500,
      category: 'food',
      day: HarvestDay.today(),
    );
    remote.refuse.add('ledger');
    final report = await syncA.run();
    expect(report.heldBack, greaterThan(0));
    expect(report.invalid, greaterThan(0));
    final left = (await a.select(a.outbox).get())
        .map((r) => r.targetTable)
        .toSet();
    expect(left, containsAll(['expenses', 'ledger']));
    expect(
      remote.row('expenses', (await a.select(a.expenses).getSingle()).uuid),
      isNull,
    );
  });

  test('the first sync sends rows written before any account', () async {
    await NotesRepository(a).create(title: 'Old');
    await a.delete(a.outbox).go();
    await syncA.run();
    await syncB.run();
    expect(await b.select(b.notes).get(), hasLength(1));
  });
}
