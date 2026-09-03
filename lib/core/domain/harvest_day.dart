import 'package:meta/meta.dart';

/// The app's logical day: it starts at 3:00 AM local time, not midnight,
/// so a check-in at 1 AM still counts for the evening it belongs to.
///
/// This is business rule #1 and every date-keyed record stores its
/// [HarvestDay.key] computed at write time.
@immutable
final class HarvestDay implements Comparable<HarvestDay> {
  HarvestDay._(this._date)
    : assert(
        _date.hour == 0 && _date.minute == 0,
        'internal date must be normalized to midnight',
      );

  /// The Harvest Day that [moment] (local time) belongs to. Pure
  /// calendar math: before the boundary hour the moment belongs to the
  /// previous calendar date, whatever a DST change did to the night.
  factory HarvestDay.of(DateTime moment) {
    final local = moment.isUtc ? moment.toLocal() : moment;
    final shift = local.hour < boundaryHour ? 1 : 0;
    return HarvestDay._(DateTime(local.year, local.month, local.day - shift));
  }

  /// Today's Harvest Day.
  factory HarvestDay.today() => HarvestDay.of(DateTime.now());

  /// A Harvest Day from a plain calendar date (no 3 AM shift) — use
  /// this for values coming from date pickers and calendar grids.
  factory HarvestDay.fromDate(DateTime date) =>
      HarvestDay._(DateTime(date.year, date.month, date.day));

  /// Parses a [key] previously produced by [HarvestDay.key].
  factory HarvestDay.parse(String key) {
    final parsed = HarvestDay.tryParse(key);
    if (parsed == null) throw FormatException('not a Harvest Day key', key);
    return parsed;
  }

  /// [HarvestDay.parse] for stored values: null instead of throwing.
  static HarvestDay? tryParse(String? key) {
    if (key == null) return null;
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.month != month || date.day != day) return null;
    return HarvestDay._(date);
  }

  /// The local-time hour at which a new day begins.
  static const boundaryHour = 3;

  final DateTime _date;

  int get year => _date.year;
  int get month => _date.month;
  int get day => _date.day;

  /// Stable storage key, `yyyy-MM-dd`.
  String get key =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// Midnight of the calendar date this day is labelled with — for
  /// date pickers, calendars and formatting, never for the boundary.
  DateTime toDateTime() => DateTime(year, month, day);

  /// The moment this Harvest Day started (3 AM local).
  DateTime get startsAt => DateTime(year, month, day, boundaryHour);

  /// Weekday of this Harvest Day, [DateTime.monday]..[DateTime.sunday].
  int get weekday => _date.weekday;

  /// The Monday that starts this Harvest Day's week.
  HarvestDay get weekStart => addDays(1 - _date.weekday);

  /// Monday through Sunday of this Harvest Day's week.
  List<HarvestDay> get weekDays {
    final start = weekStart;
    return List.generate(7, start.addDays);
  }

  /// [n] calendar days later (or earlier for a negative [n]); DST-safe
  /// because it never adds a Duration.
  HarvestDay addDays(int n) => HarvestDay._(DateTime(year, month, day + n));

  HarvestDay get next => addDays(1);
  HarvestDay get previous => addDays(-1);

  /// Whole days between this and [other] (positive when [other] is later),
  /// counted on the calendar rather than in elapsed hours.
  int daysUntil(HarvestDay other) => DateTime.utc(
    other.year,
    other.month,
    other.day,
  ).difference(DateTime.utc(year, month, day)).inDays;

  @override
  int compareTo(HarvestDay other) => _date.compareTo(other._date);

  @override
  bool operator ==(Object other) => other is HarvestDay && other._date == _date;

  @override
  int get hashCode => _date.hashCode;

  @override
  String toString() => 'HarvestDay($key)';
}
