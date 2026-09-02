// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'streak_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(streakService)
final streakServiceProvider = StreakServiceProvider._();

final class StreakServiceProvider
    extends $FunctionalProvider<StreakService, StreakService, StreakService>
    with $Provider<StreakService> {
  StreakServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streakServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streakServiceHash();

  @$internal
  @override
  $ProviderElement<StreakService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StreakService create(Ref ref) {
    return streakService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StreakService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StreakService>(value),
    );
  }
}

String _$streakServiceHash() => r'523b00220c6177b907b6a480beaae1c4b03f0ea1';
