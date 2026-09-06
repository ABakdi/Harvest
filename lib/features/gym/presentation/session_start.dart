import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/presentation/capture_sheet.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/presentation/session_screen.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Getting into a session, from wherever I am.
///
/// Two rules live here rather than in the screens that call it. One:
/// there is only ever one session running, because I only have one
/// body — starting a second would quietly orphan the first, so the
/// running one is offered instead. Two: a day is chosen, never
/// guessed. The app does not know which day of the program I feel like
/// doing, and a wrong guess costs more than a tap.
Future<void> startSession(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  // The root navigator, so a session covers the tab bar. While I am
  // lifting the app is a workout log and nothing else — and those
  // ninety pixels are two more sets on screen.
  final navigator = Navigator.of(context, rootNavigator: true);
  final repository = ref.read(sessionsRepositoryProvider);

  final running = await repository.runningOnce();
  if (running != null) {
    if (!context.mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => SessionScreen(uuid: running.uuid),
      ),
    );
    return;
  }

  final programs = await ref.read(programsRepositoryProvider).allOnce();
  final withDays = programs.where((p) => p.days.isNotEmpty).toList();
  if (!context.mounted) return;

  if (withDays.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.gymNoProgramToStartBody)));
    return;
  }

  final picked = await _pickDay(context, withDays);
  if (picked == null || !context.mounted) return;

  final maxes = await ref
      .read(programsRepositoryProvider)
      .trainingMaxesOnce(picked.program.uuid);
  final session = await repository.start(
    day: picked.day,
    programUuid: picked.program.uuid,
    title: picked.day.name,
    trainingMaxes: maxes,
  );
  if (!context.mounted) return;

  // The mirror on the way in, for whoever prefers it that way.
  if (picked.program.photoPrompt == PhotoPrompt.before) {
    await _offerPicture(context, ref, picked.program.albumUuid);
    if (!context.mounted) return;
  }

  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => SessionScreen(uuid: session.uuid),
    ),
  );
}

typedef _Pick = ({Program program, ProgramDay day});

/// Every day of every program, flat. Scrolling past three programs is
/// cheaper than choosing a program and then choosing a day.
Future<_Pick?> _pickDay(BuildContext context, List<Program> programs) {
  final l10n = AppLocalizations.of(context);
  return showHarvestSheet<_Pick>(
    context,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return HarvestSheet(
        title: l10n.gymPickDay,
        children: [
          for (final program in programs) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: HarvestSpacing.sm,
                bottom: HarvestSpacing.xs,
              ),
              child: Text(
                program.name,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final day in program.days)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  day.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  l10n.gymDaySummary(day.slots.length, day.totalSets),
                ),
                trailing: const Icon(Icons.play_arrow),
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop((program: program, day: day)),
              ),
          ],
          const SizedBox(height: HarvestSpacing.sm),
        ],
      );
    },
  );
}

/// Offers the album a picture, before the first set.
Future<void> _offerPicture(
  BuildContext context,
  WidgetRef ref,
  String? albumUuid,
) async {
  if (albumUuid == null) return;
  final l10n = AppLocalizations.of(context);
  final album = await ref.read(galleryRepositoryProvider).albumOnce(albumUuid);
  if (album == null || !context.mounted) return;

  final ok = await confirm(
    context,
    title: l10n.gymPictureNow,
    body: l10n.gymPictureNowBody,
    confirmLabel: l10n.gymPictureYes,
  );
  if (!ok || !context.mounted) return;
  await showCaptureSheet(context, album: album);
}
