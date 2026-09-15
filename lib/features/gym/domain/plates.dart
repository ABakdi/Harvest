import 'package:harvest/features/gym/domain/program.dart';

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
/// empty bar.
PlatePlan platesFor(
  int targetGrams, {
  int barGrams = defaultBarGrams,
  List<int> plates = defaultPlatesGrams,
}) {
  final perSideTarget = (targetGrams - barGrams) / 2;
  if (perSideTarget <= 0) {
    return (
      stacks: const [],
      barGrams: barGrams,
      totalGrams: barGrams,
      shortfallGrams: targetGrams > barGrams ? targetGrams - barGrams : 0,
    );
  }

  var remaining = perSideTarget;
  final stacks = <PlateStack>[];
  for (final plate in plates) {
    final count = remaining ~/ plate;
    if (count <= 0) continue;
    stacks.add((grams: plate, perSide: count));
    remaining -= count * plate;
  }

  final loadedPerSide = stacks.fold<int>(
    0,
    (sum, stack) => sum + stack.grams * stack.perSide,
  );
  final total = barGrams + loadedPerSide * 2;
  return (
    stacks: stacks,
    barGrams: barGrams,
    totalGrams: total,
    shortfallGrams: targetGrams - total,
  );
}
