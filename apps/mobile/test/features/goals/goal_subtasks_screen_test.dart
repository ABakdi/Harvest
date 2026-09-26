import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/goals/data/goals_repository.dart';
import 'package:harvest/features/goals/domain/goal.dart';
import 'package:harvest/features/goals/presentation/goal_screen.dart';
import 'package:harvest/features/goals/presentation/goals_board.dart';
import 'package:harvest/features/goals/presentation/goals_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// M6.13 on the goal screen: Requirements and Tasks by name, subtasks
/// indented under their task, and a parent's tick that is theirs
/// ([[Goals]] GL8).
void main() {
  GoalItem item(
    String uuid, {
    GoalItemKind kind = GoalItemKind.step,
    String? parent,
    bool done = false,
    int position = 0,
  }) => GoalItem(
    uuid: uuid,
    goalUuid: 'g',
    kind: kind,
    body: uuid,
    parentUuid: parent,
    doneAt: done ? DateTime(2026, 9, 20) : null,
    position: position,
  );

  final view = GoalView(
    goal: Goal(uuid: 'g', title: 'Half marathon', createdAt: DateTime(2026)),
    items: [
      item('Running shoes', kind: GoalItemKind.need),
      item('Run a 10 km race'),
      item('Find a race', parent: 'Run a 10 km race', done: true),
      item('Register', parent: 'Run a 10 km race', done: true, position: 1),
      item('Run it', parent: 'Run a 10 km race', position: 2),
      item('Run the half', position: 1),
    ],
  );

  Widget app(Widget home, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: [
          goalSeedsProvider.overrideWith(
            (ref, uuid) => Stream.value(const <Commitment>[]),
          ),
          ...overrides,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );

  testWidgets('requirements, then tasks, with subtasks indented beneath', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const GoalScreen(uuid: 'g'),
        overrides: [
          goalProvider('g').overrideWith((ref) => Stream.value(view)),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    final requirements = find.text('Requirements — what it takes');
    final tasks = find.text('Tasks');
    expect(requirements, findsOneWidget);
    expect(tasks, findsOneWidget);
    double top(Finder f) => tester.getTopLeft(f).dy;
    double start(Finder f) => tester.getTopLeft(f).dx;
    expect(top(requirements), lessThan(top(find.text('Running shoes'))));
    expect(top(find.text('Running shoes')), lessThan(top(tasks)));
    expect(top(tasks), lessThan(top(find.text('Run a 10 km race'))));

    // Beneath their task, in order, and indented.
    const order = [
      'Run a 10 km race',
      'Find a race',
      'Register',
      'Run it',
      'Run the half',
    ];
    for (var i = 1; i < order.length; i++) {
      expect(top(find.text(order[i - 1])), lessThan(top(find.text(order[i]))));
    }
    expect(
      start(find.text('Find a race')),
      greaterThan(start(find.text('Run a 10 km race'))),
    );
    // The parent counts its subtasks, and is not done while one is open.
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('Add a subtask'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets("a task's menu offers a subtask; a subtask's, to stand alone", (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const GoalScreen(uuid: 'g'),
        overrides: [
          goalProvider('g').overrideWith((ref) => Stream.value(view)),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    final menus = find.byTooltip('Item options');
    // Running shoes, the race, its three subtasks, the half.
    expect(menus, findsNWidgets(6));
    await tester.tap(menus.at(1));
    await tester.pumpAndSettle();
    expect(find.text('Add a subtask'), findsNWidgets(2)); // menu + line
    expect(find.text('Make it a task of its own'), findsNothing);
    // It has subtasks, so it cannot go under another.
    expect(find.text('Move under…'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.tap(menus.at(2));
    await tester.pumpAndSettle();
    expect(find.text('Make it a task of its own'), findsOneWidget);
    expect(find.text('Plant as a seed'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.tap(menus.at(5));
    await tester.pumpAndSettle();
    expect(find.text('Move under…'), findsOneWidget);
  });

  testWidgets('ticking the parent ticks all its subtasks', (tester) async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    final goals = GoalsRepository(db);
    late String goalUuid;
    await tester.runAsync(() async {
      final goal = await goals.create(title: 'Half marathon');
      goalUuid = goal.uuid;
      final task = await goals.addItem(goal.uuid, body: 'Run a 10 km race');
      await goals.addSubtask(task.uuid, body: 'Find a race');
      await goals.addSubtask(task.uuid, body: 'Register');
    });

    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await tester.pumpWidget(
      app(
        GoalScreen(uuid: goalUuid),
        overrides: [databaseProvider.overrideWithValue(db)],
      ),
    );
    await settle();
    expect(find.text('0 of 2'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await settle();
    expect(find.text('2 of 2'), findsOneWidget);
    final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(boxes.every((box) => box.value ?? false), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });

  testWidgets("the board's next step is the first open subtask", (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const Scaffold(body: GoalsBoard()),
        overrides: [
          goalsProvider.overrideWith((ref) => Stream.value([view])),
        ],
      ),
    );
    await tester.pump();
    // Shoes, and the race's three: two of five ticked.
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('Next: Run it'), findsOneWidget);
  });
}
