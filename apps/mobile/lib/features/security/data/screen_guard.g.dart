// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_guard.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(screenGuard)
final screenGuardProvider = ScreenGuardProvider._();

final class ScreenGuardProvider
    extends $FunctionalProvider<ScreenGuard, ScreenGuard, ScreenGuard>
    with $Provider<ScreenGuard> {
  ScreenGuardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'screenGuardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$screenGuardHash();

  @$internal
  @override
  $ProviderElement<ScreenGuard> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ScreenGuard create(Ref ref) {
    return screenGuard(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScreenGuard value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScreenGuard>(value),
    );
  }
}

String _$screenGuardHash() => r'23338ab43c09bb402452a047228e2c48de7d97cb';
