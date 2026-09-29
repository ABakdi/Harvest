import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/guarded.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Custom expense categories, managed from Settings › Money: the
/// presets are built in; these are the user's own, deletable.
class CategorySettingsCard extends ConsumerWidget {
  const CategorySettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final customs = ref.watch(customCategoriesProvider).value ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.manageCategories, style: theme.textTheme.titleSmall),
            const SizedBox(height: HarvestSpacing.sm),
            Wrap(
              spacing: HarvestSpacing.xs,
              runSpacing: HarvestSpacing.xs,
              children: [
                for (final category in customs)
                  InputChip(
                    avatar: Icon(
                      categoryIconRegistry[category.icon] ?? Icons.category,
                      size: 18,
                    ),
                    label: Text(category.name),
                    // It said "Cancel", and deleted at once (U6-24).
                    deleteButtonTooltipMessage: l10n.categoryRemove(
                      category.name,
                    ),
                    onDeleted: () => unawaited(_remove(context, ref, category)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l10n.newCategory),
                  onPressed: () => unawaited(showCategoryCreator(context, ref)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Removed at once, as a chip's ✕ promises, with Undo in the bar.
  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    CustomCategory category,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(financesRepositoryProvider);
    if (!await runGuarded(
      context,
      repository.deleteCategory(category.uuid),
      haptic: false,
    )) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text(l10n.categoryRemoved(category.name)),
          action: SnackBarAction(
            label: l10n.undoAction,
            onPressed: () =>
                unawaited(repository.restoreCategory(category.uuid)),
          ),
        ),
      );
  }
}
