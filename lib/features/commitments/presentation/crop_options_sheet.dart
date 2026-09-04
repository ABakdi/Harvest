import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/archive_sheet.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/features/commitments/presentation/commitment_editor_sheet.dart';
import 'package:harvest/features/commitments/presentation/seed_note_sheet.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Long-press menu for a crop: focus, notes, history, edit, vacation
/// mode, archive — and, at the bottom and in red, delete.
Future<void> showCropOptions(BuildContext context, Commitment commitment) {
  unawaited(HarvestHaptics.tick());
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _OptionsSheet(commitment: commitment),
  );
}

class _OptionsSheet extends ConsumerWidget {
  const _OptionsSheet({required this.commitment});

  final Commitment commitment;

  /// Archiving keeps everything; this does not. The dialog says so in
  /// as many words, because there is no undo behind it.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final editor = ref.read(commitmentEditorProvider.notifier);
    final ok = await confirm(
      context,
      title: l10n.deleteSeedTitle,
      body: l10n.deleteSeedBody(commitment.title),
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!ok) return;
    navigator.pop();
    await editor.hardDelete(commitment.uuid);
    messenger.showSnackBar(SnackBar(content: Text(l10n.deleted)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final editor = ref.read(commitmentEditorProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(HarvestSpacing.md),
              child: Text(
                commitment.title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(l10n.focusTimer),
              onTap: () {
                Navigator.of(context).pop();
                unawaited(context.push(AppRoutes.pomodoro, extra: commitment));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: Text(l10n.seedNotesTitle),
              subtitle: Text(l10n.seedNotesSubtitle),
              onTap: () {
                Navigator.of(context).pop();
                unawaited(showSeedNoteSheet(context, commitment));
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(l10n.seedHistoryTitle),
              subtitle: Text(l10n.seedHistorySheetSubtitle),
              onTap: () {
                Navigator.of(context).pop();
                unawaited(
                  context.push('${AppRoutes.field}/seed/${commitment.uuid}'),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.editSeed),
              onTap: () {
                Navigator.of(context).pop();
                unawaited(showCommitmentEditor(context, existing: commitment));
              },
            ),
            if (commitment.type == CommitmentType.habit)
              ListTile(
                leading: Icon(
                  commitment.isPaused
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                ),
                title: Text(
                  commitment.isPaused ? l10n.resumeHabit : l10n.pauseHabit,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(
                    editor.setPaused(
                      commitment.uuid,
                      paused: !commitment.isPaused,
                    ),
                  );
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(l10n.archiveAction),
              subtitle: Text(l10n.archiveKeepsHistory),
              onTap: () async {
                final navigator = Navigator.of(context);
                await showArchiveSheet(context, commitment);
                navigator.pop();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: scheme.error),
              title: Text(
                l10n.deleteAction,
                style: TextStyle(color: scheme.error),
              ),
              subtitle: Text(l10n.deleteSeedSubtitle),
              onTap: () => unawaited(_delete(context, ref)),
            ),
            const SizedBox(height: HarvestSpacing.sm),
          ],
        ),
      ),
    );
  }
}
