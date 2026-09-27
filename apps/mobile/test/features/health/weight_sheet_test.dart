import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/health/data/health_repository.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/features/health/presentation/weight_sheet.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The weight sheet saves what I meant: the same text under another
/// unit is another number (Q5-42), and the target line is mine to set
/// and clear (G5-05).
void main() {
  late HarvestDatabase db;

  setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget app(Widget Function(BuildContext context) body) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Builder(builder: body)),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('an unchanged number read in another unit is saved in it', (
    tester,
  ) async {
    final weight = await tester.runAsync(
      () => HealthRepository(db).logWeight(grams: 82460),
    );
    await tester.pumpWidget(
      app(
        (context) => TextButton(
          onPressed: () => showWeightSheet(context, existing: weight),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('82.46'), findsOneWidget);
    await tester.tap(find.text('lb'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = await tester.runAsync(
      () => HealthRepository(db).watchWeights().first,
    );
    expect(saved!.single.grams, WeightUnit.lb.toGrams(82.46));
    await settle(tester);
  });

  testWidgets('a target is set and cleared', (tester) async {
    await tester.pumpWidget(
      app(
        (context) => TextButton(
          onPressed: () => showTargetWeightSheet(context),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '75.5');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final settings = SettingsRepository(db);
    expect(
      await tester.runAsync(() => settings.getString(HealthKeys.targetGrams)),
      '75500',
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('75.5'), findsOneWidget);
    await tester.tap(find.text('Clear target'));
    await tester.pumpAndSettle();
    expect(
      await tester.runAsync(() => settings.getString(HealthKeys.targetGrams)),
      '',
    );
    await settle(tester);
  });
}
