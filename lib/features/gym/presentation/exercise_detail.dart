import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/gym/data/exercise_media.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/exercise.dart';
import 'package:harvest/features/gym/domain/session.dart';
import 'package:harvest/features/gym/presentation/exercise_image.dart';
import 'package:harvest/features/gym/presentation/weight_text.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// What it is and how it goes: the animation, the muscles, the steps.
Future<void> showExerciseDetail(BuildContext context, Exercise exercise) =>
    showHarvestSheet<void>(
      context,
      builder: (_) => _ExerciseDetail(exercise: exercise),
    );

class _ExerciseDetail extends StatelessWidget {
  const _ExerciseDetail({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return HarvestSheet(
      title: exercise.name,
      subtitle: [
        ?exercise.bodyPart,
        ?exercise.equipment,
      ].join(' · '),
      children: [
        if (exercise.mediaStem != null) ...[
          Center(
            child: ExerciseImage(
              exercise: exercise,
              kind: MediaKind.animation,
              size: 200,
              borderRadius: BorderRadius.circular(HarvestRadii.card),
            ),
          ),
          const SizedBox(height: HarvestSpacing.xs),
          const Center(child: MediaAttribution()),
          const SizedBox(height: HarvestSpacing.md),
        ],
        if (exercise.target != null || exercise.secondary.isNotEmpty) ...[
          Wrap(
            spacing: HarvestSpacing.xs,
            runSpacing: HarvestSpacing.xs,
            children: [
              if (exercise.target != null)
                Chip(
                  avatar: Icon(
                    Icons.center_focus_strong,
                    size: 15,
                    color: scheme.secondary,
                  ),
                  label: Text(exercise.target!),
                ),
              for (final muscle in exercise.secondary)
                Chip(label: Text(muscle)),
            ],
          ),
          const SizedBox(height: HarvestSpacing.md),
        ],
        if (exercise.steps.isEmpty)
          Text(
            l10n.gymNoInstructions,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          for (final (index, step) in exercise.steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: HarvestSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${index + 1}.',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(step, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        const SizedBox(height: HarvestSpacing.md),
        _Records(exerciseId: exercise.id),
        const SizedBox(height: HarvestSpacing.sm),
      ],
    );
  }
}

/// What I have actually done on this exercise.
///
/// Under the instructions rather than above them, because the numbers
/// are why I open this sheet the tenth time and the instructions are
/// why I open it the first.
class _Records extends ConsumerWidget {
  const _Records({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;
    final records =
        ref.watch(exerciseRecordsProvider(exerciseId)).value ?? noRecords;
    final history = ref.watch(exerciseHistoryProvider(exerciseId)).value;

    if (history == null || history.isEmpty) {
      return Text(
        l10n.gymNoRecords,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    final heaviest = records.heaviest;
    final estimate = records.bestSetEstimate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.gymRecords,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: HarvestSpacing.xs),
        Row(
          children: [
            if (heaviest != null)
              Expanded(
                child: _Stat(
                  label: l10n.gymHeaviestLabel,
                  value:
                      '${formatLoad(heaviest.weightGrams, unit)}'
                      '×${heaviest.reps}',
                ),
              ),
            if (estimate != null)
              Expanded(
                child: _Stat(
                  label: l10n.gymEstimatedLabel,
                  value: formatLoad(estimate, unit),
                  hint: l10n.gymEstimatedHint,
                ),
              ),
          ],
        ),
        const SizedBox(height: HarvestSpacing.md),
        Text(
          l10n.gymHistory,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: HarvestSpacing.xs),
        for (final outing in history.take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: HarvestSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    formatDay(context, outing.day),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    [
                      for (final set in outing.sets)
                        '${formatLoad(set.weightGrams, unit)}×${set.reps}',
                    ].join('  '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (outing.bestEstimate != null)
                  Text(
                    formatLoad(outing.bestEstimate!, unit),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.secondary,
          ),
        ),
        if (hint != null)
          Text(
            hint!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
