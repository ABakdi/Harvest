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
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/goals/data/goals_repository.dart';
import 'package:harvest/features/health/data/health_repository.dart';
import 'package:harvest/features/health/domain/steps.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
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
      final key = List<int>.generate(32, (i) => i * 7 % 256);
      Future<SyncCipher?> cipher() async => SyncCipher(key);

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
    },
    skip: url == null ? 'set HARVEST_E2E_URL to run against a server' : false,
  );
}
