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
class ExerciseImage extends ConsumerWidget {
  const ExerciseImage({
    required this.exercise,
    this.kind = MediaKind.thumbnail,
    this.size,
    this.borderRadius,
    super.key,
  });

  final Exercise exercise;
  final MediaKind kind;
  final double? size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final stem = exercise.mediaStem;

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
          : ClipRRect(borderRadius: borderRadius!, child: sized);
    }

    if (stem == null) return wrap(placeholder);

    return wrap(
      FutureBuilder<File?>(
        future: ref.watch(exerciseMediaProvider).get(stem, kind),
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
