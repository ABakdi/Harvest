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
import 'package:harvest/features/places/presentation/geotag_chip.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Every session I have finished, newest first.
///
/// Read-only on purpose. A finished session is a record of what
/// happened, and I am not in the business of editing what happened
/// three weeks after it did.
class SessionHistoryScreen extends ConsumerStatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  ConsumerState<SessionHistoryScreen> createState() =>
      _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends ConsumerState<SessionHistoryScreen> {
  /// Sessions read so far. It grows a page at a time as the end comes
  /// into view: the history used to stop silently at the newest 50,
  /// about four months of training (Q6-13).
  static const _page = 50;
  int _limit = _page;
  List<WorkoutSession>? _shown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The page before stays on screen while the longer one is read.
    final sessions = _shown =
        ref.watch(finishedSessionsProvider(limit: _limit)).value ?? _shown;
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;
    final more = sessions != null && sessions.length >= _limit;

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
          // Built as they scroll into view, not all at once (P6-14).
          : ListView.builder(
              padding: const EdgeInsets.all(HarvestSpacing.md),
              itemCount: sessions.length + (more ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= sessions.length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _limit <= sessions.length) {
                      setState(() => _limit += _page);
                    }
                  });
                  return const Padding(
                    padding: EdgeInsets.all(HarvestSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return SessionTile(session: sessions[index], unit: unit);
              },
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
          '${l10n.gymSessionSummary(session.doneSets, formatVolume(context, [for (final e in session.exercises) ...e.sets], unit))}',
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
            '${l10n.gymSessionSummary(session.doneSets, formatVolume(context, [for (final e in session.exercises) ...e.sets], unit))}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          // Where the session happened, if Places was there to say.
          const SizedBox(height: HarvestSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GeotagChip(
              targetTable: 'workout_sessions',
              targetUuid: session.uuid,
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
        ref
            .watch(exerciseByIdProvider(exercise.exerciseId))
            .value
            ?.displayName ??
        l10n.gymUnknownExercise;
    // What the day was meant to be stays in the record (Y7): the
    // exercise it replaced, and why one was skipped ([[Audit-v3]] G5-10).
    final planned = exercise.replaced
        ? ref
                  .watch(exerciseByIdProvider(exercise.plannedExerciseId!))
                  .value
                  ?.displayName ??
              l10n.gymUnknownExercise
        : null;
    final done = exercise.sets.where((set) => set.done).toList();
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

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
            if (planned != null) Text(l10n.gymInsteadOf(planned), style: quiet),
            if (exercise.skipped && (exercise.skipReason ?? '').isNotEmpty)
              Text(l10n.gymSkippedBecause(exercise.skipReason!), style: quiet),
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
                        '${formatLoad(context, set.weightGrams, unit)}×${set.reps}',
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
