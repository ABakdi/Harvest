import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/data/seed_notes_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/seed_note.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'seed_providers.g.dart';

/// One day in a seed's life: what I logged, and what I wrote about it.
typedef SeedDay = ({HarvestDay day, int quantity, String? note});

@riverpod
Stream<List<Commitment>> archivedCommitments(Ref ref) =>
    ref.watch(commitmentsRepositoryProvider).watchArchived();

@riverpod
Stream<Commitment?> seed(Ref ref, String uuid) =>
    ref.watch(commitmentsRepositoryProvider).watchOne(uuid);

@riverpod
Stream<List<SeedNote>> seedNotes(Ref ref, String uuid) =>
    ref.watch(seedNotesRepositoryProvider).watchFor(uuid);

@riverpod
Stream<List<({HarvestDay day, int quantity, DateTime loggedAt})>> seedHistory(
  Ref ref,
  String uuid,
) => ref.watch(commitmentsRepositoryProvider).watchHistory(uuid);

/// The seed's whole story, newest day first: every day it was watered
/// and every day it was written about, merged into one timeline.
@riverpod
List<SeedDay> seedTimeline(Ref ref, String uuid) {
  final history = ref.watch(seedHistoryProvider(uuid)).value ?? const [];
  final notes = ref.watch(seedNotesProvider(uuid)).value ?? const [];

  final quantities = {for (final entry in history) entry.day: entry.quantity};
  final bodies = {for (final note in notes) note.day: note.body};
  final days = {...quantities.keys, ...bodies.keys}.toList()
    ..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      (day: day, quantity: quantities[day] ?? 0, note: bodies[day]),
  ];
}

/// Consecutive days checked in, counted back from the most recent one —
/// the honest history behind the stored streak, and what the detail
/// screen shows even for a seed the streak engine never judged.
int completedDaysRun(List<HarvestDay> days) {
  if (days.isEmpty) return 0;
  final sorted = [...days]..sort((a, b) => b.compareTo(a));
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i - 1].previous == sorted[i]) {
      run++;
    } else if (sorted[i - 1] != sorted[i]) {
      break;
    }
  }
  return run;
}
