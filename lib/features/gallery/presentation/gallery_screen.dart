import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/harvest_fab.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/presentation/album_sheet.dart';
import 'package:harvest/features/gallery/presentation/gallery_providers.dart';
import 'package:harvest/features/gallery/presentation/gallery_trash_screen.dart';
import 'package:harvest/features/gallery/presentation/memory_view.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Every album, with what it holds and what it costs.
///
/// The card leads with the last picture at a size worth looking at,
/// because that is the album — the name is a label on it. The size is
/// here rather than in a settings screen nobody opens: a feature that
/// quietly eats a phone should say so while it is eating it (rule G4).
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final summaries = ref.watch(albumSummariesProvider).value;
    final total = summaries?.fold(0, (sum, s) => sum + s.bytes) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.galleryTitle),
        actions: [
          if (total > 0)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  formatBytes(total),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: l10n.trashTitle,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GalleryTrashScreen(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: HarvestFab(
        onPressed: () => showAlbumSheet(context).ignore(),
        label: l10n.galleryNewAlbum,
      ),
      body: summaries == null
          ? const Center(child: CircularProgressIndicator())
          : summaries.isEmpty
          ? EmptyState(
              icon: Icons.photo_library_outlined,
              title: l10n.galleryEmpty,
              body: l10n.galleryEmptyBody,
              color: theme.colorScheme.tertiary,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                HarvestSpacing.md,
                HarvestSpacing.md,
                HarvestSpacing.md,
                96,
              ),
              children: [
                for (final summary in summaries)
                  _AlbumCard(summary: summary),
              ],
            ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.summary});

  final AlbumSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final album = summary.album;
    final latest = summary.latest;

    return Card(
      margin: const EdgeInsets.only(bottom: HarvestSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(
          context.push('${AppRoutes.gallery}/${album.uuid}'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The cover: the last picture, big enough to be the reason
            // I tap it. An empty album gets a quiet invitation instead.
            AspectRatio(
              aspectRatio: 16 / 9,
              child: latest == null
                  ? ColoredBox(
                      color: scheme.tertiary.withValues(alpha: 0.10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 30,
                            color: scheme.tertiary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.galleryAlbumEmpty,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.tertiary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        MemoryView(memory: latest),
                        // A scrim only where the text sits, so the
                        // picture is not dimmed for the sake of a label.
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.center,
                              colors: [Color(0xB3000000), Color(0x00000000)],
                            ),
                          ),
                        ),
                        Positioned(
                          left: HarvestSpacing.md,
                          right: HarvestSpacing.md,
                          bottom: HarvestSpacing.sm,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  album.name,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    shadows: const [
                                      Shadow(blurRadius: 8, color: Colors.black54),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (album.isScheduled)
                                _Pill(
                                  icon: summary.doneToday
                                      ? Icons.check_circle
                                      : Icons.repeat,
                                  label: summary.doneToday
                                      ? l10n.galleryDoneToday
                                      : l10n.galleryIsSeed,
                                  tint: summary.doneToday
                                      ? scheme.secondary
                                      : Colors.white,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HarvestSpacing.md,
                HarvestSpacing.sm,
                HarvestSpacing.sm,
                HarvestSpacing.sm,
              ),
              child: Row(
                children: [
                  if (latest == null) ...[
                    Expanded(
                      child: Text(
                        album.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        [
                          l10n.galleryAlbumCount(summary.count),
                          if (summary.bytes > 0) formatBytes(summary.bytes),
                          formatDay(context, latest.day),
                        ].join('  ·  '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small label over a picture: readable on anything underneath.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.tint});

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: tint),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: tint,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
