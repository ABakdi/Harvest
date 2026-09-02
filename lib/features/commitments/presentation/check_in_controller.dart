import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'check_in_controller.g.dart';

@Riverpod(keepAlive: true)
class CheckInController extends _$CheckInController {
  @override
  Future<void> build() async {}

  Future<CheckInResult> checkIn(Commitment commitment, {int quantity = 1}) async {
    final result = await ref
        .read(checkInServiceProvider)
        .checkIn(commitment, quantity: quantity);
    if (result is CheckInSuccess) {
      await HarvestHaptics.thud();
      await ref.read(notificationPlannerProvider).reevaluate();
    }
    return result;
  }

  Future<void> undoToday(Commitment commitment) =>
      ref.read(checkInServiceProvider).undoToday(commitment);
}

@Riverpod(keepAlive: true)
class CommitmentEditor extends _$CommitmentEditor {
  @override
  Future<void> build() async {}

  Future<void> createHabit({
    required String title,
    required Schedule schedule,
  }) =>
      ref.read(commitmentsRepositoryProvider).create(
            type: CommitmentType.habit,
            title: title,
            schedule: schedule,
          ).then((_) {});

  Future<void> createProject({
    required String title,
    required int totalTarget,
    required int dailyCommitment,
  }) =>
      ref.read(commitmentsRepositoryProvider).create(
            type: CommitmentType.project,
            title: title,
            totalTarget: totalTarget,
            dailyCommitment: dailyCommitment,
          ).then((_) {});

  Future<void> createTodo({
    required String title,
    required HarvestDay dueDay,
  }) =>
      ref.read(commitmentsRepositoryProvider).create(
            type: CommitmentType.todo,
            title: title,
            dueDay: dueDay,
          ).then((_) {});

  Future<void> archive(String uuid) =>
      ref.read(commitmentsRepositoryProvider).archive(uuid);
}
