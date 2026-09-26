import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/goals/data/goals_repository.dart';
import 'package:harvest/features/goals/domain/goal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'goals_providers.g.dart';

/// Every goal, board order.
@riverpod
Stream<List<GoalView>> goals(Ref ref) =>
    ref.watch(goalsRepositoryProvider).watchAll();

/// One goal, live; null once deleted.
@riverpod
Stream<GoalView?> goal(Ref ref, String uuid) =>
    ref.watch(goalsRepositoryProvider).watchOne(uuid);

/// The seeds a goal's card and screen show under Seeds.
@riverpod
Stream<List<Commitment>> goalSeeds(Ref ref, String goalUuid) =>
    ref.watch(commitmentsRepositoryProvider).watchForGoal(goalUuid);
