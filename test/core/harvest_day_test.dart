import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';

void main() {
  group('HarvestDay 3 AM boundary', () {
    test('2:59 AM belongs to the previous calendar day', () {
      final day = HarvestDay.of(DateTime(2026, 9, 2, 2, 59));
      expect(day.key, '2026-09-01');
    });

    test('3:00 AM starts the new day', () {
      final day = HarvestDay.of(DateTime(2026, 9, 2, 3));
      expect(day.key, '2026-09-02');
    });

    test('an evening log and a 1 AM log share the same day', () {
      final evening = HarvestDay.of(DateTime(2026, 9, 1, 22));
      final lateNight = HarvestDay.of(DateTime(2026, 9, 2, 1));
      expect(evening, lateNight);
    });

    test('month rollover: Jan 1st 00:30 is still Dec 31st', () {
      final day = HarvestDay.of(DateTime(2027, 1, 1, 0, 30));
      expect(day.key, '2026-12-31');
    });
  });

  group('calendar dates (no boundary shift)', () {
    test('fromDate keeps the picked calendar day', () {
      // A date picker returns midnight; the 3 AM rule must not apply.
      expect(HarvestDay.fromDate(DateTime(2026, 9, 2)).key, '2026-09-02');
      expect(
        HarvestDay.fromDate(DateTime(2026, 9, 2)),
        isNot(HarvestDay.of(DateTime(2026, 9, 2))),
      );
    });
  });

  group('navigation and keys', () {
    test('parse round-trips key', () {
      final day = HarvestDay.of(DateTime(2026, 9, 2, 12));
      expect(HarvestDay.parse(day.key), day);
    });

    test('next / previous move one day', () {
      final day = HarvestDay.parse('2026-09-02');
      expect(day.next.key, '2026-09-03');
      expect(day.previous.key, '2026-09-01');
      expect(day.previous.daysUntil(day.next), 2);
    });

    test('startsAt is 3 AM local of the same calendar date', () {
      final day = HarvestDay.parse('2026-09-02');
      expect(day.startsAt, DateTime(2026, 9, 2, 3));
    });

    test('ordering works', () {
      final a = HarvestDay.parse('2026-09-01');
      final b = HarvestDay.parse('2026-09-02');
      expect(a.compareTo(b) < 0, isTrue);
    });
  });
}
