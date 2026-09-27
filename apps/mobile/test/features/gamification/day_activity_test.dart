import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/gamification/domain/day_activity.dart';

/// `packages/core/fixtures/activity.json`: the heat-map counts, spans
/// and shades its days as the web's does ([[Audit-v3]] G5-11).
void main() {
  final data = jsonDecode(
    File(
      '../../packages/core/fixtures/activity.json',
    ).readAsStringSync(),
  ) as Map<String, dynamic>;
  List<Map<String, dynamic>> list(Object? json) =>
      (json! as List<dynamic>).cast<Map<String, dynamic>>();

  for (final c in list(data['window'])) {
    test('the window around ${c['today']}', () {
      final window = activityWindow(HarvestDay.parse(c['today'] as String));
      expect([window.start.key, window.end.key], [c['start'], c['end']]);
    });
  }

  test('each day is as high as its productive actions', () {
    final a = data['activity'] as Map<String, dynamic>;
    final window = activityWindow(HarvestDay.parse(a['today'] as String));
    final heights = dayActivity(
      checkIns: [
        for (final c in list(a['checkIns']))
          (
            commitmentUuid: c['commitmentUuid'] as String,
            harvestDay: c['harvestDay'] as String,
            quantity: c['quantity'] as int,
            deleted: c['deletedAt'] != null,
          ),
      ],
      seeds: [
        for (final s in list(a['seeds']))
          (
            uuid: s['uuid'] as String,
            type: s['type'] as String,
            dailyCommitment: s['dailyCommitment'] as int?,
            deleted: s['deletedAt'] != null,
          ),
      ],
      albums: [
        for (final s in list(a['albums']))
          (
            uuid: s['uuid'] as String,
            scheduled: s['scheduled'] as bool,
            deleted: s['deletedAt'] != null,
          ),
      ],
      memories: [
        for (final m in list(a['memories']))
          (
            albumUuid: m['albumUuid'] as String,
            harvestDay: m['harvestDay'] as String,
            deleted: m['deletedAt'] != null,
          ),
      ],
      start: window.start,
      end: window.end,
    );
    expect(heights, a['heights']);
  });

  for (final c in list(data['shade'])) {
    test('${c['actions']} of ${c['goal']} is shaded ${c['shade']}', () {
      expect(
        activityShade(
          c['actions'] as int,
          c['goal'] as int,
          inStreak: c['inStreak'] as bool,
        ),
        closeTo((c['shade'] as num).toDouble(), 1e-9),
      );
    });
  }
}
