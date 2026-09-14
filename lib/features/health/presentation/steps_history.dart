import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/domain/steps.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// The last month of steps: a bar a day, the goal drawn across them,
/// and the three numbers a month of walking comes to.
///
/// The card at the top of the screen is about today. This is the
/// record — the count the phone kept and the day-reset job closed at
/// 3 AM — shown beside the nights and the weight readings because it
/// is the same kind of thing: a body's day, written down
/// ([[Checkpoint-8]]).
class StepsHistory extends ConsumerWidget {
  const StepsHistory({super.key});

  /// Bars drawn; the totals cover the whole month.
  static const _barDays = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = ref.watch(recentStepsProvider(30)).value ?? const <StepDay>[];
    final goal = ref.watch(stepGoalProvider).value ?? 0;
    final stride = ref.watch(strideSettingProvider).value ?? defaultStrideCm;
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;
    final counted = days.where((day) => day.steps > 0).toList();

    if (counted.isEmpty) {
      return Card(
        child: EmptyState(
          icon: Icons.directions_walk,
          title: l10n.stepsNoDays,
          body: l10n.stepsNoDaysBody,
          compact: true,
          color: scheme.secondary,
        ),
      );
    }

    final numbers = NumberFormat.decimalPattern(localeTag(context));
    String distance(int steps) {
      final metres = stepsToMetres(steps, strideCm: stride);
      final value = unit == WeightUnit.kg ? metres / 1000 : metres / 1609.344;
      return unit == WeightUnit.kg
          ? l10n.stepsDistanceKm(value.toStringAsFixed(1))
          : l10n.stepsDistanceMi(value.toStringAsFixed(1));
    }

    final total = counted.fold<int>(0, (sum, day) => sum + day.steps);
    final best = counted.reduce((a, b) => a.steps >= b.steps ? a : b);
    final average = averageSteps(counted) ?? 0;
    final bars = days.length > _barDays
        ? days.sublist(days.length - _barDays)
        : days;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.stepsLastDays(30),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: HarvestSpacing.xs),
            Row(
              children: [
                _Figure(
                  value: numbers.format(total),
                  label: distance(total),
                ),
                _Figure(
                  value: numbers.format(average),
                  label: l10n.stepsWeekAverage.replaceFirst('7-day', ''),
                  quiet: true,
                ),
                _Figure(
                  value: numbers.format(best.steps),
                  label:
                      '${l10n.stepsBestDay} · ${formatDay(context, best.day)}',
                  quiet: true,
                ),
              ],
            ),
            const SizedBox(height: HarvestSpacing.md),
            SizedBox(
              height: 140,
              child: _StepsBars(
                days: bars,
                goal: goal,
                numbers: numbers,
                distance: distance,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.label,
    this.quiet = false,
  });

  final String value;
  final String label;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style:
                (quiet
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleLarge)
                    ?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
          ),
          Text(
            label.trim(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: quiet ? scheme.onSurfaceVariant : scheme.secondary,
              fontWeight: quiet ? null : FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A bar a day, the goal as a line across them, the peak labelled.
class _StepsBars extends StatelessWidget {
  const _StepsBars({
    required this.days,
    required this.goal,
    required this.numbers,
    required this.distance,
  });

  final List<StepDay> days;
  final int goal;
  final NumberFormat numbers;
  final String Function(int steps) distance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = localeTag(context);
    final peak = days.fold<int>(0, (m, day) => day.steps > m ? day.steps : m);
    final top = [peak, goal].reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (top * 1.25).clamp(1, double.infinity).toDouble(),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        extraLinesData: goal > 0
            ? ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: goal.toDouble(),
                    color: scheme.tertiary,
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                  ),
                ],
              )
            : null,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                final steps = days[index].steps;
                if (steps == 0 || steps != peak) return const SizedBox.shrink();
                return Text(
                  numbers.format(steps),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
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
                final day = days[index].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat.E(locale)
                        .format(day.toDateTime())
                        .substring(0, 1),
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = days[group.x];
              return BarTooltipItem(
                '${formatDay(context, day.day)}\n'
                '${numbers.format(day.steps)} · ${distance(day.steps)}',
                TextStyle(color: scheme.onInverseSurface),
              );
            },
          ),
        ),
        barGroups: [
          for (final (index, day) in days.indexed)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: day.steps.toDouble(),
                  width: 12,
                  borderRadius: BorderRadius.circular(4),
                  color: goal > 0 && day.steps >= goal
                      ? scheme.secondary
                      : scheme.secondary.withValues(alpha: 0.45),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
