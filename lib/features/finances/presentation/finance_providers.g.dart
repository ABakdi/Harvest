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

@ProviderFor(monthExpenses)
final monthExpensesProvider = MonthExpensesProvider._();

final class MonthExpensesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Expense>>,
          List<Expense>,
          Stream<List<Expense>>
        >
    with $FutureModifier<List<Expense>>, $StreamProvider<List<Expense>> {
  MonthExpensesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monthExpensesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monthExpensesHash();

  @$internal
  @override
  $StreamProviderElement<List<Expense>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Expense>> create(Ref ref) {
    return monthExpenses(ref);
  }
}

String _$monthExpensesHash() => r'00191f58489e17b2a1b384a66f1cc253622d0e70';

@ProviderFor(weekExpenses)
final weekExpensesProvider = WeekExpensesProvider._();

final class WeekExpensesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Expense>>,
          List<Expense>,
          Stream<List<Expense>>
        >
    with $FutureModifier<List<Expense>>, $StreamProvider<List<Expense>> {
  WeekExpensesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weekExpensesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weekExpensesHash();

  @$internal
  @override
  $StreamProviderElement<List<Expense>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Expense>> create(Ref ref) {
    return weekExpenses(ref);
  }
}

String _$weekExpensesHash() => r'dade004e79efd03b2bb2d5151089285fb13772cd';

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

/// Budget, currency, savings-per-currency, and manual rate settings.

@ProviderFor(FinanceSettings)
final financeSettingsProvider = FinanceSettingsProvider._();

/// Budget, currency, savings-per-currency, and manual rate settings.
final class FinanceSettingsProvider
    extends
        $StreamNotifierProvider<
          FinanceSettings,
          ({
            int? budgetMinor,
            Currency defaultCurrency,
            int? expectedDailyMinor,
            Map<Currency, int> savings,
          })
        > {
  /// Budget, currency, savings-per-currency, and manual rate settings.
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

String _$financeSettingsHash() => r'a66c339c83173ab570851743a44cb2d2c4d8c09e';

/// Budget, currency, savings-per-currency, and manual rate settings.

abstract class _$FinanceSettings
    extends
        $StreamNotifier<
          ({
            int? budgetMinor,
            Currency defaultCurrency,
            int? expectedDailyMinor,
            Map<Currency, int> savings,
          })
        > {
  Stream<
    ({
      int? budgetMinor,
      Currency defaultCurrency,
      int? expectedDailyMinor,
      Map<Currency, int> savings,
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
                  Currency defaultCurrency,
                  int? expectedDailyMinor,
                  Map<Currency, int> savings,
                })
              >,
              ({
                int? budgetMinor,
                Currency defaultCurrency,
                int? expectedDailyMinor,
                Map<Currency, int> savings,
              })
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<
                  ({
                    int? budgetMinor,
                    Currency defaultCurrency,
                    int? expectedDailyMinor,
                    Map<Currency, int> savings,
                  })
                >,
                ({
                  int? budgetMinor,
                  Currency defaultCurrency,
                  int? expectedDailyMinor,
                  Map<Currency, int> savings,
                })
              >,
              AsyncValue<
                ({
                  int? budgetMinor,
                  Currency defaultCurrency,
                  int? expectedDailyMinor,
                  Map<Currency, int> savings,
                })
              >,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The live exchange-rate picture (checkpoint P5).

@ProviderFor(rates)
final ratesProvider = RatesProvider._();

/// The live exchange-rate picture (checkpoint P5).

final class RatesProvider
    extends $FunctionalProvider<AsyncValue<Rates>, Rates, Stream<Rates>>
    with $FutureModifier<Rates>, $StreamProvider<Rates> {
  /// The live exchange-rate picture (checkpoint P5).
  RatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ratesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ratesHash();

  @$internal
  @override
  $StreamProviderElement<Rates> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Rates> create(Ref ref) {
    return rates(ref);
  }
}

String _$ratesHash() => r'5fe8a66e65e3acd2694c10b2b11d1ada7acb380c';

@ProviderFor(monthTotals)
final monthTotalsProvider = MonthTotalsProvider._();

final class MonthTotalsProvider
    extends
        $FunctionalProvider<
          Map<String, int>,
          Map<String, int>,
          Map<String, int>
        >
    with $Provider<Map<String, int>> {
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
  $ProviderElement<Map<String, int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Map<String, int> create(Ref ref) {
    return monthTotals(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, int>>(value),
    );
  }
}

String _$monthTotalsHash() => r'e8b6197452cd841f999221bd2dd2a920bc1366dd';

@ProviderFor(weekTotals)
final weekTotalsProvider = WeekTotalsProvider._();

final class WeekTotalsProvider
    extends
        $FunctionalProvider<
          Map<String, int>,
          Map<String, int>,
          Map<String, int>
        >
    with $Provider<Map<String, int>> {
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
  $ProviderElement<Map<String, int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Map<String, int> create(Ref ref) {
    return weekTotals(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, int>>(value),
    );
  }
}

String _$weekTotalsHash() => r'014d445b55a44a68fe7b4ea7f035b966acd89177';

@ProviderFor(monthByCategory)
final monthByCategoryProvider = MonthByCategoryProvider._();

final class MonthByCategoryProvider
    extends
        $FunctionalProvider<
          Map<String, int>,
          Map<String, int>,
          Map<String, int>
        >
    with $Provider<Map<String, int>> {
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
  $ProviderElement<Map<String, int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Map<String, int> create(Ref ref) {
    return monthByCategory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, int>>(value),
    );
  }
}

String _$monthByCategoryHash() => r'4951fa534b880c63d7321d61608782af79d5f5eb';

@ProviderFor(weekByCategory)
final weekByCategoryProvider = WeekByCategoryProvider._();

final class WeekByCategoryProvider
    extends
        $FunctionalProvider<
          Map<String, int>,
          Map<String, int>,
          Map<String, int>
        >
    with $Provider<Map<String, int>> {
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
  $ProviderElement<Map<String, int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Map<String, int> create(Ref ref) {
    return weekByCategory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, int>>(value),
    );
  }
}

String _$weekByCategoryHash() => r'49be071c41422c3675c61c894633726d2eb3332e';

/// Today's budget picture in the default currency; null without a budget.

@ProviderFor(budgetSnapshot)
final budgetSnapshotProvider = BudgetSnapshotProvider._();

/// Today's budget picture in the default currency; null without a budget.

final class BudgetSnapshotProvider
    extends
        $FunctionalProvider<BudgetSnapshot?, BudgetSnapshot?, BudgetSnapshot?>
    with $Provider<BudgetSnapshot?> {
  /// Today's budget picture in the default currency; null without a budget.
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

String _$budgetSnapshotHash() => r'a76b30770626360d632d5a09044992e0c8c47371';

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

String _$savingsHealthHash() => r'1e912748ff343c595cf02fd8d9548deb94c1bc25';

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
