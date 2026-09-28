import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/gamification/presentation/daily_goal_line.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The Field says how far today is toward the daily goal, so a streak
/// at 0 after one check-in reads as "1 of 3", not as broken (U6-03).
void main() {
  late HarvestDatabase db;

  setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('one of three, then the goal met', (tester) async {
    final seeds = await tester.runAsync(() async {
      final repo = CommitmentsRepository(db);
      return [
        for (final title in ['Read', 'Walk', 'Water'])
          await repo.create(
            type: CommitmentType.habit,
            title: title,
            schedule: const DailySchedule(),
            createdAt: DateTime(2026),
          ),
      ];
    });
    final checkIns = CheckInService(db, StreakService(db));
    await tester.runAsync(() => checkIns.checkIn(seeds![0]));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DailyGoalLine()),
        ),
      ),
    );
    await settle(tester);
    expect(
      find.text('1 of 3 actions today for the daily harvest'),
      findsOneWidget,
    );

    // Written from the test's own zone while the tree keeps pumping: a
    // write awaited in runAsync would wait on the stream's read, which
    // only runs when the tree is pumped.
    var written = false;
    unawaited(
      checkIns
          .checkIn(seeds![1])
          .then((_) => checkIns.checkIn(seeds[2]))
          .then((_) => written = true),
    );
    for (var i = 0; i < 20 && !written; i++) {
      await settle(tester);
    }
    expect(written, isTrue);
    await settle(tester);
    expect(
      find.text('3 actions — the daily harvest goal is met'),
      findsOneWidget,
    );
    expect(HarvestDay.today(), isNotNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
