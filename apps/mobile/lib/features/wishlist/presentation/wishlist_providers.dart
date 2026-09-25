import 'package:harvest/features/wishlist/data/wishlist_repository.dart';
import 'package:harvest/features/wishlist/domain/wishlist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'wishlist_providers.g.dart';

/// Every live item, list by list, in hand order.
@riverpod
Stream<List<WishlistItem>> wishlistItems(Ref ref) =>
    ref.watch(wishlistRepositoryProvider).watchAll();
