import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/features/gallery/domain/gallery.dart' show formatBytes;
import 'package:harvest/features/gym/data/exercise_catalogue.dart';
import 'package:harvest/features/gym/data/exercise_media.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// What the exercise pictures cost, and the two switches around them.
///
/// The animations are the only thing in this app that reaches the
/// network without being an export I tapped ([[Business-Rules]] #13),
/// so the controls for it are in plain sight rather than implied: what
/// it has downloaded, a way to get the rest before a trip, a way to
/// never fetch at all, and a way to throw the lot away.
class ExerciseMediaCard extends ConsumerStatefulWidget {
  const ExerciseMediaCard({super.key});

  @override
  ConsumerState<ExerciseMediaCard> createState() => _ExerciseMediaCardState();
}

class _ExerciseMediaCardState extends ConsumerState<ExerciseMediaCard> {
  int? _bytes;
  bool? _neverFetch;
  var _downloading = false;
  var _cancelled = false;
  var _done = 0;
  var _total = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final media = ref.read(exerciseMediaProvider);
    final bytes = await media.cacheBytes();
    final never = await media.neverFetch;
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _neverFetch = never;
    });
  }

  Future<void> _downloadAll() async {
    final l10n = AppLocalizations.of(context);
    final catalogue = await ref.read(exerciseCatalogueProvider.future);
    final stems = [
      for (final exercise in catalogue.all) ?exercise.mediaStem,
    ];
    if (!mounted) return;

    // It says what it will cost before it starts. About 93 KB an
    // animation, which is a number worth seeing before agreeing.
    final ok = await confirm(
      context,
      title: l10n.gymDownloadAll,
      body: l10n.gymDownloadAllBody(
        stems.length,
        formatBytes(stems.length * 93000),
      ),
      confirmLabel: l10n.gymDownloadAll,
    );
    if (!ok || !mounted) return;

    setState(() {
      _downloading = true;
      _cancelled = false;
      _done = 0;
      _total = stems.length;
    });
    await ref
        .read(exerciseMediaProvider)
        .fetchAll(
          stems,
          onProgress: (done, total) {
            if (mounted) setState(() => _done = done);
          },
          cancelled: () => _cancelled,
        );
    if (!mounted) return;
    setState(() => _downloading = false);
    await _refresh();
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.gymClearMedia,
      body: l10n.gymClearMediaBody,
      confirmLabel: l10n.gymClearMedia,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(exerciseMediaProvider).clearCache();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final never = _neverFetch ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.image_outlined),
                const SizedBox(width: HarvestSpacing.md),
                Expanded(child: Text(l10n.gymMediaTitle)),
                if (_bytes != null && _bytes! > 0)
                  Text(
                    formatBytes(_bytes!),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: HarvestSpacing.xs),
            Text(l10n.gymMediaBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: HarvestSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.gymNeverFetch),
              subtitle: Text(l10n.gymNeverFetchHint),
              value: never,
              onChanged: (value) async {
                await ref
                    .read(exerciseMediaProvider)
                    .setNeverFetch(value: value);
                await _refresh();
              },
            ),
            if (_downloading) ...[
              LinearProgressIndicator(
                value: _total == 0 ? null : _done / _total,
              ),
              const SizedBox(height: HarvestSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.gymDownloadProgress(_done, _total),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _cancelled = true),
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: never ? null : () => unawaited(_downloadAll()),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(l10n.gymDownloadAll),
                    ),
                  ),
                  if ((_bytes ?? 0) > 0) ...[
                    const SizedBox(width: HarvestSpacing.sm),
                    TextButton(
                      onPressed: () => unawaited(_clear()),
                      child: Text(l10n.gymClearMedia),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: HarvestSpacing.xs),
            Text(
              l10n.gymMediaAttribution(mediaAttribution),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
