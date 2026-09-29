import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/ui/scroll_behavior.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/data/seed_notes_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/commitments/presentation/seed_note_sheet.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// A seed's note sheet with a long note in it moves with a finger on
/// the note field, keyboard up: the field has nothing of its own to
/// scroll, so the sheet around it does.
void main() {
  final lastTime = [
    'FIRST LINE OF LAST TIME',
    for (var i = 2; i <= 40; i++) 'Last time, line $i',
  ].join('\n');

  Future<void> open(WidgetTester tester, {String today = ''}) async {
    // A phone-sized screen with the keyboard taking its lower half.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    tester.view.viewInsets = const FakeViewPadding(bottom: 1200);
    addTearDown(tester.view.reset);

    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    late Commitment book;
    await tester.runAsync(() async {
      book = await CommitmentsRepository(db).create(
        type: CommitmentType.habit,
        title: 'Read',
        schedule: const DailySchedule(),
        createdAt: DateTime(2026),
      );
      final day = container.read(currentHarvestDayProvider);
      final notes = container.read(seedNotesRepositoryProvider);
      await notes.write(
        commitmentUuid: book.uuid,
        day: day.previous,
        body: lastTime,
      );
      if (today.isNotEmpty) {
        await notes.write(commitmentUuid: book.uuid, day: day, body: today);
      }
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          scrollBehavior: const HarvestScrollBehavior(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSeedNoteSheet(context, book),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
  }

  ScrollPosition sheet(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  ScrollPosition field(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(EditableText),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  testWidgets('a drag on the note field scrolls the sheet back to the '
      'long note above it', (tester) async {
    await open(tester);
    expect(find.textContaining('FIRST LINE OF LAST TIME'), findsOneWidget);
    // Focusing the field brought it into view, past the long note.
    expect(sheet(tester).pixels, greaterThan(0));

    final on = tester.getCenter(find.byType(EditableText));
    await tester.timedDragFrom(
      on,
      const Offset(0, 1500),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();

    expect(sheet(tester).pixels, 0);
  });

  testWidgets('a note longer than the field still scrolls inside it', (
    tester,
  ) async {
    await open(
      tester,
      today: [for (var i = 1; i <= 20; i++) 'Today, line $i'].join('\n'),
    );
    final inner = field(tester);
    expect(inner.maxScrollExtent, greaterThan(0));
    final before = inner.pixels;

    final on = tester.getCenter(find.byType(EditableText));
    await tester.timedDragFrom(
      on,
      Offset(0, before > 0 ? 60 : -60),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(field(tester).pixels, isNot(before));
  });
}
