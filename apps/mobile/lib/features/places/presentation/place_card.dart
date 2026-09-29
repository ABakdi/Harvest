import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// One saved place, shown when its pin is tapped: the name, the note
/// it carries, and Edit and Forget.
class SavedPlaceCard extends StatelessWidget {
  const SavedPlaceCard({required this.place, super.key});

  final SavedPlace place;

  String _coord(double value) => value.toStringAsFixed(4);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.md,
          HarvestSpacing.xs,
          HarvestSpacing.md,
          HarvestSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.place, color: Color(0xFFEA4335)),
                const SizedBox(width: HarvestSpacing.sm),
                Expanded(
                  child: Text(
                    place.name,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (place.notes case final notes? when notes.isNotEmpty) ...[
              const SizedBox(height: HarvestSpacing.sm),
              Text(notes, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: HarvestSpacing.sm),
            Text(
              '${_coord(place.latitude)}, ${_coord(place.longitude)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: HarvestSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, 'forget'),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.placesForgetPlace),
                ),
                const SizedBox(width: HarvestSpacing.sm),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, 'edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.placesEditPlace),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
