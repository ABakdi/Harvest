import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/security/file_vault.dart';
import 'package:harvest/core/security/vault_image.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/presentation/sync_pin_sheet.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/data/memory_files.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
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

    // A file that lands — by a sync, or fetched for this very frame —
    // is looked for again.
    ref.watch(fileArrivalsProvider);
    final image = FutureBuilder<File>(
      future: ref.watch(galleryRepositoryProvider).fileOf(memory),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return placeholder;
        }
        if (file == null || !file.existsSync()) {
          return MemoryAbsent(
            key: ValueKey(memory.uuid),
            memory: memory,
            failed: false,
          );
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
          // Sealed on disk: opened in memory, never written out plain.
          builder: (context, constraints) => Image(
            image: ResizeImage.resizeIfNeeded(
              decodeWidth(context, constraints.maxWidth),
              null,
              VaultFileImage(file, ref.watch(fileVaultProvider)),
            ),
            fit: fit,
            gaplessPlayback: true,
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

/// Why a memory's picture is not here, in words ([[Gallery]] G9), or
/// null while it is on its way: not sent yet by the device that took
/// it, or waiting for the sync PIN. Share says the same.
String? memoryAbsentWords(
  AppLocalizations l10n,
  Memory memory, {
  required bool pinSet,
}) {
  if (memory.fileHash == null) return l10n.galleryFileNotSent;
  if (!pinSet) return l10n.galleryFileNeedsPin;
  return null;
}

/// Why a memory's picture is not here, in place of the picture
/// ([[Gallery]] G9): not sent yet by the device that took it, waiting
/// for the sync PIN, on its way down, or not loaded — with *Try again*.
/// Never a blank frame. A picture the server has is fetched the moment
/// it is shown, on its own, and drawn when it lands. In a thumbnail too
/// small for words, the icon says it and the words are its label.
class MemoryAbsent extends ConsumerStatefulWidget {
  const MemoryAbsent({required this.memory, required this.failed, super.key});

  final Memory memory;

  /// The file is here but would not draw.
  final bool failed;

  @override
  ConsumerState<MemoryAbsent> createState() => _MemoryAbsentState();
}

class _MemoryAbsentState extends ConsumerState<MemoryAbsent> {
  var _started = false;
  var _fetching = false;
  var _missing = false;

  void _fetch({bool retry = false, bool again = false}) {
    _started = true;
    setState(() {
      _fetching = true;
      _missing = false;
    });
    unawaited(
      ref
          .read(memoryFilesProvider)
          .fetch(widget.memory, retry: retry, again: again)
          .then((
            landed,
          ) {
            if (!mounted) return;
            setState(() {
              _fetching = false;
              _missing = !landed;
            });
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final memory = widget.memory;
    final pinSet = ref.watch(syncPassphraseProvider).value ?? false;
    final reachable = memory.fileHash != null && pinSet;
    if (!widget.failed && reachable && !_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetch();
      });
    }
    final waiting = !widget.failed && reachable && (_fetching || !_missing);

    final (
      IconData icon,
      String words,
      String? action,
      VoidCallback? onTap,
    ) = switch ((widget.failed, memory.fileHash, pinSet)) {
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
      _ when waiting => (
        Icons.cloud_download_outlined,
        l10n.galleryFileDownloading,
        null,
        null,
      ),
      _ => (
        Icons.broken_image_outlined,
        l10n.galleryFileFailed,
        reachable && !_fetching ? l10n.galleryFileRetry : null,
        reachable && !_fetching
            ? () => _fetch(retry: true, again: widget.failed)
            : null,
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
                  if (waiting) ...[
                    const SizedBox(height: 8),
                    const SizedBox(
                      width: 64,
                      child: LinearProgressIndicator(),
                    ),
                  ],
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
