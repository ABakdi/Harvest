import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/gym/presentation/weight_text.dart';
import 'package:harvest/features/health/data/health_repository.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// One number off the scale.
Future<void> showWeightSheet(
  BuildContext context, {
  BodyWeight? existing,
}) => showHarvestSheet<void>(
  context,
  builder: (_) => _WeightSheet(existing: existing),
);

class _WeightSheet extends ConsumerStatefulWidget {
  const _WeightSheet({this.existing});

  final BodyWeight? existing;

  @override
  ConsumerState<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends ConsumerState<_WeightSheet> {
  final _value = TextEditingController();
  final _note = TextEditingController();
  var _saving = false;
  var _loaded = false;

  /// What the field was filled with, to tell a note-only edit apart
  /// from a new number.
  var _prefilled = '';

  /// The unit it was filled in: the same text under another unit is
  /// another number (the scale said what it said).
  WeightUnit? _prefilledUnit;

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _entered =>
      double.tryParse(_value.text.trim().replaceAll(',', '.'));

  /// A number a person can weigh, in the unit on screen: outside
  /// 20–400 kg it is a typo, and it is refused (W6-15).
  bool _plausible(WeightUnit unit) {
    final entered = _entered;
    return entered != null && isPlausibleBodyWeight(unit.toGrams(entered));
  }

  Future<void> _save(WeightUnit unit) async {
    final entered = _entered;
    if (entered == null || !_plausible(unit) || _saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(healthRepositoryProvider);
    final note = _note.text.trim();
    final existing = widget.existing;
    // A number the field only showed me is not a number I typed: coming
    // back to add a note used to re-save the weight through the field's
    // own rounding, so 82.46 kg became 82.5 ([[Audit-v2]] U3-19). The
    // stored grams stand unless the text changed.
    // Switching the unit re-reads the same text as that unit, so the
    // text alone is not enough: 82.46 read as pounds is a new number,
    // as the web has it ([[Audit-v3]] Q5-42).
    final grams =
        existing != null &&
            _value.text.trim() == _prefilled &&
            unit == _prefilledUnit
        ? existing.grams
        : unit.toGrams(entered);
    try {
      if (existing == null) {
        await repository.logWeight(
          grams: grams,
          note: note.isEmpty ? null : note,
        );
      } else {
        await repository.updateWeight(
          existing.uuid,
          grams: grams,
          note: note.isEmpty ? null : note,
        );
      }
    } on Object {
      // Without this the button spun for the rest of the sheet's life.
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;
    final existing = widget.existing;

    // Prefilled once the unit is known, so the number is in the units
    // the field is labelled with.
    if (!_loaded && existing != null) {
      _loaded = true;
      _prefilled = loadFieldValue(existing.grams, unit);
      _prefilledUnit = unit;
      _value.text = _prefilled;
      _note.text = existing.note ?? '';
    }

    return HarvestSheet(
      title: existing == null ? l10n.weightLog : l10n.weightEdit,
      subtitle: l10n.weightHint,
      actionLabel: l10n.save,
      onAction: _plausible(unit) && !_saving ? () => _save(unit) : null,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _value,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: InputDecoration(
                  labelText: l10n.weightLabel,
                  suffixText: unitLabel(context, unit),
                  errorText: _entered != null && !_plausible(unit)
                      ? l10n.weightImplausible(
                          formatWeightRange(context, unit),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: HarvestSpacing.sm),
            SegmentedButton<WeightUnit>(
              segments: [
                ButtonSegment(value: WeightUnit.kg, label: Text(l10n.unitKg)),
                ButtonSegment(value: WeightUnit.lb, label: Text(l10n.unitLb)),
              ],
              selected: {unit},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                // Changing units re-reads the same number, it does not
                // convert what I typed: the scale said what it said.
                ref
                    .read(weightUnitSettingProvider.notifier)
                    .set(selection.first)
                    .ignore();
              },
            ),
          ],
        ),
        const SizedBox(height: HarvestSpacing.md),
        TextField(
          controller: _note,
          maxLines: 2,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.weightNote,
            hintText: l10n.weightNoteHint,
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
      ],
    );
  }
}

/// The target weight: a line on the chart and a distance from it, set,
/// changed or cleared here ([[Health]], [[Audit-v3]] G5-05).
Future<void> showTargetWeightSheet(BuildContext context) =>
    showHarvestSheet<void>(context, builder: (_) => const _TargetSheet());

class _TargetSheet extends ConsumerStatefulWidget {
  const _TargetSheet();

  @override
  ConsumerState<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends ConsumerState<_TargetSheet> {
  final _value = TextEditingController();
  var _loaded = false;
  var _saving = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  double? get _entered =>
      double.tryParse(_value.text.trim().replaceAll(',', '.'));

  Future<void> _save(int? grams) async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(targetWeightProvider.notifier).set(grams);
    } on Object {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;
    final target = ref.watch(targetWeightProvider).value;
    if (!_loaded && target != null) {
      _loaded = true;
      _value.text = loadFieldValue(target, unit);
    }
    final entered = _entered;
    final valid =
        entered != null && isPlausibleBodyWeight(unit.toGrams(entered));

    return HarvestSheet(
      title: l10n.weightTargetTitle,
      subtitle: l10n.weightTargetHint,
      trailing: target == null
          ? null
          : TextButton(
              onPressed: _saving ? null : () => _save(null),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: Text(l10n.weightTargetClear),
            ),
      actionLabel: l10n.save,
      onAction: valid && !_saving ? () => _save(unit.toGrams(entered)) : null,
      children: [
        TextField(
          controller: _value,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          style: theme.textTheme.headlineSmall,
          decoration: InputDecoration(
            labelText: l10n.weightLegendTarget,
            suffixText: unitLabel(context, unit),
            errorText: entered != null && !valid
                ? l10n.weightImplausible(formatWeightRange(context, unit))
                : null,
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
      ],
    );
  }
}

/// "20–400 kg" or "44–882 lb": the weights the sheet takes, in the unit
/// on screen.
String formatWeightRange(BuildContext context, WeightUnit unit) =>
    '${formatNumber(context, unit.from(minBodyWeightGrams), decimals: 0)}–'
    '${formatNumber(context, unit.from(maxBodyWeightGrams), decimals: 0)} '
    '${unitLabel(context, unit)}';
