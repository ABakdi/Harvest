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
          AsyncValue<({int best, int current, int freezes})>,
          ({int best, int current, int freezes}),
          Stream<({int best, int current, int freezes})>
        >
    with
        $FutureModifier<({int best, int current, int freezes})>,
        $StreamProvider<({int best, int current, int freezes})> {
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
  $StreamProviderElement<({int best, int current, int freezes})> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<({int best, int current, int freezes})> create(Ref ref) {
    return globalStreak(ref);
  }
}

String _$globalStreakHash() => r'e7a97de60cdbf64d9fba712615a6ef71885b6062';

@ProviderFor(coinTotal)
final coinTotalProvider = CoinTotalProvider._();

final class CoinTotalProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  CoinTotalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coinTotalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coinTotalHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return coinTotal(ref);
  }
}

String _$coinTotalHash() => r'5de7c782932d0edeca79841574cd6a517f1ab578';
