/// The activity heat-map: what a day's square counts, over which
/// window, and how it is shaded. The same rule as
/// `packages/core/src/activity.ts`, held to `fixtures/activity.json`, so
/// the phone and the web draw the same map ([[Audit-v3]] G5-11).
library;

import 'dart:math' as math;

import 'package:harvest/core/domain/harvest_day.dart';

/// How many whole weeks the heat-map shows, the current one included.
const activityWeeks = 26;

/// The heat-map's days: whole weeks, Monday to Sunday, the last being
/// [today]'s week.
({HarvestDay start, HarvestDay end}) activityWindow(
  HarvestDay today, {
  int weeks = activityWeeks,
}) {
  final end = today.weekStart.addDays(6);
  return (start: end.addDays(-(weeks * 7 - 1)), end: end);
}

typedef ActivityCheckIn = ({
  String commitmentUuid,
  String harvestDay,
  int quantity,
  bool deleted,
});

typedef ActivitySeed = ({
  String uuid,
  String type,
  int? dailyCommitment,
  bool deleted,
});

typedef ActivityAlbum = ({String uuid, bool scheduled, bool deleted});

typedef ActivityMemory = ({String albumUuid, String harvestDay, bool deleted});

/// Each day's height between [start] and [end]: its productive actions,
/// the count the Daily Harvest Goal is judged by, so a square means what
/// the streak means. A project counts once its daily amount is met; a
/// scheduled album with a picture counts one. A deleted seed or album,
/// and whatever is in the trash, counts nothing; an archived seed's past
/// effort still counts. Days with nothing are left out.
Map<String, int> dayActivity({
  required Iterable<ActivityCheckIn> checkIns,
  required Iterable<ActivitySeed> seeds,
  required HarvestDay start,
  required HarvestDay end,
  Iterable<ActivityAlbum> albums = const [],
  Iterable<ActivityMemory> memories = const [],
}) {
  bool inWindow(String key) =>
      key.compareTo(start.key) >= 0 && key.compareTo(end.key) <= 0;
  final live = {
    for (final seed in seeds)
      if (!seed.deleted) seed.uuid: seed,
  };
  final units = <String, Map<String, int>>{};
  for (final row in checkIns) {
    if (row.deleted || !inWindow(row.harvestDay)) continue;
    final day = units.putIfAbsent(row.harvestDay, () => {});
    day[row.commitmentUuid] = (day[row.commitmentUuid] ?? 0) + row.quantity;
  }
  final scheduled = {
    for (final album in albums)
      if (!album.deleted && album.scheduled) album.uuid,
  };
  final pictured = <String, Set<String>>{};
  for (final memory in memories) {
    if (memory.deleted ||
        !scheduled.contains(memory.albumUuid) ||
        !inWindow(memory.harvestDay)) {
      continue;
    }
    pictured.putIfAbsent(memory.harvestDay, () => {}).add(memory.albumUuid);
  }
  final heights = <String, int>{};
  for (final key in {...units.keys, ...pictured.keys}) {
    var actions = pictured[key]?.length ?? 0;
    for (final MapEntry(key: uuid, value: logged)
        in (units[key] ?? const <String, int>{}).entries) {
      final seed = live[uuid];
      if (seed == null) continue;
      if (seed.type == 'project') {
        final daily = seed.dailyCommitment ?? 0;
        if (daily > 0 && logged >= daily) actions++;
      } else {
        actions++;
      }
    }
    if (actions > 0) heights[key] = actions;
  }
  return heights;
}

/// How strongly a day's square is filled, 0 to 1. A day of the current
/// streak is simply on; a quiet day is off; any other day is faded to
/// how close it came to the goal, kept well short of solid so a busy
/// day off the streak never passes for a streak square.
double activityShade(int actions, int goal, {required bool inStreak}) {
  if (inStreak) return 1;
  if (actions <= 0) return 0;
  return math.min(0.4, math.max(0.2, goal > 0 ? actions / goal : 0.4));
}
