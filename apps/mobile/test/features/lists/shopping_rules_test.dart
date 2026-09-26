import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/lists/data/lists_repository.dart';
import 'package:harvest/features/lists/domain/lists.dart';

/// The shopping lists keep every Wishlist rule ([[Lists]] L3, L4, L7;
/// [[Wishlist]] W2–W4, W7), carried over from the Wishlist's own tests
/// when its tab and wrapper went.
void main() {
  late HarvestDatabase db;
  late ListsRepository repo;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    repo = ListsRepository(db);
  });

  tearDown(() async => db.close());

  final buy = BuiltInList.buy.uuid;
  final wish = BuiltInList.wish.uuid;

  test('an estimate is a plan: adding and buying write no money (L3, L4)', () async {
    final coat = await repo.addItem(
      buy,
      title: 'Winter coat',
      priceMinor: 1800000,
    );
    await repo.setDone(coat.uuid, done: true);

    expect(await db.select(db.expenses).get(), isEmpty);
    expect(await db.select(db.moneyTxns).get(), isEmpty);
    expect(await db.select(db.ledger).get(), isEmpty);
    expect(await db.select(db.debts).get(), isEmpty);
  });

  test('bought is a stamp, and un-buying takes it back', () async {
    final coat = await repo.addItem(buy, title: 'Winter coat');
    await repo.setDone(coat.uuid, done: true);
    expect((await repo.item(coat.uuid))!.doneAt, isNotNull);

    await repo.setDone(coat.uuid, done: false);
    expect((await repo.item(coat.uuid))!.isDone, isFalse);
  });

  test('a moved item keeps its price, currency, note and day (W4)', () async {
    final coat = await repo.addItem(
      wish,
      title: 'Winter coat',
      priceMinor: 1800000,
      currency: Currency.eur,
      note: 'Wool, dark grey',
      targetDay: HarvestDay.parse('2026-10-15'),
    );
    expect(await repo.moveItem(coat.uuid, buy), isTrue);

    final moved = (await repo.item(coat.uuid))!;
    expect(moved.listUuid, buy);
    expect(moved.priceMinor, 1800000);
    expect(moved.currency, Currency.eur);
    expect(moved.note, 'Wool, dark grey');
    expect(moved.targetDay, HarvestDay.parse('2026-10-15'));
  });

  test('a wish moves to To buy first, then is bought (L7)', () async {
    final machine = await repo.addItem(wish, title: 'Espresso machine');
    expect(await repo.setDone(machine.uuid, done: true), isFalse);
    expect((await repo.item(machine.uuid))!.isDone, isFalse);

    await repo.moveItem(machine.uuid, buy);
    expect(await repo.setDone(machine.uuid, done: true), isTrue);
    expect((await repo.item(machine.uuid))!.isDone, isTrue);
  });
}
