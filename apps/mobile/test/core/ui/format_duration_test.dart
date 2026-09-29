import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/ui/format.dart';

void main() {
  group('formatDuration', () {
    test('minutes and seconds under an hour', () {
      expect(formatDuration(Duration.zero), '0:00');
      expect(formatDuration(const Duration(minutes: 4, seconds: 5)), '4:05');
      expect(formatDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('hours past an hour, never 100 minutes', () {
      expect(formatDuration(const Duration(hours: 1)), '1:00:00');
      expect(
        formatDuration(const Duration(minutes: 100, seconds: 5)),
        '1:40:05',
      );
      expect(
        formatDuration(
          const Duration(minutes: 100, seconds: 5),
          padMinutes: true,
        ),
        '1:40:05',
      );
    });

    test('padded minutes for the timer and recordings', () {
      expect(
        formatDuration(
          const Duration(minutes: 4, seconds: 5),
          padMinutes: true,
        ),
        '04:05',
      );
      expect(
        formatDuration(const Duration(minutes: 25), padMinutes: true),
        '25:00',
      );
    });

    test('a negative duration reads as zero', () {
      expect(formatDuration(const Duration(seconds: -3)), '0:00');
      expect(
        formatDuration(const Duration(seconds: -3), padMinutes: true),
        '00:00',
      );
    });

    test('drops the fraction of a second', () {
      expect(formatDuration(const Duration(milliseconds: 5999)), '0:05');
    });
  });
}
