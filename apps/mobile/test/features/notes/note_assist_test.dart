import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/assist/data/assist_settings.dart';
import 'package:harvest/features/assist/domain/assist.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/presentation/notes_screen.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// ⋮ → Assist always answers: with the actions, or with where the
/// assist is set up, even when the question of who answers never
/// comes back ([[Audit-v3]] U6-01).
void main() {
  late HarvestDatabase db;

  setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> openAssist(
    WidgetTester tester,
    Future<AssistProvider?> Function() provider,
  ) async {
    final note = await tester.runAsync(
      () => NotesRepository(db).create(title: 'Plan', body: 'Some words'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          assistProviderInUseProvider.overrideWith((ref) => provider()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotesScreen(initialUuid: note!.uuid),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assist'));
    await tester.pump();
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('nobody to ask says where the assist is set up', (
    tester,
  ) async {
    await openAssist(tester, () async => null);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Settings'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a question that never comes back ends in the same place', (
    tester,
  ) async {
    await openAssist(tester, () => Completer<AssistProvider?>().future);
    expect(find.text('Looking for the assist…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Settings'), findsOneWidget);
    await leave(tester);
  });
}
