import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/core/ui/widgets/text_prompt.dart';
import 'package:harvest/features/gym/data/exercises_repository.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/presentation/weight_text.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The numbers a program's percentages are percentages *of*.
///
/// Set by hand and bumped by hand. The app does not calculate a
/// training max from a one-rep max, does not add 2.5 kg because a cycle
/// ended, and does not suggest one: that is programming, and this app
/// records training rather than prescribing it.
Future<void> showTrainingMaxes(
  BuildContext context, {
  required Program program,
}) => showHarvestSheet<void>(
  context,
  builder: (_) => _TrainingMaxSheet(programUuid: program.uuid),
);

class _TrainingMaxSheet extends ConsumerWidget {
  const _TrainingMaxSheet({required this.programUuid});

  final String programUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;
    final program = ref.watch(programProvider(programUuid)).value;
    final maxes = ref.watch(trainingMaxesProvider(programUuid)).value ?? const {};
    final needed = program?.percentageExercises.toList() ?? const <String>[];

    return HarvestSheet(
      title: l10n.gymTrainingMaxes,
      subtitle: l10n.gymTrainingMaxesHint,
      children: [
        if (needed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HarvestSpacing.md),
            child: Text(
              l10n.gymNoPercentSets,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final exerciseId in needed)
            _MaxRow(
              programUuid: programUuid,
              exerciseId: exerciseId,
              grams: maxes[exerciseId],
              unit: unit,
            ),
        const SizedBox(height: HarvestSpacing.sm),
      ],
    );
  }
}

class _MaxRow extends ConsumerWidget {
  const _MaxRow({
    required this.programUuid,
    required this.exerciseId,
    required this.unit,
    this.grams,
  });

  final String programUuid;
  final String exerciseId;
  final WeightUnit unit;
  final int? grams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final exercise = ref.watch(exerciseByIdProvider(exerciseId)).value;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(exercise?.name ?? l10n.gymUnknownExercise),
      subtitle: Text(
        grams == null ? l10n.gymNoTrainingMax : formatLoad(grams!, unit),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: grams == null
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () => unawaited(_edit(context, ref, exercise?.name)),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    String? name,
  ) async {
    final l10n = AppLocalizations.of(context);
    final entered = await promptForText(
      context,
      title: name ?? l10n.gymTrainingMaxes,
      initial: grams == null ? '' : unit.from(grams!).toString(),
      hint: unit.suffix,
    );
    if (entered == null) return;
    final value = double.tryParse(entered.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    await ref
        .read(programsRepositoryProvider)
        .setTrainingMax(
          programUuid: programUuid,
          exerciseId: exerciseId,
          grams: roundLoad(unit.toGrams(value)),
        );
  }
}
