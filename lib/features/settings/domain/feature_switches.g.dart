// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_switches.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which optional features are on, live.

@ProviderFor(featureSwitches)
final featureSwitchesProvider = FeatureSwitchesProvider._();

/// Which optional features are on, live.

final class FeatureSwitchesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, bool>>,
          Map<String, bool>,
          Stream<Map<String, bool>>
        >
    with
        $FutureModifier<Map<String, bool>>,
        $StreamProvider<Map<String, bool>> {
  /// Which optional features are on, live.
  FeatureSwitchesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureSwitchesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureSwitchesHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, bool>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, bool>> create(Ref ref) {
    return featureSwitches(ref);
  }
}

String _$featureSwitchesHash() => r'9cbc2926eff8bc715d9cc1ba8b640bcdfdc1a788';

@ProviderFor(notesEnabled)
final notesEnabledProvider = NotesEnabledProvider._();

final class NotesEnabledProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  NotesEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notesEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notesEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return notesEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$notesEnabledHash() => r'584b87924c459ad27fbb66158da7884270d686ba';

@ProviderFor(galleryEnabled)
final galleryEnabledProvider = GalleryEnabledProvider._();

final class GalleryEnabledProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  GalleryEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return galleryEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$galleryEnabledHash() => r'edf95c4221b162a4479cb1886a7169409b79064b';

@ProviderFor(healthEnabled)
final healthEnabledProvider = HealthEnabledProvider._();

final class HealthEnabledProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  HealthEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return healthEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$healthEnabledHash() => r'11bd9d12c7e1cc4807f648ccd913a779191d5f36';

@ProviderFor(gymEnabled)
final gymEnabledProvider = GymEnabledProvider._();

final class GymEnabledProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  GymEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gymEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gymEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return gymEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$gymEnabledHash() => r'a05238209aa9054a9fd156f6c5aa4b4ba6a4e8f5';
