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
      CommitmentType.habit => commitment.isPaused ||
          loggedNow > 0 ||
          commitment.schedule!.isDueOn(
            today,
            doneDaysThisWeek: weekDone[commitment.uuid] ?? 0,
          ),
      CommitmentType.project => loggedNow > 0 || !item.projectCompleted,
      // Pending and due (today or overdue) — never future-planted
      // (checkpoint P2) — or completed today.
      CommitmentType.todo => loggedNow > 0 ||
          (total == 0 &&
              (commitment.dueDay == null ||
                  commitment.dueDay!.compareTo(today) <= 0)),
    };
    if (visible) items.add(item);
  }

  items.sort((a, b) {
    // Paused crops rest at the bottom, done ones just above them.
    final aRank = a.commitment.isPaused ? 2 : (a.isDone ? 1 : 0);
    final bRank = b.commitment.isPaused ? 2 : (b.isDone ? 1 : 0);
    if (aRank != bRank) return aRank - bRank;
    return a.commitment.createdAt.compareTo(b.commitment.createdAt);
  });
  return items;
}
