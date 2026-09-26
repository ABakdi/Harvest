import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/portable_settings.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/due.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/gamification/data/gamification_repository.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/goals/domain/goal.dart';
import 'package:harvest/features/health/data/health_repository.dart';
import 'package:harvest/features/health/domain/sleep.dart';
import 'package:harvest/features/pomodoro/domain/pomodoro_service.dart';

/// The fixtures the TypeScript side is held to ([[ADR-009-Monorepo]]).
///
/// `packages/core/fixtures` are the domain rules as inputs and expected
/// outputs; this suite runs them through the Dart originals, and the
/// vitest suite runs them through the port. `packages/contracts/fixtures`
/// are sync records; this suite checks that every column they carry is
/// a column of the Drift table, with the right type, and no column is
/// missing. When the two sides disagree, one of the suites fails.
///
/// Tests run from `apps/mobile`, so the packages are two levels up.
const _core = '../../packages/core/fixtures';
const _contracts = '../../packages/contracts/fixtures';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _list(Map<String, dynamic> json, String key) =>
    (json[key] as List<dynamic>).cast<Map<String, dynamic>>();

String _label(Map<String, dynamic> c, String fallback) {
  final why = c['why'] as String?;
  return why == null ? fallback : '$fallback: $why';
}

void main() {
  group('core/harvest-day.json', () {
    final data = _read('$_core/harvest-day.json');

    for (final c in _list(data, 'of')) {
      test(_label(c, 'of(${c['local']}) is ${c['day']}'), () {
        final moment = DateTime.parse(c['local'] as String);
        expect(moment.isUtc, isFalse, reason: 'fixtures are wall-clock');
        expect(HarvestDay.of(moment).key, c['day']);
      });
    }

    for (final c in _list(data, 'parse')) {
      test(_label(c, 'tryParse(${c['key']}) is ${c['day']}'), () {
        expect(HarvestDay.tryParse(c['key'] as String)?.key, c['day']);
      });
    }

    for (final c in _list(data, 'addDays')) {
      test('${c['day']} + ${c['n']} is ${c['result']}', () {
        final day = HarvestDay.parse(c['day'] as String);
        expect(day.addDays(c['n'] as int).key, c['result']);
      });
    }

    for (final c in _list(data, 'daysUntil')) {
      test(_label(c, '${c['from']} → ${c['to']} is ${c['days']}'), () {
        final from = HarvestDay.parse(c['from'] as String);
        final to = HarvestDay.parse(c['to'] as String);
        expect(from.daysUntil(to), c['days']);
      });
    }

    for (final c in _list(data, 'weekday')) {
      test('${c['day']} is weekday ${c['weekday']}', () {
        expect(HarvestDay.parse(c['day'] as String).weekday, c['weekday']);
      });
    }

    for (final c in _list(data, 'weekStart')) {
      test(_label(c, '${c['day']} starts its week on ${c['weekStart']}'), () {
        final day = HarvestDay.parse(c['day'] as String);
        expect(day.weekStart.key, c['weekStart']);
        expect(day.weekDays.first.key, c['weekStart']);
      });
    }
  });

  group('core/schedules.json', () {
    final cases = _list(_read('$_core/schedules.json'), 'cases');
    for (final (i, c) in cases.indexed) {
      test(_label(c, '#$i ${jsonEncode(c['schedule'])} on ${c['day']}'), () {
        final schedule = Schedule.fromJson(
          c['schedule'] as Map<String, dynamic>,
        );
        final due = schedule.isDueOn(
          HarvestDay.parse(c['day'] as String),
          doneDaysThisWeek: c['doneDaysThisWeek'] as int? ?? 0,
        );
        expect(due, c['due']);
      });
    }
  });

  group('core/due.json', () {
    final cases = _list(_read('$_core/due.json'), 'cases');
    for (final (i, c) in cases.indexed) {
      final raw = c['commitment'] as Map<String, dynamic>;
      test(_label(c, '#$i ${raw['type']} on ${c['day']}'), () {
        final commitment = _commitmentOf(raw);
        final day = HarvestDay.parse(c['day'] as String);
        final totalLogged = c['totalLogged'] as int? ?? 0;
        expect(
          isDueOn(
            commitment,
            day,
            doneDaysThisWeek: c['doneDaysThisWeek'] as int? ?? 0,
            totalLogged: totalLogged,
          ),
          c['due'],
        );
        expect(
          isOverdueOn(commitment, day, totalLogged: totalLogged),
          c['overdue'],
        );
      });
    }
  });

  group('core/over-log.json', () {
    // The real CheckInService against a real (in-memory) database: the
    // cap is a transaction's decision, and the fixture pins the whole of
    // it, not just maxUnitsPerDay.
    late HarvestDatabase db;
    setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    final cases = _list(_read('$_core/over-log.json'), 'cases');
    for (final (i, c) in cases.indexed) {
      test(
        _label(c, '#$i ${c['type']}: ${c['quantity']} on ${c['loggedToday']}'),
        () async {
          final type = CommitmentType.values.byName(c['type'] as String);
          final daily = c['dailyCommitment'] as int?;
          final commitment = Commitment(
            uuid: 'seed-$i',
            type: type,
            title: 'Seed $i',
            createdAt: DateTime(2026, 9),
            schedule: type == CommitmentType.habit
                ? const DailySchedule()
                : null,
            totalTarget: type == CommitmentType.project
                ? (c['totalTarget'] as int? ?? 1000)
                : null,
            dailyCommitment: daily,
          );
          final day = HarvestDay.parse('2026-09-19');
          await db
              .into(db.commitments)
              .insert(
                CommitmentsCompanion.insert(
                  uuid: commitment.uuid,
                  type: type.name,
                  title: commitment.title,
                  dailyCommitment: Value(daily),
                  totalTarget: Value(commitment.totalTarget),
                ),
              );
          final loggedToday = c['loggedToday'] as int;
          // What was logged on the seed before today, on the day before.
          final earlier =
              (c['totalLogged'] as int? ?? loggedToday) - loggedToday;
          if (earlier > 0) {
            await db
                .into(db.checkIns)
                .insert(
                  CheckInsCompanion.insert(
                    uuid: 'before-$i',
                    commitmentUuid: commitment.uuid,
                    harvestDay: day.previous.key,
                    quantity: Value(earlier),
                  ),
                );
          }
          if (loggedToday > 0) {
            await db
                .into(db.checkIns)
                .insert(
                  CheckInsCompanion.insert(
                    uuid: 'earlier-$i',
                    commitmentUuid: commitment.uuid,
                    harvestDay: day.key,
                    quantity: Value(loggedToday),
                  ),
                );
          }

          final result = await CheckInService(
            db,
            StreakService(db),
          ).checkIn(commitment, quantity: c['quantity'] as int, day: day);

          final (logged, xp, capped) = switch (result) {
            CheckInSuccess(:final quantityLogged, :final xpEarned) => (
              quantityLogged,
              xpEarned,
              false,
            ),
            CheckInCapped(:final quantityLogged, :final xpEarned) => (
              quantityLogged,
              xpEarned,
              true,
            ),
          };
          expect(logged, c['quantityLogged']);
          expect(xp, c['xpEarned']);
          expect(capped, c['capped']);
        },
      );
    }
  });

  group('core/xp.json', () {
    final data = _read('$_core/xp.json');
    final xp = data['xp'] as Map<String, dynamic>;

    test('every amount the phone pays', () {
      expect(xp['habitOrTodo'], Xp.habitOrTodo);
      expect(xp['perProjectUnit'], Xp.perProjectUnit);
      // A picture in a scheduled album and a finished gym session are
      // both paid as a check-in.
      expect(xp['memory'], Xp.habitOrTodo);
      expect(xp['gymSession'], Xp.habitOrTodo);
      expect(xp['sleep'], sleepXp);
      expect(xp['bodyWeight'], weightXp);
      expect(xp['stepGoal'], stepGoalXp);
      expect(xp['expenseLog'], expenseLogXp);
      expect(xp['pomodoroBlock'], pomodoroBlockXp);
    });

    test('the coin economy', () {
      final coins = (data['streakMilestoneCoins'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(int.parse(key), value as int),
      );
      expect(coins, streakMilestoneCoins);
      expect(data['freezeCost'], freezeCost);
      expect(data['maxFreezesStored'], maxFreezesStored);
      expect(data['defaultDailyHarvestGoal'], StreakService.defaultGoal);
    });

    for (final c in _list(data, 'ranks')) {
      test('${c['xp']} XP is ${c['rank']}', () {
        expect(FarmerRank.forXp(c['xp'] as int).name, c['rank']);
      });
    }
  });

  group('core/goals.json', () {
    final data = _read('$_core/goals.json');

    /// The live items of a case, as the repository hands them over:
    /// deleted ones are never read.
    List<GoalItem> live(List<Map<String, dynamic>> items) => [
      for (final (i, c) in items.indexed)
        if (c['deletedAt'] == null)
          GoalItem(
            uuid: c['uuid'] as String? ?? 'i$i',
            goalUuid: 'g',
            kind: GoalItemKind.values.byName(c['kind'] as String? ?? 'step'),
            body: c['uuid'] as String? ?? 'i$i',
            doneAt: DateTime.tryParse(c['doneAt'] as String? ?? ''),
            position: c['position'] as int? ?? 0,
            parentUuid: c['parentUuid'] as String?,
            createdAt: DateTime.tryParse(c['createdAt'] as String? ?? ''),
          ),
    ];

    for (final (i, c) in _list(data, 'cases').indexed) {
      test(_label(c, 'progress case $i'), () {
        final tally = goalTally(live(_list(c, 'items')));
        final expected = c['progress'] as Map<String, dynamic>?;
        if (expected == null) {
          expect(tally, isNull);
          return;
        }
        expect(tally!.done, expected['done']);
        expect(tally.total, expected['total']);
        expect(tally.ratio, (expected['ratio'] as num).toDouble());
        expect(tally.complete, expected['complete']);
      });
    }

    for (final (i, c) in _list(data, 'parentDone').indexed) {
      test(_label(c, 'parent done case $i'), () {
        final drawn = parentDoneAt(live(_list(c, 'subtasks')));
        expect(drawn.derived, c['derived']);
        final at = c['doneAt'] as String?;
        expect(drawn.doneAt?.toUtc(), at == null ? null : DateTime.parse(at));
      });
    }

    for (final (i, c) in _list(data, 'next').indexed) {
      test(_label(c, 'next case $i'), () {
        expect(GoalOutline(live(_list(c, 'items'))).next?.uuid, c['next']);
      });
    }
  });

  group('contracts', () {
    late HarvestDatabase db;
    setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    TableInfo<Table, dynamic> tableNamed(String name) =>
        db.allTables.firstWhere((t) => t.actualTableName == name);

    test('every table syncs, except the outbox and quests', () {
      final records = Directory('$_contracts/records')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.endsWith('.json'))
          .map((name) => name.substring(0, name.length - 5))
          .toSet();
      final tables = db.allTables.map((t) => t.actualTableName).toSet()
        ..removeAll(['outbox', 'quests']);
      expect(records, tables);
    });

    test('the settings allow-list is the same list', () {
      final prefixes =
          (_read('$_contracts/portable-settings.json')['prefixes']
                  as List<dynamic>)
              .cast<String>();
      expect(prefixes, importableSettingPrefixes);
    });

    final plain = Directory('$_contracts/records')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)
        .where((record) => record['data'] != null)
        .toList();
    final private = Directory('$_contracts/private-data')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map(
          (f) => {
            'table': f.uri.pathSegments.last.replaceAll('.json', ''),
            'data': jsonDecode(f.readAsStringSync()),
          },
        )
        .toList();

    for (final record in [...plain, ...private]) {
      final table = record['table'] as String;
      test('$table: data is exactly the Drift columns, typed', () {
        final data = record['data'] as Map<String, dynamic>;
        final columns = {
          for (final column in tableNamed(table).$columns)
            _camel(column.$name): column,
        };
        expect(data.keys.toSet(), columns.keys.toSet());
        for (final MapEntry(:key, :value) in data.entries) {
          _expectColumnValue(columns[key]!, value, '$table.$key');
        }
      });
    }
  });
}

Commitment _commitmentOf(Map<String, dynamic> raw) {
  final schedule = raw['schedule'] as Map<String, dynamic>?;
  final dueDay = raw['dueDay'] as String?;
  return Commitment(
    uuid: 'fixture',
    type: CommitmentType.values.byName(raw['type'] as String),
    title: 'Fixture',
    createdAt: DateTime.parse(raw['createdAt'] as String),
    schedule: schedule == null ? null : Schedule.fromJson(schedule),
    totalTarget: raw['totalTarget'] as int?,
    dailyCommitment: raw['dailyCommitment'] as int?,
    dueDay: dueDay == null ? null : HarvestDay.parse(dueDay),
    pausedAt: raw['paused'] == true ? DateTime.utc(2026, 9) : null,
  );
}

/// `harvest_day` → `harvestDay`, the way Drift named the getter.
String _camel(String snake) {
  final parts = snake.split('_');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

/// A value on the wire must be what the column holds: a timestamp is
/// ISO-8601 in UTC, a bool is a bool, an integer is an integer.
void _expectColumnValue(
  GeneratedColumn<Object> column,
  Object? value,
  String where,
) {
  if (value == null) {
    expect(column.$nullable, isTrue, reason: '$where is not nullable');
    return;
  }
  switch (column.type) {
    case DriftSqlType.string:
      expect(value, isA<String>(), reason: where);
    case DriftSqlType.int || DriftSqlType.bigInt:
      expect(value, isA<int>(), reason: where);
    case DriftSqlType.bool:
      expect(value, isA<bool>(), reason: where);
    case DriftSqlType.double:
      expect(value, isA<num>(), reason: where);
    case DriftSqlType.dateTime:
      expect(value, isA<String>(), reason: where);
      final parsed = DateTime.tryParse(value as String);
      expect(parsed, isNotNull, reason: '$where is not ISO-8601');
      expect(parsed!.isUtc, isTrue, reason: '$where is not UTC');
    default:
      fail('$where: a column type the contract does not cover');
  }
}
