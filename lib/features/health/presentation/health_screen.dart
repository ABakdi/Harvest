import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/harvest_fab.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/features/health/data/health_repository.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/domain/steps.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/features/health/presentation/weight_chart.dart';
import 'package:harvest/features/health/presentation/weight_sheet.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Steps, weight, and — later — sleep.
///
/// Three numbers with one thing in common: none of them is a target to
/// hit every day, and all of them are a line to look at.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final weights = ref.watch(bodyWeightsProvider).value ?? const <BodyWeight>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navHealth)),
      floatingActionButton: HarvestFab(
        onPressed: () => showWeightSheet(context).ignore(),
        icon: Icons.monitor_weight_outlined,
        label: l10n.weightLog,
      ),
      body: ListView(
        // Clearance for the floating action *and* the switch under
        // the screen, which the tab adds below this list.
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.md,
          HarvestSpacing.sm,
          HarvestSpacing.md,
          120,
        ),
        children: [
          const _StepsCard(),
          SectionHeader(l10n.weightTitle),
          if (weights.isEmpty)
            Card(
              child: EmptyState(
                icon: Icons.monitor_weight_outlined,
                title: l10n.weightEmpty,
                body: l10n.weightEmptyBody,
                compact: true,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            )
          else
            _WeightCard(weights: weights),
          if (weights.isNotEmpty) ...[
            SectionHeader(l10n.weightHistory),
            for (final weight in weights.reversed.take(20))
              _WeightRow(weight: weight),
          ],
        ],
      ),
    );
  }
}

/// Today's steps, and the week around them.
class _StepsCard extends ConsumerWidget {
  const _StepsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(stepsTodayProvider).value;
    final week = ref.watch(recentStepsProvider(7)).value ?? const <StepDay>[];
    final goal = ref.watch(stepGoalProvider).value ?? 0;
    final steps = today?.steps ?? 0;
    final average = averageSteps(week);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  Icons.directions_walk,
                  color: scheme.secondary,
                ),
                const SizedBox(width: HarvestSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.stepsToday,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '$steps',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (average != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.stepsWeekAverage,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '$average',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (goal > 0) ...[
              const SizedBox(height: HarvestSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (steps / goal).clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.stepsOfGoal(steps, goal),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: HarvestSpacing.sm),
            Text(
              l10n.stepsPassive,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chart, the sentence, and the window the sentence reads over.
class _WeightCard extends ConsumerWidget {
  const _WeightCard({required this.weights});

  final List<BodyWeight> weights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;
    final target = ref.watch(targetWeightProvider).value;
    final days = ref.watch(trendDaysProvider).value ?? 30;

    final latest = weights.last;
    final points = weightSeries(weights);
    final trend = weightTrend(weights, days: days);

    String amount(int grams) =>
        '${unit.from(grams.abs()).toStringAsFixed(1)} ${unit.suffix}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  unit.from(latest.grams).toStringAsFixed(1),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    unit.suffix,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formatDay(context, latest.day),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            // Direction, amount, window — and not a word about whether
            // that is good ([[Health]] rule H5).
            Text(
              trend == null
                  ? l10n.weightNoTrendYet
                  : trend.gramsChanged == 0
                  ? l10n.weightSteady(trend.days)
                  : trend.gramsChanged < 0
                  ? l10n.weightDown(amount(trend.gramsChanged), trend.days)
                  : l10n.weightUp(amount(trend.gramsChanged), trend.days),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            if (target != null) ...[
              const SizedBox(height: 2),
              Text(
                l10n.weightToTarget(
                  amount(latest.grams - target),
                  '${unit.from(target).toStringAsFixed(1)} ${unit.suffix}',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: HarvestSpacing.md),
            WeightChart(points: points, unit: unit, targetGrams: target),
            const SizedBox(height: HarvestSpacing.sm),
            WeightChartLegend(
              entriesLabel: l10n.weightLegendEntries,
              trendLabel: l10n.weightLegendTrend,
              targetLabel: target == null ? null : l10n.weightLegendTarget,
            ),
            const Divider(height: HarvestSpacing.lg),
            Row(
              children: [
                Text(
                  l10n.weightWindow,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: HarvestSpacing.sm),
                Expanded(
                  child: Wrap(
                    spacing: HarvestSpacing.xs,
                    children: [
                      for (final window in trendWindows)
                        ChoiceChip(
                          label: Text(l10n.weightDays(window)),
                          selected: days == window,
                          onSelected: (_) => ref
                              .read(trendDaysProvider.notifier)
                              .set(window)
                              .ignore(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightRow extends ConsumerWidget {
  const _WeightRow({required this.weight});

  final BodyWeight weight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;

    return Card(
      margin: const EdgeInsets.only(bottom: HarvestSpacing.xs),
      child: ListTile(
        dense: true,
        title: Text(
          '${unit.from(weight.grams).toStringAsFixed(1)} ${unit.suffix}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          [
            formatDay(context, weight.day),
            formatTime(context, weight.measuredAt),
            if ((weight.note ?? '').isNotEmpty) weight.note!,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => showWeightSheet(context, existing: weight).ignore(),
        trailing: IconButton(
          tooltip: l10n.deleteAction,
          icon: const Icon(Icons.delete_outline),
          onPressed: () => unawaited(_remove(context, ref)),
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(healthRepositoryProvider);
    final ok = await confirm(
      context,
      title: l10n.weightDeleteTitle,
      body: l10n.weightDeleteBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!ok) return;
    await repository.removeWeight(weight.uuid);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.deleted),
        action: SnackBarAction(
          label: l10n.undoAction,
          onPressed: () => repository.restoreWeight(weight.uuid).ignore(),
        ),
      ),
    );
  }
}
