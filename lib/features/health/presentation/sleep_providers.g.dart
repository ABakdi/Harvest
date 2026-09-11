// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sleepNights)
final sleepNightsProvider = SleepNightsProvider._();

final class SleepNightsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SleepNight>>,
          List<SleepNight>,
          Stream<List<SleepNight>>
        >
    with $FutureModifier<List<SleepNight>>, $StreamProvider<List<SleepNight>> {
  SleepNightsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepNightsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepNightsHash();

  @$internal
  @override
  $StreamProviderElement<List<SleepNight>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SleepNight>> create(Ref ref) {
    return sleepNights(ref);
  }
}

String _$sleepNightsHash() => r'6758fb9b4eda9ae5fc231d40441756e8bfce4e7d';

/// The night I mean to have, per weekday, over the daily cycle.

@ProviderFor(sleepTargets)
final sleepTargetsProvider = SleepTargetsProvider._();

/// The night I mean to have, per weekday, over the daily cycle.

final class SleepTargetsProvider
    extends
        $FunctionalProvider<
          AsyncValue<SleepTargets>,
          SleepTargets,
          Stream<SleepTargets>
        >
    with $FutureModifier<SleepTargets>, $StreamProvider<SleepTargets> {
  /// The night I mean to have, per weekday, over the daily cycle.
  SleepTargetsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepTargetsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepTargetsHash();

  @$internal
  @override
  $StreamProviderElement<SleepTargets> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SleepTargets> create(Ref ref) {
    return sleepTargets(ref);
  }
}

String _$sleepTargetsHash() => r'6b63149c272ac05cbec72b6e39ae6419916f028a';

/// What is owed, over the last two weeks.

@ProviderFor(sleepDebtNow)
final sleepDebtNowProvider = SleepDebtNowProvider._();

/// What is owed, over the last two weeks.

final class SleepDebtNowProvider
    extends
        $FunctionalProvider<AsyncValue<SleepDebt>, SleepDebt, Stream<SleepDebt>>
    with $FutureModifier<SleepDebt>, $StreamProvider<SleepDebt> {
  /// What is owed, over the last two weeks.
  SleepDebtNowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepDebtNowProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepDebtNowHash();

  @$internal
  @override
  $StreamProviderElement<SleepDebt> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<SleepDebt> create(Ref ref) {
    return sleepDebtNow(ref);
  }
}

String _$sleepDebtNowHash() => r'015f39781989879f61d80f5d4469f722f92c97e6';

/// Whether last night is still waiting to be written down.

@ProviderFor(sleepUnlogged)
final sleepUnloggedProvider = SleepUnloggedProvider._();

/// Whether last night is still waiting to be written down.

final class SleepUnloggedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether last night is still waiting to be written down.
  SleepUnloggedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepUnloggedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepUnloggedHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return sleepUnlogged(ref);
  }
}

String _$sleepUnloggedHash() => r'8e2689b9ed224d46eea0c9668b202b11b957c0ce';

/// Whether the alarm rings at all. Off until it is asked for — an app
/// that appoints itself your alarm clock without being asked is an app
/// you uninstall.

@ProviderFor(SleepAlarmOn)
final sleepAlarmOnProvider = SleepAlarmOnProvider._();

/// Whether the alarm rings at all. Off until it is asked for — an app
/// that appoints itself your alarm clock without being asked is an app
/// you uninstall.
final class SleepAlarmOnProvider
    extends $StreamNotifierProvider<SleepAlarmOn, bool> {
  /// Whether the alarm rings at all. Off until it is asked for — an app
  /// that appoints itself your alarm clock without being asked is an app
  /// you uninstall.
  SleepAlarmOnProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepAlarmOnProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepAlarmOnHash();

  @$internal
  @override
  SleepAlarmOn create() => SleepAlarmOn();
}

String _$sleepAlarmOnHash() => r'1e37e6e2aa38a64cdfd13e397c1e00034bf48679';

/// Whether the alarm rings at all. Off until it is asked for — an app
/// that appoints itself your alarm clock without being asked is an app
/// you uninstall.

abstract class _$SleepAlarmOn extends $StreamNotifier<bool> {
  Stream<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether anything is said before bedtime.

@ProviderFor(SleepWindDownOn)
final sleepWindDownOnProvider = SleepWindDownOnProvider._();

/// Whether anything is said before bedtime.
final class SleepWindDownOnProvider
    extends $StreamNotifierProvider<SleepWindDownOn, bool> {
  /// Whether anything is said before bedtime.
  SleepWindDownOnProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepWindDownOnProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepWindDownOnHash();

  @$internal
  @override
  SleepWindDownOn create() => SleepWindDownOn();
}

String _$sleepWindDownOnHash() => r'7fa5b6ce6fcc62ba34a4b0e819fa41c038bbd6b7';

/// Whether anything is said before bedtime.

abstract class _$SleepWindDownOn extends $StreamNotifier<bool> {
  Stream<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// One weekday's own night, or none.

@ProviderFor(SleepNightOverride)
final sleepNightOverrideProvider = SleepNightOverrideFamily._();

/// One weekday's own night, or none.
final class SleepNightOverrideProvider
    extends $StreamNotifierProvider<SleepNightOverride, DailyCycle?> {
  /// One weekday's own night, or none.
  SleepNightOverrideProvider._({
    required SleepNightOverrideFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'sleepNightOverrideProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sleepNightOverrideHash();

  @override
  String toString() {
    return r'sleepNightOverrideProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SleepNightOverride create() => SleepNightOverride();

  @override
  bool operator ==(Object other) {
    return other is SleepNightOverrideProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sleepNightOverrideHash() =>
    r'36f110e5b8da5124ee88d018b7f32ac14d09a632';

/// One weekday's own night, or none.

final class SleepNightOverrideFamily extends $Family
    with
        $ClassFamilyOverride<
          SleepNightOverride,
          AsyncValue<DailyCycle?>,
          DailyCycle?,
          Stream<DailyCycle?>,
          int
        > {
  SleepNightOverrideFamily._()
    : super(
        retry: null,
        name: r'sleepNightOverrideProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One weekday's own night, or none.

  SleepNightOverrideProvider call(int weekday) =>
      SleepNightOverrideProvider._(argument: weekday, from: this);

  @override
  String toString() => r'sleepNightOverrideProvider';
}

/// One weekday's own night, or none.

abstract class _$SleepNightOverride extends $StreamNotifier<DailyCycle?> {
  late final _$args = ref.$arg as int;
  int get weekday => _$args;

  Stream<DailyCycle?> build(int weekday);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<DailyCycle?>, DailyCycle?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DailyCycle?>, DailyCycle?>,
              AsyncValue<DailyCycle?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
