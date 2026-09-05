import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/domain/gallery_service.dart';
import 'package:harvest/features/gallery/presentation/memory_view.dart';
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

  Memory get _current => widget.memories[_index];

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
      messenger.showSnackBar(SnackBar(content: Text(l10n.galleryFileGone)));
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
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
        content: Text(l10n.galleryMovedToTrash),
        action: SnackBarAction(
          label: l10n.undoAction,
          onPressed: () =>
              service.restore(memory, album: widget.album).ignore(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final memories = widget.memories;
    if (memories.isEmpty) return const SizedBox.shrink();
    final current = memories[_index.clamp(0, memories.length - 1)];

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
          if ((current.note ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(HarvestSpacing.md),
              color: Colors.black,
              child: SafeArea(
                top: false,
                child: Text(
                  current.note!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
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
    final controller = VideoPlayerController.file(File(file.path));
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
    unawaited(_controller?.dispose());
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
