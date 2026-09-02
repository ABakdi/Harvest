import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/vault.dart';

void main() {
  late HarvestDatabase db;
  late VaultRepository vault;
  final day = HarvestDay.parse('2026-09-02');

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    vault = VaultRepository(db);
  });

  tearDown(() => db.close());

  group('wallet and savings balances', () {
    test('balances sum signed movements per account and currency',
        () async {
      await vault.move(
        account: MoneyAccount.wallet,
        deltaMinor: 5000,
        currency: Currency.dzd,
        day: day,
      );
      await vault.move(
        account: MoneyAccount.wallet,
        deltaMinor: -1500,
        currency: Currency.dzd,
        day: day,
      );
      await vault.move(
        account: MoneyAccount.savings,
        deltaMinor: 10000,
        currency: Currency.usd,
        day: day,
      );

      final balances = await vault.watchBalances().first;
      expect(balances[(MoneyAccount.wallet, Currency.dzd)], 3500);
      expect(balances[(MoneyAccount.savings, Currency.usd)], 10000);
    });

    test('savings→wallet transfer moves both pots and keeps history',
        () async {
      await vault.move(
        account: MoneyAccount.savings,
        deltaMinor: 8000,
        currency: Currency.dzd,
        day: day,
      );
      await vault.transferSavingsToWallet(
        amountMinor: 3000,
        currency: Currency.dzd,
        note: 'groceries money',
      );

      final balances = await vault.watchBalances().first;
      expect(balances[(MoneyAccount.savings, Currency.dzd)], 5000);
      expect(balances[(MoneyAccount.wallet, Currency.dzd)], 3000);

      final txns = await vault.watchRecentTxns().first;
      expect(txns.length, 3);
      // Both legs of the transfer carry the note.
      expect(
        txns.where((t) => t.note == 'groceries money').length,
        2,
      );
    });
  });

  group('debts', () {
    test('partial payments accumulate; full payment settles', () async {
      await vault.createDebt(
        person: 'Sami',
        amountMinor: 10000,
        currency: Currency.dzd,
        payOffBy: HarvestDay.parse('2026-09-20'),
      );
      var debts = await vault.watchDebts().first;
      final debt = debts.single;
      expect(debt.remainingMinor, 10000);
      expect(debt.isSettled, isFalse);

      await vault.payDebt(debt.uuid, 4000);
      debts = await vault.watchDebts().first;
      expect(debts.single.remainingMinor, 6000);
      expect(debts.single.isSettled, isFalse);

      await vault.payDebt(debt.uuid, 6000);
      debts = await vault.watchDebts().first;
      expect(debts.single.remainingMinor, 0);
      expect(debts.single.isSettled, isTrue);
    });

    test('every write lands in the outbox', () async {
      await vault.createDebt(
        person: 'Nour',
        amountMinor: 2000,
        currency: Currency.eur,
      );
      await vault.move(
        account: MoneyAccount.wallet,
        deltaMinor: 100,
        currency: Currency.dzd,
        day: day,
      );
      final ops = await db.select(db.outbox).get();
      expect(
        ops.map((o) => o.targetTable).toSet(),
        containsAll(['debts', 'money_txns']),
      );
    });
  });
}
