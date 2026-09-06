import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/harvest_fab.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/core/ui/widgets/text_prompt.dart';
import 'package:harvest/features/gym/data/exercise_catalogue.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/presentation/exercise_detail.dart';
import 'package:harvest/features/gym/presentation/exercise_picker.dart';
import 'package:harvest/features/gym/presentation/program_editor.dart';
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
    final programs = ref.watch(programsProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navGym)),
      floatingActionButton: HarvestFab(
        onPressed: () => unawaited(_newProgram(context, ref)),
        label: l10n.gymNewProgram,
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
          if (programs != null && programs.isEmpty)
            Card(
              child: EmptyState(
                icon: Icons.list_alt_outlined,
                title: l10n.gymNoPrograms,
                body: l10n.gymNoProgramsBody,
                compact: true,
                color: scheme.tertiary,
                action: FilledButton.icon(
                  onPressed: () => unawaited(_newProgram(context, ref)),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.gymNewProgram),
                ),
              ),
            )
          else
            for (final program in programs ?? const <Program>[])
              Card(
                margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
                child: ListTile(
                  leading: IconBadge(
                    Icons.list_alt_outlined,
                    color: scheme.tertiary,
                  ),
                  title: Text(
                    program.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    l10n.gymProgramSummary(
                      program.days.length,
                      program.days.fold(0, (sum, d) => sum + d.totalSets),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProgramEditor(uuid: program.uuid),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _newProgram(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final name = await promptForText(
      context,
      title: l10n.gymNewProgram,
      hint: l10n.gymProgramNameHint,
      confirmLabel: l10n.notesCreate,
    );
    if (name == null || name.trim().isEmpty) return;
    final program = await ref
        .read(programsRepositoryProvider)
        .createProgram(name: name);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ProgramEditor(uuid: program.uuid),
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
