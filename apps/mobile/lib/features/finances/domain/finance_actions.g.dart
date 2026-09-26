// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(financeActions)
final financeActionsProvider = FinanceActionsProvider._();

final class FinanceActionsProvider
    extends $FunctionalProvider<FinanceActions, FinanceActions, FinanceActions>
    with $Provider<FinanceActions> {
  FinanceActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'financeActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financeActionsHash();

  @$internal
  @override
  $ProviderElement<FinanceActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FinanceActions create(Ref ref) {
    return financeActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinanceActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinanceActions>(value),
    );
  }
}

String _$financeActionsHash() => r'b574f11ad96fdf8268b5be65d3a9f81db159ff80';
