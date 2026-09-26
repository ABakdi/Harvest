import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/gauge_ring.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/goals/data/goals_repository.dart';
import 'package:harvest/features/goals/domain/goal.dart';
import 'package:harvest/features/goals/presentation/goals_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The Goals half of the field ([[Goals]]): one card per active goal in
/// my order, then what I achieved and what I let go, folded away.
class GoalsBoard extends ConsumerWidget {
  const GoalsBoard({this.bottomPadding = 96, super.key});

  /// Room under the list for the floating button.
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(goalsProvider).value;
    if (all == null) return const SizedBox.shrink();

    final active = [
      for (final v in all)
        if (v.goal.isActive) v,
    ];
    final achieved = [
      for (final v in all)
        if (v.goal.status == GoalStatus.achieved) v,
    ];
    final dropped = [
      for (final v in all)
        if (v.goal.status == GoalStatus.dropped) v,
    ];

    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.flag_outlined,
        title: l10n.goalsEmptyTitle,
        body: l10n.goalsEmptyBody,
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            HarvestSpacing.md,
            HarvestSpacing.md,
            HarvestSpacing.md,
            0,
          ),
          sliver: SliverReorderableList(
            itemCount: active.length,
            onReorderItem: (from, to) {
              final uuids = [for (final v in active) v.goal.uuid];
              final moved = uuids.removeAt(from);
              uuids.insert(to, moved);
              unawaited(ref.read(goalsRepositoryProvider).reorder(uuids));
            },
            itemBuilder: (context, i) {
              final view = active[i];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(view.goal.uuid),
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: HarvestSpacing.sm),
                  child: GoalCard(view: view),
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            HarvestSpacing.md,
            0,
            HarvestSpacing.md,
            bottomPadding,
          ),
          sliver: SliverList.list(
            children: [
              if (achieved.isNotEmpty)
                _Folded(title: l10n.goalAchievedSection, goals: achieved),
              if (dropped.isNotEmpty)
                _Folded(title: l10n.goalDroppedSection, goals: dropped),
            ],
          ),
        ),
      ],
    );
  }
}

class _Folded extends StatelessWidget {
  const _Folded({required this.title, required this.goals});

  final String title;
  final List<GoalView> goals;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text('$title · ${goals.length}'),
    children: [
      for (final view in goals)
        Padding(
          padding: const EdgeInsets.only(bottom: HarvestSpacing.sm),
          child: GoalCard(view: view),
        ),
    ],
  );
}

/// One goal on the board: its title and deadline, how far along it is,
/// what to do next, and the seeds working on it.
class GoalCard extends ConsumerWidget {
  const GoalCard({required this.view, super.key});

  final GoalView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final goal = view.goal;
    final today = ref.watch(currentHarvestDayProvider);
    final seeds = ref.watch(goalSeedsProvider(goal.uuid)).value ?? const [];
    final progress = view.progress;
    final left = goal.daysLeft(today);
    final next = view.next;
    final muted = !goal.isActive;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(context.push('${AppRoutes.goal}/${goal.uuid}')),
        child: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (progress != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: HarvestSpacing.md,
                  ),
                  child: GaugeRing(
                    progress: progress,
                    color: muted ? scheme.outline : scheme.primary,
                    size: 52,
                    strokeWidth: 6,
                    semanticsLabel: '${(progress * 100).round()}%',
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: muted ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                    if (left != null && goal.isActive)
                      Text(
                        left >= 0
                            ? l10n.goalDaysLeft(left)
                            : l10n.goalDaysPast(-left),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: left < 0 ? scheme.error : scheme.primary,
                        ),
                      ),
                    const SizedBox(height: HarvestSpacing.xs),
                    if (progress == null && goal.isActive)
                      Text(
                        l10n.goalAddWhatItTakes,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else if (next != null && goal.isActive)
                      Text(
                        l10n.goalNext(next.body),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      )
                    else if (view.complete && goal.isActive)
                      Text(
                        l10n.goalComplete,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    if (seeds.isNotEmpty) ...[
                      const SizedBox(height: HarvestSpacing.sm),
                      Wrap(
                        spacing: HarvestSpacing.xs,
                        runSpacing: HarvestSpacing.xs,
                        children: [
                          for (final seed in seeds) SeedChip(seed: seed),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A seed serving a goal, small: its kind and its name, dimmed once it
/// is archived (GL5).
class SeedChip extends StatelessWidget {
  const SeedChip({required this.seed, super.key});

  final Commitment seed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (seed.type) {
      CommitmentType.habit => Icons.repeat,
      CommitmentType.project => Icons.flag,
      CommitmentType.todo => Icons.check,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(
        seed.isArchived
            ? '${seed.title} · ${l10n.goalSeedArchived}'
            : seed.title,
      ),
      labelStyle: seed.isArchived
          ? TextStyle(color: scheme.onSurfaceVariant)
          : null,
    );
  }
}
