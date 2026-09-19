import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/core/ui/widgets/stat_tile.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/day_range.dart';
import 'package:harvest/features/finances/domain/move_filter.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/finances/presentation/move_filter_bar.dart';
import 'package:harvest/features/finances/presentation/moves_ledger.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Spending, broken down: daily bars with their amounts written on
/// them, a category donut whose slices say what they are worth, and the
/// movements the range actually contains.
///
/// The range used to be week or month; it is now week, month, or any
/// two dates I pick, and everything on the page reads from that one
/// span (checkpoint C4-2).
class FinanceInsights extends ConsumerStatefulWidget {
  const FinanceInsights({super.key});

  @override
  ConsumerState<FinanceInsights> createState() => _FinanceInsightsState();
}

class _FinanceInsightsState extends ConsumerState<FinanceInsights> {
  RangeKind _kind = RangeKind.week;
  DayRange? _custom;
  MoveFilter _filter = MoveFilter.empty;

  DayRange _range(HarvestDay today) => switch (_kind) {
    RangeKind.week => DayRange.week(today),
    RangeKind.month => DayRange.month(today),
    RangeKind.custom => _custom ?? DayRange.week(today),
  };

  Future<void> _pickRange(HarvestDay today) async {
    final now = today.toDateTime();
    final current = _custom;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: current == null
          ? DateTimeRange(start: today.addDays(-13).toDateTime(), end: now)
          : DateTimeRange(
              start: current.from.toDateTime(),
              end: current.to.toDateTime(),
            ),
    );
    if (picked == null) return;
    setState(() {
      _custom = DayRange(
        from: HarvestDay.fromDate(picked.start),
        to: HarvestDay.fromDate(picked.end),
      );
      _kind = RangeKind.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = ref.watch(currentHarvestDayProvider);
    final currency = ref.watch(defaultCurrencyProvider);
    final customs = ref.watch(customCategoriesProvider).value ?? const [];

    final range = _range(today);
    final dayTotals = ref.watch(rangeTotalsProvider(range));
    final byCategory = ref.watch(rangeByCategoryProvider(range));
    final txns =
        ref.watch(rangeTxnsProvider(range)).value ?? const <MoneyTxn>[];
    final shown = _filter.apply(txns);

    final total = dayTotals.values.fold(0, (a, b) => a + b);
    final elapsed = range.elapsedDays(today);
    final average = elapsed == 0 ? 0 : total ~/ elapsed;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HarvestSpacing.md,
        HarvestSpacing.md,
        HarvestSpacing.md,
        120,
      ),
      children: [
        SegmentedButton<RangeKind>(
          segments: [
            ButtonSegment(
              value: RangeKind.week,
              icon: const Icon(Icons.view_week),
              label: Text(l10n.rangeWeek),
            ),
            ButtonSegment(
              value: RangeKind.month,
              icon: const Icon(Icons.calendar_month),
              label: Text(l10n.rangeMonth),
            ),
            ButtonSegment(
              value: RangeKind.custom,
              icon: const Icon(Icons.date_range),
              label: Text(l10n.rangeCustom),
            ),
          ],
          selected: {_kind},
          onSelectionChanged: (selection) {
            final next = selection.first;
            if (next == RangeKind.custom) {
              unawaited(_pickRange(today));
              return;
            }
            setState(() => _kind = next);
          },
        ),
        const SizedBox(height: HarvestSpacing.sm),
        // Whatever the segments say, the dates are spelled out — a
        // custom range with no label is a chart of nothing in particular.
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.rangeOf(
                  formatDay(context, range.from),
                  formatDay(context, range.to),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_kind == RangeKind.custom)
              TextButton.icon(
                onPressed: () => unawaited(_pickRange(today)),
                icon: const Icon(Icons.edit_calendar, size: 18),
                label: Text(l10n.rangePick),
              ),
          ],
        ),
        const SizedBox(height: HarvestSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.payments,
                  color: theme.colorScheme.primary,
                  label: l10n.totalSpent,
                  value: formatAmount(total, currency),
                ),
              ),
              const SizedBox(width: HarvestSpacing.sm),
              Expanded(
                child: StatTile(
                  icon: Icons.today,
                  color: theme.colorScheme.tertiary,
                  label: l10n.avgPerDay(''),
                  value: formatAmount(average, currency),
                ),
              ),
            ],
          ),
        ),
        if (total == 0)
          Padding(
            padding: const EdgeInsets.only(top: HarvestSpacing.md),
            child: Card(
              child: EmptyState(
                icon: Icons.bar_chart,
                title: l10n.noSpendingYet,
                color: theme.colorScheme.tertiary,
                compact: true,
              ),
            ),
          )
        else ...[
          SectionHeader(
            l10n.rangeOf(
              formatDay(context, range.from),
              formatDay(context, range.to),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                HarvestSpacing.md,
                HarvestSpacing.lg,
                HarvestSpacing.md,
                HarvestSpacing.md,
              ),
              child: SizedBox(
                height: 190,
                child: _DailyBars(
                  range: range,
                  dayTotals: dayTotals,
                  currency: currency,
                  today: today,
                ),
              ),
            ),
          ),
          SectionHeader(l10n.statsSpending),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(HarvestSpacing.md),
              child: _CategoryDonut(
                byCategory: byCategory,
                currency: currency,
                customs: customs,
              ),
            ),
          ),
        ],
        SectionHeader(
          l10n.insightsMoves,
          subtitle: l10n.insightsMovesCount(shown.length),
        ),
        MoveFilterBar(
          filter: _filter,
          matches: shown.length,
          total: txns.length,
          onChanged: (filter) => setState(() => _filter = filter),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        if (txns.isNotEmpty && shown.isEmpty)
          Card(
            child: EmptyState(
              icon: Icons.search_off,
              title: l10n.movesNoMatch,
              body: l10n.movesNoMatchBody,
              color: theme.colorScheme.tertiary,
              compact: true,
            ),
          )
        else
          MovesLedger(
            txns: shown,
            rates: ref.watch(ratesOrDefaultProvider),
            emptyTitle: l10n.noMovesYet,
            emptyIcon: Icons.receipt_long_outlined,
            color: theme.colorScheme.tertiary,
          ),
      ],
    );
  }
}

/// Daily bars with the amount written above each one.
///
/// A chart of spending that will not tell you what was spent is a
/// picture, not a report — so short ranges label every bar, and long
/// ones (where labels would collide) label the days that stand out and
/// answer for the rest on a tap.
class _DailyBars extends StatelessWidget {
  const _DailyBars({
    required this.range,
    required this.dayTotals,
    required this.currency,
    required this.today,
  });

  final DayRange range;
  final Map<String, int> dayTotals;
  final Currency currency;
  final HarvestDay today;

  /// Above this many bars, a label on each one is a smear.
  static const _labelLimit = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = localeTag(context);
    final days = range.eachDay;
    final labelEvery = days.length <= _labelLimit;

    final values = [for (final day in days) dayTotals[day.key] ?? 0];
    final maxValue = values.isEmpty
        ? 0
        : values.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxValue * 1.32).clamp(1, double.infinity).toDouble(),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= values.length) {
                  return const SizedBox.shrink();
                }
                final amount = values[index];
                if (amount == 0) return const SizedBox.shrink();
                // On a long range only the peak is written, so the
                // number that matters is still on the page.
                if (!labelEvery && amount != maxValue) {
                  return const SizedBox.shrink();
                }
                return Text(
                  formatAmount(amount, currency),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                final day = days[index];
                final show = labelEvery || day.day == 1 || day.day % 7 == 0;
                if (!show) return const SizedBox.shrink();
                final label = labelEvery
                    ? DateFormat.E(locale).format(day.toDateTime())
                    : '${day.day}';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label, style: theme.textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        // Every bar answers for itself on a tap, however long the range.
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = days[group.x];
              return BarTooltipItem(
                '${formatDay(context, day)}\n'
                '${formatAmount(rod.toY.round(), currency)}',
                theme.textTheme.labelMedium!.copyWith(
                  color: theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i].toDouble(),
                  width: days.length <= 8
                      ? 18
                      : days.length <= 16
                      ? 10
                      : 6,
                  borderRadius: BorderRadius.circular(4),
                  color: days[i] == today
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.55),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The category split, each slice carrying its share **and** what that
/// share is worth. A percentage on its own is half an answer.
class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({
    required this.byCategory,
    required this.currency,
    required this.customs,
  });

  final Map<String, int> byCategory;
  final Currency currency;
  final List<dynamic> customs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0, (a, b) => a + b.value);
    final palette = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.error,
      theme.colorScheme.primary.withValues(alpha: 0.6),
      theme.colorScheme.secondary.withValues(alpha: 0.6),
      theme.colorScheme.tertiary.withValues(alpha: 0.6),
    ];

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 32,
              startDegreeOffset: -90,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: palette[i % palette.length],
                    radius: 32,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: HarvestSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entries.length && i < 6; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette[i % palette.length],
                        ),
                      ),
                      const SizedBox(width: HarvestSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              categoryLabel(l10n, entries[i].key),
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              l10n.shareOfSpending(
                                (entries[i].value * 100 / total).round(),
                                formatAmount(entries[i].value, currency),
                              ),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
