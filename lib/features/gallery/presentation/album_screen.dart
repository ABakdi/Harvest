import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/harvest_fab.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/presentation/album_sheet.dart';
import 'package:harvest/features/gallery/presentation/capture_sheet.dart';
import 'package:harvest/features/gallery/presentation/compare_screen.dart';
import 'package:harvest/features/gallery/presentation/gallery_providers.dart';
import 'package:harvest/features/gallery/presentation/memory_view.dart';
import 'package:harvest/features/gallery/presentation/memory_viewer.dart';
import 'package:harvest/features/gallery/presentation/timelapse_screen.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// One album: the grid, and the two things worth doing with a run of
/// pictures — playing it, and putting two of them beside each other.
class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({required this.uuid, super.key});

  final String uuid;

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  final _search = TextEditingController();
  var _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _deleteAlbum(Album album) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final ok = await confirm(
      context,
      title: l10n.galleryDeleteAlbumTitle(album.name),
      body: l10n.galleryDeleteAlbumBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(galleryRepositoryProvider).deleteAlbum(album.uuid);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final album = ref.watch(albumProvider(widget.uuid)).value;
    final all =
        ref.watch(albumMemoriesProvider(widget.uuid)).value ??
        const <Memory>[];

    if (album == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.galleryTitle)),
        body: EmptyState(
          icon: Icons.photo_library_outlined,
          title: l10n.galleryAlbumGone,
        ),
      );
    }

    final query = _search.text.trim().toLowerCase();
    final memories = query.isEmpty
        ? all
        : all
              .where(
                (m) => (m.note ?? '').toLowerCase().contains(query),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  hintText: l10n.gallerySearchHint,
                ),
              )
            : Text(album.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l10n.gallerySearchNotes,
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => switch (value) {
              'edit' => unawaited(showAlbumSheet(context, existing: album)),
              _ => unawaited(_deleteAlbum(album)),
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(l10n.editAction)),
              PopupMenuItem(value: 'delete', child: Text(l10n.deleteAction)),
            ],
          ),
        ],
      ),
      floatingActionButton: HarvestFab(
        onPressed: () => unawaited(showCaptureSheet(context, album: album)),
        icon: Icons.photo_camera,
        label: l10n.galleryAdd,
      ),
      body: Column(
        children: [
          if (all.length >= 2)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HarvestSpacing.md,
                vertical: HarvestSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TimelapseScreen(
                            album: album,
                            memories: all.reversed.toList(),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.galleryPlay),
                    ),
                  ),
                  const SizedBox(width: HarvestSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CompareScreen(
                            album: album,
                            memories: all,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.compare_arrows),
                      label: Text(l10n.galleryCompare),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: memories.isEmpty
                ? EmptyState(
                    icon: Icons.photo_camera_outlined,
                    title: all.isEmpty
                        ? l10n.galleryAlbumEmpty
                        : l10n.galleryNoMatch,
                    body: all.isEmpty ? l10n.galleryAlbumEmptyBody : null,
                    color: theme.colorScheme.tertiary,
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      HarvestSpacing.md,
                      0,
                      HarvestSpacing.md,
                      96,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: HarvestSpacing.xs,
                          mainAxisSpacing: HarvestSpacing.xs,
                        ),
                    itemCount: memories.length,
                    itemBuilder: (context, index) => _MemoryTile(
                      memory: memories[index],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MemoryViewer(
                            album: album,
                            memories: memories,
                            initial: index,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.memory, required this.onTap});

  final Memory memory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HarvestRadii.chip),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MemoryView(memory: memory),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatDay(context, memory.day),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if ((memory.note ?? '').isNotEmpty)
                      const Icon(
                        Icons.sticky_note_2_outlined,
                        size: 12,
                        color: Colors.white,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
