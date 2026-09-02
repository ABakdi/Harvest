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
          AsyncValue<Map<ExpenseCategory, int>>,
          Map<ExpenseCategory, int>,
          Stream<Map<ExpenseCategory, int>>
        >
    with
        $FutureModifier<Map<ExpenseCategory, int>>,
        $StreamProvider<Map<ExpenseCategory, int>> {
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
  $StreamProviderElement<Map<ExpenseCategory, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<ExpenseCategory, int>> create(Ref ref) {
    return monthByCategory(ref);
  }
}

String _$monthByCategoryHash() => r'6513cdd166630237818ad3178b010ce702185298';

@ProviderFor(weekByCategory)
final weekByCategoryProvider = WeekByCategoryProvider._();

final class WeekByCategoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<ExpenseCategory, int>>,
          Map<ExpenseCategory, int>,
          Stream<Map<ExpenseCategory, int>>
        >
    with
        $FutureModifier<Map<ExpenseCategory, int>>,
        $StreamProvider<Map<ExpenseCategory, int>> {
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
  $StreamProviderElement<Map<ExpenseCategory, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<ExpenseCategory, int>> create(Ref ref) {
    return weekByCategory(ref);
  }
}

String _$weekByCategoryHash() => r'eb3723796d8ca7cc774f9c97f415fb24fca3ddfd';

/// Budget + currency settings.

@ProviderFor(FinanceSettings)
final financeSettingsProvider = FinanceSettingsProvider._();

/// Budget + currency settings.
final class FinanceSettingsProvider
    extends
        $StreamNotifierProvider<
          FinanceSettings,
          ({int? budgetMinor, String symbol})
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

String _$financeSettingsHash() => r'2d8d2d31c5ceaf08e8c453426042e39334198352';

/// Budget + currency settings.

abstract class _$FinanceSettings
    extends $StreamNotifier<({int? budgetMinor, String symbol})> {
  Stream<({int? budgetMinor, String symbol})> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<({int? budgetMinor, String symbol})>,
              ({int? budgetMinor, String symbol})
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<({int? budgetMinor, String symbol})>,
                ({int? budgetMinor, String symbol})
              >,
              AsyncValue<({int? budgetMinor, String symbol})>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

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
