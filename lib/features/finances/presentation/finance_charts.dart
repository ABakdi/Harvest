import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/core/ui/widgets/stat_tile.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

enum _Range { week, month }

/// Spending broken down visually (checkpoint gap G9): daily bars and a
/// category donut for the chosen range.
class FinanceInsights extends ConsumerStatefulWidget {
  const FinanceInsights({super.key});

  @override
  ConsumerState<FinanceInsights> createState() => _FinanceInsightsState();
}

class _FinanceInsightsState extends ConsumerState<FinanceInsights> {
  _Range _range = _Range.week;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final symbol =
        (ref.watch(financeSettingsProvider).value?.defaultCurrency ??
                Currency.dzd)
            .symbol;
    final customs = ref.watch(customCategoriesProvider).value ?? const [];

    final dayTotals = _range == _Range.week
        ? ref.watch(weekTotalsProvider)
        : ref.watch(monthTotalsProvider);
    final byCategory = _range == _Range.week
        ? ref.watch(weekByCategoryProvider)
        : ref.watch(monthByCategoryProvider);

    final total = dayTotals.values.fold(0, (a, b) => a + b);
    final elapsedDays = _elapsedDays();
    final average = elapsedDays == 0 ? 0 : total ~/ elapsedDays;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HarvestSpacing.md,
        HarvestSpacing.md,
        HarvestSpacing.md,
        120,
      ),
      children: [
        SegmentedButton<_Range>(
          segments: [
            ButtonSegment(
              value: _Range.week,
              icon: const Icon(Icons.view_week),
              label: Text(l10n.rangeWeek),
            ),
            ButtonSegment(
              value: _Range.month,
              icon: const Icon(Icons.calendar_month),
              label: Text(l10n.rangeMonth),
            ),
          ],
          selected: {_range},
          onSelectionChanged: (selection) =>
              setState(() => _range = selection.first),
        ),
        const SizedBox(height: HarvestSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.payments,
                  color: theme.colorScheme.primary,
                  label: l10n.totalSpent,
                  value: '$symbol${formatGrouped(total)}',
                ),
              ),
              const SizedBox(width: HarvestSpacing.sm),
              Expanded(
                child: StatTile(
                  icon: Icons.today,
                  color: theme.colorScheme.tertiary,
                  label: l10n.avgPerDay(''),
                  value: '$symbol${formatGrouped(average)}',
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
          SectionHeader(_rangeTitle(l10n)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(HarvestSpacing.md),
              child: SizedBox(
                height: 180,
                child: _DailyBars(
                  dayTotals: dayTotals,
                  range: _range,
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
                symbol: symbol,
                customs: customs,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _rangeTitle(AppLocalizations l10n) =>
      _range == _Range.week ? l10n.rangeWeek : l10n.rangeMonth;

  int _elapsedDays() {
    final today = HarvestDay.today();
    return _range == _Range.week
        ? today.weekStart.daysUntil(today) + 1
        : today.day;
  }
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.dayTotals, required this.range});

  final Map<String, int> dayTotals;
  final _Range range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final today = HarvestDay.today();

    final days = <HarvestDay>[];
    if (range == _Range.week) {
      var day = today.weekStart;
      for (var i = 0; i < 7; i++) {
        days.add(day);
        day = day.next;
      }
    } else {
      final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
      for (var i = 1; i <= daysInMonth; i++) {
        days.add(HarvestDay.fromDate(DateTime(today.year, today.month, i)));
      }
    }

    final maxValue = dayTotals.values.isEmpty
        ? 0
        : dayTotals.values.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxValue * 1.2).clamp(1, double.infinity).toDouble(),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                final day = days[index];
                final show =
                    range == _Range.week || day.day == 1 || day.day % 7 == 0;
                if (!show) return const SizedBox.shrink();
                final label = range == _Range.week
                    ? DateFormat.E(locale).format(
                        DateTime(day.year, day.month, day.day),
                      )
                    : '${day.day}';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: const BarTouchData(enabled: false),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (dayTotals[days[i].key] ?? 0).toDouble(),
                  width: range == _Range.week ? 18 : 6,
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

class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({
    required this.byCategory,
    required this.symbol,
    required this.customs,
  });

  final Map<String, int> byCategory;
  final String symbol;
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
          width: 140,
          height: 140,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 34,
              startDegreeOffset: -90,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: palette[i % palette.length],
                    radius: 34,
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
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette[i % palette.length],
                        ),
                      ),
                      const SizedBox(width: HarvestSpacing.sm),
                      Expanded(
                        child: Text(
                          categoryLabel(l10n, entries[i].key),
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '${(entries[i].value * 100 / total).round()}%',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
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
