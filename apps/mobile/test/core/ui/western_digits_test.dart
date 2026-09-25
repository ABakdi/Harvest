import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Arabic dates and times count in the same digits as money: a screen
/// had "٦:٤٩ م" and "٢٨ سبتمبر" beside "DA5,000" ([[Finances]]).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    useWesternDigits();
  });

  final moment = DateTime(2026, 9, 28, 18, 49);
  final arabicIndic = RegExp('[٠-٩]');

  test('times and dates in Arabic use Western digits', () {
    final time = DateFormat.jm('ar').format(moment);
    final day = DateFormat.MMMd('ar').format(moment);
    final full = DateFormat.yMMMEd('ar').format(moment);
    for (final text in [time, day, full]) {
      expect(text, isNot(contains(arabicIndic)), reason: text);
    }
    expect(time, contains('6:49'));
    expect(day, contains('28'));
  });

  test('numbers in Arabic use Western digits', () {
    expect(NumberFormat.decimalPattern('ar').format(1240.5), '1,240.5');
  });
}
