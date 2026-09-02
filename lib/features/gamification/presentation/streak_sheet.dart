import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/gamification/data/gamification_repository.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/l10n/app_localizations.dart';

Future<void> showStreakSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HarvestRadii.sheet),
        ),
      ),
      builder: (_) => const _StreakSheet(),
    );

class _StreakSheet extends ConsumerWidget {
  const _StreakSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final streak = ref.watch(globalStreakProvider).value ??
        (current: 0, best: 0, freezes: 0);
    final coins = ref.watch(coinTotalProvider).value ?? 0;

    return Padding(
      padding: const EdgeInsets.all(HarvestSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.streakSheetTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.paid, color: theme.colorScheme.tertiary),
                  const SizedBox(width: HarvestSpacing.xs),
                  Text(
                    l10n.coinBalance(coins),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: HarvestSpacing.lg),
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                size: 48,
                color: streak.current > 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              const SizedBox(width: HarvestSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.streakCurrent(streak.current),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    l10n.streakBest(streak.best),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: HarvestSpacing.lg),
          Text(
            l10n.freezesStored(streak.freezes, maxFreezesStored),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: HarvestSpacing.xs),
          Text(
            l10n.freezeExplainer,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: HarvestSpacing.md),
          FilledButton.icon(
            icon: const Icon(Icons.ac_unit),
            onPressed:
                streak.freezes < maxFreezesStored && coins >= freezeCost
                    ? () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final bought = await ref
                            .read(streakServiceProvider)
                            .buyFreeze();
                        if (bought) unawaited(HarvestHaptics.thud());
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              bought
                                  ? l10n.freezeBought
                                  : l10n.freezeUnavailable,
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    : null,
            label: Text(l10n.buyFreeze(freezeCost)),
          ),
          const SizedBox(height: HarvestSpacing.sm),
        ],
      ),
    );
  }
}
