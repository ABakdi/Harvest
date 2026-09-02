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

/// Budget, currency, and expectation settings. Savings moved to the
/// vault's transaction ledger (checkpoint round 3).

@ProviderFor(FinanceSettings)
final financeSettingsProvider = FinanceSettingsProvider._();

/// Budget, currency, and expectation settings. Savings moved to the
/// vault's transaction ledger (checkpoint round 3).
final class FinanceSettingsProvider
    extends
        $StreamNotifierProvider<
          FinanceSettings,
          ({
            int? budgetMinor,
            Currency defaultCurrency,
            int? expectedDailyMinor,
          })
        > {
  /// Budget, currency, and expectation settings. Savings moved to the
  /// vault's transaction ledger (checkpoint round 3).
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

String _$financeSettingsHash() => r'70e6fd2c154a54d045357fe1249b4b7019317c05';

/// Budget, currency, and expectation settings. Savings moved to the
/// vault's transaction ledger (checkpoint round 3).

abstract class _$FinanceSettings
    extends
        $StreamNotifier<
          ({
            int? budgetMinor,
            Currency defaultCurrency,
            int? expectedDailyMinor,
          })
        > {
  Stream<
    ({int? budgetMinor, Currency defaultCurrency, int? expectedDailyMinor})
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
                })
              >,
              ({
                int? budgetMinor,
                Currency defaultCurrency,
                int? expectedDailyMinor,
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
                  })
                >,
                ({
                  int? budgetMinor,
                  Currency defaultCurrency,
                  int? expectedDailyMinor,
                })
              >,
              AsyncValue<
                ({
                  int? budgetMinor,
                  Currency defaultCurrency,
                  int? expectedDailyMinor,
                })
              >,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(vaultBalances)
final vaultBalancesProvider = VaultBalancesProvider._();

final class VaultBalancesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<(MoneyAccount, Currency), int>>,
          Map<(MoneyAccount, Currency), int>,
          Stream<Map<(MoneyAccount, Currency), int>>
        >
    with
        $FutureModifier<Map<(MoneyAccount, Currency), int>>,
        $StreamProvider<Map<(MoneyAccount, Currency), int>> {
  VaultBalancesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultBalancesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultBalancesHash();

  @$internal
  @override
  $StreamProviderElement<Map<(MoneyAccount, Currency), int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<(MoneyAccount, Currency), int>> create(Ref ref) {
    return vaultBalances(ref);
  }
}

String _$vaultBalancesHash() => r'7a9de6e29db6d72381e2a52f5c0d90b93ca800a7';

@ProviderFor(recentTxns)
final recentTxnsProvider = RecentTxnsProvider._();

final class RecentTxnsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MoneyTxn>>,
          List<MoneyTxn>,
          Stream<List<MoneyTxn>>
        >
    with $FutureModifier<List<MoneyTxn>>, $StreamProvider<List<MoneyTxn>> {
  RecentTxnsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentTxnsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentTxnsHash();

  @$internal
  @override
  $StreamProviderElement<List<MoneyTxn>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MoneyTxn>> create(Ref ref) {
    return recentTxns(ref);
  }
}

String _$recentTxnsHash() => r'237c3d573cecfc5d75752208a7ed78228717eaeb';

/// One pot's own ledger (round 4: each section lists its atomic moves).

@ProviderFor(accountTxns)
final accountTxnsProvider = AccountTxnsFamily._();

/// One pot's own ledger (round 4: each section lists its atomic moves).

final class AccountTxnsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MoneyTxn>>,
          List<MoneyTxn>,
          Stream<List<MoneyTxn>>
        >
    with $FutureModifier<List<MoneyTxn>>, $StreamProvider<List<MoneyTxn>> {
  /// One pot's own ledger (round 4: each section lists its atomic moves).
  AccountTxnsProvider._({
    required AccountTxnsFamily super.from,
    required MoneyAccount super.argument,
  }) : super(
         retry: null,
         name: r'accountTxnsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountTxnsHash();

  @override
  String toString() {
    return r'accountTxnsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<MoneyTxn>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MoneyTxn>> create(Ref ref) {
    final argument = this.argument as MoneyAccount;
    return accountTxns(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountTxnsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountTxnsHash() => r'99bcde359e9d3af0eb91184599ac1edf2b8e626b';

/// One pot's own ledger (round 4: each section lists its atomic moves).

final class AccountTxnsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<MoneyTxn>>, MoneyAccount> {
  AccountTxnsFamily._()
    : super(
        retry: null,
        name: r'accountTxnsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One pot's own ledger (round 4: each section lists its atomic moves).

  AccountTxnsProvider call(MoneyAccount account) =>
      AccountTxnsProvider._(argument: account, from: this);

  @override
  String toString() => r'accountTxnsProvider';
}

@ProviderFor(debts)
final debtsProvider = DebtsProvider._();

final class DebtsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Debt>>,
          List<Debt>,
          Stream<List<Debt>>
        >
    with $FutureModifier<List<Debt>>, $StreamProvider<List<Debt>> {
  DebtsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'debtsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$debtsHash();

  @$internal
  @override
  $StreamProviderElement<List<Debt>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Debt>> create(Ref ref) {
    return debts(ref);
  }
}

String _$debtsHash() => r'42e14e78804630be424c816bb8319a8106d062b2';

@ProviderFor(debtPayments)
final debtPaymentsProvider = DebtPaymentsProvider._();

final class DebtPaymentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DebtPayment>>,
          List<DebtPayment>,
          Stream<List<DebtPayment>>
        >
    with
        $FutureModifier<List<DebtPayment>>,
        $StreamProvider<List<DebtPayment>> {
  DebtPaymentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'debtPaymentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$debtPaymentsHash();

  @$internal
  @override
  $StreamProviderElement<List<DebtPayment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<DebtPayment>> create(Ref ref) {
    return debtPayments(ref);
  }
}

String _$debtPaymentsHash() => r'b0bdd94bb538e8b8abfec1ca4cd48286350ec1aa';

/// Per-currency balances of one pot, zero balances dropped.

@ProviderFor(accountBalances)
final accountBalancesProvider = AccountBalancesFamily._();

/// Per-currency balances of one pot, zero balances dropped.

final class AccountBalancesProvider
    extends
        $FunctionalProvider<
          Map<Currency, int>,
          Map<Currency, int>,
          Map<Currency, int>
        >
    with $Provider<Map<Currency, int>> {
  /// Per-currency balances of one pot, zero balances dropped.
  AccountBalancesProvider._({
    required AccountBalancesFamily super.from,
    required MoneyAccount super.argument,
  }) : super(
         retry: null,
         name: r'accountBalancesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountBalancesHash();

  @override
  String toString() {
    return r'accountBalancesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<Map<Currency, int>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<Currency, int> create(Ref ref) {
    final argument = this.argument as MoneyAccount;
    return accountBalances(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<Currency, int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<Currency, int>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountBalancesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountBalancesHash() => r'1175ee58fc350a2d44895e60b5b5e115b8a2f2fe';

/// Per-currency balances of one pot, zero balances dropped.

final class AccountBalancesFamily extends $Family
    with $FunctionalFamilyOverride<Map<Currency, int>, MoneyAccount> {
  AccountBalancesFamily._()
    : super(
        retry: null,
        name: r'accountBalancesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Per-currency balances of one pot, zero balances dropped.

  AccountBalancesProvider call(MoneyAccount account) =>
      AccountBalancesProvider._(argument: account, from: this);

  @override
  String toString() => r'accountBalancesProvider';
}

/// The vault at a glance, everything converted into the default
/// currency (face value when a rate is missing — never blocks).

@ProviderFor(vaultTotals)
final vaultTotalsProvider = VaultTotalsProvider._();

/// The vault at a glance, everything converted into the default
/// currency (face value when a rate is missing — never blocks).

final class VaultTotalsProvider
    extends
        $FunctionalProvider<
          ({int owed, int savings, int wallet}),
          ({int owed, int savings, int wallet}),
          ({int owed, int savings, int wallet})
        >
    with $Provider<({int owed, int savings, int wallet})> {
  /// The vault at a glance, everything converted into the default
  /// currency (face value when a rate is missing — never blocks).
  VaultTotalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultTotalsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultTotalsHash();

  @$internal
  @override
  $ProviderElement<({int owed, int savings, int wallet})> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ({int owed, int savings, int wallet}) create(Ref ref) {
    return vaultTotals(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({int owed, int savings, int wallet}) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<({int owed, int savings, int wallet})>(value),
    );
  }
}

String _$vaultTotalsHash() => r'2d1c15e3440813c773fa2b46ddf7d63b12df9853';

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

String _$savingsHealthHash() => r'd3572e0849a0e993559b8be3e740959f1510d234';

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
