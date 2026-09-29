import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/security/file_vault.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/data/memory_files.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/domain/gallery_service.dart';
import 'package:harvest/features/gallery/presentation/gallery_providers.dart';
import 'package:harvest/features/gallery/presentation/memory_view.dart';
import 'package:harvest/features/places/presentation/geotag_chip.dart';
import 'package:harvest/features/places/presentation/places_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

/// Full-screen memory, swipeable, with its note and the way out.
class MemoryViewer extends ConsumerStatefulWidget {
  const MemoryViewer({
    required this.album,
    required this.memories,
    required this.initial,
    super.key,
  });

  final Album album;

  /// The album's memories as the caller had them. They are only the
  /// opening order and the first frame: the viewer watches the album
  /// itself, so a note saved here shows at once rather than the copy
  /// this list was made from ([[Audit-v2]] U3-08).
  final List<Memory> memories;
  final int initial;

  @override
  ConsumerState<MemoryViewer> createState() => _MemoryViewerState();
}

class _MemoryViewerState extends ConsumerState<MemoryViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initial,
  );
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// The album as it is now, falling back to what the caller passed
  /// until the first read arrives.
  List<Memory> get _memories {
    final live = ref.read(albumMemoriesProvider(widget.album.uuid)).value;
    return live == null || live.isEmpty ? widget.memories : live;
  }

  Memory get _current => _memories[_index.clamp(0, _memories.length - 1)];

  Future<void> _editNote() async {
    final memory = _current;
    final note = await showHarvestSheet<String>(
      context,
      builder: (_) => _NoteSheet(initial: memory.note ?? ''),
    );
    if (note == null) return;
    await ref
        .read(galleryRepositoryProvider)
        .setMemoryNote(memory.uuid, note.isEmpty ? null : note);
  }

  /// Out of the app, deliberately.
  ///
  /// The gallery keeps its files to itself (rule G2) — this is the one
  /// door out, and it is one I have to open by hand, per picture.
  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final memory = _current;
    final file = await ref.read(galleryRepositoryProvider).fileOf(memory);
    if (!file.existsSync()) {
      // Not here yet says why, as the frame does ([[Gallery]] G9); one
      // the server has comes down first.
      final pinSet = ref.read(syncPassphraseProvider).value ?? false;
      final why = memoryAbsentWords(l10n, memory, pinSet: pinSet);
      if (why != null) {
        messenger.showSnackBar(SnackBar(content: Text(why)));
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.galleryFileDownloading)),
      );
      final landed = await ref.read(memoryFilesProvider).fetch(memory);
      messenger.hideCurrentSnackBar();
      if (!landed || !file.existsSync()) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.galleryFileFailed)),
        );
        return;
      }
    }
    // Sealed on disk: what is shared is a plain copy in the app's cache,
    // which the other app may still be reading after the sheet closes;
    // it goes at the next start (`FileVault.clearCopies`).
    final copy = await ref.read(fileVaultProvider).openCopy(file);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(copy.path)],
        text: memory.note,
      ),
    );
  }

  /// Rule G5, as revised: the picture goes to the trash rather than
  /// off the disk, and the snack bar can put it straight back.
  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(galleryServiceProvider);
    final memory = _current;
    await service.remove(memory, album: widget.album);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        // An action is an offer for a few seconds, not a fixture.
        persist: false,
        content: Text(l10n.galleryMovedToTrash),
        action: SnackBarAction(
          label: l10n.undoAction,
          // A refused undo says so rather than leaving the picture
          // gone with no word ([[Audit-v3]] Q6-12).
          onPressed: () => unawaited(
            service.restore(memory, album: widget.album).catchError((
              Object _,
            ) {
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.saveFailed)),
              );
            }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final live = ref.watch(albumMemoriesProvider(widget.album.uuid)).value;
    final memories = live == null || live.isEmpty ? widget.memories : live;
    if (memories.isEmpty) return const SizedBox.shrink();
    final current = memories[_index.clamp(0, memories.length - 1)];
    final hasNote = (current.note ?? '').isNotEmpty;
    final showsPlace = GeotagChip.shows(
      ref
          .watch(geotagForProvider((table: 'memories', uuid: current.uuid)))
          .value,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // The theme's title colour is meant for a cream app bar; on
        // black it disappears.
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        title: Text(formatDay(context, current.day, weekday: true)),
        actions: [
          IconButton(
            tooltip: l10n.galleryMemoryNote,
            icon: const Icon(Icons.sticky_note_2_outlined),
            onPressed: () => unawaited(_editNote()),
          ),
          IconButton(
            tooltip: l10n.shareAction,
            icon: const Icon(Icons.ios_share),
            onPressed: () => unawaited(_share()),
          ),
          IconButton(
            tooltip: l10n.deleteAction,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => unawaited(_delete()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: memories.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final memory = memories[index];
                return memory.kind == MemoryKind.video
                    ? _VideoMemory(memory: memory)
                    : InteractiveViewer(
                        maxScale: 5,
                        child: MemoryView(
                          memory: memory,
                          fit: BoxFit.contain,
                        ),
                      );
              },
            ),
          ),
          // The note, and where the picture was taken when Places was
          // there to say ([[Places]]), share one bar and one inset —
          // and with neither there is no bar at all.
          if (hasNote || showsPlace)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                HarvestSpacing.md,
                HarvestSpacing.sm,
                HarvestSpacing.md,
                HarvestSpacing.sm,
              ),
              color: Colors.black,
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasNote)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: HarvestSpacing.xs,
                        ),
                        child: Text(
                          current.note!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                    if (showsPlace)
                      GeotagChip(
                        targetTable: 'memories',
                        targetUuid: current.uuid,
                        onDark: true,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A clip, played in place. Nothing fancy: tap to pause.
class _VideoMemory extends ConsumerStatefulWidget {
  const _VideoMemory({required this.memory});

  final Memory memory;

  @override
  ConsumerState<_VideoMemory> createState() => _VideoMemoryState();
}

class _VideoMemoryState extends ConsumerState<_VideoMemory> {
  VideoPlayerController? _controller;

  /// The video opened into a temporary file to play: sealed on disk, it
  /// is let go with the player.
  File? _opened;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final file = await ref
        .read(galleryRepositoryProvider)
        .fileOf(widget.memory);
    if (!mounted || !file.existsSync()) return;
    final opened = await ref.read(fileVaultProvider).openCopy(file);
    if (!mounted) {
      await FileVault.release(opened);
      return;
    }
    _opened = opened;
    final controller = VideoPlayerController.file(opened);
    try {
      await controller.initialize();
    } on Object {
      await controller.dispose();
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    await controller.setLooping(true);
    await controller.play();
    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    final opened = _opened;
    unawaited(
      (_controller?.dispose() ?? Future<void>.value()).whenComplete(
        () => FileVault.release(opened),
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return GestureDetector(
      onTap: () => setState(() {
        controller.value.isPlaying
            ? unawaited(controller.pause())
            : unawaited(controller.play());
      }),
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

/// What I wrote about one picture.
///
/// Its own widget so the controller dies with the sheet rather than
/// the instant the sheet's future completes.
class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.initial});

  final String initial;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HarvestSheet(
      title: l10n.galleryMemoryNote,
      actionLabel: l10n.save,
      onAction: () => Navigator.of(context).pop(_controller.text.trim()),
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: l10n.galleryMemoryNoteHint),
        ),
      ],
    );
  }
}
