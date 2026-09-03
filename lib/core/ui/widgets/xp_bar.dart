import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/l10n/app_localizations.dart';

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
              AppLocalizations.of(context).xpAmount(xp),
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
          child: Stack(
            children: [
              Container(
                height: 8,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                widthFactor: (intoRank / xpPerRank).clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: theme.primaryGradient,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
