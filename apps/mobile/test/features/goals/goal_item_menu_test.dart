import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/goals/domain/goal.dart';
import 'package:harvest/features/goals/presentation/goal_screen.dart';
import 'package:harvest/features/goals/presentation/goals_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

void main() {
  testWidgets("an item's menu offers to Remove it, not \"Removed\"", (
    tester,
  ) async {
    final view = GoalView(
      goal: Goal(uuid: 'g', title: 'Half marathon', createdAt: DateTime(2026)),
      items: const [
        GoalItem(
          uuid: 'i',
          goalUuid: 'g',
          kind: GoalItemKind.step,
          body: 'Buy shoes',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goalProvider('g').overrideWith((ref) => Stream.value(view)),
          goalSeedsProvider('g').overrideWith(
            (ref) => Stream.value(const <Commitment>[]),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GoalScreen(uuid: 'g'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Item options'));
    await tester.pumpAndSettle();
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Removed'), findsNothing);
  });
}
