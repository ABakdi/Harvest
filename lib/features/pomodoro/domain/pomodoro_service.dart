import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'pomodoro_service.g.dart';

/// XP paid per completed focus block.
const pomodoroBlockXp = 5;

enum PomodoroPhase { focus, shortBreak, longBreak }

/// Settings keys for the timer lengths (checkpoint gap G2).
abstract final class PomodoroKeys {
  static const focus = 'pomodoro.focusMinutes';
  static const shortBreak = 'pomodoro.shortBreakMinutes';
  static const longBreak = 'pomodoro.longBreakMinutes';
  static const blocksPerLong = 'pomodoro.blocksPerLongBreak';
}

/// Timer lengths, user-adjustable in settings.
class PomodoroConfig {
  const PomodoroConfig({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.blocksPerLongBreak = 4,
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int blocksPerLongBreak;

  Duration of(PomodoroPhase phase) => switch (phase) {
        PomodoroPhase.focus => Duration(minutes: focusMinutes),
        PomodoroPhase.shortBreak => Duration(minutes: shortBreakMinutes),
        PomodoroPhase.longBreak => Duration(minutes: longBreakMinutes),
      };
}

/// The persisted timer snapshot. Time is kept as wall-clock instants,
/// never a ticking counter, so process death cannot corrupt a session.
class PomodoroSnapshot {
  const PomodoroSnapshot({
    required this.sessionUuid,
    required this.phase,
    required this.blocksDone,
    this.commitmentUuid,
    this.endsAt,
    this.pausedRemaining,
    this.userPaused = false,
  }) : assert(
          (endsAt == null) != (pausedRemaining == null),
          'exactly one of endsAt / pausedRemaining must be set',
        );

  factory PomodoroSnapshot.fromJson(Map<String, dynamic> json) =>
      PomodoroSnapshot(
        sessionUuid: json['sessionUuid'] as String,
        phase: PomodoroPhase.values.byName(json['phase'] as String),
        blocksDone: json['blocksDone'] as int,
        commitmentUuid: json['commitmentUuid'] as String?,
        endsAt: json['endsAt'] == null
            ? null
            : DateTime.parse(json['endsAt'] as String),
        pausedRemaining: json['pausedRemaining'] == null
            ? null
            : Duration(seconds: json['pausedRemaining'] as int),
        userPaused: json['userPaused'] as bool? ?? false,
      );


  final String sessionUuid;
  final PomodoroPhase phase;
  final int blocksDone;
  final String? commitmentUuid;

  /// Running: the wall-clock moment this phase completes.
  final DateTime? endsAt;

  /// Paused (or waiting to start the next phase): time left on the clock.
  final Duration? pausedRemaining;

  /// True when the farmer pressed pause (vs. a break running out).
  final bool userPaused;

  bool get isRunning => endsAt != null;

  Duration remaining(DateTime now) => isRunning
      ? endsAt!.difference(now)
      : pausedRemaining!;

  Map<String, dynamic> toJson() => {
        'sessionUuid': sessionUuid,
        'phase': phase.name,
        'blocksDone': blocksDone,
        'commitmentUuid': commitmentUuid,
        'endsAt': endsAt?.toIso8601String(),
        'pausedRemaining': pausedRemaining?.inSeconds,
        'userPaused': userPaused,
      };

  PomodoroSnapshot copyWith({
    PomodoroPhase? phase,
    int? blocksDone,
    DateTime? endsAt,
    Duration? pausedRemaining,
    bool clearEndsAt = false,
    bool clearPausedRemaining = false,
    bool? userPaused,
  }) =>
      PomodoroSnapshot(
        sessionUuid: sessionUuid,
        phase: phase ?? this.phase,
        blocksDone: blocksDone ?? this.blocksDone,
        commitmentUuid: commitmentUuid,
        endsAt: clearEndsAt ? null : endsAt ?? this.endsAt,
        pausedRemaining: clearPausedRemaining
            ? null
            : pausedRemaining ?? this.pausedRemaining,
        userPaused: userPaused ?? this.userPaused,
      );
}

/// Persistence and payout for pomodoro sessions.
class PomodoroService {
  PomodoroService(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();
  static const _activeKey = 'pomodoro.active';

  Future<PomodoroSnapshot?> loadActive() async {
    final row = await (_db.select(_db.kvSettings)
          ..where((s) => s.key.equals(_activeKey)))
        .getSingleOrNull();
    if (row == null) return null;
    final json = jsonDecode(row.valueJson);
    if (json == null) return null;
    return PomodoroSnapshot.fromJson(json as Map<String, dynamic>);
  }

  Future<void> saveActive(PomodoroSnapshot? snapshot) =>
      _db.into(_db.kvSettings).insertOnConflictUpdate(
            KvSettingsCompanion.insert(
              key: _activeKey,
              valueJson: jsonEncode(snapshot?.toJson()),
              updatedAt: Value(DateTime.now()),
            ),
          );

  /// Starts a session: creates the history row and returns the snapshot.
  Future<PomodoroSnapshot> startSession({
    required PomodoroConfig config,
    String? commitmentUuid,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final snapshot = PomodoroSnapshot(
      sessionUuid: _uuid.v4(),
      phase: PomodoroPhase.focus,
      blocksDone: 0,
      commitmentUuid: commitmentUuid,
      endsAt: at.add(config.of(PomodoroPhase.focus)),
    );
    await _db.into(_db.pomodoroSessions).insert(
          PomodoroSessionsCompanion.insert(
            uuid: snapshot.sessionUuid,
            commitmentUuid: Value(commitmentUuid),
            harvestDay: HarvestDay.of(at).key,
            startedAt: at,
          ),
        );
    await saveActive(snapshot);
    return snapshot;
  }

  /// Records one completed focus block: +XP, session row update.
  Future<void> completeBlock(PomodoroSnapshot snapshot, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.pomodoroSessions)
            ..where((p) => p.uuid.equals(snapshot.sessionUuid)))
          .write(
        PomodoroSessionsCompanion(
          focusBlocks: Value(snapshot.blocksDone + 1),
        ),
      );
      await _db.into(_db.ledger).insert(
            LedgerCompanion.insert(
              uuid: _uuid.v4(),
              kind: 'xp',
              delta: pomodoroBlockXp,
              reason: 'pomodoro:${snapshot.sessionUuid}',
              harvestDay: HarvestDay.of(at).key,
            ),
          );
    });
  }

  /// Ends the session (finished or abandoned) and clears the active slot.
  Future<void> endSession(PomodoroSnapshot snapshot, {DateTime? now}) async {
    await (_db.update(_db.pomodoroSessions)
          ..where((p) => p.uuid.equals(snapshot.sessionUuid)))
        .write(
      PomodoroSessionsCompanion(endedAt: Value(now ?? DateTime.now())),
    );
    await saveActive(null);
  }
}

@Riverpod(keepAlive: true)
PomodoroService pomodoroService(Ref ref) =>
    PomodoroService(ref.watch(databaseProvider));

/// The live timer configuration, persisted in settings.
@Riverpod(keepAlive: true)
class PomodoroConfigSetting extends _$PomodoroConfigSetting {
  @override
  Stream<PomodoroConfig> build() {
    int parse(String? raw, int fallback) => int.tryParse(raw ?? '') ?? fallback;
    return ref.watch(settingsRepositoryProvider).watchAll(const [
      PomodoroKeys.focus,
      PomodoroKeys.shortBreak,
      PomodoroKeys.longBreak,
      PomodoroKeys.blocksPerLong,
    ]).map(
      (values) => PomodoroConfig(
        focusMinutes: parse(values[PomodoroKeys.focus], 25),
        shortBreakMinutes: parse(values[PomodoroKeys.shortBreak], 5),
        longBreakMinutes: parse(values[PomodoroKeys.longBreak], 15),
        blocksPerLongBreak: parse(values[PomodoroKeys.blocksPerLong], 4),
      ),
    );
  }

  Future<void> set(String key, int value) =>
      ref.read(settingsRepositoryProvider).setString(key, '$value');
}
