import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The streak indicator: a flame and the current run of days.
class StreakFlame extends StatelessWidget {
  const StreakFlame({required this.days, super.key});

  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = days > 0;
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      label: AppLocalizations.of(context).streakSemantics(days),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, color: color, size: 28),
          const SizedBox(width: HarvestSpacing.xs),
          Text(
            '$days',
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
