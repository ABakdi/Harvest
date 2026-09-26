import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:harvest/features/places/presentation/places_providers.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The "where was it" line under an expense, a note, a picture, a
/// check-in or a session ([[Places]]).
///
/// A pin, the name of the saved place it falls in — or its coordinates
/// when it has none — and the time. Tapping it takes the map to that
/// day, on that pin. When the geotag never found a fix (PL3), the line
/// is a quiet "no location recorded" instead; while it is still
/// looking, and when there is no geotag at all, there is no line.
class GeotagChip extends ConsumerWidget {
  const GeotagChip({
    required this.targetTable,
    required this.targetUuid,
    this.onDark = false,
    super.key,
  });

  /// Whether [geotag] draws a line at all: a pin, or a settled "no
  /// location". A geotag still waiting for its fix says nothing yet —
  /// it may well find one.
  static bool shows(Geotag? geotag) =>
      geotag != null &&
      (geotag.hasPlace || geotag.state != GeotagState.pending);

  /// Drawn over a black bar (the photo viewer) rather than the theme's
  /// surface, so the text and icon stay light in the light theme too.
  final bool onDark;

  /// The action table the geotag points at: `expenses`, `notes`,
  /// `memories`, `check_ins`, `workout_sessions`…
  final String targetTable;

  /// The row's own uuid inside that table.
  final String targetUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final geotag = ref
        .watch(
          geotagForProvider((table: targetTable, uuid: targetUuid)),
        )
        .value;
    if (geotag == null || !shows(geotag)) return const SizedBox.shrink();

    final hasPlace = geotag.hasPlace;
    // The map only opens while Places is on; a link that can't be
    // followed must not leave a request waiting for the next visit.
    final canOpen = hasPlace && ref.watch(placesEnabledProvider);
    String label;
    if (hasPlace) {
      final saved = ref.watch(savedPlacesProvider).value ?? const [];
      final name = saved
          .where(
            (place) => place.contains(geotag.latitude!, geotag.longitude!),
          )
          .map((place) => place.name)
          .firstOrNull;
      final time = TimeOfDay.fromDateTime(geotag.at).format(context);
      label = l10n.geoWhere(
        name ?? '${_coord(geotag.latitude!)}, ${_coord(geotag.longitude!)}',
        time,
      );
    } else {
      label = l10n.geoUnavailable;
    }

    return InkWell(
      onTap: canOpen
          ? () {
              ref.read(placesFocusRequestProvider.notifier).focus =
                  PlacesFocus(
                    day: geotag.day,
                    table: targetTable,
                    uuid: targetUuid,
                  );
              unawaited(context.push(AppRoutes.places));
            }
          : null,
      borderRadius: BorderRadius.circular(HarvestRadii.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HarvestSpacing.xs,
          vertical: HarvestSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasPlace ? Icons.place_outlined : Icons.location_off_outlined,
              size: 15,
              color: hasPlace
                  ? const Color(0xFFEA4335)
                  : onDark
                  ? Colors.white54
                  : scheme.outline,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: onDark ? Colors.white70 : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _coord(double value) => value.toStringAsFixed(4);
}
