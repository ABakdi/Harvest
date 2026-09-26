import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/ui/widgets/crop_card.dart';
import 'package:harvest/core/ui/widgets/reminder_countdown.dart';
import 'package:harvest/features/commitments/presentation/schedule_label.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/presentation/capture_sheet.dart';
import 'package:harvest/features/gamification/presentation/gamification_providers.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// A scheduled album, on the field, as a crop.
///
/// Rule G3: it is due like a habit is due, it wears the same card, and
/// tapping it opens the camera instead of a quantity sheet. The check-in
/// itself is the picture — there is nothing to tick.
class AlbumCropTile extends ConsumerWidget {
  const AlbumCropTile({
    required this.album,
    required this.done,
    super.key,
  });

  final Album album;
  final bool done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final remindAt = SettingsRepository.parseTime(album.remindAt);
    // A scheduled album keeps a streak like any other seed, and the
    // engine has kept it all along — the card just never showed it
    // ([[Gallery]], [[Audit-v2]] P3-07).
    final streak =
        (ref.watch(commitmentStreaksProvider).value ?? const {})[album.uuid];

    return CropCard(
      title: album.name,
      subtitle: scheduleLabel(context, l10n, album.schedule),
      icon: Icons.photo_camera_outlined,
      note: album.note,
      done: done,
      extra: streak == null || streak.current <= 0
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  l10n.streakCurrent(streak.current),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
      reminder: remindAt == null
          ? null
          : ReminderCountdown(
              hour: remindAt.$1,
              minute: remindAt.$2,
              silenced: done,
            ),
      onTap: () => unawaited(
        done
            ? context.push('${AppRoutes.gallery}/${album.uuid}')
            : showCaptureSheet(context, album: album),
      ),
      onOptions: () =>
          unawaited(context.push('${AppRoutes.gallery}/${album.uuid}')),
    );
  }
}
