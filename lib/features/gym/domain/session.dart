import 'package:harvest/core/domain/harvest_day.dart';
import 'package:meta/meta.dart';

/// One set, as it actually went.
@immutable
class WorkoutSet {
  const WorkoutSet({
    required this.uuid,
    required this.sessionExerciseUuid,
    required this.position,
    required this.weightGrams,
    required this.reps,
    this.done = false,
    this.targetLabel,
    this.openEnded = false,
    this.loggedAt,
  });

  final String uuid;
  final String sessionExerciseUuid;
  final int position;
  final int weightGrams;
  final int reps;

  /// Ticked. An unticked row is what the program asked for, not
  /// something I did.
  final bool done;

  /// What this set was asked to be, kept as text so "did I hit the
  /// target?" is answerable a year later without the program still
  /// existing.
  final String? targetLabel;
  final bool openEnded;
  final DateTime? loggedAt;

  /// Weight × reps. Zero for anything not actually done.
  int get volumeGrams => done ? weightGrams * reps : 0;

  WorkoutSet copyWith({
    int? weightGrams,
    int? reps,
    bool? done,
    int? position,
  }) => WorkoutSet(
    uuid: uuid,
    sessionExerciseUuid: sessionExerciseUuid,
    position: position ?? this.position,
    weightGrams: weightGrams ?? this.weightGrams,
    reps: reps ?? this.reps,
    done: done ?? this.done,
    targetLabel: targetLabel,
    openEnded: openEnded,
    loggedAt: loggedAt,
  );
}

/// One exercise inside a session, as it actually went.
@immutable
class SessionExercise {
  const SessionExercise({
    required this.uuid,
    required this.sessionUuid,
    required this.position,
    required this.exerciseId,
    this.plannedExerciseId,
    this.slotUuid,
    this.skipped = false,
    this.note,
    this.restSeconds,
    this.barGrams = 20000,
    this.sets = const [],
  });

  final String uuid;
  final String sessionUuid;
  final int position;

  /// What I actually did.
  final String exerciseId;

  /// What the program asked for, when that is not the same thing.
  final String? plannedExerciseId;
  final String? slotUuid;
  final bool skipped;
  final String? note;
  final int? restSeconds;
  final int barGrams;
  final List<WorkoutSet> sets;

  /// Swapped for something else mid-session (rule Y7).
  bool get replaced =>
      plannedExerciseId != null && plannedExerciseId != exerciseId;

  int get doneSets => sets.where((set) => set.done).length;
  bool get complete => sets.isNotEmpty && doneSets == sets.length;
}

/// One day of a program, actually done.
@immutable
class WorkoutSession {
  const WorkoutSession({
    required this.uuid,
    required this.day,
    required this.startedAt,
    this.programUuid,
    this.dayUuid,
    this.title,
    this.endedAt,
    this.note,
    this.pausedAt,
    this.pausedSeconds = 0,
    this.exercises = const [],
  });

  final String uuid;
  final String? programUuid;
  final String? dayUuid;

  /// Kept as text so a session survives its program being deleted.
  final String? title;
  final HarvestDay day;
  final DateTime startedAt;

  /// Null while it is still running — which is how an interrupted
  /// workout is found and resumed ([[Gym]] rule Y3).
  final DateTime? endedAt;
  final String? note;

  /// Set while the clock is stopped. A paused session is still the
  /// running one — it just is not counting.
  final DateTime? pausedAt;

  /// The pauses that have already ended, added up.
  final int pausedSeconds;
  final List<SessionExercise> exercises;

  bool get running => endedAt == null;
  bool get paused => running && pausedAt != null;

  /// Time on the clock: from the start to now (or the end, or the
  /// pause), less every pause that finished. A workout that stopped
  /// for a twenty-minute phone call was not twenty minutes longer.
  Duration elapsedAt(DateTime now) {
    final until = endedAt ?? pausedAt ?? now;
    final gross = until.difference(startedAt);
    final net = gross - Duration(seconds: pausedSeconds);
    return net.isNegative ? Duration.zero : net;
  }

  Duration get elapsed => elapsedAt(DateTime.now());

  int get doneSets =>
      exercises.fold(0, (sum, exercise) => sum + exercise.doneSets);

  int get totalSets =>
      exercises.fold(0, (sum, exercise) => sum + exercise.sets.length);

  int get volumeGrams => exercises.fold(
    0,
    (sum, exercise) =>
        sum + exercise.sets.fold(0, (s, set) => s + set.volumeGrams),
  );
}

/// Estimated one-rep max, by **Epley**: `w × (1 + reps ÷ 30)`.
///
/// Labelled as an estimate wherever it appears, with the formula named
/// ([[Gym]] rule Y6). It is a way to compare a heavy triple with a
/// light set of ten; it is not a number I have ever lifted, and the app
/// never presents it as one.
///
/// A single rep estimates to itself, which is the one case where the
/// formula is not a guess at all.
int? estimatedOneRepMax({required int weightGrams, required int reps}) {
  if (weightGrams <= 0 || reps <= 0) return null;
  if (reps == 1) return weightGrams;
  return (weightGrams * (1 + reps / 30)).round();
}

/// The three records worth keeping, per exercise.
typedef ExerciseRecords = ({
  /// The most weight moved for at least one rep.
  WorkoutSet? heaviest,

  /// The highest estimated 1RM from any single set.
  WorkoutSet? bestSet,
  int? bestSetEstimate,

  /// The most weight × reps in one session.
  int bestSessionVolumeGrams,
});

const ExerciseRecords noRecords = (
  heaviest: null,
  bestSet: null,
  bestSetEstimate: null,
  bestSessionVolumeGrams: 0,
);

/// Works the records out from the log.
///
/// Derived, never stored as the only copy, so deleting a set that
/// should not have been there corrects them ([[Gym]] rule Y5).
/// [sessionVolumes] is the volume of each finished session for this
/// exercise, which the caller already has and this cannot recompute
/// from loose sets.
ExerciseRecords recordsFrom(
  Iterable<WorkoutSet> sets, {
  Iterable<int> sessionVolumes = const [],
}) {
  WorkoutSet? heaviest;
  WorkoutSet? bestSet;
  int? bestEstimate;

  for (final set in sets) {
    if (!set.done || set.reps <= 0 || set.weightGrams <= 0) continue;

    if (heaviest == null || set.weightGrams > heaviest.weightGrams) {
      heaviest = set;
    }
    final estimate = estimatedOneRepMax(
      weightGrams: set.weightGrams,
      reps: set.reps,
    );
    if (estimate != null && (bestEstimate == null || estimate > bestEstimate)) {
      bestEstimate = estimate;
      bestSet = set;
    }
  }

  return (
    heaviest: heaviest,
    bestSet: bestSet,
    bestSetEstimate: bestEstimate,
    bestSessionVolumeGrams: sessionVolumes.isEmpty
        ? 0
        : sessionVolumes.reduce((a, b) => a > b ? a : b),
  );
}

/// Which record a set has just beaten, if any.
enum RecordKind { heaviest, estimated }

/// Whether [set] beats [records] — checked the moment it is ticked,
/// because that is the feedback loop the whole feature exists to close.
///
/// Compared against the records *before* this set, so a set cannot beat
/// itself.
List<RecordKind> recordsBeatenBy(WorkoutSet set, ExerciseRecords records) {
  if (!set.done || set.reps <= 0 || set.weightGrams <= 0) return const [];
  final beaten = <RecordKind>[];

  final heaviest = records.heaviest;
  if (heaviest == null || set.weightGrams > heaviest.weightGrams) {
    beaten.add(RecordKind.heaviest);
  }

  final estimate = estimatedOneRepMax(
    weightGrams: set.weightGrams,
    reps: set.reps,
  );
  final best = records.bestSetEstimate;
  if (estimate != null && (best == null || estimate > best)) {
    beaten.add(RecordKind.estimated);
  }
  return beaten;
}
