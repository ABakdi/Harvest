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

  /// How wide to decode a picture drawn into [width] logical pixels.
  ///
  /// A phone camera's 1600 px frame costs about 7.7 MB decoded whether
  /// it fills the screen or a 44 dp thumbnail, and a three-column grid
  /// of those walks straight past the 100 MB image cache and re-decodes
  /// as it scrolls ([[Audit-v2]] U3-05). Decoding at the size actually
  /// drawn — device pixels, so it is still sharp — is the whole fix.
  ///
  /// Null when the width is unbounded or nonsense: better a full-size
  /// decode than a one-pixel one.
  static int? decodeWidth(BuildContext context, double width) {
    if (!width.isFinite || width <= 0) return null;
    final pixels = width * MediaQuery.devicePixelRatioOf(context);
    return pixels.isFinite && pixels >= 1 ? pixels.ceil() : null;
  }

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
        // The width comes from the layout rather than the caller, so
        // every place that draws a memory — the grid, the compare
        // strip, the album covers — gets the right decode without
        // having to know its own size.
        return LayoutBuilder(
          builder: (context, constraints) => Image.file(
            file,
            fit: fit,
            gaplessPlayback: true,
            cacheWidth: decodeWidth(context, constraints.maxWidth),
            errorBuilder: (context, error, stack) => placeholder,
          ),
        );
      },
    );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
