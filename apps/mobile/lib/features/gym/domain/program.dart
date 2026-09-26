import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:meta/meta.dart';

/// Weights are stored in grams, integer, for the reason money is
/// stored in minor units: a barbell load is not a float.
const gramsPerKg = 1000;

/// What a resolved weight is rounded to in kilos.
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

/// Pounds as the whole grams that read back as exactly those pounds.
int gramsOfPounds(num pounds) => (pounds * WeightUnit.gramsPerPound).round();

/// Grams as whole quarter pounds, the pound's loadable step.
int quarterPounds(int grams) => (grams / WeightUnit.gramsPerPound * 4).round();

/// The bar a pound gym has: 45 lb, not 20 kg ([[Gym]] rule Y8).
final int defaultBarGramsLb = gramsOfPounds(45);

/// The bars a slot can be told about: EZ, Smith, Olympic, the heavy one.
const barChoicesGrams = [10000, 15000, 20000, 25000];

/// The bars in pounds: the women's and the men's Olympic.
final List<int> barChoicesGramsLb = [gramsOfPounds(35), gramsOfPounds(45)];

/// The bar chips for the unit on screen.
List<int> barChoicesIn(WeightUnit unit) =>
    unit == WeightUnit.lb ? barChoicesGramsLb : barChoicesGrams;

/// The bar a slot really has in [unit]: a slot still on the 20 kg
/// default is the 45 lb bar to someone lifting in pounds; any other bar
/// is the one I set.
int barIn(int barGrams, WeightUnit unit) =>
    unit == WeightUnit.lb && barGrams == defaultBarGrams
    ? defaultBarGramsLb
    : barGrams;

/// The rest to count down when nothing else has been said.
///
/// Two minutes is wrong for curls and wrong for a heavy single, and
/// right often enough that it beats asking before every timer.
const int defaultRestSeconds = 120;

/// The rests worth one tap. Anything else is a number nobody wants to
/// type while holding a bar.
const restChoices = [60, 90, 120, 180, 240, 300];

/// Rounds to something that can actually be loaded: the nearest
/// quarter kilo, or for pounds the nearest quarter pound, kept as the
/// whole grams of that many pounds so 135 lb reads back as 135 and not
/// 135.03 ([[Gym]] rule Y8).
int roundLoad(num grams, {WeightUnit unit = WeightUnit.kg}) =>
    unit == WeightUnit.lb
    ? gramsOfPounds((grams / WeightUnit.gramsPerPound * 4).round() / 4)
    : (grams / roundingGrams).round() * roundingGrams;

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
  /// which is a question to ask, not a zero to load. A percentage is
  /// rounded in the [unit] I lift in.
  int? resolve({int? trainingMaxGrams, WeightUnit unit = WeightUnit.kg}) {
    if (weightGrams != null) return weightGrams;
    if (percentTenths == null) return null;
    if (trainingMaxGrams == null) return null;
    return roundLoad(trainingMaxGrams * percentTenths! / 1000, unit: unit);
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
List<ResolvedSet> resolveSlot(
  ProgramSlot slot, {
  int? trainingMaxGrams,
  WeightUnit unit = WeightUnit.kg,
}) => [
  for (final set in slot.sets)
    (
      target: set,
      grams: set.resolve(trainingMaxGrams: trainingMaxGrams, unit: unit),
    ),
];

/// Where a new row goes: after the highest live position, not at the
/// count. Counting repeats a position once a row has been dropped from
/// the middle — sets 0, 1, 2, drop 1, add, and two rows would claim 2.
int nextPosition(Iterable<int> positions) => positions.fold(
  0,
  (next, position) => position + 1 > next ? position + 1 : next,
);

/// The slot order after dragging the item at [from] to [to], where
/// [to] is its index in the list *after* the move — what
/// `ReorderableListView.onReorderItem` reports.
List<String> reorderedUuids(List<String> uuids, int from, int to) {
  final next = [...uuids];
  final moved = next.removeAt(from);
  next.insert(to, moved);
  return next;
}

/// What a new plain target set starts as: a copy of the last plain set
/// there is — five sets of 100 × 5 is one number typed, not five — or
/// five reps of nothing yet. The open set is never copied; there is
/// one of those.
({int reps, int? weightGrams, int? percentTenths}) nextTargetSet(
  Iterable<TargetSet> sets,
) {
  final last = sets.where((set) => !set.openEnded).lastOrNull;
  return (
    reps: last?.reps ?? 5,
    weightGrams: last?.weightGrams,
    percentTenths: last?.percentTenths,
  );
}
