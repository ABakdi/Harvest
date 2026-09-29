import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/settings/presentation/settings_screen.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// With reminders off, the late-streak switch is plainly off and
/// disabled, not a tinted thumb that reads as half on (U6-38).
void main() {
  late HarvestDatabase db;

  setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('the streak switch is off while reminders are off', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsSectionScreen(SettingsSection.reminders),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    final streak = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Late streak warning'),
    );
    expect(streak.onChanged, isNull);
    expect(streak.value, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
