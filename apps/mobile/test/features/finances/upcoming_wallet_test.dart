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

/// An expense logged ahead counts on its day, not before ([[Finances]]):
/// one dated the 28th "from the wallet" took DA200 out of the wallet on
/// the 25th, while the Upcoming note said it would wait.
void main() {
  late HarvestDatabase db;
  late VaultRepository vault;
  late FinanceActions actions;
  final today = HarvestDay.today();

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    vault = VaultRepository(db);
    actions = FinanceActions(db, FinancesRepository(db), vault);
  });

  tearDown(() => db.close());

  Future<int> wallet(HarvestDay asOf) async =>
      (await vault.watchBalances(asOf: asOf).first)[(
        MoneyAccount.wallet,
        Currency.dzd,
      )] ??
      0;

  test('a wallet expense dated ahead waits for its day', () async {
    await vault.move(
      account: MoneyAccount.wallet,
      deltaMinor: 500000,
      currency: Currency.dzd,
    );
    await actions.logExpense(
      amountMinor: 20000,
      category: 'food',
      currency: Currency.dzd,
      fromWallet: true,
      day: today.addDays(3),
    );

    expect(await wallet(today), 500000);
    expect(await vault.watchBalances().first, {
      (MoneyAccount.wallet, Currency.dzd): 500000,
    });
    expect(await wallet(today.addDays(2)), 500000);
    // On its day it is spent, and stays spent after.
    expect(await wallet(today.addDays(3)), 480000);
    expect(await wallet(today.addDays(4)), 480000);
  });

  test('the ledger lists it on top, under its own day', () async {
    await vault.move(
      account: MoneyAccount.wallet,
      deltaMinor: 500000,
      currency: Currency.dzd,
    );
    await actions.logExpense(
      amountMinor: 20000,
      category: 'food',
      currency: Currency.dzd,
      fromWallet: true,
      day: today.addDays(3),
    );
    final txns = await vault.watchTxns(account: MoneyAccount.wallet).first;
    expect(txns.map((t) => t.deltaMinor), [-20000, 500000]);
    expect(txns.first.day, today.addDays(3));
    expect(txns.first.isUpcoming(today), isTrue);
    expect(txns.last.isUpcoming(today), isFalse);
  });

  test('editing an upcoming expense gives nothing back to the wallet', () {
    final linked = MoneyTxn(
      uuid: 't',
      account: MoneyAccount.wallet,
      deltaMinor: -20000,
      currency: Currency.dzd,
      day: today.addDays(3),
      loggedAt: DateTime.now(),
    );
    // The balance never took it, so there is nothing to give back.
    expect(
      walletBalanceFor(
        {Currency.dzd: 500000},
        Currency.dzd,
        linked: linked,
        today: today,
      ),
      500000,
    );
    // On its day it was taken, and an edit gives it back.
    expect(
      walletBalanceFor(
        {Currency.dzd: 480000},
        Currency.dzd,
        linked: linked,
        today: today.addDays(3),
      ),
      500000,
    );
  });
}
