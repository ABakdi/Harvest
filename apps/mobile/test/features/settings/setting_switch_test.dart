import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/db/portable_settings.dart';
import 'package:harvest/core/platform/day_reset.dart';
import 'package:harvest/features/account/domain/heartbeat.dart';
import 'package:harvest/features/news/domain/news.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/presentation/setting_switch.dart';

/// *Share my streak* and *News from Harvest* ([[Admin]]): on until
/// turned off, and this phone's alone.
void main() {
  test('what this phone tells, and asks, never leaves it as a setting', () {
    for (final key in [
      HeartbeatKeys.day,
      HeartbeatKeys.shareStreak,
      NewsKeys.enabled,
      NewsKeys.notified,
      NewsKeys.shown,
      NewsKeys.askedAt,
      NewsKeys.permissionAsked,
    ]) {
      expect(isImportableSetting(key), isFalse, reason: key);
    }
  });

  test('the news is asked for every few hours in the background', () {
    expect(NewsJob.taskName, isNot(DayResetJob.taskName));
    expect(NewsJob.every, const Duration(hours: 3));
  });

  testWidgets('a switch that is on until turned off, and keeps its word', (
    tester,
  ) async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    var turnedOn = <bool>[];
    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: SettingSwitchTile(
              settingKey: NewsKeys.enabled,
              title: 'News from Harvest',
              onChanged: ({required on}) async => turnedOn = [...turnedOn, on],
            ),
          ),
        ),
      ),
    );
    await settle();
    bool value() =>
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;
    expect(value(), isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await settle();
    expect(value(), isFalse);
    expect(turnedOn, [false]);
    final kept = await tester.runAsync(
      () => SettingsRepository(db).getBool(NewsKeys.enabled),
    );
    expect(kept, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(db.close);
  });
}
