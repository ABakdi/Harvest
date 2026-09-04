import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/features/commitments/presentation/commitment_editor_sheet.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Long-press menu for a crop: focus, edit, vacation mode, archive.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(l10n.archiveAction),
              onTap: () async {
                final navigator = Navigator.of(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.archiveConfirmTitle),
                    content: Text(l10n.archiveConfirmBody(commitment.title)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(l10n.archiveAction),
                      ),
                    ],
                  ),
                );
                if (confirmed ?? false) {
                  await editor.archive(commitment.uuid);
                }
                navigator.pop();
              },
            ),
            const SizedBox(height: HarvestSpacing.sm),
          ],
        ),
      ),
    );
  }
}
