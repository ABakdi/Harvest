import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/ui/widgets/reminder_countdown.dart';

/// Checkpoint C3-1: the reminder on a card counts down instead of
/// sitting there as a time I have to subtract from the clock myself.
void main() {
  group('next occurrence', () {
    test('is today when the time is still ahead', () {
      expect(
        nextOccurrence(18, 0, DateTime(2026, 9, 10, 9, 30)),
        DateTime(2026, 9, 10, 18),
      );
    });

    test('rolls to tomorrow once the time has gone by', () {
      expect(
        nextOccurrence(8, 0, DateTime(2026, 9, 10, 9, 30)),
        DateTime(2026, 9, 11, 8),
      );
    });

    test('rolls over a month boundary on the calendar, not by hours', () {
      expect(
        nextOccurrence(8, 0, DateTime(2026, 9, 30, 9)),
        DateTime(2026, 10, 1, 8),
      );
    });
  });

  group('formatting', () {
    test('hours and minutes while it is still a way off', () {
      expect(
        formatReminderRemaining(const Duration(hours: 3, minutes: 12)),
        '3h 12m',
      );
    });

    test('minutes only inside the hour', () {
      expect(formatReminderRemaining(const Duration(minutes: 42)), '42m');
    });

    test('ticks by the second in the last five minutes', () {
      expect(
        formatReminderRemaining(const Duration(minutes: 4, seconds: 7)),
        '4:07',
      );
      expect(formatReminderRemaining(const Duration(seconds: 9)), '0:09');
    });

    test('says now as it lands, and never a negative', () {
      expect(formatReminderRemaining(Duration.zero), 'now');
      expect(formatReminderRemaining(const Duration(seconds: -30)), 'now');
    });

    test('the unit suffixes are injected so they localize', () {
      expect(
        formatReminderRemaining(
          const Duration(hours: 2, minutes: 5),
          hours: 'س',
          minutes: 'د',
        ),
        '2س 5د',
      );
    });
  });
}
