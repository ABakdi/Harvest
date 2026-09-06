import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/harvest_fab.dart';
import 'package:harvest/core/ui/widgets/text_prompt.dart';
import 'package:harvest/features/gym/data/exercises_repository.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/presentation/exercise_image.dart';
import 'package:harvest/features/gym/presentation/exercise_picker.dart';
import 'package:harvest/features/gym/presentation/program_seed_card.dart';
import 'package:harvest/features/gym/presentation/target_set_sheet.dart';
import 'package:harvest/features/gym/presentation/training_max_sheet.dart';
import 'package:harvest/features/gym/presentation/weight_text.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Writing a program: days, the exercises in them, and what each asks.
///
/// There is no generator and there never will be. This is a list I fill
/// in — the app's job is to make filling it in fast, which is why
/// duplicating a day is one tap: most days are the last day with two
/// numbers changed.
class ProgramEditor extends ConsumerWidget {
  const ProgramEditor({required this.uuid, super.key});

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final program = ref.watch(programProvider(uuid)).value;
    final maxes = ref.watch(trainingMaxesProvider(uuid)).value ?? const {};

    if (program == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.gymProgramsTitle)),
        body: EmptyState(
          icon: Icons.fitness_center,
          title: l10n.gymProgramGone,
        ),
      );
    }

    final needsMax = program.percentageExercises
        .where((id) => !maxes.containsKey(id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(program.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l10n.gymTrainingMaxes,
            icon: const Icon(Icons.speed_outlined),
            onPressed: () =>
                unawaited(showTrainingMaxes(context, program: program)),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => switch (value) {
              'rename' => unawaited(_rename(context, ref, program)),
              _ => unawaited(_delete(context, ref, program)),
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'rename', child: Text(l10n.gymRename)),
              PopupMenuItem(value: 'delete', child: Text(l10n.deleteAction)),
            ],
          ),
        ],
      ),
      floatingActionButton: HarvestFab(
        onPressed: () => unawaited(_addDay(context, ref, program)),
        label: l10n.gymAddDay,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.md,
          HarvestSpacing.sm,
          HarvestSpacing.md,
          120,
        ),
        children: [
          ProgramSeedCard(program: program),
          // A percentage set with no training max cannot resolve into a
          // weight, so the program says so here rather than showing a
          // blank in the session.
          if (needsMax.isNotEmpty)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: ListTile(
                leading: const Icon(Icons.help_outline),
                title: Text(l10n.gymNeedsTrainingMax(needsMax.length)),
                subtitle: Text(l10n.gymNeedsTrainingMaxBody),
                onTap: () =>
                    unawaited(showTrainingMaxes(context, program: program)),
              ),
            ),
          if (program.days.isEmpty)
            EmptyState(
              icon: Icons.calendar_view_week_outlined,
              title: l10n.gymNoDays,
              body: l10n.gymNoDaysBody,
              color: theme.colorScheme.tertiary,
            )
          else
            for (final day in program.days)
              _DayCard(program: program, day: day, maxes: maxes),
        ],
      ),
    );
  }

  Future<void> _addDay(
    BuildContext context,
    WidgetRef ref,
    Program program,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = await promptForText(
      context,
      title: l10n.gymAddDay,
      initial: l10n.gymDayNumber(program.days.length + 1),
      hint: l10n.gymDayNameHint,
      confirmLabel: l10n.gymAddDay,
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(programsRepositoryProvider).addDay(program.uuid, name: name);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Program program,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = await promptForText(
      context,
      title: l10n.gymRename,
      initial: program.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(programsRepositoryProvider)
        .updateProgram(
          program.uuid,
          name: name,
        );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Program program,
  ) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final ok = await confirm(
      context,
      title: l10n.gymDeleteProgram(program.name),
      body: l10n.gymDeleteProgramBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(programsRepositoryProvider).deleteProgram(program.uuid);
    navigator.pop();
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.program,
    required this.day,
    required this.maxes,
  });

  final Program program;
  final ProgramDay day;
  final Map<String, int> maxes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: HarvestSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l10n.gymDaySummary(day.slots.length, day.totalSets),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => switch (value) {
                    'duplicate' => unawaited(
                      ref.read(programsRepositoryProvider).duplicateDay(day),
                    ),
                    'accessories' => unawaited(_editAccessories(context, ref)),
                    'rename' => unawaited(_rename(context, ref)),
                    _ => unawaited(_remove(context, ref)),
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Text(l10n.gymDuplicateDay),
                    ),
                    PopupMenuItem(
                      value: 'accessories',
                      child: Text(l10n.gymAccessories),
                    ),
                    PopupMenuItem(value: 'rename', child: Text(l10n.gymRename)),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.deleteAction),
                    ),
                  ],
                ),
              ],
            ),
            if ((day.accessories ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: HarvestSpacing.xs),
                child: Text(
                  l10n.gymRecommended(day.accessories!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const Divider(),
            for (final slot in day.slots)
              _SlotRow(slot: slot, trainingMaxGrams: maxes[slot.exerciseId]),
            TextButton.icon(
              onPressed: () => unawaited(_addSlot(context, ref)),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.gymAddExercise),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSlot(BuildContext context, WidgetRef ref) async {
    final exercise = await pickExercise(context);
    if (exercise == null) return;
    await ref
        .read(programsRepositoryProvider)
        .addSlot(day.uuid, exerciseId: exercise.id);
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final name = await promptForText(
      context,
      title: l10n.gymRename,
      initial: day.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(programsRepositoryProvider).updateDay(day.uuid, name: name);
  }

  Future<void> _editAccessories(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final text = await promptForText(
      context,
      title: l10n.gymAccessories,
      initial: day.accessories ?? '',
      hint: l10n.gymAccessoriesHint,
    );
    if (text == null) return;
    await ref
        .read(programsRepositoryProvider)
        .updateDay(day.uuid, accessories: text.trim());
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.gymDeleteDay(day.name),
      body: l10n.gymDeleteDayBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(programsRepositoryProvider).removeDay(day.uuid);
  }
}

class _SlotRow extends ConsumerWidget {
  const _SlotRow({required this.slot, this.trainingMaxGrams});

  final ProgramSlot slot;
  final int? trainingMaxGrams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final exercise = ref.watch(exerciseByIdProvider(slot.exerciseId)).value;
    final resolved = resolveSlot(slot, trainingMaxGrams: trainingMaxGrams);

    return InkWell(
      borderRadius: BorderRadius.circular(HarvestRadii.chip),
      onTap: () => unawaited(showTargetSets(context, slot: slot)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: HarvestSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (exercise != null)
              ExerciseImage(
                exercise: exercise,
                size: 40,
                borderRadius: BorderRadius.circular(HarvestRadii.chip),
              )
            else
              const SizedBox(width: 40, height: 40),
            const SizedBox(width: HarvestSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise?.name ?? l10n.gymUnknownExercise,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (slot.sets.isEmpty)
                    Text(
                      l10n.gymNoSetsYet,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        for (final entry in resolved)
                          Text(
                            targetLabel(context, entry),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: entry.target.openEnded
                                  ? scheme.secondary
                                  : scheme.onSurfaceVariant,
                              fontWeight: entry.target.openEnded
                                  ? FontWeight.w800
                                  : null,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
