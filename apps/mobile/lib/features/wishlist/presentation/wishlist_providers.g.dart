// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wishlist_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every live item, list by list, in hand order.

@ProviderFor(wishlistItems)
final wishlistItemsProvider = WishlistItemsProvider._();

/// Every live item, list by list, in hand order.

final class WishlistItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WishlistItem>>,
          List<WishlistItem>,
          Stream<List<WishlistItem>>
        >
    with
        $FutureModifier<List<WishlistItem>>,
        $StreamProvider<List<WishlistItem>> {
  /// Every live item, list by list, in hand order.
  WishlistItemsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wishlistItemsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wishlistItemsHash();

  @$internal
  @override
  $StreamProviderElement<List<WishlistItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<WishlistItem>> create(Ref ref) {
    return wishlistItems(ref);
  }
}

String _$wishlistItemsHash() => r'32ea6f23cdfa7b530fb82edf742a0378cd153185';
