import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/goals/domain/goal.dart';
import 'package:harvest/features/goals/presentation/goals_board.dart';
import 'package:harvest/features/goals/presentation/goals_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

void main() {
  Widget board(List<GoalView> goals) => ProviderScope(
    overrides: [
      goalsProvider.overrideWith((ref) => Stream.value(goals)),
      goalSeedsProvider.overrideWith(
        (ref, uuid) => Stream.value(const <Commitment>[]),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: GoalsBoard()),
    ),
  );

  GoalItem item(String body, {bool done = false}) => GoalItem(
    uuid: body,
    goalUuid: 'g',
    kind: GoalItemKind.step,
    body: body,
    doneAt: done ? DateTime(2026) : null,
  );

  testWidgets('an empty board says what it is for', (tester) async {
    await tester.pumpWidget(board(const []));
    await tester.pump();
    expect(find.text('No goals yet'), findsOneWidget);
  });

  testWidgets('a card shows progress, the next step, and folds the rest', (
    tester,
  ) async {
    await tester.pumpWidget(
      board([
        GoalView(
          goal: Goal(
            uuid: 'g',
            title: 'Half marathon',
            createdAt: DateTime(2026),
            targetDay: HarvestDay.today().addDays(10),
          ),
          items: [item('Buy shoes', done: true), item('Run 10 km')],
        ),
        GoalView(
          goal: Goal(
            uuid: 'a',
            title: 'Learn to swim',
            createdAt: DateTime(2026),
            status: GoalStatus.achieved,
          ),
          items: const [],
        ),
      ]),
    );
    await tester.pump();

    expect(find.text('Half marathon'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Next: Run 10 km'), findsOneWidget);
    expect(find.text('10 days left'), findsOneWidget);
    // Achieved goals are folded away until asked for.
    expect(find.text('Learn to swim'), findsNothing);
    await tester.tap(find.text('Achieved · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Learn to swim'), findsOneWidget);
  });
}
