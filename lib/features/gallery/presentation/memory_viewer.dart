import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/domain/gallery_service.dart';
import 'package:harvest/features/gallery/presentation/memory_view.dart';
import 'package:harvest/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final memory = _current;
    final controller = TextEditingController(text: memory.note ?? '');
    final note = await showHarvestSheet<String>(
      context,
      builder: (context) => HarvestSheet(
        title: l10n.galleryMemoryNote,
        actionLabel: l10n.save,
        onAction: () => Navigator.of(context).pop(controller.text.trim()),
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            decoration: InputDecoration(hintText: l10n.galleryMemoryNoteHint),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    await ref
        .read(galleryRepositoryProvider)
        .setMemoryNote(memory.uuid, note.isEmpty ? null : note);
  }

  /// Rule G5: a photo I asked to be gone must be gone. No undo, and the
  /// dialog says so before the file goes.
  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final ok = await confirm(
      context,
      title: l10n.galleryDeleteMemoryTitle,
      body: l10n.galleryDeleteMemoryBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(galleryServiceProvider)
        .remove(_current, album: widget.album);
    navigator.pop();
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
        title: Text(formatDay(context, current.day, weekday: true)),
        actions: [
          IconButton(
            tooltip: l10n.galleryMemoryNote,
            icon: const Icon(Icons.sticky_note_2_outlined),
            onPressed: () => unawaited(_editNote()),
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
