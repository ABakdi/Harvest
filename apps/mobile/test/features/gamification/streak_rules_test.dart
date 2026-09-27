import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gamification/domain/streak_rules.dart';

/// `packages/core/fixtures/streaks.json`, the live streak rules the web
/// runs through core, read here through [StreakRules].
void main() {
  final data = jsonDecode(
    File(
      '../../packages/core/fixtures/streaks.json',
    ).readAsStringSync(),
  ) as Map<String, dynamic>;

  List<Map<String, dynamic>> list(String key) =>
      (data[key] as List<dynamic>).cast<Map<String, dynamic>>();

  StreakState? state(Object? json) {
    if (json == null) return null;
    final m = json as Map<String, dynamic>;
    return StreakState(
      current: m['current'] as int,
      best: m['best'] as int,
      lastEarnedDay: m['lastEarnedDay'] as String?,
      freezesStored: m['freezesStored'] as int,
    );
  }

  String label(Map<String, dynamic> c, String fallback) =>
      c['why'] == null ? fallback : '$fallback: ${c['why']}';

  String previous(String key) => HarvestDay.parse(key).previous.key;

  group('earnHabitDay', () {
    for (final (i, c) in list('earnHabitDay').indexed) {
      test(label(c, 'case $i'), () {
        final habit = c['habit'] as Map<String, dynamic>?;
        final calendar = habit == null
            ? null
            : HabitCalendar(
                schedule: habit['schedule'] == null
                    ? null
                    : Schedule.fromJson(
                        habit['schedule'] as Map<String, dynamic>,
                      ),
                pausedDay: HarvestDay.tryParse(habit['pausedDay'] as String?),
              );
        expect(
          StreakRules.earnHabitDay(
            state(c['streak'])!,
            c['day'] as String,
            habit: calendar,
          ),
          state(c['next']),
        );
      });
    }
  });

  group('retractHabitDay', () {
    for (final (i, c) in list('retractHabitDay').indexed) {
      test(label(c, 'case $i'), () {
        final day = c['day'] as String;
        expect(
          StreakRules.retractHabitDay(state(c['streak'])!, day, previous(day)),
          state(c['next']),
        );
      });
    }
  });

  group('refreshGlobal', () {
    for (final (i, c) in list('refreshGlobal').indexed) {
      test(label(c, 'case $i'), () {
        final day = c['day'] as String;
        final refresh = StreakRules.refreshGlobal(
          state(c['streak'])!,
          actions: c['actions'] as int,
          goal: c['goal'] as int,
          dayKey: day,
          previousDayKey: previous(day),
          paid: [
            for (final p in (c['paid'] as List<dynamic>? ?? const []))
              (
                reason: (p as Map<String, dynamic>)['reason'] as String,
                harvestDay: p['harvestDay'] as String,
              ),
          ],
        );
        expect(refresh.next, state(c['next']));
        final milestone = c['milestone'] as Map<String, dynamic>?;
        expect(
          refresh.milestone,
          milestone == null
              ? null
              : (
                  coins: milestone['coins'] as int,
                  reason: milestone['reason'] as String,
                ),
        );
      });
    }
  });
}
