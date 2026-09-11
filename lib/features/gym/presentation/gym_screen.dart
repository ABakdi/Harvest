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
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/presentation/exercise_detail.dart';
import 'package:harvest/features/gym/presentation/exercise_picker.dart';
import 'package:harvest/features/gym/presentation/program_editor.dart';
import 'package:harvest/features/gym/presentation/session_history.dart';
import 'package:harvest/features/gym/presentation/session_screen.dart';
import 'package:harvest/features/gym/presentation/session_start.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Programs, sessions and records.
///
/// Ordered by how often I open the tab for each: the running session
/// first, because if one is running that is the only reason I am
/// here; then starting one; then the programs I would edit between
/// sessions; then the catalogue, which is a reference book.
class GymScreen extends ConsumerWidget {
  const GymScreen({this.title, this.tabs, super.key});

  /// The title and tabs of the paired screen this is half of, when it
  /// is one ([[Checkpoint-6]]); on its own it names itself.
  final String? title;
  final PreferredSizeWidget? tabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final catalogue = ref.watch(exerciseCatalogueProvider).value;
    final programs = ref.watch(programsProvider).value;
    final running = ref.watch(runningSessionProvider).value;
    final finished = ref.watch(finishedSessionsProvider).value;
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? l10n.navGym),
        bottom: tabs,
      ),
      floatingActionButton: HarvestFab(
        onPressed: () => unawaited(startSession(context, ref)),
        icon: Icons.play_arrow,
        label: running == null ? l10n.gymStart : l10n.gymResume,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.md,
          HarvestSpacing.sm,
          HarvestSpacing.md,
          120,
        ),
        children: [
          // A session left running is the loudest thing on the screen:
          // the app killed mid-workout is the normal case, not the
          // exception, and picking it back up must be one tap.
          if (running != null)
            Card(
              color: scheme.secondaryContainer,
              child: InkWell(
                borderRadius: BorderRadius.circular(HarvestRadii.card),
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SessionScreen(uuid: running.uuid),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(HarvestSpacing.md),
                  child: Row(
                    children: [
                      IconBadge(
                        Icons.fitness_center,
                        color: scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: HarvestSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              running.title ?? l10n.gymRunningSession,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                            Text(
                              l10n.gymRunningSessionBody(
                                running.doneSets,
                                running.totalSets,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: scheme.onSecondaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SectionHeader(l10n.gymExercisesTitle),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(HarvestRadii.card),
              onTap: () => unawaited(_browse(context)),
              child: Padding(
                padding: const EdgeInsets.all(HarvestSpacing.md),
                child: Row(
                  children: [
                    IconBadge(
                      Icons.menu_book_outlined,
                      color: scheme.secondary,
                    ),
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
          SectionHeader(
            l10n.gymProgramsTitle,
            trailing: IconButton(
              tooltip: l10n.gymNewProgram,
              icon: const Icon(Icons.add),
              onPressed: () => unawaited(_newProgram(context, ref)),
            ),
          ),
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
                  subtitle: _ProgramSubtitle(program: program),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProgramEditor(uuid: program.uuid),
                    ),
                  ),
                ),
              ),
          if (finished != null && finished.isNotEmpty) ...[
            SectionHeader(
              l10n.gymHistory,
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SessionHistoryScreen(),
                  ),
                ),
                child: Text(l10n.gymSeeAll),
              ),
            ),
            for (final session in finished.take(3))
              SessionTile(session: session, unit: unit),
          ],
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

/// Days and sets, and which day is up next — the one number worth
/// knowing before tapping Start.
class _ProgramSubtitle extends ConsumerWidget {
  const _ProgramSubtitle({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final next = ref.watch(nextDayProvider(program.uuid)).value;
    final summary = l10n.gymProgramSummary(
      program.days.length,
      program.days.fold(0, (sum, d) => sum + d.totalSets),
    );
    return Text(
      next == null ? summary : '$summary · ${l10n.gymNextDay(next.name)}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
