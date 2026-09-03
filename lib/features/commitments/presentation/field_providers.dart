import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/due.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'field_providers.g.dart';

@riverpod
Stream<List<Commitment>> activeCommitments(Ref ref) =>
    ref.watch(commitmentsRepositoryProvider).watchActive();

/// Units logged today per commitment — follows the live Harvest Day, so
/// the field turns over at 3 AM without a restart.
@riverpod
Stream<Map<String, int>> loggedToday(Ref ref) => ref
    .watch(commitmentsRepositoryProvider)
    .watchLoggedOn(ref.watch(currentHarvestDayProvider));

@riverpod
Stream<Map<String, int>> lifetimeTotals(Ref ref) =>
    ref.watch(commitmentsRepositoryProvider).watchTotals();

@riverpod
Stream<Map<String, int>> doneDaysThisWeek(Ref ref) => ref
    .watch(commitmentsRepositoryProvider)
    .watchDoneDaysThisWeek(ref.watch(currentHarvestDayProvider));

/// Today's field: every commitment due today, undone first.
@riverpod
List<FieldItem> todayField(Ref ref) {
  final commitments = ref.watch(activeCommitmentsProvider).value ?? const [];
  final logged = ref.watch(loggedTodayProvider).value ?? const {};
  final totals = ref.watch(lifetimeTotalsProvider).value ?? const {};
  final weekDone = ref.watch(doneDaysThisWeekProvider).value ?? const {};
  final today = ref.watch(currentHarvestDayProvider);

  final items = <FieldItem>[];
  for (final commitment in commitments) {
    final loggedNow = logged[commitment.uuid] ?? 0;
    final total = totals[commitment.uuid] ?? 0;
    final item = FieldItem(
      commitment: commitment,
      loggedToday: loggedNow,
      totalLogged: total,
    );

    // Anything watered today stays visible; paused habits rest in view;
    // otherwise the shared due rule decides (future to-dos stay off).
    final visible =
        loggedNow > 0 ||
        commitment.isPaused ||
        isDueOn(
          commitment,
          today,
          doneDaysThisWeek: weekDone[commitment.uuid] ?? 0,
          totalLogged: total,
        );
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
