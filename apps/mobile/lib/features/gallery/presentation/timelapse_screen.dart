import 'dart:async';

import 'package:flutter/material.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/presentation/memory_view.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The album, played: one frame per memory, oldest first.
///
/// This is the point of the whole feature (spec: *Play*), so it is one
/// tap from the album and it does exactly one thing — no export, no
/// rendering, no waiting. The frames are already on the phone; playing
/// them is a timer and an index.
class TimelapseScreen extends StatefulWidget {
  const TimelapseScreen({
    required this.album,
    required this.memories,
    super.key,
  });

  final Album album;

  /// Oldest first — the order they are played in.
  final List<Memory> memories;

  @override
  State<TimelapseScreen> createState() => _TimelapseScreenState();
}

class _TimelapseScreenState extends State<TimelapseScreen> {
  /// Frames per second, and the speeds worth offering.
  static const speeds = [2.0, 4.0, 8.0, 12.0];

  Timer? _timer;
  var _index = 0;
  var _speed = 4.0;
  var _playing = true;

  @override
  void initState() {
    super.initState();
    _start();
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
      (_) => setState(() {
        _index = _index + 1 >= widget.memories.length ? 0 : _index + 1;
      }),
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
                // Keyed so each frame replaces the last outright — a
                // timelapse that cross-fades is a slideshow, not a run.
                MemoryView(
                  key: ValueKey(current.uuid),
                  memory: current,
                  fit: BoxFit.contain,
                ),
                Positioned(
                  left: HarvestSpacing.md,
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
            padding: const EdgeInsets.fromLTRB(
              HarvestSpacing.md,
              HarvestSpacing.sm,
              HarvestSpacing.md,
              0,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        color: Colors.white,
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                        onPressed: () =>
                            setState(_playing ? _stop : _start),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.gallerySpeed,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: HarvestSpacing.sm),
                      for (final speed in speeds)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            label: Text(l10n.galleryFps(speed.round())),
                            selected: _speed == speed,
                            onSelected: (_) => setState(() {
                              _speed = speed;
                              if (_playing) _start();
                            }),
                          ),
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
