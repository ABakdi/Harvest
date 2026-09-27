import 'package:drift/drift.dart' show Variable;
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
import 'package:harvest/features/sync/domain/row_codec.dart';
import 'package:harvest/features/sync/domain/sync_cipher.dart';
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

  test('money waits for the passphrase; a refused row leaves the outbox, '
      'flagged, and is not sent again until it changes (Q5-54)', () async {
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
    expect(left, contains('expenses'));
    expect(left, isNot(contains('ledger')), reason: 'flagged, not pending');
    expect(
      remote.row('expenses', (await a.select(a.expenses).getSingle()).uuid),
      isNull,
    );

    final offered = remote.offered.where((id) => id.startsWith('ledger/'));
    final before = offered.length;
    final again = await syncA.run();
    expect(again.invalid, report.invalid, reason: 'still counted');
    expect(
      remote.offered.where((id) => id.startsWith('ledger/')).length,
      before,
      reason: 'not retried every run',
    );
  });

  test('a row the first snapshot has refused is flagged too (Q5-54)', () async {
    await NotesRepository(a).create(title: 'Old');
    await a.delete(a.outbox).go();
    remote.refuse.add('notes');
    final report = await syncA.run();
    expect(report.invalid, 1);

    // It goes again once it changes, and is no longer flagged.
    remote.refuse.clear();
    final note = await a.select(a.notes).getSingle();
    await NotesRepository(a).update(note.uuid, body: 'again');
    final after = await syncA.run();
    expect(after.invalid, 0);
    expect(remote.row('notes', note.uuid), isNotNull);
  });

  test('the first sync sends rows written before any account', () async {
    await NotesRepository(a).create(title: 'Old');
    await a.delete(a.outbox).go();
    await syncA.run();
    await syncB.run();
    expect(await b.select(b.notes).get(), hasLength(1));
  });

  group('the private tier', () {
    final key = List<int>.generate(32, (i) => i);
    final other = List<int>.generate(32, (i) => 255 - i);

    Future<void> logExpense(HarvestDatabase db) => FinancesRepository(db).log(
      amountMinor: 1250,
      category: 'food',
      note: 'bread',
      day: HarvestDay.today(),
    );

    test('money travels sealed, and the server never sees a column', () async {
      final sealedA = SyncService(
        a,
        remote,
        cipher: () async => SyncCipher(key),
      );
      final sealedB = SyncService(
        b,
        remote,
        cipher: () async => SyncCipher(key),
      );
      await logExpense(a);
      await sealedA.run();

      final uuid = (await a.select(a.expenses).getSingle()).uuid;
      final stored = remote.row('expenses', uuid)!;
      expect(stored.containsKey('data'), isFalse);
      expect(stored['enc'], isA<Map<String, Object?>>());
      expect('${stored['enc']}', isNot(contains('bread')));

      await sealedB.run();
      final row = await b.select(b.expenses).getSingle();
      expect(row.amountMinor, 1250);
      expect(row.note, 'bread');
    });

    test('a device that gets the passphrase late reads what waited', () async {
      final sealedA = SyncService(
        a,
        remote,
        cipher: () async => SyncCipher(key),
      );
      await logExpense(a);
      await sealedA.run();

      SyncCipher? later;
      final plainB = SyncService(b, remote, cipher: () async => later);
      await plainB.run();
      expect(await b.select(b.expenses).get(), isEmpty);

      later = SyncCipher(key);
      await plainB.privateTierOpened();
      await plainB.run();
      expect(await b.select(b.expenses).get(), hasLength(1));
    });

    test('a key that cannot open a row locks that row and goes on '
        '(S5-09)', () async {
      await logExpense(a);
      await NotesRepository(a).create(title: 'plain');
      await SyncService(a, remote, cipher: () async => SyncCipher(key)).run();
      final wrong = SyncService(
        b,
        remote,
        cipher: () async => SyncCipher(other),
      );
      final report = await wrong.run();
      expect(report.locked, greaterThan(0));
      expect(await b.select(b.expenses).get(), isEmpty);
      expect(await b.select(b.notes).get(), hasLength(1));
    });

    test('an older ciphertext offered under a newer clock is locked, not '
        'taken (S5-10)', () async {
      final sealedA = SyncService(
        a,
        remote,
        cipher: () async => SyncCipher(key),
      );
      final sealedB = SyncService(
        b,
        remote,
        cipher: () async => SyncCipher(key),
      );
      await logExpense(a);
      await sealedA.run();
      await sealedB.run();
      final uuid = (await b.select(b.expenses).getSingle()).uuid;

      // The server replays the same ciphertext as if it were newer.
      final stored = remote.row('expenses', uuid)!;
      await remote.push('server', [
        {
          ...stored,
          'updatedAt': '2099-01-01T00:00:00.000Z',
        }..remove('seq'),
      ]);
      final report = await sealedB.run();
      expect(report.locked, 1);
      expect((await b.select(b.expenses).getSingle()).note, 'bread');
    });
  });

  group('the merge rules', () {
    Future<Map<String, Object?>> pushedNote(String uuid) async =>
        remote.row('notes', uuid)!;

    test(
      'a pulled purge older than a local edit keeps the row (Q5-08)',
      () async {
        final note = await NotesRepository(a).create(title: 'Kept');
        await syncA.run();
        await syncB.run();
        final local = await (b.select(
          b.notes,
        )..where((n) => n.uuid.equals(note.uuid))).getSingle();

        final older = local.updatedAt.subtract(const Duration(minutes: 1));
        final purge = {
          'table': 'notes',
          'uuid': note.uuid,
          'updatedAt': isoUtc(older),
          'deletedAt': isoUtc(older),
          'purged': true,
        };
        expect(await syncB.merge(purge), isFalse);
        expect(await b.select(b.notes).get(), hasLength(1));

        final newer = local.updatedAt.add(const Duration(minutes: 1));
        expect(
          await syncB.merge({
            ...purge,
            'updatedAt': isoUtc(newer),
            'deletedAt': isoUtc(newer),
          }),
          isTrue,
        );
        expect(await b.select(b.notes).get(), isEmpty);
      },
    );

    test('a delete still waiting to go up is a tombstone, stamped when it '
        'was made (Q5-09)', () async {
      final notes = NotesRepository(a);
      final note = await notes.create(title: 'Gone');
      await syncA.run();
      final record = await pushedNote(note.uuid);
      await notes.purge(note.uuid);

      // The older copy comes down again before the purge has gone up.
      expect(await syncA.merge(record), isFalse);
      expect(await a.select(a.notes).get(), isEmpty);

      // And the purge goes up stamped when it happened, not when sent.
      final queued = (await a.select(a.outbox).get())
          .where((o) => o.rowUuid == note.uuid)
          .map((o) => o.queuedAt)
          .reduce((x, y) => x.isAfter(y) ? x : y);
      await SyncService(a, remote, clock: () => DateTime.utc(2031)).run();
      final tombstone = remote.row('notes', note.uuid)!;
      expect(tombstone['purged'], isTrue);
      expect(
        DateTime.parse(tombstone['updatedAt']! as String),
        queued.toUtc(),
      );
    });

    test('a row with no clock of its own keeps an edit not sent yet '
        '(Q5-07)', () async {
      final note = await NotesRepository(a).create(title: 'Links');
      Map<String, Object?> link(String title, DateTime at) => {
        'table': 'note_links',
        'uuid': 'link-1',
        'updatedAt': isoUtc(at),
        'deletedAt': null,
        'data': {
          'uuid': 'link-1',
          'fromUuid': note.uuid,
          'toTitle': title,
          'toUuid': null,
        },
      };
      await a
          .into(a.noteLinks)
          .insert(
            NoteLinksCompanion.insert(
              uuid: 'link-1',
              fromUuid: note.uuid,
              toTitle: 'mine',
            ),
          );
      await a.logChange('note_links', 'link-1', 'insert');

      final earlier = DateTime.now().subtract(const Duration(hours: 1));
      expect(await syncA.merge(link('theirs, older', earlier)), isFalse);
      var row = await a.select(a.noteLinks).getSingle();
      expect(row.toTitle, 'mine');

      final later = DateTime.now().add(const Duration(hours: 1));
      expect(await syncA.merge(link('theirs, newer', later)), isTrue);
      row = await a.select(a.noteLinks).getSingle();
      expect(row.toTitle, 'theirs, newer');
    });

    test('an edit made after a row from a clock ahead of this one still '
        'wins (Q5-10)', () async {
      final note = await NotesRepository(a).create(title: 'Skew');
      await syncA.run();
      // Another device, an hour ahead, writes the row.
      final ahead = DateTime.now().toUtc().add(const Duration(hours: 1));
      final stored = await pushedNote(note.uuid);
      await remote.push('fast-clock', [
        {
          ...stored,
          'updatedAt': isoUtc(ahead),
          'data': {
            ...stored['data']! as Map<String, Object?>,
            'body': 'from the fast clock',
            'updatedAt': isoUtc(ahead),
          },
        }..remove('seq'),
      ]);
      await syncB.run();

      await NotesRepository(b).update(note.uuid, body: 'edited here, after');
      final report = await syncB.run();
      expect(report.pushed, greaterThan(0));
      final now = await pushedNote(note.uuid);
      expect(
        (now['data']! as Map<String, Object?>)['body'],
        'edited here, after',
      );
      expect(
        DateTime.parse(now['updatedAt']! as String).isAfter(ahead),
        isTrue,
      );
      await syncA.run();
      final there = await (a.select(
        a.notes,
      )..where((n) => n.uuid.equals(note.uuid))).getSingle();
      expect(there.body, 'edited here, after');
    });

    test(
      'a push the server finds stale takes the server copy (Q5-10)',
      () async {
        final note = await NotesRepository(a).create(title: 'Tie');
        await syncA.run();
        await syncB.run();
        // The same clock, other words: the server's copy is the one kept.
        await b.customUpdate(
          "UPDATE notes SET body = 'mine' WHERE uuid = ?",
          variables: [Variable(note.uuid)],
        );
        await b.logChange('notes', note.uuid, 'update');
        await syncB.run();
        await syncB.run();
        final row = await (b.select(
          b.notes,
        )..where((n) => n.uuid.equals(note.uuid))).getSingle();
        expect(row.body, '');
        expect(await b.select(b.outbox).get(), isEmpty);
      },
    );

    test(
      'where a request goes never syncs, and never comes in (S5-01)',
      () async {
        const keys = ['assist.baseUrl', 'assist.provider', 'places.styleUrl'];
        for (final key in keys) {
          await SettingsRepository(a)
              .setString(key, 'https://attacker.example');
        }
        await syncA.run();
        expect(
          remote.offered.where((id) => keys.any((key) => id.endsWith(key))),
          isEmpty,
        );

        // Written to the account by someone else, all the same.
        for (final key in keys) {
          await remote.push('elsewhere', [
            {
              'table': 'kv_settings',
              'uuid': key,
              'updatedAt': '2026-09-20T10:00:00.000Z',
              'deletedAt': null,
              'data': {
                'key': key,
                'valueJson': '"https://attacker.example"',
                'updatedAt': '2026-09-20T10:00:00.000Z',
              },
            },
          ]);
        }
        await syncB.run();
        final settings = SettingsRepository(b);
        for (final key in keys) {
          expect(await settings.getString(key), isNull, reason: key);
        }
      },
    );

    test('a pulled purge hands the row it removed to whoever keeps its '
        'file (Q5-23)', () async {
      final purged = <(String, Map<String, Object?>)>[];
      final withFiles = SyncService(
        b,
        remote,
        onPurged: (table, row) async => purged.add((table, row)),
      );
      final note = await NotesRepository(a).create(title: 'Gone');
      await syncA.run();
      await withFiles.run();
      await NotesRepository(a).purge(note.uuid);
      await syncA.run();
      await withFiles.run();
      expect(purged.single.$1, 'notes');
      expect(purged.single.$2['uuid'], note.uuid);
    });
  });

  test("a parent's tick is settled again from the subtasks a sync brought "
      '(Q5-44)', () async {
    final goals = GoalsRepository(a);
    final goal = await goals.create(title: 'Move');
    final parent = await goals.addItem(goal.uuid, body: 'Pack');
    final first = await goals.addSubtask(parent.uuid, body: 'Books');
    await syncA.run();
    await syncB.run();

    await goals.setDone(first.uuid, done: true);
    await GoalsRepository(b).addSubtask(parent.uuid, body: 'Plates');
    await syncA.run();
    await syncB.run();
    await syncB.run();
    await syncA.run();

    for (final db in [a, b]) {
      final row = await (db.select(
        db.goalItems,
      )..where((i) => i.uuid.equals(parent.uuid))).getSingle();
      expect(row.doneAt, isNull, reason: 'Plates is still open');
    }
  });

  test('a row refused for a reason that can pass says why, and goes again '
      'an hour later', () async {
    final clock = _Clock(DateTime.now());
    final paced = SyncService(a, _Refusing(remote), clock: clock.now);
    await NotesRepository(a).create(title: 'Later');
    final report = await paced.run();
    expect(report.refusedFor, {'clock_ahead'});
    expect(report.invalid, 1);

    final sent = remote.offered.length;
    await paced.run();
    expect(remote.offered.length, sent, reason: 'not straight away');

    clock.at = clock.at.add(const Duration(hours: 2));
    await paced.run();
    expect(remote.offered.length, greaterThan(sent));
  });
}

class _Clock {
  _Clock(this.at);

  DateTime at;
  DateTime now() => at;
}

/// Refuses notes for a clock ahead of the server's, as the server does.
class _Refusing implements SyncRemote {
  _Refusing(this._remote);

  final FakeRemote _remote;

  @override
  Future<({List<Map<String, Object?>> results, int cursor})> push(
    String deviceId,
    List<Map<String, Object?>> records,
  ) async {
    final answer = await _remote.push(deviceId, records);
    return (
      results: [
        for (final result in answer.results)
          if (result['table'] == 'notes')
            {
              ...result,
              'status': 'invalid',
              'issues': [
                {
                  'path': ['updatedAt'],
                  'message': 'ahead',
                  'code': 'clock_ahead',
                },
              ],
            }
          else
            result,
      ],
      cursor: answer.cursor,
    );
  }

  @override
  Future<({List<Map<String, Object?>> records, int cursor, bool more})> pull(
    int after,
    int limit,
  ) => _remote.pull(after, limit);
}
