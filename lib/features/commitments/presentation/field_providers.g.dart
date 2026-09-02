// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'field_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activeCommitments)
final activeCommitmentsProvider = ActiveCommitmentsProvider._();

final class ActiveCommitmentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Commitment>>,
          List<Commitment>,
          Stream<List<Commitment>>
        >
    with $FutureModifier<List<Commitment>>, $StreamProvider<List<Commitment>> {
  ActiveCommitmentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeCommitmentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeCommitmentsHash();

  @$internal
  @override
  $StreamProviderElement<List<Commitment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Commitment>> create(Ref ref) {
    return activeCommitments(ref);
  }
}

String _$activeCommitmentsHash() => r'ba05ad92a44219950e775584a51d11ee7039be0d';

@ProviderFor(loggedToday)
final loggedTodayProvider = LoggedTodayProvider._();

final class LoggedTodayProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          Stream<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $StreamProvider<Map<String, int>> {
  LoggedTodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loggedTodayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loggedTodayHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, int>> create(Ref ref) {
    return loggedToday(ref);
  }
}

String _$loggedTodayHash() => r'c5fab3271ab74dfd1c88edbc9f5e3a6709d5868e';

@ProviderFor(lifetimeTotals)
final lifetimeTotalsProvider = LifetimeTotalsProvider._();

final class LifetimeTotalsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          Stream<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $StreamProvider<Map<String, int>> {
  LifetimeTotalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lifetimeTotalsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lifetimeTotalsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, int>> create(Ref ref) {
    return lifetimeTotals(ref);
  }
}

String _$lifetimeTotalsHash() => r'4bb0581b9ef0571058b437ea36bb00165d1af2b5';

@ProviderFor(doneDaysThisWeek)
final doneDaysThisWeekProvider = DoneDaysThisWeekProvider._();

final class DoneDaysThisWeekProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          Stream<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $StreamProvider<Map<String, int>> {
  DoneDaysThisWeekProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'doneDaysThisWeekProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$doneDaysThisWeekHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, int>> create(Ref ref) {
    return doneDaysThisWeek(ref);
  }
}

String _$doneDaysThisWeekHash() => r'5d9de1925411d7929335ef40a9989020651ee68a';

/// Today's field: every commitment due today, undone first.

@ProviderFor(todayField)
final todayFieldProvider = TodayFieldProvider._();

/// Today's field: every commitment due today, undone first.

final class TodayFieldProvider
    extends
        $FunctionalProvider<List<FieldItem>, List<FieldItem>, List<FieldItem>>
    with $Provider<List<FieldItem>> {
  /// Today's field: every commitment due today, undone first.
  TodayFieldProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayFieldProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayFieldHash();

  @$internal
  @override
  $ProviderElement<List<FieldItem>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<FieldItem> create(Ref ref) {
    return todayField(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<FieldItem> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<FieldItem>>(value),
    );
  }
}

String _$todayFieldHash() => r'87746fd1e26baedfa112fb921fe444fee7bacb4e';
