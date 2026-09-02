import 'package:flutter/material.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// One atomic entry in a ledger: a tinted mark, what it was, and the
/// signed amount on the trailing edge.
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.amount,
    this.subtitle,
    this.amountColor,
    this.caption,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  /// Already formatted, sign included ("+DA500").
  final String amount;
  final Color? amountColor;

  /// Small text under the amount (a conversion, a time).
  final String? caption;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(HarvestRadii.button),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HarvestSpacing.sm,
          vertical: HarvestSpacing.sm + 2,
        ),
        child: Row(
          children: [
            IconBadge(icon, color: color, size: 40, iconSize: 20),
            const SizedBox(width: HarvestSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: HarvestSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: amountColor ?? theme.colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
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
}

/// A quiet day divider inside a ledger ("Today", "Yesterday", "Sep 1").
class LedgerDayHeader extends StatelessWidget {
  const LedgerDayHeader(this.day, {super.key});

  final HarvestDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HarvestSpacing.sm,
        HarvestSpacing.md,
        HarvestSpacing.sm,
        HarvestSpacing.xs,
      ),
      child: Text(
        dayLabel(context, day),
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

/// "Today" / "Yesterday" / a short date, relative to the Harvest Day.
String dayLabel(BuildContext context, HarvestDay day) {
  final l10n = AppLocalizations.of(context);
  final today = HarvestDay.today();
  if (day == today) return l10n.dayToday;
  if (day == today.previous) return l10n.dayYesterday;
  final locale = Localizations.localeOf(context).toString();
  final date = DateTime(day.year, day.month, day.day);
  return day.year == today.year
      ? DateFormat.MMMd(locale).format(date)
      : DateFormat.yMMMd(locale).format(date);
}

/// Groups ledger items by Harvest Day (newest first, input order kept).
List<Widget> groupByDay<T>({
  required List<T> items,
  required HarvestDay Function(T) dayOf,
  required Widget Function(T) rowOf,
}) {
  final widgets = <Widget>[];
  HarvestDay? current;
  for (final item in items) {
    final day = dayOf(item);
    if (day != current) {
      widgets.add(LedgerDayHeader(day));
      current = day;
    }
    widgets.add(rowOf(item));
  }
  return widgets;
}
