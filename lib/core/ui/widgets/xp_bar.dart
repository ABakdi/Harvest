import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';

/// Lifetime XP with progress toward the next rank step.
class XpBar extends StatelessWidget {
  const XpBar({
    required this.xp,
    required this.rankLabel,
    required this.xpPerRank,
    super.key,
  });

  final int xp;
  final String rankLabel;
  final int xpPerRank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intoRank = xp % xpPerRank;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              rankLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '$xp XP',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: HarvestSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(HarvestRadii.chip),
          child: LinearProgressIndicator(
            value: intoRank / xpPerRank,
            minHeight: 8,
            backgroundColor:
                theme.colorScheme.onSurface.withValues(alpha: 0.08),
            valueColor:
                AlwaysStoppedAnimation(theme.colorScheme.tertiary),
          ),
        ),
      ],
    );
  }
}
