import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/health/domain/body_weight.dart';

/// The plates a gym actually has, heaviest first, in grams.
///
/// Includes the micro-plates, because the whole reason weights round to
/// 0.25 kg is that some people own 0.25 kg plates. A gym without them
/// simply never gets asked for one.
const defaultPlatesGrams = [
  25000,
  20000,
  15000,
  10000,
  5000,
  2500,
  1250,
  1000,
  500,
  250,
];

/// A pound gym's plates, heaviest first: 45, 35, 25, 10, 5 and 2.5 lb.
final List<int> defaultPlatesGramsLb = [
  for (final pounds in [45, 35, 25, 10, 5, 2.5]) gramsOfPounds(pounds),
];

/// The plates for the unit on screen.
List<int> platesIn(WeightUnit unit) =>
    unit == WeightUnit.lb ? defaultPlatesGramsLb : defaultPlatesGrams;

/// One kind of plate and how many go on each side.
typedef PlateStack = ({int grams, int perSide});

/// What to load, and what it actually comes to.
typedef PlatePlan = ({
  List<PlateStack> stacks,
  int barGrams,

  /// What the plan really weighs. Equal to the target unless the gym
  /// cannot make it.
  int totalGrams,

  /// Grams short of the target — non-zero when the plates run out.
  int shortfallGrams,

  /// Grams the empty bar is over a target lighter than it.
  int overGrams,
});

/// What goes on each side of the bar for [targetGrams].
///
/// Greedy, heaviest first, which is what anybody does in front of a
/// rack: the biggest plate that still fits, then again.
///
/// Two things it refuses to do. It never loads more than asked for, so
/// a target the gym cannot make comes back **short** and says by how
/// much rather than quietly rounding up onto my spine. And it never
/// pretends a target below the bar is achievable — an empty bar is an
/// empty bar, and the plan says how much it is over.
///
/// Pounds count in whole quarter pounds, so a 45 lb plate fits the
/// 45 lb it was asked for however the grams fell ([[Gym]] rule Y8).
PlatePlan platesFor(
  int targetGrams, {
  int barGrams = defaultBarGrams,
  WeightUnit unit = WeightUnit.kg,
  List<int>? plates,
}) {
  final pounds = unit == WeightUnit.lb;
  int step(int grams) => pounds ? quarterPounds(grams) : grams;
  final perSideTarget = (step(targetGrams) - step(barGrams)) / 2;
  if (perSideTarget <= 0) {
    return (
      stacks: const [],
      barGrams: barGrams,
      totalGrams: barGrams,
      shortfallGrams: 0,
      overGrams: perSideTarget < 0 ? barGrams - targetGrams : 0,
    );
  }

  var remaining = perSideTarget;
  var loadedPerSide = 0;
  final stacks = <PlateStack>[];
  for (final plate in plates ?? platesIn(unit)) {
    final count = remaining ~/ step(plate);
    if (count <= 0) continue;
    stacks.add((grams: plate, perSide: count));
    remaining -= count * step(plate);
    loadedPerSide += count * step(plate);
  }

  if (remaining == 0) {
    return (
      stacks: stacks,
      barGrams: barGrams,
      totalGrams: targetGrams,
      shortfallGrams: 0,
      overGrams: 0,
    );
  }
  final total =
      barGrams +
      (pounds ? gramsOfPounds(loadedPerSide / 2) : loadedPerSide * 2);
  return (
    stacks: stacks,
    barGrams: barGrams,
    totalGrams: total,
    shortfallGrams: targetGrams - total,
    overGrams: 0,
  );
}
