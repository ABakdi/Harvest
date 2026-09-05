import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:harvest/features/notes/presentation/notes_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Deleted notes, and the two things I can do with them.
///
/// The trash exists because "delete" and "gone for good" should not be
/// the same gesture. Nothing leaves here on its own except by age; the
/// button below is the only thing that empties it, and it says what it
/// is about to do before it does it.
class NoteTrashScreen extends ConsumerWidget {
  const NoteTrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final notes = ref.watch(deletedNotesProvider).value ?? const <Note>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trashTitle),
        actions: [
          if (notes.isNotEmpty)
            TextButton(
              onPressed: () => unawaited(_empty(context, ref, notes.length)),
              child: Text(l10n.trashEmpty),
            ),
        ],
      ),
      body: notes.isEmpty
          ? EmptyState(
              icon: Icons.delete_outline,
              title: l10n.trashEmptyTitle,
              body: l10n.trashNotesEmptyBody,
            )
          : ListView(
              padding: const EdgeInsets.all(HarvestSpacing.md),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: HarvestSpacing.sm),
                  child: Text(
                    l10n.trashKeeps,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final note in notes)
                  Card(
                    margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        note.title.isEmpty ? l10n.notesUntitled : note.title,
                      ),
                      subtitle: Text(
                        formatDay(context, HarvestDay.of(note.updatedAt)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l10n.trashRestore,
                            icon: const Icon(Icons.restore_from_trash_outlined),
                            onPressed: () => unawaited(
                              ref
                                  .read(notesRepositoryProvider)
                                  .restore(note.uuid),
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.trashDeleteForever,
                            icon: const Icon(Icons.delete_forever_outlined),
                            onPressed: () =>
                                unawaited(_purge(context, ref, note)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _empty(BuildContext context, WidgetRef ref, int count) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.trashEmptyConfirm(count),
      body: l10n.trashEmptyConfirmBody,
      confirmLabel: l10n.trashEmpty,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(notesRepositoryProvider).emptyTrash();
  }

  Future<void> _purge(BuildContext context, WidgetRef ref, Note note) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.trashDeleteForeverConfirm,
      body: l10n.trashDeleteForeverBody,
      confirmLabel: l10n.trashDeleteForever,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(notesRepositoryProvider).purge(note.uuid);
  }
}
