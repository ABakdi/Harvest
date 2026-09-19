import 'package:flutter/widgets.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/features/gym/domain/program.dart';
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
String formatLoad(BuildContext context, int grams, WeightUnit unit) =>
    '${formatNumber(context, unit.from(grams), decimals: 2)} '
    '${unitLabel(context, unit)}';

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
