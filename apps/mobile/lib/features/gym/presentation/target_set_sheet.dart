import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/gym/data/exercises_repository.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/presentation/rest_field.dart';
import 'package:harvest/features/gym/presentation/weight_text.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// What one exercise in a day asks for: its sets, its rest, its bar.
Future<void> showTargetSets(
  BuildContext context, {
  required ProgramSlot slot,
}) => showHarvestSheet<void>(
  context,
  builder: (_) => _TargetSetSheet(slotUuid: slot.uuid, dayUuid: slot.dayUuid),
);

class _TargetSetSheet extends ConsumerWidget {
  const _TargetSetSheet({required this.slotUuid, required this.dayUuid});

  final String slotUuid;
  final String dayUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;

    // The slot is read out of its program so the sheet redraws as sets
    // are added, rather than holding a snapshot from when it opened.
    final slot = ref
        .watch(programsProvider)
        .value
        ?.expand((program) => program.days)
        .where((day) => day.uuid == dayUuid)
        .expand((day) => day.slots)
        .where((s) => s.uuid == slotUuid)
        .firstOrNull;

    if (slot == null) return const SizedBox.shrink();

    final exercise = ref.watch(exerciseByIdProvider(slot.exerciseId)).value;
    final repository = ref.read(programsRepositoryProvider);

    return HarvestSheet(
      title: exercise?.name ?? l10n.gymUnknownExercise,
      subtitle: l10n.gymSetsSubtitle,
      children: [
        for (final set in slot.sets)
          _SetRow(
            set: set,
            unit: unit,
            onEdit: () => unawaited(_edit(context, ref, set)),
            onRemove: () => unawaited(repository.removeTargetSet(set.uuid)),
          ),
        const SizedBox(height: HarvestSpacing.xs),
        Wrap(
          spacing: HarvestSpacing.xs,
          children: [
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(l10n.gymAddSet),
              onPressed: () => unawaited(
                repository.addTargetSet(slot.uuid, reps: 5),
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.percent, size: 16),
              label: Text(l10n.gymAddPercentSet),
              onPressed: () => unawaited(
                repository.addTargetSet(
                  slot.uuid,
                  reps: 5,
                  percentTenths: 750,
                ),
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.all_inclusive, size: 16),
              label: Text(l10n.gymAddOpenSet),
              onPressed: () => unawaited(
                repository.addTargetSet(
                  slot.uuid,
                  reps: 1,
                  percentTenths: 950,
                  openEnded: true,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: HarvestSpacing.lg),
        // The bar, because an EZ bar and a Smith machine are not 20 kg
        // and the plate calculator has to know — and only where there
        // is a bar: a dumbbell row asked the question with no answer
        // ([[Checkpoint-6]]).
        //
        // Label above, chips below: a row of four chips beside a title
        // leaves the title one letter wide.
        if (exercise?.usesBar ?? false) ...[
          _ChipField(
            icon: Icons.straighten,
            label: l10n.gymBarWeight,
            value: formatLoad(slot.barGrams, unit),
            children: [
              for (final grams in [10000, 15000, 20000, 25000])
                ChoiceChip(
                  label: Text(formatLoad(grams, unit)),
                  selected: slot.barGrams == grams,
                  onSelected: (_) => unawaited(
                    repository.updateSlot(slot.uuid, barGrams: grams),
                  ),
                ),
            ],
          ),
          const SizedBox(height: HarvestSpacing.sm),
        ],
        _ChipField(
          icon: Icons.timer_outlined,
          label: l10n.gymRest,
          value: slot.restSeconds == null
              ? l10n.notSet
              : l10n.gymRestSeconds(slot.restSeconds!),
          children: [
            RestField(
              seconds: slot.restSeconds,
              onChanged: (seconds) => unawaited(
                repository.updateSlot(slot.uuid, restSeconds: seconds),
              ),
            ),
          ],
        ),
        const Divider(height: HarvestSpacing.lg),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              repository.removeSlot(slot.uuid).ignore();
            },
            icon: Icon(Icons.delete_outline, color: scheme.error),
            label: Text(
              l10n.gymRemoveExercise,
              style: TextStyle(color: scheme.error),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    TargetSet set,
  ) => showHarvestSheet<void>(
    context,
    builder: (_) => _EditSet(set: set),
  );
}

/// A labelled row of choices: the label and its current value on one
/// line, the chips wrapping underneath.
class _ChipField extends StatelessWidget {
  const _ChipField({
    required this.icon,
    required this.label,
    required this.value,
    required this.children,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: HarvestSpacing.sm),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: HarvestSpacing.xs),
        Wrap(spacing: HarvestSpacing.xs, children: children),
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.set,
    required this.unit,
    required this.onEdit,
    required this.onRemove,
  });

  final TargetSet set;
  final WeightUnit unit;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = targetLabel(
      context,
      (target: set, grams: set.weightGrams),
      unit: unit,
    );

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: set.openEnded
            ? scheme.secondary
            : scheme.surfaceContainerHighest,
        child: Text(
          // The open set is the one that decides whether the weight
          // goes up, so it gets a letter rather than a number.
          set.openEnded ? 'P' : '${set.position + 1}',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: set.openEnded ? scheme.onSecondary : scheme.onSurface,
          ),
        ),
      ),
      title: Text(label),
      onTap: onEdit,
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        onPressed: onRemove,
      ),
    );
  }
}

class _EditSet extends ConsumerStatefulWidget {
  const _EditSet({required this.set});

  final TargetSet set;

  @override
  ConsumerState<_EditSet> createState() => _EditSetState();
}

class _EditSetState extends ConsumerState<_EditSet> {
  late final TextEditingController _reps = TextEditingController(
    text: widget.set.reps?.toString() ?? '',
  );
  late final TextEditingController _load = TextEditingController(
    text: _initialLoad(),
  );
  late bool _percentage = widget.set.isPercentage;
  late bool _open = widget.set.openEnded;

  String _initialLoad() {
    final set = widget.set;
    if (set.percentTenths != null) return (set.percentTenths! / 10).toString();
    if (set.weightGrams != null) {
      final unit = ref.read(weightUnitSettingProvider).value ?? WeightUnit.kg;
      return unit.from(set.weightGrams!).toString();
    }
    return '';
  }

  @override
  void dispose() {
    _reps.dispose();
    _load.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final unit = ref.read(weightUnitSettingProvider).value ?? WeightUnit.kg;
    final value = double.tryParse(_load.text.trim().replaceAll(',', '.'));
    await ref
        .read(programsRepositoryProvider)
        .updateTargetSet(
          widget.set.uuid,
          reps: int.tryParse(_reps.text.trim()),
          openEnded: _open,
          percentTenths: _percentage && value != null
              ? (value * 10).round()
              : null,
          weightGrams: !_percentage && value != null
              ? roundLoad(unit.toGrams(value))
              : null,
          clearWeight: _percentage,
          clearPercent: !_percentage,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;

    return HarvestSheet(
      title: l10n.gymEditSet,
      actionLabel: l10n.save,
      onAction: _save,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(unit.suffix)),
            ButtonSegment(value: true, label: Text(l10n.gymPercentOfMax)),
          ],
          selected: {_percentage},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _percentage = s.first),
        ),
        const SizedBox(height: HarvestSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _load,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _percentage ? l10n.gymPercent : l10n.gymWeight,
                  suffixText: _percentage ? '%' : unit.suffix,
                ),
              ),
            ),
            const SizedBox(width: HarvestSpacing.sm),
            Expanded(
              child: TextField(
                controller: _reps,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.gymReps),
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.gymOpenSet),
          subtitle: Text(l10n.gymOpenSetHint),
          value: _open,
          onChanged: (value) => setState(() => _open = value),
        ),
        const SizedBox(height: HarvestSpacing.sm),
      ],
    );
  }
}
