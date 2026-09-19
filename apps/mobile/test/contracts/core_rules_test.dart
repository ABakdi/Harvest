import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/domain/sleep.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:harvest/features/settings/domain/daily_cycle.dart';

/// The rules the web ports live beside the phone's own
/// (`packages/core`), and a rule in two places is only one rule while
/// both are read against the same numbers. These are the fixtures the
/// TypeScript tests use, run through the Dart the app actually ships.
void main() {
  Map<String, Object?> fixture(String name) => jsonDecode(
    File('../../packages/core/fixtures/$name.json').readAsStringSync(),
  ) as Map<String, Object?>;

  List<Map<String, Object?>> list(Object? value) => [
    for (final item in value! as List<Object?>) item! as Map<String, Object?>,
  ];

  group('sleep', () {
    final spec = fixture('sleep');

    SleepNight night(Map<String, Object?> entry) {
      final day = HarvestDay.parse(entry['day']! as String);
      final slept = entry['sleptMinutes']! as int;
      return SleepNight(
        uuid: '${entry['day']}',
        day: day,
        fellAsleepAt: day.toDateTime(),
        wokeAt: day.toDateTime().add(Duration(minutes: slept)),
        targetMinutes: entry['targetMinutes']! as int,
      );
    }

    test('the debt is the same minute for minute', () {
      for (final entry in list(spec['debts'])) {
        final nights = [for (final n in list(entry['nights'])) night(n)];
        final upTo = entry['upTo'] as String?;
        expect(
          sleepDebtMinutes(
            nights,
            upTo: upTo == null ? null : HarvestDay.parse(upTo),
          ),
          entry['minutes'],
          reason: entry['why'] as String?,
        );
      }
    });

    test('the average is the same', () {
      final entry = spec['average']! as Map<String, Object?>;
      final nights = [for (final n in list(entry['nights'])) night(n)];
      expect(averageSleep(nights).inMinutes, entry['averageMinutes']);
    });

    test('a cycle is as long here as there', () {
      for (final entry in list(spec['cycles'])) {
        final cycle = decodeCycle(entry['cycle'] as String?);
        expect(
          cycle?.sleep.inMinutes,
          entry['minutes'],
          reason: entry['why'] as String?,
        );
      }
    });

    test("the weekday's own night wins here too", () {
      for (final entry in list(spec['targets'])) {
        final overrides = <int, DailyCycle>{
          for (final item
              in (entry['overrides']! as Map<String, Object?>).entries)
            int.parse(item.key): decodeCycle(item.value! as String)!,
        };
        final targets = SleepTargets(
          cycle: decodeCycle(entry['cycle'] as String?) ?? DailyCycle.fallback,
          overrides: overrides,
        );
        expect(
          targets.targetMinutesFor(HarvestDay.parse(entry['day']! as String)),
          entry['minutes'],
          reason: entry['why'] as String?,
        );
      }
    });
  });

  group('places', () {
    final spec = fixture('places');

    Fix fix(Map<String, Object?> point) => Fix(
      latitude: (point['latitude']! as num).toDouble(),
      longitude: (point['longitude']! as num).toDouble(),
      at: DateTime.parse(point['at']! as String),
    );

    test('metres between two points are the same metres', () {
      for (final entry in list(spec['distances'])) {
        final from = entry['from']! as Map<String, Object?>;
        final to = entry['to']! as Map<String, Object?>;
        expect(
          haversineMetres(
            (from['latitude']! as num).toDouble(),
            (from['longitude']! as num).toDouble(),
            (to['latitude']! as num).toDouble(),
            (to['longitude']! as num).toDouble(),
          ),
          closeTo((entry['metres']! as num).toDouble(), 1),
          reason: entry['why'] as String?,
        );
      }
    });

    test('a trail is as long here as there', () {
      final entry = spec['trail']! as Map<String, Object?>;
      final points = [for (final p in list(entry['points'])) fix(p)];
      expect(
        trailMetres(points),
        closeTo((entry['metres']! as num).toDouble(), 1),
      );
    });

    test('the same runs of points are the same stays', () {
      for (final entry in list(spec['stays'])) {
        final points = [for (final p in list(entry['points'])) fix(p)];
        final places = [
          for (final p in list(entry['places']))
            SavedPlace(
              uuid: p['uuid']! as String,
              name: p['name']! as String,
              latitude: (p['latitude']! as num).toDouble(),
              longitude: (p['longitude']! as num).toDouble(),
              radiusM: ((p['radiusM'] ?? stayRadiusM) as num).toDouble(),
            ),
        ];
        final expected = list(entry['result']);
        final stays = staysIn(points, places: places);
        expect(
          stays,
          hasLength(expected.length),
          reason: entry['why'] as String?,
        );
        for (final (i, stay) in stays.indexed) {
          expect(
            stay.latitude,
            closeTo((expected[i]['latitude']! as num).toDouble(), 0.0001),
          );
          expect(stay.from, DateTime.parse(expected[i]['from']! as String));
          expect(stay.place?.name, expected[i]['place']);
        }
      }
    });
  });

  group('the body', () {
    final spec = fixture('body');

    List<BodyWeight> weights(Object? value) => [
      for (final (i, entry) in list(value).indexed)
        BodyWeight(
          uuid: '$i',
          grams: entry['grams']! as int,
          day: HarvestDay.parse(entry['harvestDay']! as String),
          measuredAt: HarvestDay.parse(
            entry['harvestDay']! as String,
          ).toDateTime().add(Duration(minutes: i)),
        ),
    ];

    test('the chart draws the same points', () {
      for (final entry in list(spec['series'])) {
        final points = weightSeries(
          weights(entry['entries']),
          window: entry['window']! as int,
        );
        final expected = list(entry['points']);
        expect(
          points,
          hasLength(expected.length),
          reason: entry['why'] as String?,
        );
        for (final (i, point) in points.indexed) {
          expect(point.day.key, expected[i]['day']);
          expect(point.entry, expected[i]['entry']);
          expect(point.average, expected[i]['average']);
        }
      }
    });

    test('the trend moves by the same grams', () {
      for (final entry in list(spec['trends'])) {
        final trend = weightTrend(
          weights(entry['entries']),
          days: entry['days']! as int,
          window: entry['window']! as int,
        );
        final expected = entry['trend'] as Map<String, Object?>?;
        if (expected == null) {
          expect(trend, isNull, reason: entry['why'] as String?);
          continue;
        }
        expect(trend?.gramsChanged, expected['gramsChanged']);
        expect(trend?.days, expected['days']);
        expect(trend?.entries, expected['entries']);
      }
    });
  });
}
