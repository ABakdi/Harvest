import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/domain/gallery_service.dart';
import 'package:harvest/features/gallery/presentation/gallery_providers.dart';
import 'package:harvest/features/gallery/presentation/memory_view.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Deleted pictures and deleted albums, in one place.
///
/// The gallery used to delete a file the moment a picture was deleted,
/// on the theory that a photo asked to be gone must be gone. True — but
/// a thumb hitting the wrong row asked for nothing. So the promise
/// stands and now takes two steps: here, and then Empty.
class GalleryTrashScreen extends ConsumerWidget {
  const GalleryTrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final memories =
        ref.watch(deletedMemoriesProvider).value ?? const <Memory>[];
    final albums = ref.watch(deletedAlbumsProvider).value ?? const <Album>[];
    final empty = memories.isEmpty && albums.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trashTitle),
        actions: [
          if (!empty)
            TextButton(
              onPressed: () => unawaited(
                _empty(context, ref, memories.length + albums.length),
              ),
              child: Text(l10n.trashEmpty),
            ),
        ],
      ),
      body: empty
          ? EmptyState(
              icon: Icons.delete_outline,
              title: l10n.trashEmptyTitle,
              body: l10n.trashGalleryEmptyBody,
            )
          : ListView(
              padding: const EdgeInsets.all(HarvestSpacing.md),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: HarvestSpacing.sm),
                  child: Text(
                    l10n.trashKeepsFiles,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final album in albums)
                  Card(
                    margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
                    child: ListTile(
                      leading: const Icon(Icons.photo_library_outlined),
                      title: Text(album.name),
                      subtitle: Text(l10n.trashWholeAlbum),
                      trailing: _Actions(
                        onRestore: () => unawaited(
                          ref
                              .read(galleryRepositoryProvider)
                              .restoreAlbum(album.uuid),
                        ),
                        onPurge: () =>
                            unawaited(_purgeAlbum(context, ref, album)),
                      ),
                    ),
                  ),
                for (final memory in memories)
                  Card(
                    margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: SizedBox(
                        width: 46,
                        height: 46,
                        child: MemoryView(
                          memory: memory,
                          borderRadius: BorderRadius.circular(
                            HarvestRadii.chip,
                          ),
                        ),
                      ),
                      title: Text(formatDay(context, memory.day)),
                      subtitle: memory.note == null
                          ? null
                          : Text(
                              memory.note!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: _Actions(
                        onRestore: () =>
                            unawaited(_restore(ref, memory)),
                        onPurge: () =>
                            unawaited(_purgeMemory(context, ref, memory)),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _restore(WidgetRef ref, Memory memory) async {
    final album = await ref
        .read(galleryRepositoryProvider)
        .watchAlbum(memory.albumUuid)
        .first;
    if (album == null) return;
    await ref.read(galleryServiceProvider).restore(memory, album: album);
  }

  Future<void> _empty(BuildContext context, WidgetRef ref, int count) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.trashEmptyConfirm(count),
      body: l10n.trashEmptyFilesBody,
      confirmLabel: l10n.trashEmpty,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(galleryRepositoryProvider).emptyTrash();
  }

  Future<void> _purgeMemory(
    BuildContext context,
    WidgetRef ref,
    Memory memory,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.trashDeleteForeverConfirm,
      body: l10n.galleryDeleteMemoryBody,
      confirmLabel: l10n.trashDeleteForever,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(galleryRepositoryProvider).purgeMemory(memory.uuid);
  }

  Future<void> _purgeAlbum(
    BuildContext context,
    WidgetRef ref,
    Album album,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.galleryDeleteAlbumTitle(album.name),
      body: l10n.galleryDeleteAlbumBody,
      confirmLabel: l10n.trashDeleteForever,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(galleryRepositoryProvider).purgeAlbum(album.uuid);
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onRestore, required this.onPurge});

  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.trashRestore,
          icon: const Icon(Icons.restore_from_trash_outlined),
          onPressed: onRestore,
        ),
        IconButton(
          tooltip: l10n.trashDeleteForever,
          icon: const Icon(Icons.delete_forever_outlined),
          onPressed: onPurge,
        ),
      ],
    );
  }
}
