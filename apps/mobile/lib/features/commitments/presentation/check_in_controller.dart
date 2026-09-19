import 'dart:async';

import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/widget/domain/widget_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'check_in_controller.g.dart';

/// Check-ins from the UI. The state is the in-flight write: the field
/// disables taps while it is loading and shows the error when it fails.
@Riverpod(keepAlive: true)
class CheckInController extends _$CheckInController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  bool get isBusy => state.isLoading;

  Future<CheckInResult?> checkIn(Commitment commitment, {int quantity = 1}) =>
      _guard(() async {
        final result = await ref
            .read(checkInServiceProvider)
            .checkIn(commitment, quantity: quantity);
        if (result is CheckInSuccess) {
          unawaited(HarvestHaptics.thud());
          // The celebration must not wait for the planner's bookkeeping.
          unawaited(_replan());
        }
        return result;
      });

  Future<void> undoToday(Commitment commitment) => _guard(() async {
    await ref.read(checkInServiceProvider).undoToday(commitment);
    unawaited(_replan());
  });

  Future<void> _replan() async {
    try {
      await ref.read(notificationPlannerProvider).reevaluate();
      await ref.read(widgetServiceProvider).refresh();
    } on Object catch (_) {
      // Reminders and the widget are best-effort; the check-in itself
      // already landed.
    }
  }

  Future<T?> _guard<T>(Future<T> Function() run) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(run);
    state = result.hasError
        ? AsyncError(result.error!, result.stackTrace!)
        : const AsyncData(null);
    return result.value;
  }
}

/// Creates, edits, pauses and archives seeds. Every write replans the
/// reminders; a newly set reminder time asks the OS once for permission.
@Riverpod(keepAlive: true)
class CommitmentEditor extends _$CommitmentEditor {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> _afterWrite({String? remindAt, String? previousRemindAt}) async {
    if (remindAt != null && previousRemindAt == null) {
      final notifications = ref.read(notificationServiceProvider);
      if (!await notifications.canScheduleExact()) {
        await notifications.requestPermissionStatus();
      } else {
        await notifications.requestPermission();
      }
    }
    await ref.read(notificationPlannerProvider).reevaluate();
    await ref.read(widgetServiceProvider).refresh();
  }

  Future<void> _write(Future<void> Function() run) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(run);
    if (state case AsyncError(:final error, :final stackTrace)) {
      state = const AsyncData(null);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> createHabit({
    required String title,
    required Schedule schedule,
    String? note,
    String? remindAt,
  }) => _write(() async {
    await ref
        .read(commitmentsRepositoryProvider)
        .create(
          type: CommitmentType.habit,
          title: title,
          schedule: schedule,
          note: note,
          remindAt: remindAt,
        );
    await _afterWrite(remindAt: remindAt);
  });

  Future<void> createProject({
    required String title,
    required int totalTarget,
    required int dailyCommitment,
    String? note,
    String? remindAt,
    HarvestDay? deadline,
  }) => _write(() async {
    await ref
        .read(commitmentsRepositoryProvider)
        .create(
          type: CommitmentType.project,
          title: title,
          totalTarget: totalTarget,
          dailyCommitment: dailyCommitment,
          note: note,
          remindAt: remindAt,
          deadline: deadline,
        );
    await _afterWrite(remindAt: remindAt);
  });

  Future<void> createTodo({
    required String title,
    required HarvestDay dueDay,
    String? note,
    String? remindAt,
  }) => _write(() async {
    await ref
        .read(commitmentsRepositoryProvider)
        .create(
          type: CommitmentType.todo,
          title: title,
          dueDay: dueDay,
          note: note,
          remindAt: remindAt,
        );
    await _afterWrite(remindAt: remindAt);
  });

  Future<void> archive(String uuid, {String? note}) => _write(() async {
    await ref.read(commitmentsRepositoryProvider).archive(uuid, note: note);
    await _afterWrite();
  });

  Future<void> restore(String uuid) => _write(() async {
    await ref.read(commitmentsRepositoryProvider).restore(uuid);
    await _afterWrite();
  });

  /// The mistake path: the seed and everything it ever wrote, gone.
  /// Confirmed in the UI first — there is no undo behind this one.
  Future<void> hardDelete(String uuid) => _write(() async {
    await ref.read(commitmentsRepositoryProvider).hardDelete(uuid);
    await _afterWrite();
  });

  Future<void> updateCommitment(
    Commitment commitment, {
    String? previousRemindAt,
  }) => _write(() async {
    await ref.read(commitmentsRepositoryProvider).update(commitment);
    await _afterWrite(
      remindAt: commitment.remindAt,
      previousRemindAt: previousRemindAt,
    );
  });

  Future<void> setPaused(String uuid, {required bool paused}) =>
      _write(() async {
        await ref
            .read(commitmentsRepositoryProvider)
            .setPaused(uuid, paused: paused);
        await _afterWrite();
      });
}
