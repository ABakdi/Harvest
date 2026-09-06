import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/health/domain/steps.dart';

/// Phase 4, M4.1. The phone's step counter counts since boot and resets
/// without warning, so the only interesting question is what a sequence
/// of readings does to a day's total — especially across a reboot.
void main() {
  final today = HarvestDay.parse('2026-09-06');

  group('readings', () {
    test('the first one anchors without adding anything', () {
      final day = applyReading(startOfDay(today), 12000);
      expect(day.steps, 0, reason: 'nothing to measure from yet');
      expect(day.lastCounter, 12000);
    });

    test('a rising counter adds the difference', () {
      var day = applyReading(startOfDay(today), 12000);
      day = applyReading(day, 12500);
      expect(day.steps, 500);
      day = applyReading(day, 13200);
      expect(day.steps, 1200);
    });

    test('the same reading twice adds nothing', () {
      var day = applyReading(startOfDay(today), 12000);
      day = applyReading(day, 12500);
      day = applyReading(day, 12500);
      expect(day.steps, 500);
    });

    test('a reboot re-anchors and keeps what the day had', () {
      var day = applyReading(startOfDay(today), 12000);
      day = applyReading(day, 15000);
      expect(day.steps, 3000);

      // Phone reboots: the counter starts again from nearly nothing.
      day = applyReading(day, 40);
      expect(day.steps, 3000, reason: 'the day keeps what it earned');
      expect(day.lastCounter, 40, reason: 'and measures from here on');

      day = applyReading(day, 540);
      expect(day.steps, 3500);
    });

    test('never invents steps out of a reboot', () {
      var day = applyReading(startOfDay(today), 900000);
      day = applyReading(day, 900500);
      // A naive implementation would add 900,000 here.
      day = applyReading(day, 100);
      expect(day.steps, 500);
    });

    test('a new day starts at zero, anchored where the last one ended', () {
      var yesterday = applyReading(startOfDay(today), 12000);
      yesterday = applyReading(yesterday, 20000);
      expect(yesterday.steps, 8000);

      final fresh = startOfDay(today.next, counter: yesterday.lastCounter);
      expect(fresh.steps, 0);
      expect(applyReading(fresh, 20300).steps, 300);
    });
  });

  group('averages', () {
    test('ignore days the phone was off rather than calling them zero', () {
      final week = [
        StepDay(day: today, steps: 10000),
        StepDay(day: today.next, steps: 8000),
        StepDay(day: today.addDays(2), steps: 0),
      ];
      expect(averageSteps(week), 9000);
    });

    test('are null when there is nothing to average', () {
      expect(averageSteps(const []), isNull);
      expect(averageSteps([StepDay(day: today, steps: 0)]), isNull);
    });
  });
}
