// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assist_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What the signed-in server offers ([[ADR-013-Assist-Providers]]).
///
/// Asked once when the sheet opens, not kept: a server that gains a key
/// tomorrow should offer it tomorrow, and one that has none should not
/// be offered as a provider at all.

@ProviderFor(serverAssist)
final serverAssistProvider = ServerAssistProvider._();

/// What the signed-in server offers ([[ADR-013-Assist-Providers]]).
///
/// Asked once when the sheet opens, not kept: a server that gains a key
/// tomorrow should offer it tomorrow, and one that has none should not
/// be offered as a provider at all.

final class ServerAssistProvider
    extends
        $FunctionalProvider<
          AsyncValue<AssistProvider?>,
          AssistProvider?,
          FutureOr<AssistProvider?>
        >
    with $FutureModifier<AssistProvider?>, $FutureProvider<AssistProvider?> {
  /// What the signed-in server offers ([[ADR-013-Assist-Providers]]).
  ///
  /// Asked once when the sheet opens, not kept: a server that gains a key
  /// tomorrow should offer it tomorrow, and one that has none should not
  /// be offered as a provider at all.
  ServerAssistProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverAssistProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverAssistHash();

  @$internal
  @override
  $FutureProviderElement<AssistProvider?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AssistProvider?> create(Ref ref) {
    return serverAssist(ref);
  }
}

String _$serverAssistHash() => r'348c46c7cd46e8a084913d9a048c2cc9efc19e08';

/// The provider that answers: mine where I set one, the server's
/// otherwise, and none at all when neither is there.

@ProviderFor(assistProviderInUse)
final assistProviderInUseProvider = AssistProviderInUseProvider._();

/// The provider that answers: mine where I set one, the server's
/// otherwise, and none at all when neither is there.

final class AssistProviderInUseProvider
    extends
        $FunctionalProvider<
          AsyncValue<AssistProvider?>,
          AssistProvider?,
          FutureOr<AssistProvider?>
        >
    with $FutureModifier<AssistProvider?>, $FutureProvider<AssistProvider?> {
  /// The provider that answers: mine where I set one, the server's
  /// otherwise, and none at all when neither is there.
  AssistProviderInUseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assistProviderInUseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assistProviderInUseHash();

  @$internal
  @override
  $FutureProviderElement<AssistProvider?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AssistProvider?> create(Ref ref) {
    return assistProviderInUse(ref);
  }
}

String _$assistProviderInUseHash() =>
    r'c3f14ed32845d119e6ab4b39718bfeec7f32abeb';

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
