import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/core/ui/widgets/stat_tile.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/field_providers.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/gamification/presentation/gamification_providers.dart';
import 'package:harvest/features/settings/presentation/settings_controllers.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final streak = ref.watch(globalStreakProvider).value;
    final checkIns = ref.watch(checkInCountProvider).value ?? 0;
    final activity = ref.watch(dailyActivityProvider).value ?? const {};
    final goal = ref.watch(dailyGoalSettingProvider).value ?? 3;
    final commitments = ref.watch(activeCommitmentsProvider).value ?? const [];
    final totals = ref.watch(lifetimeTotalsProvider).value ?? const {};
    final streaks = ref.watch(commitmentStreaksProvider).value ?? const {};
    final weekXp = ref.watch(weeklyXpProvider).value ?? 0;
    final weekSpending = ref.watch(weekByCategoryProvider);

    final projects = commitments
        .where((c) => c.type == CommitmentType.project)
        .toList();
    final habits = commitments
        .where((c) => c.type == CommitmentType.habit)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navStats)),
      body: checkIns == 0
          ? _Empty(l10n: l10n, theme: theme)
          : ListView(
              padding: const EdgeInsets.all(HarvestSpacing.md),
              children: [
                StatTileRow(
                  children: [
                    StatTile(
                      icon: Icons.local_fire_department,
                      color: theme.colorScheme.primary,
                      label: l10n.statsBestStreak,
                      value: '${streak?.best ?? 0}',
                    ),
                    StatTile(
                      icon: Icons.check_circle,
                      color: theme.colorScheme.secondary,
                      label: l10n.statsCheckIns,
                      value: '$checkIns',
                    ),
                  ],
                ),
                SectionHeader(l10n.weeklyReport),
                _WeeklyReportCard(
                  weekXp: weekXp,
                  activity: activity,
                  weekSpending: weekSpending,
                ),
                SectionHeader(l10n.statsActivity),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(HarvestSpacing.md),
                    child: _HeatMap(activity: activity, goal: goal),
                  ),
                ),
                if (projects.isNotEmpty) ...[
                  SectionHeader(l10n.statsProjects),
                  for (final project in projects)
                    Card(
                      margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
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
                              borderRadius: BorderRadius.circular(
                                HarvestRadii.chip,
                              ),
                              child: LinearProgressIndicator(
                                value:
                                    ((totals[project.uuid] ?? 0) /
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
                              l10n.projectProgressOf(
                                totals[project.uuid] ?? 0,
                                project.totalTarget ?? 0,
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (habits.isNotEmpty) ...[
                  SectionHeader(l10n.statsHabitStreaks),
                  for (final habit in habits)
                    Card(
                      margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
                      child: ListTile(
                        leading: IconBadge(
                          Icons.local_fire_department,
                          color: (streaks[habit.uuid]?.current ?? 0) > 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.3,
                                ),
                        ),
                        title: Text(habit.title),
                        subtitle: Text(
                          l10n.statsStreakOf(
                            streaks[habit.uuid]?.current ?? 0,
                            streaks[habit.uuid]?.best ?? 0,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onTap: () => unawaited(
                          context.push('${AppRoutes.field}/seed/${habit.uuid}'),
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

/// Six months of daily activity, garden style: the greener the cell,
/// the closer the day came to the Daily Harvest Goal. Month names run
/// along the top; screen readers get the count of active days.
class _HeatMap extends StatelessWidget {
  const _HeatMap({required this.activity, required this.goal});

  final Map<String, int> activity;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = HarvestDay.today();
    final start = today.addDays(-activityWindow.inDays).weekStart;

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

    final locale = Localizations.localeOf(context).toString();
    final activeDays = activity.values.where((n) => n > 0).length;
    final theme = Theme.of(context);

    // Scrolls horizontally; latest weeks are visible first.
    return Semantics(
      label: AppLocalizations.of(context)
          .activitySemantics(activeDays, weeks.length),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var w = 0; w < weeks.length; w++)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 16,
                    width: 17,
                    child: _monthLabel(weeks, w, locale, theme),
                  ),
                  for (final cell in weeks[w])
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
        ),
      ),
    );
  }

  /// The month's short name over the first week that starts in it.
  Widget? _monthLabel(
    List<List<HarvestDay?>> weeks,
    int index,
    String locale,
    ThemeData theme,
  ) {
    final first = weeks[index].first;
    if (first == null) return null;
    final previous = index == 0 ? null : weeks[index - 1].first;
    if (previous != null && previous.month == first.month) return null;
    return Text(
      DateFormat.MMM(locale).format(first.toDateTime()),
      style: theme.textTheme.labelSmall,
      overflow: TextOverflow.visible,
      softWrap: false,
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
      child: EmptyState(
        icon: Icons.insights,
        title: l10n.statsEmptyTitle,
        body: l10n.statsEmptyBody,
        color: theme.colorScheme.tertiary,
      ),
    );
  }
}

/// The Weekly Harvest Report: XP, best and quietest day, top spending.
class _WeeklyReportCard extends StatelessWidget {
  const _WeeklyReportCard({
    required this.weekXp,
    required this.activity,
    required this.weekSpending,
  });

  final int weekXp;
  final Map<String, int> activity;
  final Map<String, int> weekSpending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final today = HarvestDay.today();

    // Actions per elapsed day of this week.
    final counts = <HarvestDay, int>{};
    var day = today.weekStart;
    while (day.compareTo(today) <= 0) {
      counts[day] = activity[day.key] ?? 0;
      day = day.next;
    }
    String weekdayName(HarvestDay d) =>
        DateFormat.EEEE(locale).format(DateTime(d.year, d.month, d.day));
    final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    final worst = counts.entries
        .reduce((a, b) => b.value < a.value ? b : a)
        .key;

    String? topCategory;
    var topAmount = -1;
    weekSpending.forEach((category, amount) {
      if (amount > topAmount) {
        topAmount = amount;
        topCategory = category;
      }
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.tertiary),
                const SizedBox(width: HarvestSpacing.sm),
                Text(
                  l10n.weeklyXp(weekXp),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: HarvestSpacing.sm),
            Text(l10n.weeklyBestDay(weekdayName(best))),
            if (counts.length > 1)
              Text(l10n.weeklyWorstDay(weekdayName(worst))),
            if (topCategory != null)
              Text(
                l10n.weeklyTopSpending(
                  categoryLabel(l10n, topCategory!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
