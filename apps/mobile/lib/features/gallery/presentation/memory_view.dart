import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/presentation/sync_pin_sheet.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/sync/presentation/sync_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';

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
        if (snapshot.connectionState != ConnectionState.done) {
          return placeholder;
        }
        if (file == null || !file.existsSync()) {
          return MemoryAbsent(memory: memory, failed: false);
        }
        if (memory.kind == MemoryKind.video) {
          return Stack(
            fit: StackFit.expand,
            children: [
              placeholder,
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 34,
                  color: Colors.white70,
                ),
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
            errorBuilder: (context, error, stack) =>
                MemoryAbsent(memory: memory, failed: true),
          ),
        );
      },
    );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}

/// Why a memory's picture is not here, in place of the picture
/// ([[Gallery]] G9): not sent yet by the device that took it, waiting
/// for the sync PIN, or not loaded — with *Try again*. Never a blank
/// frame. In a thumbnail too small for words, the icon says it and the
/// words are its label.
class MemoryAbsent extends ConsumerWidget {
  const MemoryAbsent({required this.memory, required this.failed, super.key});

  final Memory memory;

  /// The file is here but would not draw.
  final bool failed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pinSet = ref.watch(syncPassphraseProvider).value ?? false;

    final (
      IconData icon,
      String words,
      String? action,
      VoidCallback? onTap,
    ) = switch ((failed, memory.fileHash, pinSet)) {
      (false, null, _) => (
        Icons.cloud_upload_outlined,
        l10n.galleryFileNotSent,
        null,
        null,
      ),
      (false, _, false) => (
        Icons.lock_outline,
        l10n.galleryFileNeedsPin,
        l10n.syncPinSetAction,
        () => unawaited(showSyncPinSheet(context)),
      ),
      _ => (
        Icons.broken_image_outlined,
        l10n.galleryFileFailed,
        l10n.galleryFileRetry,
        () => unawaited(ref.read(syncControllerProvider.notifier).syncNow()),
      ),
    };

    return ColoredBox(
      color: scheme.onSurface.withValues(alpha: 0.06),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final roomy =
              constraints.maxWidth >= 140 && constraints.maxHeight >= 120;
          final mark = Icon(icon, color: scheme.onSurfaceVariant);
          if (!roomy) {
            return Semantics(
              label: words,
              button: onTap != null,
              child: Tooltip(
                message: words,
                child: InkWell(
                  onTap: onTap,
                  child: Center(child: ExcludeSemantics(child: mark)),
                ),
              ),
            );
          }
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  mark,
                  const SizedBox(height: 6),
                  Text(
                    words,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (action != null && onTap != null)
                    TextButton(onPressed: onTap, child: Text(action)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
