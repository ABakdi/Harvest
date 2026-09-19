import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/gamification/presentation/gamification_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

Future<void> showStreakSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _StreakSheet(),
    );

class _StreakSheet extends ConsumerStatefulWidget {
  const _StreakSheet();

  @override
  ConsumerState<_StreakSheet> createState() => _StreakSheetState();
}

class _StreakSheetState extends ConsumerState<_StreakSheet> {
  var _buying = false;

  Future<void> _buy() async {
    if (_buying) return;
    setState(() => _buying = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bought = await ref.read(streakServiceProvider).buyFreeze();
      if (bought) unawaited(HarvestHaptics.thud());
      messenger.showSnackBar(
        SnackBar(
          content: Text(bought ? l10n.freezeBought : l10n.freezeUnavailable),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final streak =
        ref.watch(globalStreakProvider).value ??
        (current: 0, best: 0, freezes: 0);
    final coins = ref.watch(coinTotalProvider).value ?? 0;
    final firstMilestone = streakMilestoneCoins.keys.reduce(math.min);
    final canBuy =
        streak.freezes < maxFreezesStored && coins >= freezeCost && !_buying;

    return SafeArea(
      child: SingleChildScrollView(
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
                      : theme.colorScheme.onSurfaceVariant,
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
                        color: theme.colorScheme.onSurfaceVariant,
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
              onPressed: canBuy ? () => unawaited(_buy()) : null,
              label: Text(l10n.buyFreeze(freezeCost)),
            ),
            if (coins < freezeCost) ...[
              const SizedBox(height: HarvestSpacing.xs),
              Text(
                l10n.freezeEarnHint(
                  streakMilestoneCoins[firstMilestone]!,
                  firstMilestone,
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: HarvestSpacing.sm),
          ],
        ),
      ),
    );
  }
}
