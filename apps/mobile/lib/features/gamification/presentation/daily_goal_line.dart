import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/gamification/presentation/gamification_providers.dart';
import 'package:harvest/features/settings/presentation/settings_controllers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// How far today is toward the Daily Harvest Goal, the one thing that
/// moves the streak: "1 of 3 actions today", then "the goal is met".
/// Without it a streak at 0 after a check-in looked broken
/// ([[Audit-v3]] U6-03).
class DailyGoalLine extends ConsumerWidget {
  const DailyGoalLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final actions = ref.watch(todayActionsProvider).value ?? 0;
    final goal = ref.watch(dailyGoalSettingProvider).value ?? 3;
    final met = actions >= goal;
    return Semantics(
      container: true,
      child: Row(
        children: [
          Icon(
            met ? Icons.local_fire_department : Icons.flag_outlined,
            size: 18,
            color: met
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: HarvestSpacing.xs),
          Expanded(
            child: Text(
              met
                  ? l10n.dailyGoalMet(actions)
                  : l10n.dailyGoalProgress(actions, goal),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
