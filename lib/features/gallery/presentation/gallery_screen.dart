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
import 'package:harvest/features/gallery/presentation/memory_view.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Every album, with what it holds and what it costs.
///
/// The size is on the card rather than in a settings screen nobody
/// opens: a feature that quietly eats a phone should say so while it is
/// eating it (rule G4).
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
            Padding(
              padding: const EdgeInsetsDirectional.only(end: HarvestSpacing.md),
              child: Center(
                child: Text(
                  formatBytes(total),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: HarvestFab(
        onPressed: () => unawaited(showAlbumSheet(context)),
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

    return Card(
      margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(
          context.push('${AppRoutes.gallery}/${album.uuid}'),
        ),
        child: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.md),
          child: Row(
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: summary.latest == null
                    ? Container(
                        decoration: BoxDecoration(
                          color: scheme.tertiary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            HarvestRadii.chip,
                          ),
                        ),
                        child: Icon(
                          Icons.photo_camera_outlined,
                          color: scheme.tertiary,
                        ),
                      )
                    : MemoryView(
                        memory: summary.latest!,
                        borderRadius: BorderRadius.circular(HarvestRadii.chip),
                      ),
              ),
              const SizedBox(width: HarvestSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
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
                        if (album.isScheduled && summary.doneToday)
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: scheme.secondary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.galleryAlbumCount(summary.count),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (album.isScheduled) ...[
                          Icon(Icons.repeat, size: 13, color: scheme.secondary),
                          const SizedBox(width: 3),
                          Text(
                            l10n.galleryIsSeed,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: HarvestSpacing.sm),
                        ],
                        if (summary.bytes > 0)
                          Text(
                            formatBytes(summary.bytes),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        if (summary.latest != null) ...[
                          const SizedBox(width: HarvestSpacing.sm),
                          Text(
                            formatDay(context, summary.latest!.day),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
