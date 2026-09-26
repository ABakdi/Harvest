import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/lists/data/lists_repository.dart';
import 'package:harvest/features/lists/domain/lists.dart';
import 'package:harvest/features/lists/presentation/list_labels.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'lists_providers.g.dart';

/// The open estimates of every shopping list, per currency — the
/// Granary's *Planned purchases* line ([[Lists]] L3). A plan: it sums
/// into no wallet, budget or total.
@riverpod
Stream<Map<Currency, int>> plannedPurchases(Ref ref) {
  final repository = ref.watch(listsRepositoryProvider);
  return repository.watchAllItems().asyncMap((items) async {
    final kinds = <String, ListKind?>{};
    for (final item in items) {
      if (kinds.containsKey(item.listUuid)) continue;
      kinds[item.listUuid] = (await repository.list(item.listUuid))?.kind;
    }
    return openEstimates([
      for (final item in items)
        if (kinds[item.listUuid] == ListKind.shopping) item,
    ]);
  });
}
