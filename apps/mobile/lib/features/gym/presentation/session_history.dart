import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/features/gym/data/exercises_repository.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/session.dart';
import 'package:harvest/features/gym/presentation/weight_text.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Every session I have finished, newest first.
///
/// Read-only on purpose. A finished session is a record of what
/// happened, and I am not in the business of editing what happened
/// three weeks after it did.
class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(finishedSessionsProvider).value;
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.gymHistory)),
      body: sessions == null
          ? const Center(child: CircularProgressIndicator())
          : sessions.isEmpty
          ? EmptyState(
              icon: Icons.history,
              title: l10n.gymNoHistory,
              body: l10n.gymNoHistoryBody,
            )
          : ListView(
              padding: const EdgeInsets.all(HarvestSpacing.md),
              children: [
                for (final session in sessions)
                  SessionTile(session: session, unit: unit),
              ],
            ),
    );
  }
}

/// One finished session, in a line: what it was, when, and how much.
class SessionTile extends StatelessWidget {
  const SessionTile({required this.session, required this.unit, super.key});

  final WorkoutSession session;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
      child: ListTile(
        leading: IconBadge(Icons.fitness_center, color: scheme.secondary),
        title: Text(
          session.title ?? l10n.gymSession,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${formatDay(context, session.day)} · '
          '${l10n.gymSessionSummary(session.doneSets, formatLoad(session.volumeGrams, unit))}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SessionDetailScreen(uuid: session.uuid),
          ),
        ),
      ),
    );
  }
}

/// A finished session, read back.
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({required this.uuid, super.key});

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = ref.watch(sessionProvider(uuid)).value;
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.gymSession)),
        body: Center(child: Text(l10n.gymSessionGone)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(session.title ?? l10n.gymSession)),
      body: ListView(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        children: [
          Text(
            '${formatDay(context, session.day)} · '
            '${l10n.gymSessionSummary(session.doneSets, formatLoad(session.volumeGrams, unit))}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (session.note case final note? when note.isNotEmpty) ...[
            const SizedBox(height: HarvestSpacing.sm),
            Card(
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(HarvestSpacing.md),
                child: Text(note, style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
          const SizedBox(height: HarvestSpacing.sm),
          for (final exercise in session.exercises)
            _DoneExercise(exercise: exercise, unit: unit),
        ],
      ),
    );
  }
}

class _DoneExercise extends ConsumerWidget {
  const _DoneExercise({required this.exercise, required this.unit});

  final SessionExercise exercise;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name =
        ref.watch(exerciseByIdProvider(exercise.exerciseId)).value?.name ??
        l10n.gymUnknownExercise;
    final done = exercise.sets.where((set) => set.done).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                decoration: exercise.skipped
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            if (done.isEmpty)
              Text(
                l10n.gymNoSetsLogged,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: HarvestSpacing.xs),
                child: Wrap(
                  spacing: HarvestSpacing.sm,
                  runSpacing: HarvestSpacing.xs,
                  children: [
                    for (final set in done)
                      Text(
                        '${formatLoad(set.weightGrams, unit)}×${set.reps}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
            if (exercise.note case final note? when note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: HarvestSpacing.xs),
                child: Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
