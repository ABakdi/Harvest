import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
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
                    deleteButtonTooltipMessage: l10n.cancel,
                    onDeleted: () => unawaited(
                      ref
                          .read(financesRepositoryProvider)
                          .deleteCategory(category.uuid),
                    ),
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
}
