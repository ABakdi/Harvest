import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/ui/widgets/action_snack_bar.dart';
import 'package:harvest/features/lists/data/lists_repository.dart';
import 'package:harvest/features/lists/domain/lists.dart';
import 'package:harvest/features/lists/domain/share_links.dart';
import 'package:harvest/features/lists/presentation/list_item_sheet.dart';
import 'package:harvest/features/lists/presentation/list_labels.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The list a share starts in ([[Lists]]: Saving from anywhere): a link
/// in *To read*, or *To watch* for a video site; text without a link in
/// the first plain list I made. Null when there is none of those — the
/// sheet then asks.
ItemList? shareTargetOf(SharedDraft draft, List<ItemList> lists) {
  final target = draft.target;
  if (target != null) {
    return lists.where((list) => list.uuid == target.list.uuid).firstOrNull;
  }
  return lists
      .where((list) => list.kind == ListKind.plain && list.builtIn == null)
      .firstOrNull;
}

/// Opens *Save to a list* for [draft] and saves what I confirm. Saving
/// into Lists switches Lists on if it was off: the item would otherwise
/// land somewhere I cannot see.
Future<void> saveShared(
  BuildContext context,
  WidgetRef ref,
  SharedDraft draft,
) async {
  final repository = ref.read(listsRepositoryProvider);
  final settings = ref.read(settingsRepositoryProvider);
  final listsOn = ref.read(listsEnabledProvider);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.maybeOf(context);
  final l10n = AppLocalizations.of(context);
  await repository.ensureBuiltIns();
  final lists = await repository.watchLists().first;
  if (!context.mounted) return;
  final item = await showShareSheet(
    context,
    draft: draft,
    lists: lists,
    initial: shareTargetOf(draft, lists),
  );
  if (item == null) return;
  if (!listsOn) await settings.setBool(FeatureKeys.lists, value: true);
  final list = lists.where((list) => list.uuid == item.listUuid).firstOrNull;
  final saved = Text(
    l10n.listsShareSaved(list == null ? '' : listName(l10n, list)),
  );
  messenger.showSnackBar(
    router == null
        ? SnackBar(content: saved)
        : actionSnackBar(
            messenger,
            content: saved,
            action: SnackBarAction(
              label: l10n.listsShareOpen,
              onPressed: () =>
                  router.go('${AppRoutes.lists}?list=${item.listUuid}'),
            ),
          ),
  );
}
