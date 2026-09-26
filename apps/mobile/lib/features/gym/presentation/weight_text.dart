import 'package:flutter/widgets.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/domain/session.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The unit as it is written in the language on screen: `kg`, `كغ`.
String unitLabel(BuildContext context, WeightUnit unit) {
  final l10n = AppLocalizations.of(context);
  return unit == WeightUnit.kg ? l10n.unitKg : l10n.unitLb;
}

/// Grams as a weight a person reads: `82.5 kg`, `100 kg`.
///
/// Trailing zeros go, because "100.00 kg" is a spreadsheet and "100 kg"
/// is a barbell. The unit is the one chosen for body weight — there is
/// no separate setting for the gym, because nobody weighs themselves in
/// kilos and lifts in pounds. Both the number and the unit are written
/// in the language on screen ([[Audit-v2]] U3-18).
///
/// A pound load reads to its quarter pound, so 60 kg shows as 132.25 lb
/// — the number the target label says — and never 132.28 ([[Gym]] rule
/// Y8).
String formatLoad(BuildContext context, int grams, WeightUnit unit) =>
    '${formatNumber(context, unit.from(shownGrams(grams, unit)), decimals: 2)} '
    '${unitLabel(context, unit)}';

/// A session's volume in the unit on screen, added up from the loads
/// as the rows show them: in pounds each done set's load is rounded to
/// its quarter first, so five sets of 132.25 lb come to 661.25 lb and
/// not the 661.5 lb the stored grams round to ([[Gym]] rule Y8).
double shownVolume(Iterable<WorkoutSet> sets, WeightUnit unit) {
  var total = 0.0;
  for (final set in sets) {
    if (!set.done) continue;
    // Exact quarters, not the grams of one: those read back a hair
    // under (132.2485), and five of them round down to 661.24.
    final load = unit == WeightUnit.lb
        ? quarterPounds(set.weightGrams) / 4
        : unit.from(set.weightGrams);
    total += load * set.reps;
  }
  return total;
}

/// [shownVolume] as text: `661.25 lb`.
String formatVolume(
  BuildContext context,
  Iterable<WorkoutSet> sets,
  WeightUnit unit,
) =>
    '${formatNumber(context, shownVolume(sets, unit), decimals: 2)} '
    '${unitLabel(context, unit)}';

/// The grams a load is shown as: a pound load rounded to its quarter
/// pound by the shared rule ([roundLoad]); kilos as stored, since they
/// were rounded when they were set. One rule with the web's
/// `shownGrams`.
int shownGrams(int grams, WeightUnit unit) =>
    unit == WeightUnit.lb ? roundLoad(grams, unit: unit) : grams;

/// A load as it goes into a field, rounded the way it reads, so the
/// box and the label never disagree: pounds to their quarter, kilos
/// to two places the way a session's label keeps them.
String loadField(int grams, WeightUnit unit) => unit == WeightUnit.lb
    ? loadFieldValue(shownGrams(grams, unit), unit)
    : unit
          .from(grams)
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

/// The same weight, but as it goes into a text field.
///
/// A field is parsed back with [double.tryParse], so what is shown has
/// to be plain digits and a dot whatever the language — and it has to
/// be rounded, because `unit.from(grams)` gives `220.46226218487757`
/// for a hundred kilos in pounds ([[Audit-v2]] U3-19).
String loadFieldValue(int grams, WeightUnit unit) {
  final rounded = (unit.from(grams) * 100).round() / 100;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
}

/// The grams a session's stored label asks for, read in [unit]; null
/// for a label with no load (`95.0%×1+`, `×5`).
///
/// A label keeps kilos to two places, ten grams at worst from the load,
/// so rounding in the unit on screen gives the pounds back exactly
/// ([[Gym]] rule Y8).
int? storedLabelGrams(String label, WeightUnit unit) {
  if (!label.contains('×')) return null;
  final first = label.split('×').first;
  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(first)) return null;
  return roundLoad((double.parse(first) * 1000).round(), unit: unit);
}

/// Percent tenths as a percentage: `82.5%`, `75%`.
String formatPercent(int tenths) {
  final whole = tenths ~/ 10;
  final rest = tenths % 10;
  return rest == 0 ? '$whole%' : '$whole.$rest%';
}

/// What one target set asks for, in the fewest words that are true.
///
/// A percentage that cannot be resolved shows the percentage rather
/// than a blank or a zero: "75% × 5" is a real instruction even before
/// the training max is known, and pretending otherwise would hide the
/// question.
String targetLabel(
  BuildContext context,
  ResolvedSet entry, {
  WeightUnit unit = WeightUnit.kg,
}) {
  final l10n = AppLocalizations.of(context);
  final reps = entry.target.openEnded
      ? l10n.gymOpenReps(entry.target.reps ?? 1)
      : '${entry.target.reps ?? 1}';

  final load = entry.grams != null
      ? formatLoad(context, entry.grams!, unit)
      : entry.target.isPercentage
      ? formatPercent(entry.target.percentTenths!)
      : null;

  return load == null ? '× $reps' : '$load × $reps';
}
