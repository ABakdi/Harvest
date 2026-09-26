import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/gym/domain/plates.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/presentation/weight_text.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// What goes on each side of the bar.
///
/// Two taps of arithmetic I should never do tired, and the one place
/// the app admits a target cannot be made: a barbell loads in pairs, so
/// its smallest step is twice the smallest plate, and 20.25 kg is not a
/// weight however much the percentage says so. In pounds it is a pound
/// gym: 45 lb bar, 45 to 2.5 lb plates ([[Gym]] rule Y8).
Future<void> showPlates(
  BuildContext context, {
  required int targetGrams,
  required int barGrams,
}) => showHarvestSheet<void>(
  context,
  builder: (_) => _PlateSheet(targetGrams: targetGrams, barGrams: barGrams),
);

class _PlateSheet extends ConsumerWidget {
  const _PlateSheet({required this.targetGrams, required this.barGrams});

  final int targetGrams;
  final int barGrams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;
    final bar = barIn(barGrams, unit);
    final plan = platesFor(targetGrams, barGrams: bar, unit: unit);

    return HarvestSheet(
      title: formatLoad(context, targetGrams, unit),
      subtitle: l10n.gymPerSide(formatLoad(context, bar, unit)),
      children: [
        if (plan.stacks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HarvestSpacing.md),
            child: Text(
              l10n.gymJustTheBar,
              style: theme.textTheme.titleMedium,
            ),
          )
        else
          Wrap(
            spacing: HarvestSpacing.sm,
            runSpacing: HarvestSpacing.sm,
            children: [
              for (final stack in plan.stacks)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HarvestSpacing.md,
                    vertical: HarvestSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(HarvestRadii.chip),
                  ),
                  child: Text(
                    '${stack.perSide} × ${formatLoad(context, stack.grams, unit)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        // Lighter than the bar: the bar is still the bar, and says by
        // how much it is over rather than pretending to be the target.
        if (plan.overGrams > 0) ...[
          const SizedBox(height: HarvestSpacing.md),
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: scheme.error),
              const SizedBox(width: HarvestSpacing.xs),
              Expanded(
                child: Text(
                  l10n.gymBarOver(formatLoad(context, plan.overGrams, unit)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (plan.shortfallGrams > 0) ...[
          const SizedBox(height: HarvestSpacing.md),
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: scheme.error),
              const SizedBox(width: HarvestSpacing.xs),
              Expanded(
                child: Text(
                  l10n.gymPlateShortfall(
                    formatLoad(context, plan.totalGrams, unit),
                    formatLoad(context, plan.shortfallGrams, unit),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: HarvestSpacing.sm),
      ],
    );
  }
}
