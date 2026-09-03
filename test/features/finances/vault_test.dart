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
    test('balances sum signed movements per account and currency', () async {
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

    test('savings→wallet transfer moves both pots and keeps history', () async {
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
      // ...and explain themselves: each leg names the other pot.
      final legs = txns.where((t) => t.kind == TxnKind.transfer).toList();
      expect(legs.length, 2);
      expect(
        legs.map((t) => (t.account, t.reference)).toSet(),
        {(MoneyAccount.savings, 'wallet'), (MoneyAccount.wallet, 'savings')},
      );
    });

    test('each pot has its own ledger', () async {
      await vault.move(
        account: MoneyAccount.wallet,
        deltaMinor: 500,
        currency: Currency.dzd,
        day: day,
      );
      await vault.move(
        account: MoneyAccount.savings,
        deltaMinor: 900,
        currency: Currency.dzd,
        day: day,
      );
      await vault.move(
        account: MoneyAccount.wallet,
        deltaMinor: -200,
        currency: Currency.dzd,
        kind: TxnKind.expense,
        reference: 'food',
        day: day,
      );

      final wallet = await vault.watchTxns(account: MoneyAccount.wallet).first;
      final savings = await vault
          .watchTxns(account: MoneyAccount.savings)
          .first;
      expect(wallet.map((t) => t.deltaMinor), [-200, 500]);
      expect(wallet.first.kind, TxnKind.expense);
      expect(wallet.first.reference, 'food');
      expect(savings.map((t) => t.deltaMinor), [900]);
      expect(savings.single.kind, TxnKind.manual);
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

    test('paying from the wallet records a debt-kind withdrawal', () async {
      await vault.move(
        account: MoneyAccount.wallet,
        deltaMinor: 9000,
        currency: Currency.dzd,
        day: day,
      );
      await vault.createDebt(
        person: 'Lina',
        amountMinor: 3000,
        currency: Currency.dzd,
      );
      final debt = (await vault.watchDebts().first).single;
      await vault.payDebt(debt.uuid, 3000, fromWallet: true);

      final balances = await vault.watchBalances().first;
      expect(balances[(MoneyAccount.wallet, Currency.dzd)], 6000);
      final wallet = await vault.watchTxns(account: MoneyAccount.wallet).first;
      expect(wallet.first.kind, TxnKind.debt);
      expect(wallet.first.reference, 'Lina');
      expect((await vault.watchDebts().first).single.isSettled, isTrue);

      final payments = await vault.watchDebtPayments().first;
      expect(payments.single.debtUuid, debt.uuid);
      expect(payments.single.amountMinor, 3000);
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

  group('debt payments are validated', () {
    Future<Debt> seedDebt({int amount = 10000}) async {
      await vault.createDebt(
        person: 'Sami',
        amountMinor: amount,
        currency: Currency.dzd,
      );
      return (await vault.watchDebts().first).single;
    }

    test('refuses a non-positive amount', () async {
      final debt = await seedDebt();
      await expectLater(
        vault.payDebt(debt.uuid, 0),
        throwsArgumentError,
      );
      await expectLater(
        vault.payDebt(debt.uuid, -100),
        throwsArgumentError,
      );
    });

    test('refuses more than is still owed', () async {
      final debt = await seedDebt();
      await vault.payDebt(debt.uuid, 6000);
      await expectLater(
        vault.payDebt(debt.uuid, 5000),
        throwsArgumentError,
      );
      expect((await vault.watchDebts().first).single.paidMinor, 6000);
    });

    test('refuses to pay a settled debt', () async {
      final debt = await seedDebt();
      await vault.payDebt(debt.uuid, 10000);
      await expectLater(
        vault.payDebt(debt.uuid, 100),
        throwsArgumentError,
      );
    });

    test('a partial payment reaches an open subscription', () async {
      final debt = await seedDebt();
      final seen = <int>[];
      final sub = vault.watchDebts().listen(
        (debts) => seen.add(debts.single.paidMinor),
      );
      addTearDown(sub.cancel);

      await pumpEventQueue();
      await vault.payDebt(debt.uuid, 2500);
      await pumpEventQueue();
      await vault.payDebt(debt.uuid, 2500);
      await pumpEventQueue();

      expect(seen.last, 5000, reason: 'the card is never stale');
    });
  });
}
