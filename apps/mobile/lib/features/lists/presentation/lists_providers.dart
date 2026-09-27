import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/lists/data/lists_repository.dart';
import 'package:harvest/features/lists/domain/lists.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'lists_providers.g.dart';

/// The open estimates of every shopping list but the Wishlist, per
/// currency — the Granary's *Planned purchases* line ([[Lists]] L3). A
/// plan: it sums into no wallet, budget or total.
@riverpod
Stream<Map<Currency, int>> plannedPurchases(Ref ref) {
  final repository = ref.watch(listsRepositoryProvider);
  return repository.watchAllItems().asyncMap((items) async {
    final lists = <String, ItemList?>{};
    for (final item in items) {
      if (lists.containsKey(item.listUuid)) continue;
      final list = await repository.list(item.listUuid);
      lists[item.listUuid] = list?.deletedAt == null ? list : null;
    }
    return plannedPurchaseTotals(lists.values.nonNulls, items);
  });
}
