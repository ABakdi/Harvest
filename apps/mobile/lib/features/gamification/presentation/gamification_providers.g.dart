// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gamification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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

@ProviderFor(checkInCount)
final checkInCountProvider = CheckInCountProvider._();

final class CheckInCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  CheckInCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checkInCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checkInCountHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return checkInCount(ref);
  }
}

String _$checkInCountHash() => r'c0a4138b480ea09d448aa0ed90c1c373c6436df2';

@ProviderFor(dailyActivity)
final dailyActivityProvider = DailyActivityProvider._();

final class DailyActivityProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          Stream<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $StreamProvider<Map<String, int>> {
  DailyActivityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dailyActivityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dailyActivityHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, int>> create(Ref ref) {
    return dailyActivity(ref);
  }
}

String _$dailyActivityHash() => r'281145a458ffacf72927a921dabbe2dd2612d4aa';

@ProviderFor(commitmentStreaks)
final commitmentStreaksProvider = CommitmentStreaksProvider._();

final class CommitmentStreaksProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, ({int best, int current})>>,
          Map<String, ({int best, int current})>,
          Stream<Map<String, ({int best, int current})>>
        >
    with
        $FutureModifier<Map<String, ({int best, int current})>>,
        $StreamProvider<Map<String, ({int best, int current})>> {
  CommitmentStreaksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commitmentStreaksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commitmentStreaksHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, ({int best, int current})>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, ({int best, int current})>> create(Ref ref) {
    return commitmentStreaks(ref);
  }
}

String _$commitmentStreaksHash() => r'2db63fda312d78705961ec9c2e01139ebc402ed6';

/// The Harvest Days the current global streak is made of.
///
/// A streak is a run, and the engine already records both ends of it:
/// the day it was last earned and how many days long it is. Counting
/// back from one by the other is the whole set — including the days a
/// freeze covered, which are part of the streak whether or not anything
/// was logged on them.

@ProviderFor(streakDays)
final streakDaysProvider = StreakDaysProvider._();

/// The Harvest Days the current global streak is made of.
///
/// A streak is a run, and the engine already records both ends of it:
/// the day it was last earned and how many days long it is. Counting
/// back from one by the other is the whole set — including the days a
/// freeze covered, which are part of the streak whether or not anything
/// was logged on them.

final class StreakDaysProvider
    extends
        $FunctionalProvider<Set<HarvestDay>, Set<HarvestDay>, Set<HarvestDay>>
    with $Provider<Set<HarvestDay>> {
  /// The Harvest Days the current global streak is made of.
  ///
  /// A streak is a run, and the engine already records both ends of it:
  /// the day it was last earned and how many days long it is. Counting
  /// back from one by the other is the whole set — including the days a
  /// freeze covered, which are part of the streak whether or not anything
  /// was logged on them.
  StreakDaysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streakDaysProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streakDaysHash();

  @$internal
  @override
  $ProviderElement<Set<HarvestDay>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<HarvestDay> create(Ref ref) {
    return streakDays(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<HarvestDay> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<HarvestDay>>(value),
    );
  }
}

String _$streakDaysHash() => r'cf6cb77b84e9a71dfe8265e249a572236385e10a';

/// The last day the global streak was earned; null before the first.

@ProviderFor(lastEarnedDay)
final lastEarnedDayProvider = LastEarnedDayProvider._();

/// The last day the global streak was earned; null before the first.

final class LastEarnedDayProvider
    extends
        $FunctionalProvider<
          AsyncValue<HarvestDay?>,
          HarvestDay?,
          Stream<HarvestDay?>
        >
    with $FutureModifier<HarvestDay?>, $StreamProvider<HarvestDay?> {
  /// The last day the global streak was earned; null before the first.
  LastEarnedDayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastEarnedDayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastEarnedDayHash();

  @$internal
  @override
  $StreamProviderElement<HarvestDay?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<HarvestDay?> create(Ref ref) {
    return lastEarnedDay(ref);
  }
}

String _$lastEarnedDayHash() => r'098b106dc8b255cdfb24f821fdff7b94cb06cae0';

@ProviderFor(weeklyXp)
final weeklyXpProvider = WeeklyXpProvider._();

final class WeeklyXpProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  WeeklyXpProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weeklyXpProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weeklyXpHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return weeklyXp(ref);
  }
}

String _$weeklyXpHash() => r'32a11417aea9c6bc3c7ecee49a85936e144dc03b';
