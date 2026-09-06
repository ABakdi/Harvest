import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/commitments/presentation/seed_providers.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/presentation/gallery_providers.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The program, on the field.
///
/// A program bound to a habit is a seed like any other: it shows up in
/// the day's list, it has a streak, and finishing a session checks it
/// in ([[Gym]] rule Y4). Unbound, it is a document — which is a
/// perfectly good thing for a program to be, so this card offers and
/// never nags.
class ProgramSeedCard extends ConsumerWidget {
  const ProgramSeedCard({required this.program, super.key});

  final Program program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!program.isSeed) {
      return Card(
        child: ListTile(
          leading: IconBadge(Icons.eco_outlined, color: scheme.primary),
          title: Text(
            l10n.gymPlantProgram,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(l10n.gymPlantProgramBody),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => unawaited(_plant(context, ref)),
        ),
      );
    }

    final commitment = ref.watch(seedProvider(program.commitmentUuid!)).value;
    final album = program.albumUuid == null
        ? null
        : ref.watch(albumProvider(program.albumUuid!)).value;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: IconBadge(Icons.eco, color: scheme.primary),
            title: Text(
              commitment?.title ?? program.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              commitment?.schedule == null
                  ? l10n.gymPlantedNoSchedule
                  : _scheduleLabel(context, commitment!.schedule!),
            ),
            trailing: IconButton(
              tooltip: l10n.gymUnplant,
              icon: const Icon(Icons.link_off),
              onPressed: () => unawaited(_unplant(context, ref)),
            ),
          ),
          if (album != null)
            ListTile(
              leading: IconBadge(
                Icons.photo_camera_outlined,
                color: scheme.tertiary,
              ),
              title: Text(album.name),
              subtitle: Text(_promptLabel(context, program.photoPrompt)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => unawaited(_choosePrompt(context, ref)),
            ),
        ],
      ),
    );
  }

  static String _scheduleLabel(BuildContext context, Schedule schedule) {
    final l10n = AppLocalizations.of(context);
    return switch (schedule) {
      TimesPerWeekSchedule(:final times) => l10n.gymTimesPerWeek(times),
      DailySchedule() => l10n.gymEveryDay,
      _ => l10n.gymPlantedNoSchedule,
    };
  }

  static String _promptLabel(BuildContext context, PhotoPrompt prompt) {
    final l10n = AppLocalizations.of(context);
    return switch (prompt) {
      PhotoPrompt.after => l10n.gymPromptAfter,
      PhotoPrompt.before => l10n.gymPromptBefore,
      PhotoPrompt.never => l10n.gymPromptNever,
    };
  }

  /// Days a week, and then the offer of an album — one dismissible
  /// suggestion, made once, at the only moment it makes sense.
  Future<void> _plant(BuildContext context, WidgetRef ref) async {
    final times = await _askTimesPerWeek(context);
    if (times == null || !context.mounted) return;

    final wantsAlbum = await _askAlbum(context);
    if (!context.mounted) return;

    final commitment = await ref
        .read(commitmentsRepositoryProvider)
        .create(
          type: CommitmentType.habit,
          title: program.name,
          schedule: times == 7
              ? const DailySchedule()
              : TimesPerWeekSchedule(times: times),
        );

    String? albumUuid;
    if (wantsAlbum) {
      // Deliberately unscheduled: the seed is the gym habit, and the
      // album hangs off it. Two scheduled things would be two cards on
      // the field and two check-ins for one workout.
      final album = await ref
          .read(galleryRepositoryProvider)
          .createAlbum(name: program.name);
      albumUuid = album.uuid;
    }

    await ref
        .read(programsRepositoryProvider)
        .updateProgram(
          program.uuid,
          commitmentUuid: commitment.uuid,
          albumUuid: albumUuid,
        );
  }

  Future<int?> _askTimesPerWeek(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showHarvestSheet<int>(
      context,
      builder: (sheetContext) => HarvestSheet(
        title: l10n.gymHowOften,
        subtitle: l10n.gymHowOftenBody,
        children: [
          Wrap(
            spacing: HarvestSpacing.sm,
            runSpacing: HarvestSpacing.sm,
            children: [
              for (var times = 1; times <= 7; times++)
                ChoiceChip(
                  label: Text(
                    times == 7 ? l10n.gymEveryDay : l10n.gymTimesPerWeek(times),
                  ),
                  selected: false,
                  onSelected: (_) => Navigator.of(sheetContext).pop(times),
                ),
            ],
          ),
          const SizedBox(height: HarvestSpacing.sm),
        ],
      ),
    );
  }

  Future<bool> _askAlbum(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    return confirm(
      context,
      title: l10n.gymAlbumOffer,
      body: l10n.gymAlbumOfferBody,
      confirmLabel: l10n.gymAlbumYes,
    );
  }

  Future<void> _choosePrompt(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showHarvestSheet<PhotoPrompt>(
      context,
      builder: (sheetContext) => HarvestSheet(
        title: l10n.gymPhotoPrompt,
        subtitle: l10n.gymPhotoPromptBody,
        children: [
          for (final prompt in PhotoPrompt.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_promptLabel(sheetContext, prompt)),
              trailing: prompt == program.photoPrompt
                  ? Icon(
                      Icons.check,
                      color: Theme.of(sheetContext).colorScheme.secondary,
                    )
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(prompt),
            ),
          const SizedBox(height: HarvestSpacing.sm),
        ],
      ),
    );
    if (chosen == null) return;
    await ref
        .read(programsRepositoryProvider)
        .updateProgram(program.uuid, photoPrompt: chosen);
  }

  /// Unbinding leaves the seed and the album standing.
  ///
  /// Deleting them here would throw away a streak to change a link,
  /// and the field is where seeds are pulled up.
  Future<void> _unplant(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.gymUnplant,
      body: l10n.gymUnplantBody,
      confirmLabel: l10n.gymUnplant,
    );
    if (!ok) return;
    await ref
        .read(programsRepositoryProvider)
        .updateProgram(
          program.uuid,
          clearCommitment: true,
          clearAlbum: true,
        );
  }
}
