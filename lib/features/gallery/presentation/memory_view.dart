import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';

/// One memory's file, drawn.
///
/// The row stores a path relative to the gallery directory, so every
/// picture has to be resolved through the repository before it can be
/// shown — that indirection is what lets the app's storage move without
/// orphaning a year of photographs.
class MemoryView extends ConsumerWidget {
  const MemoryView({
    required this.memory,
    this.fit = BoxFit.cover,
    this.borderRadius,
    super.key,
  });

  final Memory memory;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.onSurface.withValues(alpha: 0.06),
      child: Center(
        child: Icon(
          memory.kind == MemoryKind.video
              ? Icons.videocam_outlined
              : Icons.image_outlined,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );

    final image = FutureBuilder<File>(
      future: ref.watch(galleryRepositoryProvider).fileOf(memory),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null || !file.existsSync()) return placeholder;
        if (memory.kind == MemoryKind.video) {
          return Stack(
            fit: StackFit.expand,
            children: [
              placeholder,
              const Center(
                child: Icon(Icons.play_circle_fill, size: 34, color: Colors.white70),
              ),
            ],
          );
        }
        return Image.file(
          file,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => placeholder,
        );
      },
    );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
