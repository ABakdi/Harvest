import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feature_switches.g.dart';

/// The halves of the app that are nobody's business unless asked for.
///
/// Notes and the Gallery are **off until switched on** (rules N1, G1).
/// Someone who came for a streak tracker should reach their field
/// without walking past either, and turning one off hides its tab and
/// stops its prompts — it never deletes a thing.
abstract final class FeatureKeys {
  static const notes = 'features.notes';
  static const gallery = 'features.gallery';

  /// Asked in onboarding; both default to no.
  static const Map<String, bool> defaults = {notes: false, gallery: false};
}

/// Which optional features are on, live.
@Riverpod(keepAlive: true)
Stream<Map<String, bool>> featureSwitches(Ref ref) => ref
    .watch(settingsRepositoryProvider)
    .watchAll(FeatureKeys.defaults.keys.toList())
    .map(
      (values) => {
        for (final entry in FeatureKeys.defaults.entries)
          entry.key: switch (values[entry.key]) {
            'true' => true,
            'false' => false,
            _ => entry.value,
          },
      },
    );

@riverpod
bool notesEnabled(Ref ref) =>
    ref.watch(featureSwitchesProvider).value?[FeatureKeys.notes] ?? false;

@riverpod
bool galleryEnabled(Ref ref) =>
    ref.watch(featureSwitchesProvider).value?[FeatureKeys.gallery] ?? false;
