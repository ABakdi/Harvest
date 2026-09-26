import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/stats/stats_screen.dart';

/// The Weekly Harvest Report's quietest day starts from the first seed:
/// the days before it were not quiet, they were not yet — the rule the
/// web's `firstSeedDay` keeps too.
void main() {
  final monday = HarvestDay.parse('2026-09-14');
  Map<HarvestDay, int> week(List<int> counts) => {
    for (var i = 0; i < counts.length; i++) monday.addDays(i): counts[i],
  };

  group('firstSeedDay', () {
    test('is the earliest seed, or an earlier check-in from an import', () {
      expect(
        firstSeedDay([monday.addDays(3), monday.addDays(5)], const []),
        monday.addDays(3),
      );
      expect(
        firstSeedDay([monday.addDays(3)], ['2026-09-15']),
        monday.addDays(1),
      );
    });

    test('is null before the first seed', () {
      expect(firstSeedDay(const [], const []), isNull);
    });
  });

  group('quietestDay', () {
    test('ignores the days before the first seed', () {
      // Planted on Thursday: Monday to Wednesday were empty only
      // because nothing existed yet.
      final counts = week([0, 0, 0, 3, 1, 2]);
      expect(quietestDay(counts), monday);
      expect(quietestDay(counts, since: monday.addDays(3)), monday.addDays(4));
    });

    test('says nothing with fewer than two lived days to compare', () {
      final counts = week([0, 0, 0, 0, 0, 4]);
      expect(quietestDay(counts, since: monday.addDays(5)), isNull);
    });

    test('the first one wins a tie', () {
      expect(quietestDay(week([2, 1, 1, 3])), monday.addDays(1));
    });
  });
}
