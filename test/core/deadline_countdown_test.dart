import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/ui/widgets/deadline_countdown.dart';

void main() {
  group('formatDeadlineRemaining (checkpoint P3)', () {
    test('distant deadlines show days and hours', () {
      expect(
        formatDeadlineRemaining(const Duration(days: 5, hours: 14)),
        '5d 14h',
      );
    });

    test('inside a day shows hours and minutes', () {
      expect(
        formatDeadlineRemaining(const Duration(hours: 14, minutes: 32)),
        '14h 32m',
      );
    });

    test('at three hours or less it becomes a ticking clock', () {
      expect(
        formatDeadlineRemaining(const Duration(hours: 3)),
        '03:00:00',
      );
      expect(
        formatDeadlineRemaining(
          const Duration(hours: 2, minutes: 59, seconds: 41),
        ),
        '02:59:41',
      );
      expect(
        formatDeadlineRemaining(const Duration(minutes: 4, seconds: 7)),
        '00:04:07',
      );
    });

    test('just above the threshold stays in hours mode', () {
      expect(
        formatDeadlineRemaining(const Duration(hours: 3, minutes: 1)),
        '3h 1m',
      );
    });

    test('overdue yields empty (the urgent subtitle takes over)', () {
      expect(formatDeadlineRemaining(const Duration(seconds: -1)), '');
    });
  });
}
