import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/finance_actions.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/session_finisher.dart';

/// [[Audit-v2]] wave 3: the gym and the money seams.
void main() {
  late HarvestDatabase db;
  late ProgramsRepository programs;
  late SessionsRepository sessions;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    programs = ProgramsRepository(db);
    sessions = SessionsRepository(db);
  });
  tearDown(() async => db.close());

  test('B3-03: a bare session on the day up next moves "Up next" on', () async {
    final program = await programs.createProgram(name: 'PPL');
    final push = await programs.addDay(program.uuid, name: 'Push');
    final pull = await programs.addDay(program.uuid, name: 'Pull');
    final legs = await programs.addDay(program.uuid, name: 'Legs');
    final loaded = (await programs.once(program.uuid))!;
    final finisher = SessionFinisher(
      sessions,
      programs,
      CommitmentsRepository(db),
      CheckInService(db, StreakService(db)),
    );

    expect((await sessions.nextDay(loaded))?.uuid, push.uuid);
    for (final expected in [pull, legs, push]) {
      final next = await sessions.nextDay(loaded);
      final bare = await sessions.startFreeform(
        programUuid: program.uuid,
        dayUuid: next?.uuid,
      );
      await finisher.finish(bare);
      await Future<void>.delayed(const Duration(seconds: 1));
      expect((await sessions.nextDay(loaded))?.uuid, expected.uuid);
    }
  });

  test(
    'B3-04: undoing a hand tick takes back only the empty session',
    () async {
      final program = await programs.createProgram(name: 'PPL');
      final today = HarvestDay.today();
      final bare = await sessions.startFreeform(programUuid: program.uuid);
      await sessions.finish(bare.uuid);
      expect(await sessions.discardBareOn(program.uuid, today), 1);
      expect(await sessions.finishedOnce(), isEmpty);
    },
  );

  test('U3-15: a second Start resumes the running session', () async {
    final program = await programs.createProgram(name: 'PPL');
    final day = await programs.addDay(program.uuid, name: 'Push');
    final first = await sessions.start(
      day: day,
      programUuid: program.uuid,
      title: 'Push',
    );
    final second = await sessions.start(
      day: day,
      programUuid: program.uuid,
      title: 'Push',
    );
    expect(second.uuid, first.uuid);
  });

  test("B3-05: a moved expense's wallet movement moves with it", () async {
    final vault = VaultRepository(db);
    final actions = FinanceActions(db, FinancesRepository(db), vault);
    final uuid = await actions.logExpense(
      amountMinor: 500,
      category: 'food',
      currency: Currency.dzd,
      fromWallet: true,
      day: HarvestDay.parse('2026-08-31'),
    );
    await actions.updateExpense(
      uuid: uuid,
      amountMinor: 500,
      category: 'food',
      currency: Currency.dzd,
      fromWallet: true,
      day: HarvestDay.parse('2026-09-02'),
    );
    final linked = await vault.linkedTxn(uuid);
    expect(linked?.day, HarvestDay.parse('2026-09-02'));
  });
}
