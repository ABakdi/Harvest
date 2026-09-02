import 'dart:async';

import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/l10n_loader.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/features/pomodoro/domain/pomodoro_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pomodoro_controller.g.dart';

/// Notification id reserved for the ongoing timer.
const _timerNotificationId = 9001;

/// Action ids on the ongoing timer notification.
abstract final class PomodoroActions {
  static const pause = 'pomodoro.pause';
  static const abandon = 'pomodoro.abandon';
}

/// Drives the pomodoro state machine. All timing derives from wall-clock
/// instants persisted by [PomodoroService]; [evaluate] advances the
/// machine across any boundaries that passed while the app was away.
@Riverpod(keepAlive: true)
class PomodoroController extends _$PomodoroController {
  static const config = PomodoroConfig();

  @override
  Future<PomodoroSnapshot?> build() async {
    final snapshot = await ref.watch(pomodoroServiceProvider).loadActive();
    if (snapshot == null) return null;
    final advanced = await _advance(snapshot);
    // A process restart clears the ongoing notification; re-post it for
    // a session that is still running.
    if (advanced == snapshot && advanced.isRunning) {
      await _showOngoing(advanced);
    }
    return advanced;
  }

  PomodoroService get _service => ref.read(pomodoroServiceProvider);

  Future<void> start({String? commitmentUuid}) async {
    final snapshot = await _service.startSession(
      commitmentUuid: commitmentUuid,
      config: config,
    );
    await _showOngoing(snapshot);
    state = AsyncData(snapshot);
  }

  /// Re-checks the clock; called by the screen's ticker and on resume.
  Future<void> evaluate() async {
    final snapshot = state.value;
    if (snapshot == null) return;
    final advanced = await _advance(snapshot);
    if (advanced != snapshot) state = AsyncData(advanced);
  }

  Future<void> pause() async {
    final snapshot = state.value;
    if (snapshot == null || !snapshot.isRunning) return;
    final remaining = snapshot.remaining(DateTime.now());
    final paused = snapshot.copyWith(
      clearEndsAt: true,
      pausedRemaining: remaining.isNegative ? Duration.zero : remaining,
      userPaused: true,
    );
    await _service.saveActive(paused);
    await _cancelOngoing();
    state = AsyncData(paused);
  }

  Future<void> resume() async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isRunning) return;
    final running = snapshot.copyWith(
      endsAt: DateTime.now().add(snapshot.pausedRemaining!),
      clearPausedRemaining: true,
      userPaused: false,
    );
    await _service.saveActive(running);
    await _showOngoing(running);
    state = AsyncData(running);
  }

  /// Ends the session. Returns the commitment to offer a check-in for
  /// when at least one focus block was completed.
  Future<String?> finish() async {
    final snapshot = state.value;
    if (snapshot == null) return null;
    await _service.endSession(snapshot);
    await _cancelOngoing();
    state = const AsyncData(null);
    return snapshot.blocksDone > 0 ? snapshot.commitmentUuid : null;
  }

  /// Abandons mid-focus: no XP for the unfinished block, no guilt.
  Future<void> abandon() async {
    final snapshot = state.value;
    if (snapshot == null) return;
    await _service.endSession(snapshot);
    await _cancelOngoing();
    state = const AsyncData(null);
  }

  /// Walks the snapshot forward over any phase boundaries that have
  /// already passed. Focus completion pays out; breaks auto-run; a
  /// finished break waits (paused) for the next focus to start.
  Future<PomodoroSnapshot> _advance(PomodoroSnapshot snapshot) async {
    var current = snapshot;
    final now = DateTime.now();

    while (current.isRunning && !current.endsAt!.isAfter(now)) {
      final boundary = current.endsAt!;
      switch (current.phase) {
        case PomodoroPhase.focus:
          await _service.completeBlock(current, now: boundary);
          final blocksDone = current.blocksDone + 1;
          final nextPhase = blocksDone % config.blocksPerLongBreak == 0
              ? PomodoroPhase.longBreak
              : PomodoroPhase.shortBreak;
          current = current.copyWith(
            phase: nextPhase,
            blocksDone: blocksDone,
            endsAt: boundary.add(config.of(nextPhase)),
          );
          unawaited(HarvestHaptics.thud());
        case PomodoroPhase.shortBreak:
        case PomodoroPhase.longBreak:
          // Break over: wait for the farmer to start the next block.
          current = current.copyWith(
            phase: PomodoroPhase.focus,
            clearEndsAt: true,
            pausedRemaining: config.of(PomodoroPhase.focus),
          );
      }
    }

    if (current != snapshot) {
      await _service.saveActive(current);
      if (current.isRunning) {
        await _showOngoing(current);
      } else {
        await _cancelOngoing();
      }
    }
    return current;
  }

  Future<void> _showOngoing(PomodoroSnapshot snapshot) async {
    final notifications = ref.read(notificationServiceProvider);
    final l10n = await localizationsFromSettings(ref.read(databaseProvider));
    await notifications.showCountdown(
      id: _timerNotificationId,
      channelId: NotificationChannels.pomodoro,
      title: snapshot.phase == PomodoroPhase.focus
          ? l10n.phaseFocus
          : l10n.phaseShortBreak,
      until: snapshot.endsAt!,
      actions: [
        (PomodoroActions.pause, l10n.pause),
        (PomodoroActions.abandon, l10n.abandonSession),
      ],
    );
  }

  Future<void> _cancelOngoing() =>
      ref.read(notificationServiceProvider).cancel(_timerNotificationId);
}
