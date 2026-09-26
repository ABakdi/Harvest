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
import 'package:harvest/features/commitments/presentation/seed_providers.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/gamification/presentation/gamification_providers.dart';
import 'package:harvest/features/settings/presentation/settings_controllers.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({this.title, this.tabs, super.key});

  /// The title and tabs of the paired screen this is half of, when it
  /// is one ([[Checkpoint-6]]); on its own it names itself.
  final String? title;
  final PreferredSizeWidget? tabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final streak = ref.watch(globalStreakProvider).value;
    final streakDays = ref.watch(streakDaysProvider);
    final checkIns = ref.watch(checkInCountProvider).value ?? 0;
    final activity = ref.watch(dailyActivityProvider).value ?? const {};
    final goal = ref.watch(dailyGoalSettingProvider).value ?? 3;
    final commitments = ref.watch(activeCommitmentsProvider).value ?? const [];
    final totals = ref.watch(lifetimeTotalsProvider).value ?? const {};
    final streaks = ref.watch(commitmentStreaksProvider).value ?? const {};
    final weekXp = ref.watch(weeklyXpProvider).value ?? 0;
    final weekSpending = ref.watch(weekByCategoryProvider);
    final archived = ref.watch(archivedCommitmentsProvider).value ?? const [];
    final since = firstSeedDay(
      [for (final seed in [...commitments, ...archived]) seed.startDay],
      activity.keys,
    );

    final projects = commitments
        .where((c) => c.type == CommitmentType.project)
        .toList();
    final habits = commitments
        .where((c) => c.type == CommitmentType.habit)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? l10n.navStats),
        bottom: tabs,
      ),
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
                  since: since,
                ),
                SectionHeader(
                  l10n.statsActivity,
                  subtitle: l10n.statsStreakSquares(streak?.current ?? 0),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(HarvestSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeatMap(
                          activity: activity,
                          goal: goal,
                          streakDays: streakDays,
                        ),
                        const SizedBox(height: HarvestSpacing.sm),
                        const _HeatMapLegend(),
                      ],
                    ),
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

/// Six months of daily activity, garden style.
///
/// Two things are being said at once, so they are said differently. A
/// day that is **part of the current streak** is solid green — ten days
/// of streak, ten green squares, which is the number the flame is
/// showing. A day that had activity but is not in the run is the same
/// green, faded to how close it came to the Daily Harvest Goal. Month
/// names run along the top; screen readers get both counts.
class _HeatMap extends StatelessWidget {
  const _HeatMap({
    required this.activity,
    required this.goal,
    required this.streakDays,
  });

  final Map<String, int> activity;
  final int goal;
  final Set<HarvestDay> streakDays;

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

    // Scrolls horizontally; latest weeks are visible first. The window
    // is a whole number of week columns wide, so the oldest visible
    // column is never sliced through — a month name sitting on it used
    // to lose its first letters ("ay").
    return Semantics(
      label: AppLocalizations.of(context).activitySemantics(
        activeDays,
        AppLocalizations.of(context).activityLastWeeks(weeks.length),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fit = constraints.maxWidth.isFinite
              ? (constraints.maxWidth / _columnWidth).floor() * _columnWidth
              : null;
          return Align(
            alignment: AlignmentDirectional.centerEnd,
            child: SizedBox(width: fit, child: _weeks(weeks, locale, theme, scheme)),
          );
        },
      ),
    );
  }

  /// One week's column: a 14-point square with 1.5 either side.
  static const double _columnWidth = 17;

  Widget _weeks(
    List<List<HarvestDay?>> weeks,
    String locale,
    ThemeData theme,
    ColorScheme scheme,
  ) => SingleChildScrollView(
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
                    width: _columnWidth,
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
                              : _color(
                                  scheme,
                                  activity[cell.key] ?? 0,
                                  inStreak: streakDays.contains(cell),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      );

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
    // A name is wider than its column and runs on over the next ones;
    // over the newest column there is nothing to run on to, so it
    // ends at the column's end instead of being cut at the edge.
    final last = index >= weeks.length - 1;
    return OverflowBox(
      maxWidth: double.infinity,
      alignment: last
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Text(
        DateFormat.MMM(locale).format(first.toDateTime()),
        style: theme.textTheme.labelSmall,
        softWrap: false,
      ),
    );
  }

  Color _color(ColorScheme scheme, int count, {required bool inStreak}) {
    // The streak is the headline number, so its days are not shaded by
    // how much was done on them: they are simply on.
    if (inStreak) return scheme.secondary;
    if (count == 0) return scheme.onSurface.withValues(alpha: 0.06);
    // Kept well short of solid, so a busy day off the streak never
    // passes for a streak square beside a "No streak running" line.
    final intensity = (count / goal).clamp(0.2, 0.4);
    return scheme.secondary.withValues(alpha: intensity);
  }
}

/// Two greens mean two things; the legend says which.
class _HeatMapLegend extends StatelessWidget {
  const _HeatMapLegend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget swatch(Color color) => Container(
      width: 11,
      height: 11,
      margin: const EdgeInsetsDirectional.only(end: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: color,
      ),
    );

    return DefaultTextStyle.merge(
      style: theme.textTheme.labelSmall!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      child: Wrap(
        spacing: HarvestSpacing.md,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [swatch(scheme.secondary), Text(l10n.legendStreak)],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              swatch(scheme.secondary.withValues(alpha: 0.3)),
              Text(l10n.legendActive),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              swatch(scheme.onSurface.withValues(alpha: 0.06)),
              Text(l10n.legendQuiet),
            ],
          ),
        ],
      ),
    );
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
    required this.since,
  });

  final int weekXp;
  final Map<String, int> activity;
  final Map<String, int> weekSpending;

  /// The first day anything grew: the quietest day is only looked for
  /// from there on.
  final HarvestDay? since;

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
    final worst = quietestDay(counts, since: since);

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
            if (worst != null)
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

/// The first Harvest Day anything grew here: the day the first seed was
/// planted, or an earlier day with a check-in (an import can bring
/// those). Null before the first seed.
@visibleForTesting
HarvestDay? firstSeedDay(
  Iterable<HarvestDay> seedStarts,
  Iterable<String> activeDays,
) {
  HarvestDay? first;
  for (final day in [
    ...seedStarts,
    for (final key in activeDays) ?HarvestDay.tryParse(key),
  ]) {
    if (first == null || day.compareTo(first) < 0) first = day;
  }
  return first;
}

/// The week's quietest elapsed day — only counting days from [since]
/// on, because the days before the first seed were not quiet, they
/// were not yet. The first one wins a tie; null when fewer than two
/// days are left to compare.
@visibleForTesting
HarvestDay? quietestDay(Map<HarvestDay, int> counts, {HarvestDay? since}) {
  final lived = [
    for (final entry in counts.entries)
      if (since == null || entry.key.compareTo(since) >= 0) entry,
  ];
  if (lived.length < 2) return null;
  return lived.reduce((a, b) => b.value < a.value ? b : a).key;
}
