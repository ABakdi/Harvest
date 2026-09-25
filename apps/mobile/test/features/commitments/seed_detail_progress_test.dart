import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/seed_detail_screen.dart';
import 'package:harvest/features/commitments/presentation/seed_providers.dart';
import 'package:harvest/features/gamification/presentation/gamification_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// A project's page says how far it has come: 20 of 100.
void main() {
  testWidgets('a project shows its progress toward the total', (
    tester,
  ) async {
    final today = HarvestDay.parse('2026-09-19');
    final book = Commitment(
      uuid: 'book',
      type: CommitmentType.project,
      title: 'Book',
      createdAt: DateTime(2026, 9),
      totalTarget: 100,
      dailyCommitment: 10,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seedProvider('book').overrideWith((ref) => Stream.value(book)),
          seedTimelineProvider('book').overrideWithValue([
            (day: today, quantity: 12, note: null, checkInUuid: null),
            (day: today.previous, quantity: 8, note: null, checkInUuid: null),
          ]),
          commitmentStreaksProvider.overrideWith(
            (ref) => Stream.value(const {}),
          ),
          currentHarvestDayProvider.overrideWithBuild((ref, _) => today),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SeedDetailScreen(uuid: 'book'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('20 of 100'), findsOneWidget);
    expect(find.text('80 to go'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
