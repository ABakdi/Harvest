import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/tokens.dart';
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
        ref.watch(financeSettingsProvider).value?.symbol ?? r'$';
    final customs = ref.watch(customCategoriesProvider).value ?? const [];

    final dayTotals = _range == _Range.week
        ? ref.watch(weekTotalsProvider).value ?? const <String, int>{}
        : ref.watch(monthTotalsProvider).value ?? const <String, int>{};
    final byCategory = _range == _Range.week
        ? ref.watch(weekByCategoryProvider).value ?? const <String, int>{}
        : ref.watch(monthByCategoryProvider).value ?? const <String, int>{};

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
            ButtonSegment(value: _Range.week, label: Text(l10n.rangeWeek)),
            ButtonSegment(value: _Range.month, label: Text(l10n.rangeMonth)),
          ],
          selected: {_range},
          onSelectionChanged: (selection) =>
              setState(() => _range = selection.first),
        ),
        const SizedBox(height: HarvestSpacing.md),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: l10n.totalSpent,
                value: '$symbol${formatMinor(total)}',
              ),
            ),
            const SizedBox(width: HarvestSpacing.sm),
            Expanded(
              child: _StatCard(
                label: l10n.avgPerDay('$symbol${formatMinor(average)}'),
                value: '',
                swap: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: HarvestSpacing.md),
        if (total == 0)
          Padding(
            padding: const EdgeInsets.all(HarvestSpacing.xl),
            child: Text(
              l10n.noSpendingYet,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          )
        else ...[
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
          const SizedBox(height: HarvestSpacing.md),
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

  int _elapsedDays() {
    final today = HarvestDay.today();
    return _range == _Range.week
        ? today.weekStart.daysUntil(today) + 1
        : today.day;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.swap = false,
  });

  final String label;
  final String value;

  /// When true the label carries the value (avg formatting quirk).
  final bool swap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          children: [
            Text(
              swap ? label : value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            if (!swap) ...[
              const SizedBox(height: 2),
              Text(label, style: theme.textTheme.labelMedium),
            ],
          ],
        ),
      ),
    );
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
        days.add(HarvestDay.of(DateTime(today.year, today.month, i, 12)));
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
                final show = range == _Range.week ||
                    day.day == 1 ||
                    day.day % 7 == 0;
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
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
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
