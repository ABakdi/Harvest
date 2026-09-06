import 'package:meta/meta.dart';

/// Weights are stored in grams, integer, for the reason money is
/// stored in minor units: a barbell load is not a float.
const gramsPerKg = 1000;

/// What a resolved weight is rounded to.
///
/// A quarter of a kilo: fine enough for micro-plates and dumbbells,
/// coarse enough that nobody is reading `83.7625` off a screen at the
/// squat rack ([[Gym]] rule Y8).
const roundingGrams = 250;

/// What a bar weighs unless told otherwise.
///
/// An Olympic bar is 20 kg, and it is right nearly always. The EZ bar
/// and the Smith machine are not, which is why this is a default and
/// not a constant.
const int defaultBarGrams = 20 * gramsPerKg;

/// Rounds to something that can actually be loaded.
int roundLoad(num grams) => (grams / roundingGrams).round() * roundingGrams;

/// One row of what I am *meant* to do.
///
/// Exactly one of [weightGrams] and [percentTenths] carries the load: a
/// set is either "100 kg × 5" or "75% × 5", never both and never
/// neither.
@immutable
class TargetSet {
  const TargetSet({
    required this.uuid,
    required this.position,
    this.reps,
    this.weightGrams,
    this.percentTenths,
    this.openEnded = false,
  });

  final String uuid;
  final int position;

  /// Null on an open set: as many as I can.
  final int? reps;
  final int? weightGrams;

  /// Percent of the exercise's training max, ×10 — so 82.5% is 825.
  /// Tenths because programmes really do say 82.5%, and a double here
  /// would drift.
  final int? percentTenths;

  /// `1+` / AMRAP. The set that decides whether the weight goes up, so
  /// it is marked rather than inferred.
  final bool openEnded;

  bool get isPercentage => percentTenths != null;

  /// What this set asks for in grams, given the training max it is a
  /// percentage of.
  ///
  /// Null when it is a percentage and no training max has been set —
  /// which is a question to ask, not a zero to load.
  int? resolve({int? trainingMaxGrams}) {
    if (weightGrams != null) return weightGrams;
    if (percentTenths == null) return null;
    if (trainingMaxGrams == null) return null;
    return roundLoad(trainingMaxGrams * percentTenths! / 1000);
  }

  TargetSet copyWith({
    int? position,
    int? reps,
    int? weightGrams,
    int? percentTenths,
    bool? openEnded,
    bool clearReps = false,
    bool clearWeight = false,
    bool clearPercent = false,
  }) => TargetSet(
    uuid: uuid,
    position: position ?? this.position,
    reps: clearReps ? null : reps ?? this.reps,
    weightGrams: clearWeight ? null : weightGrams ?? this.weightGrams,
    percentTenths: clearPercent ? null : percentTenths ?? this.percentTenths,
    openEnded: openEnded ?? this.openEnded,
  );
}

/// One exercise in a day, in order, with what it asks for.
@immutable
class ProgramSlot {
  const ProgramSlot({
    required this.uuid,
    required this.dayUuid,
    required this.exerciseId,
    required this.position,
    this.sets = const [],
    this.restSeconds,
    this.barGrams = defaultBarGrams,
    this.note,
  });

  final String uuid;
  final String dayUuid;

  /// A catalogue id ("0001") or the uuid of one of mine.
  final String exerciseId;
  final int position;
  final List<TargetSet> sets;
  final int? restSeconds;
  final int barGrams;
  final String? note;

  bool get needsTrainingMax => sets.any((set) => set.isPercentage);
}

/// One session's worth: "Week 1 · Day 4", or just "Push".
@immutable
class ProgramDay {
  const ProgramDay({
    required this.uuid,
    required this.programUuid,
    required this.name,
    required this.position,
    this.week,
    this.accessories,
    this.slots = const [],
  });

  final String uuid;
  final String programUuid;
  final String name;
  final int position;
  final int? week;

  /// Free text: "Back, Abs". A note, not a prescription — the app does
  /// not police it.
  final String? accessories;
  final List<ProgramSlot> slots;

  int get totalSets => slots.fold(0, (sum, slot) => sum + slot.sets.length);
}

/// When the picture is asked for.
enum PhotoPrompt {
  after,
  before,
  never;

  static PhotoPrompt fromName(String? name) => PhotoPrompt.values.firstWhere(
    (prompt) => prompt.name == name,
    orElse: () => PhotoPrompt.after,
  );
}

/// A routine I wrote.
@immutable
class Program {
  const Program({
    required this.uuid,
    required this.name,
    this.note,
    this.weeks,
    this.commitmentUuid,
    this.albumUuid,
    this.photoPrompt = PhotoPrompt.after,
    this.days = const [],
  });

  final String uuid;
  final String name;
  final String? note;

  /// Null for a program that is just a list of days; a number for one
  /// that cycles.
  final int? weeks;

  /// The habit this program is: finishing a session checks it in
  /// ([[Gym]] rule Y4).
  final String? commitmentUuid;
  final String? albumUuid;
  final PhotoPrompt photoPrompt;
  final List<ProgramDay> days;

  bool get isSeed => commitmentUuid != null;

  /// Every exercise the program needs a training max for.
  Set<String> get percentageExercises => {
    for (final day in days)
      for (final slot in day.slots)
        if (slot.needsTrainingMax) slot.exerciseId,
  };
}

/// A target set, resolved into what to actually load.
typedef ResolvedSet = ({TargetSet target, int? grams});

/// What a slot asks of me today, with its percentages worked out.
List<ResolvedSet> resolveSlot(ProgramSlot slot, {int? trainingMaxGrams}) => [
  for (final set in slot.sets)
    (target: set, grams: set.resolve(trainingMaxGrams: trainingMaxGrams)),
];
