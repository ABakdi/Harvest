import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/lists/data/lists_repository.dart';
import 'package:harvest/features/lists/domain/lists.dart';
import 'package:harvest/features/lists/presentation/list_item_sheet.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// A write that fails does not leave the sheet stuck on a disabled Save:
/// it says so and can be tried again ([[Audit-v3]] Q5-41).
class _Failing extends ListsRepository {
  _Failing(super._db);

  int calls = 0;

  @override
  Future<ListItem> addItem(
    String listUuid, {
    required String title,
    String? note,
    int? priceMinor,
    Currency currency = Currency.dzd,
    HarvestDay? targetDay,
    MediaType? mediaType,
    String? link,
    String? creator,
  }) async {
    calls++;
    throw StateError('disk full');
  }
}

void main() {
  testWidgets('a failed save says so and leaves Save ready', (tester) async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    final repository = _Failing(db);
    final list = ItemList(
      uuid: 'packing',
      name: 'Packing',
      kind: ListKind.plain,
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [listsRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showListItemSheet(context, list: list),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Passport');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('That did not save. Try again.'), findsOneWidget);
    // Save is live again: a second tap tries again.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);

    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}
