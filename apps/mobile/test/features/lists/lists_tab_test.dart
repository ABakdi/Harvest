import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/lists/data/lists_repository.dart';
import 'package:harvest/features/lists/domain/lists.dart';
import 'package:harvest/features/lists/presentation/lists_screen.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/features/widget/domain/widget_service.dart';
import 'package:harvest/l10n/app_localizations.dart';

class _Planner implements NotificationPlanner {
  @override
  Future<void> planToday({DateTime? now}) async {}

  @override
  Future<void> reevaluate({DateTime? now}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Widgets implements WidgetService {
  @override
  Future<void> refresh({Object? today}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records → Lists ([[Lists]]): one screen for every list, whose kind
/// decides what a row shows and what done means.
void main() {
  late HarvestDatabase db;
  late ListsRepository repo;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    repo = ListsRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpLists(WidgetTester tester, {String? initialList}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationPlannerProvider.overrideWithValue(_Planner()),
          widgetServiceProvider.overrideWithValue(_Widgets()),
          notesEnabledProvider.overrideWithValue(true),
          ratesProvider.overrideWith(
            (ref) => Stream.value(const Rates(defaultCurrency: Currency.dzd)),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ListsScreen(initialList: initialList),
        ),
      ),
    );
    await settle(tester);
  }

  /// Takes the screen down and lets the database's streams close.
  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<T> write<T>(WidgetTester tester, Future<T> Function() run) async =>
      (await tester.runAsync(run)) as T;

  testWidgets('the built-ins show as chips in my language, with open '
      'counts', (tester) async {
    await write(tester, () => repo.addItem(BuiltInList.read.uuid, title: 'Dune'));
    await pumpLists(tester);

    expect(find.text('To buy'), findsOneWidget);
    expect(find.text('Wishlist'), findsOneWidget);
    expect(find.text('To read · 1'), findsOneWidget);
    expect(find.text('To watch'), findsOneWidget);
    expect(find.text('New list'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a plain list ticks; done folds below and opens on a tap', (
    tester,
  ) async {
    final list = await write(
      tester,
      () => repo.createList(name: 'Packing', kind: ListKind.plain),
    );
    await write(tester, () => repo.addItem(list.uuid, title: 'Passport'));
    await write(tester, () => repo.addItem(list.uuid, title: 'Charger'));
    await pumpLists(tester, initialList: list.uuid);

    await tester.tap(find.byType(Checkbox).first);
    await settle(tester);

    // Folded: the count, not the row.
    expect(find.text('1 done'), findsOneWidget);
    expect(find.text('Passport'), findsNothing);
    expect(find.text('Packing · 1'), findsOneWidget);

    await tester.tap(find.text('1 done'));
    await settle(tester);
    expect(find.text('Passport'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a media item goes want → in progress → finished, rated', (
    tester,
  ) async {
    final dune = await write(
      tester,
      () => repo.addItem(
        BuiltInList.read.uuid,
        title: 'Dune',
        mediaType: MediaType.book,
        creator: 'Frank Herbert',
      ),
    );
    await pumpLists(tester, initialList: BuiltInList.read.uuid);
    expect(find.text('Book · Frank Herbert'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.byTooltip('Start'));
    await settle(tester);
    expect(find.text('In progress · Book · Frank Herbert'), findsOneWidget);

    await tester.tap(find.byTooltip('Finish'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('4 stars'));
    await settle(tester);

    final done = (await write(tester, () => repo.item(dune.uuid)))!;
    expect(done.isDone, isTrue);
    expect(done.rating, 4);
    expect(find.text('1 finished'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('moving offers only lists of the same kind (L2)', (tester) async {
    await write(tester, () => repo.addItem(BuiltInList.read.uuid, title: 'Dune'));
    await write(
      tester,
      () => repo.createList(name: 'Groceries', kind: ListKind.shopping),
    );
    await pumpLists(tester, initialList: BuiltInList.read.uuid);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to…'));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('To watch')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('To buy')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Groceries')),
      findsNothing,
    );

    await tester.tap(find.descendant(of: sheet, matching: find.text('To watch')));
    await settle(tester);
    expect(find.text('To watch · 1'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a list I made is deleted with undo; a built-in is not '
      'offered (L6, L10)', (tester) async {
    final list = await write(
      tester,
      () => repo.createList(name: 'Gift ideas', kind: ListKind.plain),
    );
    await write(tester, () => repo.addItem(list.uuid, title: 'Scarf'));
    await pumpLists(tester);

    await tester.tap(find.byTooltip('List options'));
    await tester.pumpAndSettle();
    expect(find.text('Delete list'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gift ideas · 1'));
    await settle(tester);
    await tester.tap(find.byTooltip('List options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete list'));
    await settle(tester);

    expect(find.textContaining('Gift ideas'), findsOneWidget); // the snack bar
    expect(find.text('Gift ideas · 1'), findsNothing);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('Gift ideas · 1'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a wish is not bought where it is (L7)', (tester) async {
    await write(
      tester,
      () => repo.addItem(BuiltInList.wish.uuid, title: 'Espresso machine'),
    );
    await pumpLists(tester, initialList: BuiltInList.wish.uuid);

    expect(find.text('Espresso machine'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    await leave(tester);
  });

  testWidgets('bought opens the expense sheet prefilled, and logs nothing '
      'by itself (L4)', (tester) async {
    await write(
      tester,
      () => repo.addItem(
        BuiltInList.buy.uuid,
        title: 'Kettle',
        priceMinor: 85000,
      ),
    );
    await pumpLists(tester, initialList: BuiltInList.buy.uuid);
    expect(find.text('Open'), findsOneWidget);
    expect(find.textContaining('850'), findsWidgets);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text)
        .toList();
    expect(fields, contains('850'));
    expect(fields, contains('Kettle'));

    // Dismissed: the item is bought, and no money moved.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(await write(tester, () => db.select(db.expenses).get()), isEmpty);
    expect(await write(tester, () => db.select(db.moneyTxns).get()), isEmpty);
    expect(find.text('1 bought'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('planting a book makes a project and links it; the row '
      'follows its progress', (tester) async {
    final dune = await write(
      tester,
      () => repo.addItem(
        BuiltInList.read.uuid,
        title: 'Dune',
        mediaType: MediaType.book,
      ),
    );
    await pumpLists(tester, initialList: BuiltInList.read.uuid);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plant as a seed'));
    await tester.pumpAndSettle();

    // "300 pages, 10 a day", typed over at will.
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text)
        .toList();
    expect(fields, containsAll(['Dune', '300', '10']));

    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);

    final linked = (await write(tester, () => repo.item(dune.uuid)))!;
    expect(linked.seedUuid, isNotNull);
    final seed = await write(
      tester,
      () => CommitmentsRepository(db).once(linked.seedUuid!),
    );
    expect(seed!.type, CommitmentType.project);
    expect(seed.totalTarget, 300);
    expect(find.text('Seed · 0 of 300'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a finished seed offers to finish the item', (tester) async {
    final todo = await write(
      tester,
      () => CommitmentsRepository(db).create(
        type: CommitmentType.todo,
        title: 'Kettle',
      ),
    );
    final plain = await write(
      tester,
      () => repo.createList(name: 'Errands', kind: ListKind.plain),
    );
    final item = await write(
      tester,
      () => repo.addItem(plain.uuid, title: 'Kettle'),
    );
    await write(tester, () => repo.linkSeed(item.uuid, todo.uuid));
    await write(tester, () => CommitmentsRepository(db).archive(todo.uuid));
    await pumpLists(tester, initialList: plain.uuid);

    expect(find.text('Its seed is done'), findsOneWidget);
    await tester.tap(find.text('Mark finished'));
    await settle(tester);
    expect((await write(tester, () => repo.item(item.uuid)))!.isDone, isTrue);
    await leave(tester);
  });
}
