import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The two halves of the app that stay out of the way until asked for.
///
/// Turning one off hides its tab and stops its prompts. It never
/// deletes a note or a picture, and the switch says so — otherwise
/// nobody would dare touch it (rules N1 and G1).
class FeaturesCard extends ConsumerWidget {
  const FeaturesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notes = ref.watch(notesEnabledProvider);
    final gallery = ref.watch(galleryEnabledProvider);

    Future<void> set(String key, {required bool on}) async {
      await HarvestHaptics.tick();
      await ref.read(settingsRepositoryProvider).setBool(key, value: on);
    }

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.description_outlined),
            title: Text(l10n.featureNotes),
            subtitle: Text(l10n.featureNotesHint),
            value: notes,
            onChanged: (on) => set(FeatureKeys.notes, on: on),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.featureGallery),
            subtitle: Text(l10n.featureGalleryHint),
            value: gallery,
            onChanged: (on) => set(FeatureKeys.gallery, on: on),
          ),
          if (gallery) const _GallerySize(),
        ],
      ),
    );
  }
}

/// What the gallery is costing, in the place the switch is (rule G4:
/// storage is shown, not discovered).
class _GallerySize extends ConsumerWidget {
  const _GallerySize();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<int>(
      future: ref.watch(galleryStorageProvider).totalBytes(),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes == 0) return const SizedBox.shrink();
        return ListTile(
          dense: true,
          leading: const SizedBox(width: 24),
          title: Text(l10n.featureGallerySize(formatBytes(bytes))),
          titleTextStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}
