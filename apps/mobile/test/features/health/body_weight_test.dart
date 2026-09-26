import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/health/domain/body_weight.dart';

/// Phase 4, M4.2. The weight chart's one claim: it shows the **trend**,
/// not the noise — and it never says whether the trend is good.
void main() {
  var counter = 0;
  BodyWeight at(String day, double kg, {String? note}) => BodyWeight(
    uuid: 'w${counter++}',
    grams: (kg * 1000).round(),
    day: HarvestDay.parse(day),
    measuredAt: DateTime.parse('${day}T08:00:00'),
    note: note,
  );

  group('units', () {
    test('are a display choice; grams are the truth', () {
      expect(WeightUnit.kg.toGrams(82.4), 82400);
      expect(WeightUnit.kg.from(82400), closeTo(82.4, 0.001));
      expect(WeightUnit.lb.toGrams(180), 81647);
      expect(WeightUnit.lb.from(81647), closeTo(180, 0.01));
    });

    test('round-trip without drifting', () {
      for (final kg in [50.0, 72.35, 99.9, 120.0]) {
        final grams = WeightUnit.kg.toGrams(kg);
        expect(WeightUnit.kg.from(grams), closeTo(kg, 0.001));
        expect(
          WeightUnit.lb.toGrams(WeightUnit.lb.from(grams)),
          closeTo(grams, 1),
        );
      }
    });

    test('an unknown name falls back to kilograms', () {
      expect(WeightUnit.fromName(null), WeightUnit.kg);
      expect(WeightUnit.fromName('stone'), WeightUnit.kg);
      expect(WeightUnit.fromName('lb'), WeightUnit.lb);
    });
  });

  group('the series', () {
    test('is empty for nothing', () {
      expect(weightSeries(const []), isEmpty);
    });

    test('has one point per day, gaps included', () {
      final series = weightSeries([
        at('2026-09-01', 80),
        at('2026-09-05', 80),
      ]);
      expect(series, hasLength(5));
      expect(series[1].entry, isNull, reason: 'the 2nd has no entry');
      expect(series[1].average, isNotNull, reason: 'but the line goes on');
    });

    test('averages two weigh-ins on one day into one day', () {
      final series = weightSeries([
        at('2026-09-01', 80),
        at('2026-09-01', 82),
      ]);
      expect(series.single.entry, 81000);
      expect(series.single.average, 81000);
    });

    test('smooths the noise the raw dots carry', () {
      // A week that wobbles two kilos a day but goes nowhere.
      final series = weightSeries([
        at('2026-09-01', 80),
        at('2026-09-02', 82),
        at('2026-09-03', 80),
        at('2026-09-04', 82),
        at('2026-09-05', 80),
        at('2026-09-06', 82),
        at('2026-09-07', 80),
      ]);
      expect(series.last.entry, 80000);
      // The line sits between the swings rather than following them.
      expect(series.last.average, closeTo(80857, 1));
    });

    test('a week away from the scale does not drag the line down', () {
      final series = weightSeries([
        at('2026-09-01', 80),
        at('2026-09-10', 79),
      ]);
      // Days 2–9 have no reading, so the line holds at the last known
      // average rather than falling toward zero.
      expect(series[4].average, 80000);
      expect(series.last.average, 79000);
    });
  });

  group('the trend', () {
    test('needs two points to say anything', () {
      expect(weightTrend(const [], days: 30), isNull);
      expect(weightTrend([at('2026-09-01', 80)], days: 30), isNull);
    });

    test('reports direction, amount and the window it measured', () {
      final trend = weightTrend([
        for (var i = 0; i < 30; i++)
          at('2026-09-${(i + 1).toString().padLeft(2, '0')}', 82 - i * 0.05),
      ], days: 30)!;

      expect(trend.gramsChanged, lessThan(0), reason: 'going down');
      expect(trend.days, 29);
      expect(trend.entries, 30);
    });

    test('measures on the line, not on two raw entries', () {
      // Ends on a heavy day after a falling month. The dots say up;
      // the trend says down, and the trend is right.
      final entries = [
        for (var i = 0; i < 20; i++)
          at('2026-09-${(i + 1).toString().padLeft(2, '0')}', 85 - i * 0.2),
        at('2026-09-21', 84),
      ];
      expect(entries.last.grams, greaterThan(entries[19].grams));
      expect(weightTrend(entries, days: 30)!.gramsChanged, lessThan(0));
    });

    test('a window longer than the data uses what there is', () {
      final trend = weightTrend([
        at('2026-09-01', 80),
        at('2026-09-03', 79),
      ], days: 365)!;
      expect(trend.days, 2);
    });
  });
}
