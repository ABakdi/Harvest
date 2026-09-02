import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'field_providers.g.dart';

@riverpod
Stream<List<Commitment>> activeCommitments(Ref ref) =>
    ref.watch(commitmentsRepositoryProvider).watchActive();

@riverpod
Stream<Map<String, int>> loggedToday(Ref ref) => ref
    .watch(commitmentsRepositoryProvider)
    .watchLoggedOn(HarvestDay.today());

@riverpod
Stream<Map<String, int>> lifetimeTotals(Ref ref) =>
    ref.watch(commitmentsRepositoryProvider).watchTotals();

@riverpod
Stream<Map<String, int>> doneDaysThisWeek(Ref ref) => ref
    .watch(commitmentsRepositoryProvider)
    .watchDoneDaysThisWeek(HarvestDay.today());

/// Today's field: every commitment due today, undone first.
@riverpod
List<FieldItem> todayField(Ref ref) {
  final commitments = ref.watch(activeCommitmentsProvider).value ?? const [];
  final logged = ref.watch(loggedTodayProvider).value ?? const {};
  final totals = ref.watch(lifetimeTotalsProvider).value ?? const {};
  final weekDone = ref.watch(doneDaysThisWeekProvider).value ?? const {};
  final today = HarvestDay.today();

  final items = <FieldItem>[];
  for (final commitment in commitments) {
    final loggedNow = logged[commitment.uuid] ?? 0;
    final total = totals[commitment.uuid] ?? 0;
    final item = FieldItem(
      commitment: commitment,
      loggedToday: loggedNow,
      totalLogged: total,
    );

    final visible = switch (commitment.type) {
      CommitmentType.habit => loggedNow > 0 ||
          commitment.schedule!.isDueOn(
            today,
            doneDaysThisWeek: weekDone[commitment.uuid] ?? 0,
          ),
      CommitmentType.project => loggedNow > 0 || !item.projectCompleted,
      CommitmentType.todo => total == 0 ||
          loggedNow > 0, // pending (incl. overdue) or completed today
    };
    if (visible) items.add(item);
  }

  items.sort((a, b) {
    if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
    return a.commitment.createdAt.compareTo(b.commitment.createdAt);
  });
  return items;
}
