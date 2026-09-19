// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assist_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(secretStore)
final secretStoreProvider = SecretStoreProvider._();

final class SecretStoreProvider
    extends $FunctionalProvider<SecretStore, SecretStore, SecretStore>
    with $Provider<SecretStore> {
  SecretStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secretStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secretStoreHash();

  @$internal
  @override
  $ProviderElement<SecretStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecretStore create(Ref ref) {
    return secretStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecretStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecretStore>(value),
    );
  }
}

String _$secretStoreHash() => r'eb0b7784f35ec0fb86eda263d033d31ef3ae7d59';

/// Reads and writes the assist's configuration.

@ProviderFor(AssistSettings)
final assistSettingsProvider = AssistSettingsProvider._();

/// Reads and writes the assist's configuration.
final class AssistSettingsProvider
    extends $AsyncNotifierProvider<AssistSettings, AssistConfig> {
  /// Reads and writes the assist's configuration.
  AssistSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assistSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assistSettingsHash();

  @$internal
  @override
  AssistSettings create() => AssistSettings();
}

String _$assistSettingsHash() => r'32ec167037614ae2eebe81ec423370ac17f828f4';

/// Reads and writes the assist's configuration.

abstract class _$AssistSettings extends $AsyncNotifier<AssistConfig> {
  FutureOr<AssistConfig> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AssistConfig>, AssistConfig>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AssistConfig>, AssistConfig>,
              AsyncValue<AssistConfig>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
