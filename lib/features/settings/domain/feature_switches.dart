import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feature_switches.g.dart';

/// The halves of the app that are nobody's business unless asked for.
///
/// Notes, the Gallery, Health and the Gym are all **off until switched
/// on** (rules N1, G1, H1, Y1). Someone who came for a streak tracker
/// should reach their field without walking past any of them, and
/// turning one off hides its tab and stops its prompts — it never
/// deletes a thing.
///
/// They also pair up in the navigation bar: notes and pictures share
/// the Records tab, sleep and training share the Body tab. Five tabs is
/// the ceiling, and this is how four optional features fit under two.
abstract final class FeatureKeys {
  static const notes = 'features.notes';
  static const gallery = 'features.gallery';
  static const health = 'features.health';
  static const gym = 'features.gym';

  /// Asked in onboarding; every one of them defaults to no.
  static const Map<String, bool> defaults = {
    notes: false,
    gallery: false,
    health: false,
    gym: false,
  };
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

@riverpod
bool healthEnabled(Ref ref) =>
    ref.watch(featureSwitchesProvider).value?[FeatureKeys.health] ?? false;

@riverpod
bool gymEnabled(Ref ref) =>
    ref.watch(featureSwitchesProvider).value?[FeatureKeys.gym] ?? false;
