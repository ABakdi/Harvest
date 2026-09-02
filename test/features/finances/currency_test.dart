import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';

void main() {
  const rates = Rates(
    defaultCurrency: Currency.dzd,
    dzdPerUsd: 135,
    dzdPerEur: 145,
    usdPerEur: 1.08,
  );

  group('Rates.toDefault', () {
    test('same currency is identity', () {
      expect(rates.toDefault(500, Currency.dzd), 500);
    });

    test('usd and eur convert through the manual DZD legs', () {
      expect(rates.toDefault(100, Currency.usd), 13500);
      expect(rates.toDefault(100, Currency.eur), 14500);
    });

    test('eur→usd uses the fetched rate when USD is the default', () {
      const usdDefault = Rates(
        defaultCurrency: Currency.usd,
        usdPerEur: 1.08,
      );
      expect(usdDefault.toDefault(1000, Currency.eur), 1080);
    });

    test('missing rate yields null, never a crash', () {
      const bare = Rates(defaultCurrency: Currency.dzd);
      expect(bare.toDefault(100, Currency.usd), isNull);
    });
  });

  group('display', () {
    test('shows the conversion in parentheses when known', () {
      final text = amountWithConversion(
        minor: 800,
        currency: Currency.usd,
        rates: rates,
      );
      expect(text, contains(r'$8'));
      expect(text, contains('DA1,080'));
    });

    test('omits the parenthetical without a rate', () {
      const bare = Rates(defaultCurrency: Currency.dzd);
      final text = amountWithConversion(
        minor: 800,
        currency: Currency.usd,
        rates: bare,
      );
      expect(text, r'$8');
    });
  });

  group('aggregation converts before summing', () {
    Expense expense(int minor, Currency currency) => Expense(
      uuid: '$minor-${currency.code}',
      amountMinor: minor,
      currency: currency,
      category: 'food',
      day: HarvestDay.parse('2026-09-02'),
      loggedAt: DateTime(2026, 9, 2),
    );

    test('mixed currencies land in the default currency', () {
      final totals = totalsByCategory(
        [expense(1000, Currency.dzd), expense(100, Currency.usd)],
        rates,
      );
      expect(totals['food'], 1000 + 13500);
    });

    test('face value fallback when a rate is missing', () {
      const bare = Rates(defaultCurrency: Currency.dzd);
      final totals = totalsByDay(
        [expense(1000, Currency.dzd), expense(100, Currency.usd)],
        bare,
      );
      expect(totals['2026-09-02'], 1100);
    });
  });
}
