import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The album, played: one frame per memory, oldest first.
///
/// This is the point of the whole feature (spec: *Play*), so it is one
/// tap from the album and it does exactly one thing — no export, no
/// rendering, no waiting. The frames are already on the phone; playing
/// them is a timer and an index.
class TimelapseScreen extends ConsumerStatefulWidget {
  const TimelapseScreen({
    required this.album,
    required this.memories,
    super.key,
  });

  final Album album;

  /// Oldest first — the order they are played in.
  final List<Memory> memories;

  @override
  ConsumerState<TimelapseScreen> createState() => _TimelapseScreenState();
}

class _TimelapseScreenState extends ConsumerState<TimelapseScreen> {
  /// Frames per second, and the speeds worth offering.
  static const speeds = [2.0, 4.0, 8.0, 12.0];

  /// How many frames ahead are decoded while the current one is up.
  static const _lookahead = 3;

  Timer? _timer;
  var _index = 0;
  var _speed = 4.0;
  var _playing = true;

  /// The files, resolved once, in the order they are played.
  ///
  /// Every memory's path is relative to the gallery directory, so a
  /// frame used to resolve its own file, check that it existed and
  /// decode it from scratch — twelve times a second, which showed the
  /// placeholder more often than the picture ([[Audit-v2]] U3-04).
  /// Resolving the whole album once costs one pass before playback and
  /// nothing after it.
  List<File?>? _files;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    final repository = ref.read(galleryRepositoryProvider);
    final files = <File?>[];
    for (final memory in widget.memories) {
      if (memory.kind == MemoryKind.video) {
        files.add(null);
        continue;
      }
      final file = await repository.fileOf(memory);
      files.add(file.existsSync() ? file : null);
    }
    if (!mounted) return;
    setState(() => _files = files);
    _start();
  }

  /// Decodes the frames just ahead, so the timer never waits on a disk.
  void _warm() {
    final files = _files;
    if (files == null || files.isEmpty) return;
    for (var i = 1; i <= _lookahead; i++) {
      final file = files[(_index + i) % files.length];
      if (file != null) unawaited(precacheImage(FileImage(file), context));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: (1000 / _speed).round()),
      (_) {
        setState(() {
          _index = _index + 1 >= widget.memories.length ? 0 : _index + 1;
        });
        _warm();
      },
    );
    _playing = true;
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _playing = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final memories = widget.memories;
    if (memories.isEmpty) return const SizedBox.shrink();
    final current = memories[_index.clamp(0, memories.length - 1)];
    final file = _files?[_index.clamp(0, memories.length - 1)];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        title: Text(widget.album.name, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // One image for the whole run, kept unkeyed and gapless
                // so a frame replaces the last outright instead of
                // blanking between the two.
                _Frame(file: file, memory: current),
                PositionedDirectional(
                  start: HarvestSpacing.md,
                  bottom: HarvestSpacing.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HarvestSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(HarvestRadii.chip),
                    ),
                    child: Text(
                      formatDay(context, current.day),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.only(
              left: HarvestSpacing.md,
              right: HarvestSpacing.md,
              top: HarvestSpacing.sm,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        color: Colors.white,
                        tooltip: _playing ? l10n.pause : l10n.galleryPlay,
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                        onPressed: () => setState(_playing ? _stop : _start),
                      ),
                      Expanded(
                        child: Slider(
                          value: _index.toDouble(),
                          max: (memories.length - 1).toDouble(),
                          onChanged: (value) => setState(() {
                            _stop();
                            _index = value.round();
                          }),
                        ),
                      ),
                      Text(
                        '${_index + 1}/${memories.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  // A label and four chips do not fit a 360 dp phone in
                  // one line, and in Arabic they fit less ([[Audit-v2]]
                  // U3-20). They wrap onto a second row instead.
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        l10n.gallerySpeed,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      for (final speed in speeds)
                        ChoiceChip(
                          label: Text(l10n.galleryFps(speed.round())),
                          selected: _speed == speed,
                          onSelected: (_) => setState(() {
                            _speed = speed;
                            if (_playing) _start();
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: HarvestSpacing.sm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One frame of the run.
///
/// A video has no still to show, and a file that has gone missing has
/// none either; both fall back to the same mark rather than an empty
/// black screen that looks like the end of the album.
class _Frame extends StatelessWidget {
  const _Frame({required this.file, required this.memory});

  final File? file;
  final Memory memory;

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      return Center(
        child: Icon(
          memory.kind == MemoryKind.video
              ? Icons.videocam_outlined
              : Icons.image_outlined,
          color: Colors.white38,
          size: 48,
        ),
      );
    }
    return Image.file(
      file!,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white38),
      ),
    );
  }
}
