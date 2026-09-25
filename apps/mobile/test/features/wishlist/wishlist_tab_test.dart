import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/wishlist/data/wishlist_repository.dart';
import 'package:harvest/features/wishlist/domain/wishlist.dart';
import 'package:harvest/features/wishlist/presentation/wishlist_tab.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// An in-memory wishlist, so the widget test never touches a live
/// drift watch stream (whose cache-keeping `Timer.run` trips the test
/// binding). Writes mutate the list and re-emit, exactly like the tab
/// expects.
class FakeWishlist extends WishlistRepository {
  // ignore: matching_super_parameters — the repository names it `_db`.
  FakeWishlist(super.db);

  final items = <WishlistItem>[];

  /// Broadcast so the tab can have many listeners, but replays the
  /// current list to each new one — events seeded before a listener
  /// subscribes are never lost. `late` so it can read `items`.
  late final StreamController<List<WishlistItem>> _changes =
      StreamController<List<WishlistItem>>.broadcast(
        onListen: () => _changes.add(List.of(items)),
      );
  var _next = 0;

  void push() => _changes.add(List.of(items));

  void seed(WishlistItem item) {
    items.add(item);
    push();
  }

  int? find(String uuid) {
    final i = items.indexWhere((item) => item.uuid == uuid);
    return i == -1 ? null : i;
  }

  @override
  Stream<List<WishlistItem>> watchAll() => _changes.stream;

  @override
  Future<WishlistItem> add({
    required WishlistList list,
    required String title,
    int? priceMinor,
    Currency currency = Currency.dzd,
    String? note,
    HarvestDay? targetDay,
  }) async {
    final item = WishlistItem(
      uuid: 'w${_next++}',
      list: list,
      title: title,
      priceMinor: priceMinor,
      currency: currency,
      note: note,
      targetDay: targetDay,
      position: items.length,
      createdAt: DateTime(2026),
    );
    items.add(item);
    push();
    return item;
  }

  @override
  Future<void> setBought(String uuid, {required bool bought, DateTime? at}) async {
    final i = find(uuid);
    if (i == null) return;
    items[i] = WishlistItem(
      uuid: items[i].uuid,
      list: items[i].list,
      title: items[i].title,
      priceMinor: items[i].priceMinor,
      currency: items[i].currency,
      note: items[i].note,
      targetDay: items[i].targetDay,
      boughtAt: bought ? (at ?? DateTime(2026, 10)) : null,
      position: items[i].position,
      createdAt: items[i].createdAt,
    );
    push();
  }

  @override
  Future<void> move(String uuid, WishlistList to) async {
    final i = find(uuid);
    if (i == null) return;
    final item = items[i];
    items[i] = WishlistItem(
      uuid: item.uuid,
      list: to,
      title: item.title,
      priceMinor: item.priceMinor,
      currency: item.currency,
      note: item.note,
      targetDay: item.targetDay,
      boughtAt: item.boughtAt,
      position: item.position,
      createdAt: item.createdAt,
    );
    push();
  }

  @override
  Future<void> delete(String uuid, {DateTime? at}) async {
    final i = find(uuid);
    if (i != null) {
      items.removeAt(i);
      push();
    }
  }
}

void main() {
  late FakeWishlist repo;
  late HarvestDatabase db;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    repo = FakeWishlist(db);
  });

  tearDown(() async {
    await repo._changes.close();
    await db.close();
  });

  Widget tab() => ProviderScope(
    overrides: [
      wishlistRepositoryProvider.overrideWith((ref) => repo),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: WishlistTab()),
    ),
  );

  WishlistItem item(
    String title, {
    WishlistList list = WishlistList.buy,
    int? price,
    DateTime? boughtAt,
    String? note,
    HarvestDay? targetDay,
  }) =>
      WishlistItem(
        uuid: title,
        list: list,
        title: title,
        priceMinor: price,
        boughtAt: boughtAt,
        note: note,
        targetDay: targetDay,
        createdAt: DateTime(2026),
      );

  testWidgets('the buy list shows open items, prices and the Add action', (
    tester,
  ) async {
    repo
      ..seed(item('Winter coat', price: 1800000))
      ..seed(item('Kettle', price: 85000));

    await tester.pumpWidget(tab());
    await tester.pump();

    expect(find.text('Winter coat'), findsOneWidget);
    expect(find.text('Kettle'), findsOneWidget);
    expect(
      find.textContaining('18,000'),
      findsOneWidget, // the per-currency open total
    );
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('ticking an item folds it under Bought, and unticking returns', (
    tester,
  ) async {
    repo.seed(item('Winter coat'));

    await tester.pumpWidget(tab());
    await tester.pump();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(repo.items.single.isBought, isTrue, reason: 'checkbox should mark bought');
    expect(find.textContaining('bought'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.textContaining('bought'), findsNothing);
  });

  testWidgets('bought items render struck through in their own section', (
    tester,
  ) async {
    repo
      ..seed(item('Winter coat'))
      ..seed(item('Kettle', boughtAt: DateTime(2026, 10)));

    await tester.pumpWidget(tab());
    await tester.pump();

    expect(find.text('Kettle'), findsOneWidget);
    expect(find.textContaining('bought'), findsOneWidget);
  });

  testWidgets('the wishlist segment holds its own items', (tester) async {
    repo
      ..seed(item('Espresso machine', list: WishlistList.wish))
      ..seed(item('DSLR', list: WishlistList.wish))
      ..seed(item('Winter coat'));

    await tester.pumpWidget(tab());
    await tester.pump();

    await tester.tap(find.text('Wishlist').last);
    await tester.pump();

    expect(find.text('Espresso machine'), findsOneWidget);
    expect(find.text('DSLR'), findsOneWidget);
    expect(find.text('Winter coat'), findsNothing);
  });

  testWidgets('moving an item takes it to the other list', (tester) async {
    repo.seed(item('Winter coat'));

    await tester.pumpWidget(tab());
    await tester.pump();

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('To the wishlist'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wishlist').last);
    await tester.pump();
    expect(find.text('Winter coat'), findsOneWidget);
  });

  testWidgets('a row shows its target day and its note together', (
    tester,
  ) async {
    repo.seed(
      item(
        'Winter coat',
        note: 'Wool, dark grey',
        targetDay: HarvestDay.today().addDays(3),
      ),
    );

    await tester.pumpWidget(tab());
    await tester.pump();

    expect(find.text('In 3 days · Wool, dark grey'), findsOneWidget);
  });

  testWidgets('a bought wish item stays in view, with no Bought fold (W7)', (
    tester,
  ) async {
    repo.seed(
      item('Espresso machine', list: WishlistList.wish, boughtAt: DateTime(2026, 10)),
    );

    await tester.pumpWidget(tab());
    await tester.pump();
    await tester.tap(find.text('Wishlist').last);
    await tester.pump();

    expect(find.text('Espresso machine'), findsOneWidget);
    expect(find.textContaining('bought'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('a planned day already passed still opens the day picker', (
    tester,
  ) async {
    repo.seed(
      item('Winter coat', targetDay: HarvestDay.today().addDays(-5)),
    );

    await tester.pumpWidget(tab());
    await tester.pump();
    await tester.tap(find.text('Winter coat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planned purchase day'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('an empty list says what it is for', (tester) async {
    await tester.pumpWidget(tab());
    await tester.pump();
    expect(find.text('Nothing to buy'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('the empty wish segment says it is a wishlist', (tester) async {
    await tester.pumpWidget(tab());
    await tester.pump();

    await tester.tap(find.text('Wishlist').last);
    await tester.pump();

    expect(find.text('Nothing wished for'), findsOneWidget);
    expect(find.text('Nothing to buy'), findsNothing);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('adding from the wish segment preselects the wishlist', (tester) async {
    await tester.pumpWidget(tab());
    await tester.pump();

    await tester.tap(find.text('Wishlist').last);
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final segments = tester
        .widgetList<SegmentedButton<WishlistList>>(
          find.byType(SegmentedButton<WishlistList>),
        )
        .toList();
    // The tab's toggle stays in the tree behind the sheet; the sheet's is
    // added on top, so it is the last one.
    expect(segments, hasLength(2));
    expect(segments.last.selected, {WishlistList.wish});
  });

  testWidgets('the list follows writes even while provider watches are '
      'paused, as after a sheet and a permission prompt', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [wishlistRepositoryProvider.overrideWith((ref) => repo)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Tickers off is what pauses a ConsumerWidget's watches.
          home: TickerMode(enabled: false, child: Scaffold(body: WishlistTab())),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Nothing to buy'), findsOneWidget);

    await repo.add(list: WishlistList.buy, title: 'Kettle');
    await tester.pump();
    expect(find.text('Kettle'), findsOneWidget);
    expect(find.text('Nothing to buy'), findsNothing);

    await repo.setBought(repo.items.single.uuid, bought: true);
    await tester.pump();
    expect(find.textContaining('bought'), findsOneWidget);
  });

  testWidgets('an estimate reads in the plain text colour, not the accent', (
    tester,
  ) async {
    repo.seed(item('Kettle', price: 85000));
    await tester.pumpWidget(tab());
    await tester.pump();

    final price = tester.widget<Text>(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.textContaining('850'),
      ),
    );
    final context = tester.element(find.byType(WishlistTab));
    final scheme = Theme.of(context).colorScheme;
    expect(price.style?.color, scheme.onSurface);
    expect(price.style?.color, isNot(scheme.primary));
  });

  testWidgets('the editor offers the same currency pills as the expense '
      'sheet', (tester) async {
    await tester.pumpWidget(tab());
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    for (final currency in Currency.values) {
      expect(find.text(currency.symbol), findsWidgets);
    }
    expect(find.text('DZD'), findsNothing);
    expect(find.text('USD'), findsNothing);
    expect(find.text('EUR'), findsNothing);
  });
}
