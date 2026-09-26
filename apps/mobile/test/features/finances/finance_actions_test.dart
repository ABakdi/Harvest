import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/finance_actions.dart';
import 'package:harvest/features/finances/domain/vault.dart';

/// An expense paid from the wallet and the wallet movement behind it
/// are one thing: they are written together, edited together, and go
/// away together.
void main() {
  late HarvestDatabase db;
  late FinancesRepository finances;
  late VaultRepository vault;
  late FinanceActions actions;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    finances = FinancesRepository(db);
    vault = VaultRepository(db);
    actions = FinanceActions(db, finances, vault);
  });

  tearDown(() => db.close());

  Future<int> walletBalance([Currency currency = Currency.dzd]) async {
    final balances = await vault.watchBalances().first;
    return balances[(MoneyAccount.wallet, currency)] ?? 0;
  }

  Future<void> fundWallet(int minor) => vault.move(
    account: MoneyAccount.wallet,
    deltaMinor: minor,
    currency: Currency.dzd,
  );

  group('expenses paid from the wallet', () {
    test('one transaction writes the expense and the withdrawal', () async {
      await fundWallet(10000);
      final uuid = await actions.logExpense(
        amountMinor: 2500,
        category: 'food',
        currency: Currency.dzd,
        fromWallet: true,
      );

      expect(await walletBalance(), 7500);
      final linked = await vault.linkedTxn(uuid);
      expect(linked, isNotNull);
      expect(linked!.kind, TxnKind.expense);
      expect(linked.reference, 'food');
      expect(linked.deltaMinor, -2500);
    });

    test('without the toggle the wallet is untouched', () async {
      await fundWallet(10000);
      final uuid = await actions.logExpense(
        amountMinor: 2500,
        category: 'food',
        currency: Currency.dzd,
      );
      expect(await walletBalance(), 10000);
      expect(await vault.linkedTxn(uuid), isNull);
    });

    test('editing the amount moves the withdrawal with it', () async {
      await fundWallet(10000);
      final uuid = await actions.logExpense(
        amountMinor: 2500,
        category: 'food',
        currency: Currency.dzd,
        fromWallet: true,
      );
      await actions.updateExpense(
        uuid: uuid,
        amountMinor: 4000,
        category: 'transport',
        currency: Currency.dzd,
        fromWallet: true,
      );

      expect(await walletBalance(), 6000);
      final linked = await vault.linkedTxn(uuid);
      expect(linked!.deltaMinor, -4000);
      expect(linked.reference, 'transport');
    });

    test('turning the toggle off gives the money back', () async {
      await fundWallet(10000);
      final uuid = await actions.logExpense(
        amountMinor: 2500,
        category: 'food',
        currency: Currency.dzd,
        fromWallet: true,
      );
      await actions.updateExpense(
        uuid: uuid,
        amountMinor: 2500,
        category: 'food',
        currency: Currency.dzd,
        fromWallet: false,
      );
      expect(await walletBalance(), 10000);
      expect(await vault.linkedTxn(uuid), isNull);
    });

    test('turning it on later takes the money out', () async {
      await fundWallet(10000);
      final uuid = await actions.logExpense(
        amountMinor: 2500,
        category: 'food',
        currency: Currency.dzd,
      );
      await actions.updateExpense(
        uuid: uuid,
        amountMinor: 2500,
        category: 'food',
        currency: Currency.dzd,
        fromWallet: true,
      );
      expect(await walletBalance(), 7500);
    });

    test('deleting refunds the wallet, and undo takes it back out', () async {
      await fundWallet(10000);
      final uuid = await actions.logExpense(
        amountMinor: 2500,
        category: 'food',
        currency: Currency.dzd,
        fromWallet: true,
      );

      await actions.removeExpense(uuid);
      expect(await walletBalance(), 10000, reason: 'no ghost withdrawal');
      expect(await finances.watchDay(HarvestDay.today()).first, isEmpty);

      await actions.restoreExpense(uuid);
      expect(await walletBalance(), 7500);
      expect(await vault.linkedTxn(uuid), isNotNull);
    });
  });

  group('savings', () {
    test('a deposit from the wallet is a transfer, not new money', () async {
      await fundWallet(10000);
      await actions.depositSavings(
        amountMinor: 3000,
        currency: Currency.dzd,
        fromWallet: true,
      );
      final balances = await vault.watchBalances().first;
      expect(balances[(MoneyAccount.wallet, Currency.dzd)], 7000);
      expect(balances[(MoneyAccount.savings, Currency.dzd)], 3000);
    });

    test('new money only grows savings', () async {
      await actions.depositSavings(
        amountMinor: 3000,
        currency: Currency.dzd,
        fromWallet: false,
      );
      final balances = await vault.watchBalances().first;
      expect(balances[(MoneyAccount.wallet, Currency.dzd)], isNull);
      expect(balances[(MoneyAccount.savings, Currency.dzd)], 3000);
    });

    test('a withdrawal always lands in the wallet', () async {
      await actions.depositSavings(
        amountMinor: 5000,
        currency: Currency.dzd,
        fromWallet: false,
      );
      await actions.withdrawSavings(
        amountMinor: 2000,
        currency: Currency.dzd,
      );
      final balances = await vault.watchBalances().first;
      expect(balances[(MoneyAccount.savings, Currency.dzd)], 3000);
      expect(balances[(MoneyAccount.wallet, Currency.dzd)], 2000);
    });
  });
}
