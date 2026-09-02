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

  /// The Harvest Day that [moment] (local time) belongs to.
  factory HarvestDay.of(DateTime moment) {
    final local = moment.isUtc ? moment.toLocal() : moment;
    final shifted = local.subtract(const Duration(hours: boundaryHour));
    return HarvestDay._(DateTime(shifted.year, shifted.month, shifted.day));
  }

  /// Today's Harvest Day.
  factory HarvestDay.today() => HarvestDay.of(DateTime.now());

  /// Parses a [key] previously produced by [HarvestDay.key].
  factory HarvestDay.parse(String key) {
    final parts = key.split('-').map(int.parse).toList();
    return HarvestDay._(DateTime(parts[0], parts[1], parts[2]));
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

  /// The moment this Harvest Day started (3 AM local).
  DateTime get startsAt =>
      DateTime(year, month, day).add(const Duration(hours: boundaryHour));

  /// Weekday of this Harvest Day, [DateTime.monday]..[DateTime.sunday].
  int get weekday => _date.weekday;

  /// The Monday that starts this Harvest Day's week.
  HarvestDay get weekStart =>
      HarvestDay._(_date.subtract(Duration(days: _date.weekday - 1)));

  HarvestDay get next => HarvestDay._(_date.add(const Duration(days: 1)));
  HarvestDay get previous =>
      HarvestDay._(_date.subtract(const Duration(days: 1)));

  /// Whole days between this and [other] (positive when [other] is later).
  int daysUntil(HarvestDay other) =>
      other._date.difference(_date).inDays;

  @override
  int compareTo(HarvestDay other) => _date.compareTo(other._date);

  @override
  bool operator ==(Object other) =>
      other is HarvestDay && other._date == _date;

  @override
  int get hashCode => _date.hashCode;

  @override
  String toString() => 'HarvestDay($key)';
}
