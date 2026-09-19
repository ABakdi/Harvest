import 'package:harvest/core/domain/harvest_day.dart';
import 'package:meta/meta.dart';

/// Which units I read a weight in.
///
/// A display choice only: storage is grams, always, for the reason
/// money is stored in minor units — a body weight is not a float
/// ([[Health]] rule H4).
enum WeightUnit {
  kg,
  lb;

  static const gramsPerPound = 453.59237;

  /// Grams as a number in this unit.
  double from(int grams) =>
      this == WeightUnit.kg ? grams / 1000 : grams / gramsPerPound;

  /// A number in this unit, as grams.
  int toGrams(double value) => this == WeightUnit.kg
      ? (value * 1000).round()
      : (value * gramsPerPound).round();

  String get suffix => this == WeightUnit.kg ? 'kg' : 'lb';

  static WeightUnit fromName(String? name) => WeightUnit.values.firstWhere(
    (unit) => unit.name == name,
    orElse: () => WeightUnit.kg,
  );
}

/// One time I stood on a scale.
@immutable
class BodyWeight {
  const BodyWeight({
    required this.uuid,
    required this.grams,
    required this.day,
    required this.measuredAt,
    this.note,
  });

  final String uuid;
  final int grams;
  final HarvestDay day;
  final DateTime measuredAt;

  /// "after the flu", "new scale" — the outlier always has a reason,
  /// and the reason is what makes the chart readable a year later.
  final String? note;
}

/// A point on the chart: what was measured, and what the trend says.
typedef WeightPoint = ({HarvestDay day, double? entry, double? average});

/// Which way it is going, over how long, by how much.
///
/// Deliberately says nothing about whether that is good. It is my body
/// and my goal; the arithmetic is the app's job and the judgement is
/// not ([[Health]] rule H5).
typedef WeightTrend = ({int gramsChanged, int days, int entries});

/// How many days of entries the average smooths over.
///
/// Raw daily weights are noise — water, salt, the time of day — and a
/// chart of them tells me nothing. A week's worth is long enough to
/// flatten that and short enough to still turn when I do.
const trendWindow = 7;

/// The chart: every entry as a dot, and the moving average as the line
/// that actually means something.
///
/// One point per day between the first and last entry, so a gap in the
/// middle is drawn as a gap rather than closed silently. The average at
/// a day is the mean of every entry within [trendWindow] days back —
/// including that day, excluding days with nothing, so a week away from
/// the scale does not drag the line down to nothing.
List<WeightPoint> weightSeries(
  List<BodyWeight> entries, {
  int window = trendWindow,
}) {
  if (entries.isEmpty) return const [];

  final byDay = <String, List<int>>{};
  for (final entry in entries) {
    byDay.putIfAbsent(entry.day.key, () => []).add(entry.grams);
  }

  final sorted = [...entries]..sort((a, b) => a.day.compareTo(b.day));
  final first = sorted.first.day;
  final last = sorted.last.day;

  final points = <WeightPoint>[];
  for (var day = first; day.compareTo(last) <= 0; day = day.next) {
    final today = byDay[day.key];

    // Mean of the means: two weigh-ins on one day are one day's worth
    // of evidence, not two.
    final recent = <double>[];
    for (var back = 0; back < window; back++) {
      final readings = byDay[day.addDays(-back).key];
      if (readings == null || readings.isEmpty) continue;
      recent.add(readings.reduce((a, b) => a + b) / readings.length);
    }

    points.add((
      day: day,
      entry: today == null
          ? null
          : today.reduce((a, b) => a + b) / today.length,
      average: recent.isEmpty
          ? null
          : recent.reduce((a, b) => a + b) / recent.length,
    ));
  }
  return points;
}

/// The change over the last [days], measured on the trend line rather
/// than on two raw entries.
///
/// Comparing today's number with the one from a month ago compares two
/// pieces of noise. Comparing the averages compares two weeks.
WeightTrend? weightTrend(
  List<BodyWeight> entries, {
  required int days,
  int window = trendWindow,
}) {
  if (entries.length < 2) return null;
  final series = weightSeries(entries, window: window);
  final withAverage = [
    for (final point in series)
      if (point.average != null) point,
  ];
  if (withAverage.length < 2) return null;

  final last = withAverage.last;
  final cutoff = last.day.addDays(-(days - 1));
  final from = withAverage.firstWhere(
    (point) => point.day.compareTo(cutoff) >= 0,
    orElse: () => withAverage.first,
  );
  if (from.day == last.day) return null;

  final counted = entries
      .where((entry) => entry.day.compareTo(from.day) >= 0)
      .length;
  return (
    gramsChanged: (last.average! - from.average!).round(),
    days: from.day.daysUntil(last.day),
    entries: counted,
  );
}

/// The windows the summary can be read over.
const trendWindows = [30, 90, 365];
