// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lists_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The open estimates of every shopping list but the Wishlist, per
/// currency — the Granary's *Planned purchases* line ([[Lists]] L3). A
/// plan: it sums into no wallet, budget or total.

@ProviderFor(plannedPurchases)
final plannedPurchasesProvider = PlannedPurchasesProvider._();

/// The open estimates of every shopping list but the Wishlist, per
/// currency — the Granary's *Planned purchases* line ([[Lists]] L3). A
/// plan: it sums into no wallet, budget or total.

final class PlannedPurchasesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<Currency, int>>,
          Map<Currency, int>,
          Stream<Map<Currency, int>>
        >
    with
        $FutureModifier<Map<Currency, int>>,
        $StreamProvider<Map<Currency, int>> {
  /// The open estimates of every shopping list but the Wishlist, per
  /// currency — the Granary's *Planned purchases* line ([[Lists]] L3). A
  /// plan: it sums into no wallet, budget or total.
  PlannedPurchasesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'plannedPurchasesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$plannedPurchasesHash();

  @$internal
  @override
  $StreamProviderElement<Map<Currency, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<Currency, int>> create(Ref ref) {
    return plannedPurchases(ref);
  }
}

String _$plannedPurchasesHash() => r'd16e7edec09cf64e660bc1029b4becd87ed97457';
