// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gamification_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(gamificationRepository)
final gamificationRepositoryProvider = GamificationRepositoryProvider._();

final class GamificationRepositoryProvider
    extends
        $FunctionalProvider<
          GamificationRepository,
          GamificationRepository,
          GamificationRepository
        >
    with $Provider<GamificationRepository> {
  GamificationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gamificationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gamificationRepositoryHash();

  @$internal
  @override
  $ProviderElement<GamificationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GamificationRepository create(Ref ref) {
    return gamificationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GamificationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GamificationRepository>(value),
    );
  }
}

String _$gamificationRepositoryHash() =>
    r'ff58c7ce98ae48444f3393bde0450438e9257551';

@ProviderFor(xpTotal)
final xpTotalProvider = XpTotalProvider._();

final class XpTotalProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  XpTotalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'xpTotalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$xpTotalHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return xpTotal(ref);
  }
}

String _$xpTotalHash() => r'a612be27aabaa2f742d6385cc7bfb18160f22ccb';

@ProviderFor(globalStreak)
final globalStreakProvider = GlobalStreakProvider._();

final class GlobalStreakProvider
    extends
        $FunctionalProvider<
          AsyncValue<({int best, int current})>,
          ({int best, int current}),
          Stream<({int best, int current})>
        >
    with
        $FutureModifier<({int best, int current})>,
        $StreamProvider<({int best, int current})> {
  GlobalStreakProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'globalStreakProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$globalStreakHash();

  @$internal
  @override
  $StreamProviderElement<({int best, int current})> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<({int best, int current})> create(Ref ref) {
    return globalStreak(ref);
  }
}

String _$globalStreakHash() => r'845714106f95816ccabb62f9d418d734bd68fa24';
