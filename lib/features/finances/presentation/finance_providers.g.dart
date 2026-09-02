// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(todayExpenses)
final todayExpensesProvider = TodayExpensesProvider._();

final class TodayExpensesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Expense>>,
          List<Expense>,
          Stream<List<Expense>>
        >
    with $FutureModifier<List<Expense>>, $StreamProvider<List<Expense>> {
  TodayExpensesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayExpensesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayExpensesHash();

  @$internal
  @override
  $StreamProviderElement<List<Expense>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Expense>> create(Ref ref) {
    return todayExpenses(ref);
  }
}

String _$todayExpensesHash() => r'455f6eabf908a6915d3aad99ecd0c60538611e52';

@ProviderFor(monthTotals)
final monthTotalsProvider = MonthTotalsProvider._();

final class MonthTotalsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          Stream<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $StreamProvider<Map<String, int>> {
  MonthTotalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monthTotalsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monthTotalsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, int>> create(Ref ref) {
    return monthTotals(ref);
  }
}

String _$monthTotalsHash() => r'e72aa01b295f9db526dae407cf9abfaf7dbe6c2c';

@ProviderFor(monthByCategory)
final monthByCategoryProvider = MonthByCategoryProvider._();

final class MonthByCategoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          Stream<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $StreamProvider<Map<String, int>> {
  MonthByCategoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monthByCategoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monthByCategoryHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, int>> create(Ref ref) {
    return monthByCategory(ref);
  }
}

String _$monthByCategoryHash() => r'aef297328ce875497760d0e76a535e6cabe6e45d';

@ProviderFor(weekByCategory)
final weekByCategoryProvider = WeekByCategoryProvider._();

final class WeekByCategoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          Stream<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $StreamProvider<Map<String, int>> {
  WeekByCategoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weekByCategoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weekByCategoryHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, int>> create(Ref ref) {
    return weekByCategory(ref);
  }
}

String _$weekByCategoryHash() => r'5dd2ab568a8389c5a2b084e56c1f41f7ab7e6301';

@ProviderFor(customCategories)
final customCategoriesProvider = CustomCategoriesProvider._();

final class CustomCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CustomCategory>>,
          List<CustomCategory>,
          Stream<List<CustomCategory>>
        >
    with
        $FutureModifier<List<CustomCategory>>,
        $StreamProvider<List<CustomCategory>> {
  CustomCategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customCategoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customCategoriesHash();

  @$internal
  @override
  $StreamProviderElement<List<CustomCategory>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CustomCategory>> create(Ref ref) {
    return customCategories(ref);
  }
}

String _$customCategoriesHash() => r'9a052100e740ed81810d72e1411b6e35d90c512e';

/// Budget + currency settings.

@ProviderFor(FinanceSettings)
final financeSettingsProvider = FinanceSettingsProvider._();

/// Budget + currency settings.
final class FinanceSettingsProvider
    extends
        $StreamNotifierProvider<
          FinanceSettings,
          ({
            int? budgetMinor,
            int? expectedDailyMinor,
            int? savingsMinor,
            String symbol,
          })
        > {
  /// Budget + currency settings.
  FinanceSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'financeSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financeSettingsHash();

  @$internal
  @override
  FinanceSettings create() => FinanceSettings();
}

String _$financeSettingsHash() => r'aee6776ebe5630d4425a649966e06304c9ed9235';

/// Budget + currency settings.

abstract class _$FinanceSettings
    extends
        $StreamNotifier<
          ({
            int? budgetMinor,
            int? expectedDailyMinor,
            int? savingsMinor,
            String symbol,
          })
        > {
  Stream<
    ({
      int? budgetMinor,
      int? expectedDailyMinor,
      int? savingsMinor,
      String symbol,
    })
  >
  build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<
                ({
                  int? budgetMinor,
                  int? expectedDailyMinor,
                  int? savingsMinor,
                  String symbol,
                })
              >,
              ({
                int? budgetMinor,
                int? expectedDailyMinor,
                int? savingsMinor,
                String symbol,
              })
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<
                  ({
                    int? budgetMinor,
                    int? expectedDailyMinor,
                    int? savingsMinor,
                    String symbol,
                  })
                >,
                ({
                  int? budgetMinor,
                  int? expectedDailyMinor,
                  int? savingsMinor,
                  String symbol,
                })
              >,
              AsyncValue<
                ({
                  int? budgetMinor,
                  int? expectedDailyMinor,
                  int? savingsMinor,
                  String symbol,
                })
              >,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(savingsHealth)
final savingsHealthProvider = SavingsHealthProvider._();

final class SavingsHealthProvider
    extends $FunctionalProvider<SavingsHealth, SavingsHealth, SavingsHealth>
    with $Provider<SavingsHealth> {
  SavingsHealthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savingsHealthProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savingsHealthHash();

  @$internal
  @override
  $ProviderElement<SavingsHealth> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SavingsHealth create(Ref ref) {
    return savingsHealth(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavingsHealth value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavingsHealth>(value),
    );
  }
}

String _$savingsHealthHash() => r'9f21a65975f1d16361d04f6b7c2bbe79978488e7';

/// Daily totals for the current week (Mon..today).

@ProviderFor(weekTotals)
final weekTotalsProvider = WeekTotalsProvider._();

/// Daily totals for the current week (Mon..today).

final class WeekTotalsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          Stream<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $StreamProvider<Map<String, int>> {
  /// Daily totals for the current week (Mon..today).
  WeekTotalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weekTotalsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weekTotalsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, int>> create(Ref ref) {
    return weekTotals(ref);
  }
}

String _$weekTotalsHash() => r'f1d83a556d061402e6daeea4a0a82cefc0939e14';

/// Today's budget picture; null while no budget is set.

@ProviderFor(budgetSnapshot)
final budgetSnapshotProvider = BudgetSnapshotProvider._();

/// Today's budget picture; null while no budget is set.

final class BudgetSnapshotProvider
    extends
        $FunctionalProvider<BudgetSnapshot?, BudgetSnapshot?, BudgetSnapshot?>
    with $Provider<BudgetSnapshot?> {
  /// Today's budget picture; null while no budget is set.
  BudgetSnapshotProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'budgetSnapshotProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$budgetSnapshotHash();

  @$internal
  @override
  $ProviderElement<BudgetSnapshot?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BudgetSnapshot? create(Ref ref) {
    return budgetSnapshot(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BudgetSnapshot? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BudgetSnapshot?>(value),
    );
  }
}

String _$budgetSnapshotHash() => r'6c57ba31e76389429ad7f0ccf60cc10fd5c9605e';

/// The smart-repeat suggestion, refreshed as today's log changes.

@ProviderFor(repeatSuggestion)
final repeatSuggestionProvider = RepeatSuggestionProvider._();

/// The smart-repeat suggestion, refreshed as today's log changes.

final class RepeatSuggestionProvider
    extends
        $FunctionalProvider<
          AsyncValue<RepeatSuggestion?>,
          RepeatSuggestion?,
          FutureOr<RepeatSuggestion?>
        >
    with
        $FutureModifier<RepeatSuggestion?>,
        $FutureProvider<RepeatSuggestion?> {
  /// The smart-repeat suggestion, refreshed as today's log changes.
  RepeatSuggestionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'repeatSuggestionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$repeatSuggestionHash();

  @$internal
  @override
  $FutureProviderElement<RepeatSuggestion?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RepeatSuggestion?> create(Ref ref) {
    return repeatSuggestion(ref);
  }
}

String _$repeatSuggestionHash() => r'2bf6ba5b7fb957ee21aa8b1d1bfaf42ad076dffd';
