import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/features/gym/data/exercise_media.dart';
import 'package:harvest/features/gym/domain/exercise.dart';

/// An exercise's picture, if it can be had.
///
/// Fetches on first sight and caches forever; falls back to a quiet
/// placeholder when there is no network, no media, or fetching is
/// switched off. A missing picture is an ordinary state, never an
/// error — the gym works completely on words
/// ([[ADR-008-Exercise-Catalogue]]).
class ExerciseImage extends ConsumerStatefulWidget {
  const ExerciseImage({
    required this.exercise,
    this.kind = MediaKind.thumbnail,
    this.size,
    this.borderRadius,
    this.fetch = true,
    super.key,
  });

  final Exercise exercise;
  final MediaKind kind;
  final double? size;
  final BorderRadius? borderRadius;

  /// Whether a picture that is not on disk may be fetched. A list says
  /// no: scrolling a catalogue of 1,324 exercises would otherwise ask
  /// the network for a screenful on every keystroke, and `get` does not
  /// de-duplicate ([[Audit-v2]] U3-06). The detail screen says yes.
  final bool fetch;

  @override
  ConsumerState<ExerciseImage> createState() => _ExerciseImageState();
}

class _ExerciseImageState extends ConsumerState<ExerciseImage> {
  /// Made once per exercise rather than on every build: a future built
  /// in `build` is a new fetch each time the list rebuilds.
  Future<File?>? _file;
  String? _for;

  Future<File?> _load(String stem) {
    final key = '$stem/${widget.kind.name}/${widget.fetch}';
    if (_for == key && _file != null) return _file!;
    _for = key;
    final media = ref.read(exerciseMediaProvider);
    return _file = widget.fetch
        ? media.get(stem, widget.kind)
        : media.cached(stem, widget.kind);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = widget.size;
    final borderRadius = widget.borderRadius;
    final stem = widget.exercise.mediaStem;

    final placeholder = ColoredBox(
      color: scheme.secondary.withValues(alpha: 0.12),
      child: Center(
        child: Icon(
          Icons.fitness_center,
          size: (size ?? 48) * 0.45,
          color: scheme.secondary,
        ),
      ),
    );

    Widget wrap(Widget child) {
      final sized = size == null
          ? child
          : SizedBox(width: size, height: size, child: child);
      return borderRadius == null
          ? sized
          : ClipRRect(borderRadius: borderRadius, child: sized);
    }

    if (stem == null) return wrap(placeholder);

    return wrap(
      FutureBuilder<File?>(
        future: _load(stem),
        builder: (context, snapshot) {
          final file = snapshot.data;
          if (file == null || !file.existsSync()) return placeholder;
          return Image.file(
            file,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => placeholder,
          );
        },
      ),
    );
  }
}

/// The line the licence asks for, wherever the media appears.
class MediaAttribution extends StatelessWidget {
  const MediaAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      mediaAttribution,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
