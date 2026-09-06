import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_fab.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/features/gym/data/exercise_catalogue.dart';
import 'package:harvest/features/gym/presentation/exercise_detail.dart';
import 'package:harvest/features/gym/presentation/exercise_picker.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Programs, sessions and records.
///
/// The catalogue works; the programs and the session screen land in
/// M4.4 and M4.5, so the tab says so plainly rather than pretending.
class GymScreen extends ConsumerWidget {
  const GymScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final catalogue = ref.watch(exerciseCatalogueProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navGym)),
      floatingActionButton: HarvestFab(
        onPressed: () => unawaited(_browse(context)),
        icon: Icons.search,
        label: l10n.gymBrowse,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.md,
          HarvestSpacing.sm,
          HarvestSpacing.md,
          120,
        ),
        children: [
          SectionHeader(l10n.gymExercisesTitle),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(HarvestRadii.card),
              onTap: () => unawaited(_browse(context)),
              child: Padding(
                padding: const EdgeInsets.all(HarvestSpacing.md),
                child: Row(
                  children: [
                    IconBadge(Icons.menu_book_outlined, color: scheme.secondary),
                    const SizedBox(width: HarvestSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            catalogue == null
                                ? l10n.gymCatalogueLoading
                                : l10n.gymExerciseCount(catalogue.all.length),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            l10n.gymCatalogueHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          SectionHeader(l10n.gymProgramsTitle),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(HarvestSpacing.md),
              child: Row(
                children: [
                  IconBadge(Icons.construction_outlined, color: scheme.tertiary),
                  const SizedBox(width: HarvestSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.gymComingTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          l10n.gymComingBody,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Browsing is picking without keeping the pick: an exercise chosen
  /// here opens its instructions rather than going anywhere.
  Future<void> _browse(BuildContext context) async {
    final exercise = await pickExercise(context);
    if (exercise == null || !context.mounted) return;
    await showExerciseDetail(context, exercise);
  }
}
