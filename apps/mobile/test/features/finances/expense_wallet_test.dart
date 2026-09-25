import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/finance_actions.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';

/// The wallet never pays for more than it holds, and an expense's
/// wallet movement stays one row however often its switch is flipped.
void main() {
  group('the expense sheet’s wallet switch', () {
    MoneyTxn move(int delta, Currency currency) => MoneyTxn(
      uuid: 't',
      account: MoneyAccount.wallet,
      deltaMinor: delta,
      currency: currency,
      day: HarvestDay.parse('2026-09-19'),
      loggedAt: DateTime(2026, 9, 19),
    );

    test('is off when the wallet cannot cover the amount, even if chosen', () {
      expect(
        paysFromWallet(amountMinor: 5000, walletBalance: 4000, choice: true),
        isFalse,
      );
      expect(paysFromWallet(amountMinor: 4000, walletBalance: 4000), isTrue);
      expect(
        paysFromWallet(amountMinor: 4000, walletBalance: 4000, choice: false),
        isFalse,
      );
      expect(paysFromWallet(amountMinor: null, walletBalance: 4000), isFalse);
    });

    test('an edit gives its own movement back before comparing', () {
      // 10 left in the wallet after this expense took 25 out of it.
      final balances = {Currency.dzd: 1000};
      final linked = move(-2500, Currency.dzd);
      expect(walletBalanceFor(balances, Currency.dzd, linked: linked), 3500);
      // Another currency's movement gives nothing back to this one.
      expect(walletBalanceFor(balances, Currency.eur, linked: linked), 0);
      expect(
        paysFromWallet(
          amountMinor: 3000,
          walletBalance: walletBalanceFor(
            balances,
            Currency.dzd,
            linked: linked,
          ),
          choice: true,
        ),
        isTrue,
      );
    });
  });

  group('the linked movement', () {
    late HarvestDatabase db;
    late VaultRepository vault;
    late FinanceActions actions;

    setUp(() {
      db = HarvestDatabase.forTesting(NativeDatabase.memory());
      vault = VaultRepository(db);
      actions = FinanceActions(db, FinancesRepository(db), vault);
    });

    tearDown(() => db.close());

    Future<int> walletBalance() async {
      final balances = await vault.watchBalances().first;
      return balances[(MoneyAccount.wallet, Currency.dzd)] ?? 0;
    }

    Future<List<MoneyTxnRow>> linkedRows(String uuid) => (db.select(
      db.moneyTxns,
    )..where((t) => t.linkUuid.equals(uuid))).get();

    test('the switch back on revives the old row, not a second', () async {
      await vault.move(
        account: MoneyAccount.wallet,
        deltaMinor: 10000,
        currency: Currency.dzd,
      );
      final uuid = await actions.logExpense(
        amountMinor: 2500,
        category: 'food',
        currency: Currency.dzd,
        fromWallet: true,
      );
      for (final fromWallet in [false, true]) {
        await actions.updateExpense(
          uuid: uuid,
          amountMinor: 3000,
          category: 'food',
          currency: Currency.dzd,
          fromWallet: fromWallet,
        );
      }
      final rows = await linkedRows(uuid);
      expect(rows, hasLength(1));
      expect(rows.single.deletedAt, isNull);
      expect(rows.single.deltaMinor, -3000);
      expect(await walletBalance(), 7000);
    });

    test('undo restores the movement deleted with the expense', () async {
      await vault.move(
        account: MoneyAccount.wallet,
        deltaMinor: 10000,
        currency: Currency.dzd,
      );
      final uuid = await actions.logExpense(
        amountMinor: 2500,
        category: 'food',
        currency: Currency.dzd,
        fromWallet: true,
      );
      // An older movement of the same expense, dropped long ago, and
      // stored ahead of the live one, so the first row found is not
      // the right one.
      final live = (await linkedRows(uuid)).single;
      await (db.delete(
        db.moneyTxns,
      )..where((t) => t.uuid.equals(live.uuid))).go();
      await db
          .into(db.moneyTxns)
          .insert(
            MoneyTxnsCompanion.insert(
              uuid: 'old',
              account: 'wallet',
              deltaMinor: -9000,
              currency: const Value('DZD'),
              kind: const Value('expense'),
              linkUuid: Value(uuid),
              harvestDay: '2026-09-01',
              deletedAt: Value(DateTime(2026, 9)),
            ),
          );
      await db.into(db.moneyTxns).insert(live);
      await actions.removeExpense(uuid);
      expect(await walletBalance(), 10000);
      await actions.restoreExpense(uuid);
      expect(await walletBalance(), 7500);
      final old = (await linkedRows(uuid)).firstWhere((r) => r.uuid == 'old');
      expect(old.deletedAt, isNotNull);
    });
  });
}
