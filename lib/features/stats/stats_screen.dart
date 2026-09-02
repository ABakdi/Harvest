import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/field_providers.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/gamification/data/gamification_repository.dart';
import 'package:harvest/features/settings/presentation/settings_controllers.dart';
import 'package:harvest/l10n/app_localizations.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final xp = ref.watch(xpTotalProvider).value ?? 0;
    final streak = ref.watch(globalStreakProvider).value;
    final checkIns = ref.watch(checkInCountProvider).value ?? 0;
    final activity = ref.watch(dailyActivityProvider).value ?? const {};
    final goal = ref.watch(dailyGoalSettingProvider).value ?? 3;
    final commitments =
        ref.watch(activeCommitmentsProvider).value ?? const [];
    final totals = ref.watch(lifetimeTotalsProvider).value ?? const {};
    final streaks = ref.watch(commitmentStreaksProvider).value ?? const {};
    final spending = ref.watch(monthByCategoryProvider).value ?? const {};
    final symbol =
        ref.watch(financeSettingsProvider).value?.symbol ?? r'$';

    final projects = commitments
        .where((c) => c.type == CommitmentType.project)
        .toList();
    final habits =
        commitments.where((c) => c.type == CommitmentType.habit).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navStats)),
      body: checkIns == 0
          ? _Empty(l10n: l10n, theme: theme)
          : ListView(
              padding: const EdgeInsets.all(HarvestSpacing.md),
              children: [
                Row(
                  children: [
                    _StatTile(label: l10n.statsLifetimeXp, value: '$xp'),
                    const SizedBox(width: HarvestSpacing.sm),
                    _StatTile(
                      label: l10n.statsBestStreak,
                      value: '${streak?.best ?? 0}',
                    ),
                    const SizedBox(width: HarvestSpacing.sm),
                    _StatTile(label: l10n.statsCheckIns, value: '$checkIns'),
                  ],
                ),
                const SizedBox(height: HarvestSpacing.lg),
                _SectionTitle(l10n.statsActivity),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(HarvestSpacing.md),
                    child: _HeatMap(activity: activity, goal: goal),
                  ),
                ),
                if (projects.isNotEmpty) ...[
                  const SizedBox(height: HarvestSpacing.lg),
                  _SectionTitle(l10n.statsProjects),
                  for (final project in projects)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(HarvestSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: HarvestSpacing.sm),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(HarvestRadii.chip),
                              child: LinearProgressIndicator(
                                value: ((totals[project.uuid] ?? 0) /
                                        (project.totalTarget ?? 1))
                                    .clamp(0, 1)
                                    .toDouble(),
                                minHeight: 10,
                                backgroundColor: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.08),
                              ),
                            ),
                            const SizedBox(height: HarvestSpacing.xs),
                            Text(
                              l10n.projectSubtitle(
                                totals[project.uuid] ?? 0,
                                project.totalTarget ?? 0,
                                0,
                                project.dailyCommitment ?? 0,
                              ).split('·').first.trim(),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (spending.isNotEmpty) ...[
                  const SizedBox(height: HarvestSpacing.lg),
                  _SectionTitle(l10n.statsSpending),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(HarvestSpacing.md),
                      child: _SpendingBreakdown(
                        spending: spending,
                        symbol: symbol,
                      ),
                    ),
                  ),
                ],
                if (habits.isNotEmpty) ...[
                  const SizedBox(height: HarvestSpacing.lg),
                  _SectionTitle(l10n.statsHabitStreaks),
                  for (final habit in habits)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.local_fire_department,
                          color: (streaks[habit.uuid]?.current ?? 0) > 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                        ),
                        title: Text(habit.title),
                        subtitle: Text(
                          l10n.statsStreakOf(
                            streaks[habit.uuid]?.current ?? 0,
                            streaks[habit.uuid]?.best ?? 0,
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 96),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: HarvestSpacing.sm),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.md),
          child: Column(
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ten weeks of daily activity, GitHub-garden style: the greener the
/// cell, the closer the day came to the Daily Harvest Goal.
class _HeatMap extends StatelessWidget {
  const _HeatMap({required this.activity, required this.goal});

  final Map<String, int> activity;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = HarvestDay.today();
    final start = HarvestDay.of(
      DateTime.now().subtract(const Duration(days: 69)),
    ).weekStart;

    final weeks = <List<HarvestDay?>>[];
    var day = start;
    while (day.compareTo(today) <= 0) {
      final week = <HarvestDay?>[];
      for (var i = 0; i < 7; i++) {
        week.add(day.compareTo(today) <= 0 ? day : null);
        day = day.next;
      }
      weeks.add(week);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final week in weeks)
          Column(
            children: [
              for (final cell in week)
                Padding(
                  padding: const EdgeInsets.all(1.5),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: cell == null
                          ? Colors.transparent
                          : _color(scheme, activity[cell.key] ?? 0),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Color _color(ColorScheme scheme, int count) {
    if (count == 0) return scheme.onSurface.withValues(alpha: 0.06);
    final intensity = (count / goal).clamp(0.25, 1.0);
    return scheme.secondary.withValues(alpha: intensity);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.l10n, required this.theme});

  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights, size: 96, color: theme.colorScheme.tertiary),
            const SizedBox(height: HarvestSpacing.lg),
            Text(
              l10n.statsEmptyTitle,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HarvestSpacing.sm),
            Text(
              l10n.statsEmptyBody,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


/// Month-to-date spending per category, biggest first.
class _SpendingBreakdown extends StatelessWidget {
  const _SpendingBreakdown({required this.spending, required this.symbol});

  final Map<ExpenseCategory, int> spending;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entries = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.first.value;

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HarvestSpacing.xs),
            child: Row(
              children: [
                Icon(
                  categoryIcon(entry.key),
                  size: 20,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: HarvestSpacing.sm),
                SizedBox(
                  width: 88,
                  child: Text(
                    categoryLabel(l10n, entry.key),
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(HarvestRadii.chip),
                    child: LinearProgressIndicator(
                      value: entry.value / max,
                      minHeight: 8,
                      backgroundColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: HarvestSpacing.sm),
                Text(
                  '$symbol${formatMinor(entry.value)}',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
