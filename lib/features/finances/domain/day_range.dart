import 'package:harvest/core/domain/harvest_day.dart';
import 'package:meta/meta.dart';

/// Which stretch of days the Insights page is looking at.
enum RangeKind { week, month, custom }

/// A closed span of Harvest Days, both ends included.
///
/// Week and month used to be two separate sets of providers; making the
/// span a value means the third option — whatever two dates I pick —
/// costs nothing extra, and the charts, the totals and the moves all
/// read from the same one.
@immutable
class DayRange {
  const DayRange({
    required this.from,
    required this.to,
    this.kind = RangeKind.custom,
  });

  factory DayRange.week(HarvestDay today) => DayRange(
    from: today.weekStart,
    to: today.weekStart.addDays(6),
    kind: RangeKind.week,
  );

  factory DayRange.month(HarvestDay today) => DayRange(
    from: HarvestDay.fromDate(DateTime(today.year, today.month)),
    to: HarvestDay.fromDate(DateTime(today.year, today.month + 1, 0)),
    kind: RangeKind.month,
  );

  final HarvestDay from;
  final HarvestDay to;
  final RangeKind kind;

  /// Days in the span, both ends counted.
  int get length => from.daysUntil(to) + 1;

  List<HarvestDay> get eachDay => List.generate(length, from.addDays);

  bool contains(HarvestDay day) =>
      day.compareTo(from) >= 0 && day.compareTo(to) <= 0;

  /// How much of the span has actually happened. A month that is four
  /// days old should divide by four, not by thirty-one.
  int elapsedDays(HarvestDay today) {
    if (today.compareTo(from) < 0) return 0;
    return (today.compareTo(to) < 0
            ? from.daysUntil(today)
            : from.daysUntil(to)) +
        1;
  }

  @override
  bool operator ==(Object other) =>
      other is DayRange &&
      other.from == from &&
      other.to == to &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(from, to, kind);

  @override
  String toString() => 'DayRange(${from.key}..${to.key})';
}
