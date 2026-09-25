import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/money.dart';

/// Money is integer minor units everywhere; these are the edges where a
/// wrong answer would quietly corrupt a ledger.
void main() {
  group('formatting', () {
    test('groups thousands and drops empty cents', () {
      expect(formatGrouped(6666776), '66,667.76');
      expect(formatGrouped(50000), '500');
      expect(formatGrouped(1250), '12.50');
      expect(formatGrouped(0), '0');
    });

    test('formatMinor keeps the sign', () {
      expect(formatMinor(1250), '12.50');
      expect(formatMinor(1200), '12');
      expect(formatMinor(5), '0.05');
      expect(formatMinor(-50), '-0.50');
    });

    test('amounts and signs carry the symbol', () {
      expect(formatAmount(108000, Currency.dzd), 'DA1,080');
      expect(formatSigned(500, Currency.dzd), '+DA5');
      expect(formatSigned(-500, Currency.dzd), '−DA5');
    });
  });

  group('parsing', () {
    test('accepts plain and decimal amounts', () {
      expect(parseToMinor('12'), 1200);
      expect(parseToMinor('12.5'), 1250);
      expect(parseToMinor('12.50'), 1250);
      expect(parseToMinor(' 12 '), 1200);
    });

    test('a comma is a decimal point, unless it groups thousands', () {
      expect(parseToMinor('1,5'), 150);
      expect(parseToMinor('1,234'), 123400);
      expect(parseToMinor('1,234,567'), 123456700);
    });

    test('reads Arabic-Indic digits', () {
      expect(parseToMinor('١٢'), 1200);
      expect(parseToMinor('١٢٫٥'.replaceAll('٫', '.')), 1250);
    });

    test('refuses what is not a plain positive amount', () {
      for (final input in [
        '',
        '   ',
        '0',
        '-5',
        '+5',
        'abc',
        '1e3',
        '12.345',
        '1.2.3',
        '12.',
      ]) {
        expect(parseToMinor(input), isNull, reason: 'rejects "$input"');
      }
    });

    test('refuses an amount that would overflow the ledger', () {
      expect(parseToMinor('$maxMajorUnits'), maxMajorUnits * 100);
      expect(parseToMinor('${maxMajorUnits + 1}'), isNull);
      expect(parseToMinor('184467440737095517'), isNull);
    });
  });

  group('conversion captions', () {
    const rates = Rates(defaultCurrency: Currency.dzd, dzdPerUsd: 135);

    test('shows the default-currency equivalent', () {
      final caption = conversionCaption(
        minor: 800,
        currency: Currency.usd,
        rates: rates,
      );
      expect(caption, ltrIsolate('≈DA1,080'));
    });

    test('says nothing for the default currency or a missing rate', () {
      expect(
        conversionCaption(minor: 800, currency: Currency.dzd, rates: rates),
        isNull,
      );
      expect(
        conversionCaption(
          minor: 800,
          currency: Currency.eur,
          rates: const Rates(defaultCurrency: Currency.dzd),
        ),
        isNull,
      );
    });
  });

  group('money on screen', () {
    test('groups thousands with no space after the symbol', () {
      expect(formatMoney(500000, Currency.dzd), ltrIsolate('DA5,000'));
      expect(formatMoney(0, Currency.dzd), ltrIsolate('DA0'));
    });

    test('holds the sign before the number, left to right, in Arabic too', () {
      final text = formatMoneySigned(-26000, Currency.dzd);
      expect(text, '\u2066−DA260\u2069');
      expect(text.startsWith('\u2066'), isTrue);
      expect(text.endsWith('\u2069'), isTrue);
    });
  });
}
