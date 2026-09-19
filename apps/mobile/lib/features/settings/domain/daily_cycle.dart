import 'package:meta/meta.dart';

/// When I sleep and when I wake — the shape of my day.
///
/// The point of putting this in the app is to stop the day being
/// assumed. A reminder at 7 AM is a good idea for someone who wakes at
/// 6 and a useless one for someone who gets to bed at 5; the app should
/// bend to the second person rather than making them "fix their sleep"
/// first. Everything here works in minutes of the day and wraps around
/// midnight, because most people's nights do.
@immutable
class DailyCycle {
  const DailyCycle({required this.bedTime, required this.wakeTime});

  /// The default before anyone says otherwise: 11 PM to 7 AM.
  static const DailyCycle fallback = DailyCycle(
    bedTime: (23, 0),
    wakeTime: (7, 0),
  );

  /// What the app suggests, and the least it will suggest. Below
  /// [shortest] the card warns; it does not refuse, because a night
  /// shift is a fact and not a mistake to be corrected by a dialog.
  static const recommended = Duration(hours: 8);
  static const shortest = Duration(hours: 5);

  final (int, int) bedTime;
  final (int, int) wakeTime;

  static int minutesOf((int, int) time) => time.$1 * 60 + time.$2;

  static (int, int) timeOf(int minutes) {
    final wrapped = minutes % _day;
    final positive = wrapped < 0 ? wrapped + _day : wrapped;
    return (positive ~/ 60, positive % 60);
  }

  static const int _day = 24 * 60;

  /// How long the night is, wrapping midnight. A window that starts and
  /// ends at the same minute is a whole day asleep, not none.
  Duration get sleep {
    final from = minutesOf(bedTime);
    final to = minutesOf(wakeTime);
    final span = to > from ? to - from : to + _day - from;
    return Duration(minutes: span == 0 ? _day : span);
  }

  bool get isShort => sleep < shortest;
  bool get meetsRecommendation => sleep >= recommended;

  /// Whether [time] falls inside the night. The wake minute itself is
  /// already morning: a reminder set for the moment I get up is not a
  /// reminder that wakes me.
  bool covers((int, int) time) {
    final at = minutesOf(time);
    final from = minutesOf(bedTime);
    final to = minutesOf(wakeTime);
    if (from == to) return true;
    return to > from ? at >= from && at < to : at >= from || at < to;
  }

  /// The same reminder, kept at its own distance from waking.
  ///
  /// This is the whole rule: a thing I do two hours after getting up
  /// stays two hours after getting up. Move the alarm and it follows.
  (int, int) shiftedWith(DailyCycle to, (int, int) time) {
    final delta = minutesOf(to.wakeTime) - minutesOf(wakeTime);
    return timeOf(minutesOf(time) + delta);
  }

  /// How long after waking [time] falls.
  Duration afterWaking((int, int) time) {
    final offset = minutesOf(time) - minutesOf(wakeTime);
    return Duration(minutes: offset < 0 ? offset + _day : offset);
  }

  DailyCycle copyWith({(int, int)? bedTime, (int, int)? wakeTime}) =>
      DailyCycle(
        bedTime: bedTime ?? this.bedTime,
        wakeTime: wakeTime ?? this.wakeTime,
      );

  @override
  bool operator ==(Object other) =>
      other is DailyCycle &&
      other.bedTime == bedTime &&
      other.wakeTime == wakeTime;

  @override
  int get hashCode => Object.hash(bedTime, wakeTime);

  @override
  String toString() =>
      'DailyCycle(${bedTime.$1}:${bedTime.$2} → '
      '${wakeTime.$1}:${wakeTime.$2})';
}
