import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';

/// One option in a [showChoiceSheet].
class ChoiceOption<T> {
  const ChoiceOption({
    required this.value,
    required this.label,
    required this.icon,
    this.hint,
    this.color,
  });

  final T value;
  final String label;
  final String? hint;
  final IconData icon;
  final Color? color;
}

/// A short "which one?" sheet: a title and two or three tappable
/// options with icons — clearer than a yes/no dialog for money.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<ChoiceOption<T>> options,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) {
    final theme = Theme.of(sheetContext);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.lg,
          0,
          HarvestSpacing.lg,
          HarvestSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: HarvestSpacing.md),
            for (final option in options)
              Padding(
                padding: const EdgeInsets.only(bottom: HarvestSpacing.sm),
                child: Material(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
                  borderRadius: BorderRadius.circular(HarvestRadii.button),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(sheetContext).pop(option.value),
                    child: Padding(
                      padding: const EdgeInsets.all(HarvestSpacing.md),
                      child: Row(
                        children: [
                          IconBadge(
                            option.icon,
                            color: option.color ?? theme.colorScheme.primary,
                          ),
                          const SizedBox(width: HarvestSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.label,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (option.hint != null)
                                  Text(
                                    option.hint!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  },
);
