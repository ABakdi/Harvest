import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/calendar_entries.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';

/// `packages/core/fixtures/calendar.json`: a calendar day lists what the
/// web's lists, done or not ([[Audit-v3]] G5-12).
void main() {
  final data = jsonDecode(
    File(
      '../../packages/core/fixtures/calendar.json',
    ).readAsStringSync(),
  ) as Map<String, dynamic>;
  List<Map<String, dynamic>> list(Object? json) =>
      (json! as List<dynamic>).cast<Map<String, dynamic>>();

  DateTime? at(Object? text) =>
      text == null ? null : DateTime.parse(text as String);
  HarvestDay? day(Object? key) => HarvestDay.tryParse(key as String?);

  // Deleted seeds never reach the calendar on the phone: the repository
  // leaves them out before the rule sees them.
  final seeds = [
    for (final s in list(data['seeds']))
      if (s['deletedAt'] == null)
        Commitment(
          uuid: s['uuid'] as String,
          type: CommitmentType.values.byName(s['type'] as String),
          title: s['uuid'] as String,
          createdAt: DateTime.parse(s['createdAt'] as String),
          // A habit stored without one is daily, as the repository reads it.
          schedule: s['scheduleJson'] == null
              ? (s['type'] == 'habit' ? const DailySchedule() : null)
              : Schedule.fromJson(
                  jsonDecode(s['scheduleJson'] as String)
                      as Map<String, dynamic>,
                ),
          totalTarget: s['totalTarget'] as int?,
          dailyCommitment: s['dailyCommitment'] as int?,
          dueDay: day(s['dueDay']),
          deadline: day(s['deadline']),
          pausedAt: at(s['pausedAt']),
          archivedAt: at(s['archivedAt']),
        ),
  ];
  final checkIns = [
    for (final c in list(data['checkIns']))
      if (c['deletedAt'] == null)
        (
          commitmentUuid: c['commitmentUuid'] as String,
          harvestDay: c['harvestDay'] as String,
          quantity: c['quantity'] as int,
        ),
  ];

  for (final c in list(data['days'])) {
    test(c['why'] as String, () {
      final entries = calendarEntries(
        seeds,
        checkIns,
        HarvestDay.parse(c['day'] as String),
      );
      expect(
        [
          for (final e in entries)
            {
              'uuid': e.commitment.uuid,
              'deadline': e.deadline,
              'done': e.done,
            },
        ],
        c['entries'],
      );
    });
  }
}
