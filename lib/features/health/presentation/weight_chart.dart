import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:intl/intl.dart';

/// Every entry as a dot, the seven-day average as the line.
///
/// The dots are there because they are the truth and hiding them would
/// be dishonest. The line is there because the dots are unreadable: a
/// body weight swings a kilo either side on water and salt alone, and a
/// chart of that says nothing about whether anything is happening.
class WeightChart extends StatelessWidget {
  const WeightChart({
    required this.points,
    required this.unit,
    this.targetGrams,
    super.key,
  });

  final List<WeightPoint> points;
  final WeightUnit unit;
  final int? targetGrams;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (points.length < 2) return const SizedBox.shrink();

    final first = points.first.day;
    double x(HarvestDay day) => first.daysUntil(day).toDouble();

    final dots = [
      for (final point in points)
        if (point.entry != null)
          FlSpot(x(point.day), unit.from(point.entry!.round())),
    ];
    final line = [
      for (final point in points)
        if (point.average != null)
          FlSpot(x(point.day), unit.from(point.average!.round())),
    ];

    final values = [
      ...dots.map((s) => s.y),
      if (targetGrams != null) unit.from(targetGrams!),
    ];
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    // A hair of headroom, and never a flat line pinned to the axis.
    final pad = ((high - low) * 0.15).clamp(0.5, 5.0);

    final locale = Localizations.localeOf(context).toString();
    final labels = DateFormat.MMMd(locale);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: low - pad,
          maxY: high + pad,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(0),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (points.length / 4).ceilToDouble().clamp(1, 999),
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final day = points[index].day;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels.format(DateTime(day.year, day.month, day.day)),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: targetGrams == null
              ? const ExtraLinesData()
              : ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: unit.from(targetGrams!),
                      color: scheme.tertiary,
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                    ),
                  ],
                ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  if (spot.barIndex == 0)
                    LineTooltipItem(
                      '${spot.y.toStringAsFixed(1)} ${unit.suffix}',
                      theme.textTheme.labelMedium!.copyWith(
                        color: scheme.onInverseSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else
                    null,
              ],
            ),
          ),
          lineBarsData: [
            // The dots: what the scale actually said.
            LineChartBarData(
              spots: dots,
              barWidth: 0,
              dotData: FlDotData(
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 2.5,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                ),
              ),
            ),
            // The line: what is actually happening.
            LineChartBarData(
              spots: line,
              isCurved: true,
              curveSmoothness: 0.2,
              barWidth: 3,
              color: scheme.primary,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: scheme.primary.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The legend, because two series in one chart need saying.
class WeightChartLegend extends StatelessWidget {
  const WeightChartLegend({
    required this.entriesLabel,
    required this.trendLabel,
    this.targetLabel,
    super.key,
  });

  final String entriesLabel;
  final String trendLabel;
  final String? targetLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget key(Widget swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Wrap(
      spacing: HarvestSpacing.md,
      runSpacing: HarvestSpacing.xs,
      children: [
        key(
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
          ),
          entriesLabel,
        ),
        key(
          Container(
            width: 14,
            height: 3,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          trendLabel,
        ),
        if (targetLabel != null)
          key(
            Container(
              width: 14,
              height: 3,
              decoration: BoxDecoration(
                border: Border.all(color: scheme.tertiary, width: 1.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            targetLabel!,
          ),
      ],
    );
  }
}
