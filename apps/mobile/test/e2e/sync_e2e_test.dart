import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/secret_store.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/goals/data/goals_repository.dart';
import 'package:harvest/features/health/data/health_repository.dart';
import 'package:harvest/features/health/domain/steps.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/sync/domain/file_sync.dart';
import 'package:harvest/features/sync/domain/sync_cipher.dart';
import 'package:harvest/features/sync/domain/sync_service.dart';

class _Secrets implements SecretStore {
  final _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String? value) async =>
      value == null ? _values.remove(key) : _values[key] = value;
}

/// The phone's sync against the real server — its strict contract
/// included — on a throwaway database. Runs only when pointed at one:
///
///   pnpm --filter @harvest/server e2e
///   HARVEST_E2E_URL=http://localhost:4100 flutter test test/e2e
void main() {
  final url = Platform.environment['HARVEST_E2E_URL'];

  test(
    'two phones converge through the real server, and nothing is refused',
    () async {
      final email = 'e2e${DateTime.now().microsecondsSinceEpoch}@example.org';
      const password = 'a long enough passphrase';
      Future<ApiClient> signedIn({required bool register}) async {
        final api = ApiClient(
          baseUrl: () => Uri.parse(url!),
          tokens: TokenStore(_Secrets()),
        );
        final auth = await api.postAnonymous(
          register ? '/v1/auth/register' : '/v1/auth/login',
          {'email': email, 'password': password, 'client': 'mobile'},
        );
        await api.adopt(auth);
        return api;
      }

      final a = HarvestDatabase.forTesting(NativeDatabase.memory());
      final b = HarvestDatabase.forTesting(NativeDatabase.memory());
      addTearDown(a.close);
      addTearDown(b.close);

      final apiA = await signedIn(register: true);
      // The e2e server verifies new accounts on its own.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final apiB = await signedIn(register: false);

      // A little of everything that syncs in plain.
      final seed = await CommitmentsRepository(a).create(
        type: CommitmentType.habit,
        title: 'Read',
        schedule: const WeeklySchedule(weekdays: {1, 3, 5}),
      );
      await CheckInService(a, StreakService(a)).checkIn(seed);
      final goal = await GoalsRepository(a).create(
        title: 'Read 20 books',
        targetDay: HarvestDay.today().addDays(90),
      );
      final item = await GoalsRepository(a).addItem(goal.uuid, body: 'Card');
      await GoalsRepository(a).setDone(item.uuid, done: true);
      await GoalsRepository(a).achieve(goal.uuid);
      final note = await NotesRepository(a).create(title: 'Log');
      await NotesRepository(a).update(note.uuid, body: 'see [[Sleep]]');
      await HealthRepository(a).saveStepDay(
        StepDay(day: HarvestDay.today(), steps: 8123, lastCounter: 400),
      );
      await SettingsRepository(a).setString('themeMode', 'dark');
      await FinancesRepository(a).log(
        amountMinor: 1250,
        category: 'food',
        note: 'bread',
        day: HarvestDay.today(),
      );
      // The key as a phone makes it: the first phone chooses the PIN and
      // sets its verifier and key check; the second shows the PIN's proof
      // and is handed the key share only for the right one (S6-04).
      final shareA = await ApiSyncKeys(apiA).fetch();
      expect(shareA.choosing, isTrue);
      final base = await SyncCipher.deriveBase(
        '482913',
        shareA.salt,
        iterations: 1000,
      );
      final key = await SyncCipher.keyOf(base, shareA.keyShare!);
      final proof = await SyncCipher.proofOf(base);
      final epoch = await ApiSyncKeys(apiA).setPin(
        await SyncCipher.verifierOf(proof),
        await SyncCipher(key).sealCheck(),
      );
      expect(epoch, isNotNull);
      final stateB = await ApiSyncKeys(apiB).fetch();
      expect(stateB.choosing, isFalse);
      expect(stateB.keyShare, isNull, reason: 'no share before a proof');
      final wrong = await SyncCipher.deriveBase(
        '482914',
        stateB.salt,
        iterations: 1000,
      );
      await expectLater(
        ApiSyncKeys(apiB).unlock(base64Encode(await SyncCipher.proofOf(wrong))),
        throwsA(
          isA<SyncPinRefused>().having((r) => r.triesLeft, 'tries left', 4),
        ),
      );
      final opened = await ApiSyncKeys(apiB).unlock(base64Encode(proof));
      expect(opened.epoch, epoch);
      final keyB = await SyncCipher.keyOf(base, opened.keyShare);
      expect(keyB, key);
      expect(await SyncCipher(keyB).opensCheck(opened.check), isTrue);
      // A second device choosing now is told a PIN is set.
      expect(
        await ApiSyncKeys(apiB).setPin(
          await SyncCipher.verifierOf(await SyncCipher.proofOf(wrong)),
          await SyncCipher(keyB).sealCheck(),
        ),
        isNull,
      );
      Future<SyncCipher?> cipher() async => SyncCipher(key, epoch: epoch!);

      final reportA = await SyncService(
        a,
        ApiRemote(apiA),
        cipher: cipher,
      ).run();
      expect(reportA.invalid, 0, reason: 'the server refused a phone row');
      final reportB = await SyncService(
        b,
        ApiRemote(apiB),
        cipher: cipher,
      ).run();
      expect(reportB.invalid, 0);

      expect(
        (await CommitmentsRepository(b).activeOnce()).single.title,
        'Read',
      );
      expect(await b.select(b.checkIns).get(), hasLength(1));
      final goals = await GoalsRepository(b).watchAll().first;
      expect(goals.single.goal.title, 'Read 20 books');
      expect(goals.single.items.single.isDone, isTrue);
      expect(
        (await (b.select(
          b.notes,
        )..where((n) => n.uuid.equals(note.uuid))).getSingle()).body,
        'see [[Sleep]]',
      );
      expect(
        (await HealthRepository(b).stepsOn(HarvestDay.today())).steps,
        8123,
      );
      expect(await SettingsRepository(b).getString('themeMode'), 'dark');
      expect((await b.select(b.expenses).getSingle()).note, 'bread');

      // And a picture, which is not a row: it goes up sealed under the
      // name of its own bytes and comes down on the other phone
      // ([[Sync-API]], files).
      final roomA = await Directory.systemTemp.createTemp('e2e-a');
      final roomB = await Directory.systemTemp.createTemp('e2e-b');
      addTearDown(() => roomA.delete(recursive: true));
      addTearDown(() => roomB.delete(recursive: true));
      final bytes = List<int>.generate(4096, (index) => (index * 31) % 256);
      final album = await GalleryRepository(
        a,
        GalleryStorage(),
      ).createAlbum(name: 'Gym');
      await a
          .into(a.memories)
          .insert(
            MemoriesCompanion.insert(
              uuid: 'e2e-memory',
              albumUuid: album.uuid,
              harvestDay: HarvestDay.today().key,
              path: 'e2e.jpg',
            ),
          );
      await File('${roomA.path}/e2e.jpg').writeAsBytes(bytes);

      Future<FileReport> files(
        HarvestDatabase db,
        ApiClient api,
        Directory room,
      ) => FileSync(db, ApiFiles(api), SyncCipher(key, epoch: epoch!)).run(
        gallery: (relative) async => File('${room.path}/$relative'),
        attachments: (relative) async => File('${room.path}/$relative'),
      );

      expect((await files(a, apiA, roomA)).uploaded, 1);
      // The row now carries the hash; sync it, then fetch the file.
      await SyncService(a, ApiRemote(apiA), cipher: cipher).run();
      await SyncService(b, ApiRemote(apiB), cipher: cipher).run();
      expect((await files(b, apiB, roomB)).downloaded, 1);
      expect(await File('${roomB.path}/e2e.jpg').readAsBytes(), bytes);

      // A file a row on the server still names is not let go of.
      final hash = (await b.select(b.memories).getSingle()).fileHash!;
      await ApiFiles(apiB).forget(hash);
      expect(await ApiFiles(apiB).missing([hash]), isEmpty);

      // Starting the PIN over: a wrong password changes nothing; the
      // right one drops the check and the share, and the old key opens
      // nothing any more.
      await expectLater(
        ApiSyncKeys(apiA).startOver('not the password'),
        throwsA(isA<ApiException>()),
      );
      expect((await ApiSyncKeys(apiA).fetch()).choosing, isFalse);
      await ApiSyncKeys(apiA).startOver(password);
      final fresh = await ApiSyncKeys(apiB).fetch();
      expect(fresh.choosing, isTrue);
      expect(fresh.epoch, epoch! + 1);
      expect(fresh.keyShare, isNot(shareA.keyShare));
      final pulled = await ApiRemote(apiB).pull(0, 1000);
      expect(
        pulled.records.where(
          (r) => r['table'] == 'expenses' && r['enc'] != null,
        ),
        isEmpty,
      );

      // A device still on the old key stores nothing under it: its
      // sealed push and its file are refused as `key_changed` (S6-07).
      await FinancesRepository(b).log(
        amountMinor: 300,
        category: 'tea',
        note: 'late',
        day: HarvestDay.today(),
      );
      await expectLater(
        SyncService(b, ApiRemote(apiB), cipher: cipher).run(),
        throwsA(isA<SyncKeyChanged>()),
      );
      final stale = await SyncCipher(key).sealFile('ab' * 32, [1, 2, 3]);
      await expectLater(
        ApiFiles(apiB).upload(
          'ab' * 32,
          stale.bytes,
          base64Encode(stale.iv),
          keyEpoch: epoch,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'key_changed'),
        ),
      );
    },
    skip: url == null ? 'set HARVEST_E2E_URL to run against a server' : false,
  );
}
