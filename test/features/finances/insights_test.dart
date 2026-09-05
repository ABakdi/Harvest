import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/day_range.dart';
import 'package:harvest/features/finances/domain/move_filter.dart';
import 'package:harvest/features/finances/domain/vault.dart';

/// Checkpoint C4-2: the Insights page reads one span, and a ledger can
/// be narrowed to the question actually being asked of it.
void main() {
  group('the span', () {
    // A Thursday.
    final today = HarvestDay.parse('2026-09-10');

    test('a week runs Monday to Sunday', () {
      final week = DayRange.week(today);
      expect(week.from, HarvestDay.parse('2026-09-07'));
      expect(week.to, HarvestDay.parse('2026-09-13'));
      expect(week.length, 7);
    });

    test('a month runs first to last, however long it is', () {
      final month = DayRange.month(today);
      expect(month.from, HarvestDay.parse('2026-09-01'));
      expect(month.to, HarvestDay.parse('2026-09-30'));
      expect(month.length, 30);

      final february = DayRange.month(HarvestDay.parse('2026-02-14'));
      expect(february.to, HarvestDay.parse('2026-02-28'));
    });

    test('any two days make a span, both ends counted', () {
      final range = DayRange(
        from: HarvestDay.parse('2026-09-01'),
        to: HarvestDay.parse('2026-09-01'),
      );
      expect(range.length, 1);
      expect(range.eachDay, [HarvestDay.parse('2026-09-01')]);
    });

    test('the average divides by days elapsed, not days in the span', () {
      // A month four days old is four days of spending, not thirty.
      final month = DayRange.month(today);
      expect(month.elapsedDays(today), 10);
      expect(month.elapsedDays(HarvestDay.parse('2026-10-05')), 30);
      expect(month.elapsedDays(HarvestDay.parse('2026-08-30')), 0);
    });

    test('a span knows what falls inside it', () {
      final week = DayRange.week(today);
      expect(week.contains(today), isTrue);
      expect(week.contains(week.from), isTrue);
      expect(week.contains(week.to), isTrue);
      expect(week.contains(week.to.next), isFalse);
    });
  });

  group('narrowing a ledger', () {
    MoneyTxn txn({
      required TxnKind kind,
      String? reference,
      String? note,
      int delta = -1000,
    }) => MoneyTxn(
      uuid: '$kind-$reference-$note',
      account: MoneyAccount.wallet,
      deltaMinor: delta,
      currency: Currency.dzd,
      day: HarvestDay.parse('2026-09-10'),
      loggedAt: DateTime(2026, 9, 10, 12),
      kind: kind,
      reference: reference,
      note: note,
    );

    final coffee = txn(
      kind: TxnKind.expense,
      reference: 'food',
      note: 'Coffee',
    );
    final bus = txn(kind: TxnKind.expense, reference: 'transport');
    final saved = txn(kind: TxnKind.transfer, reference: 'savings');
    final paid = txn(kind: TxnKind.debt, reference: 'Sam', note: 'car money');
    final all = [coffee, bus, saved, paid];

    test('an empty filter hides nothing', () {
      expect(MoveFilter.empty.isEmpty, isTrue);
      expect(MoveFilter.empty.apply(all), all);
    });

    test('by form of movement', () {
      const filter = MoveFilter(kinds: {TxnKind.debt});
      expect(filter.apply(all), [paid]);
    });

    test('several forms at once', () {
      const filter = MoveFilter(kinds: {TxnKind.debt, TxnKind.transfer});
      expect(filter.apply(all), [saved, paid]);
    });

    test('by category, which can only mean expenses', () {
      const filter = MoveFilter(categories: {'food'});
      expect(filter.apply(all), [coffee]);
      // A transfer has no category, so a category filter excludes it
      // rather than letting it through on a technicality.
      expect(filter.matches(saved), isFalse);
    });

    test('by a word in the note', () {
      const filter = MoveFilter(query: 'coff');
      expect(filter.apply(all), [coffee]);
    });

    test('the search ignores case and stray spaces', () {
      expect(const MoveFilter(query: '  CAR ').apply(all), [paid]);
    });

    test('the search reaches the reference as well as the note', () {
      // "Sam" is who the debt was paid to, not something I typed.
      expect(const MoveFilter(query: 'sam').apply(all), [paid]);
    });

    test('filters stack rather than compete', () {
      const filter = MoveFilter(
        kinds: {TxnKind.expense},
        categories: {'food'},
        query: 'coffee',
      );
      expect(filter.apply(all), [coffee]);
      expect(filter.activeCount, 3);

      const wrongWord = MoveFilter(
        kinds: {TxnKind.expense},
        categories: {'food'},
        query: 'bus',
      );
      expect(wrongWord.apply(all), isEmpty);
    });

    test('two filters that say the same thing are the same filter', () {
      const a = MoveFilter(kinds: {TxnKind.expense, TxnKind.debt});
      const b = MoveFilter(kinds: {TxnKind.debt, TxnKind.expense});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
