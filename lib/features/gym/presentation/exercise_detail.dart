import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/gym/data/exercise_media.dart';
import 'package:harvest/features/gym/domain/exercise.dart';
import 'package:harvest/features/gym/presentation/exercise_image.dart';
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
        const SizedBox(height: HarvestSpacing.sm),
      ],
    );
  }
}
