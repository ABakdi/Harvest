import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';

/// The sheet body is the one place every form in the app is laid out,
/// so the keyboard rules are pinned here: never overflow, and never
/// leave the confirm button under the keyboard or the gesture bar — not
/// even for a moment, before scrolling ([[Checkpoint-12]] B12-01).
void main() {
  // A short phone, so a form only has to be moderately tall to break.
  const screen = Size(360, 560);

  Future<void> pumpSheet(
    WidgetTester tester, {
    required int fields,
    double keyboard = 0,
    double gestureBar = 0,
  }) async {
    await tester.binding.setSurfaceSize(screen);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: EdgeInsets.only(bottom: keyboard),
              padding: EdgeInsets.only(bottom: gestureBar),
            ),
            // How a modal sheet is laid out: pinned to the bottom, free
            // to take as much of the screen as it needs.
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                child: HarvestSheet(
                  title: 'Plant a seed',
                  subtitle: 'Every day counts',
                  actionLabel: 'Save',
                  onAction: () {},
                  children: [
                    for (var i = 0; i < fields; i++)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: TextField(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a form taller than the screen scrolls instead of overflowing', (
    tester,
  ) async {
    await pumpSheet(tester, fields: 12, keyboard: 280);

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('the confirm button sits above the keyboard, unscrolled', (
    tester,
  ) async {
    const keyboard = 280.0;
    await pumpSheet(tester, fields: 12, keyboard: keyboard);
    await tester.pumpAndSettle();

    expect(
      tester.getBottomLeft(find.byType(BigBouncySheetButton)).dy,
      lessThanOrEqualTo(screen.height - keyboard),
    );
  });

  testWidgets('with the keyboard down the confirm clears the gesture bar', (
    tester,
  ) async {
    const gestureBar = 48.0;
    await pumpSheet(tester, fields: 12, gestureBar: gestureBar);
    await tester.pumpAndSettle();

    expect(
      tester.getBottomLeft(find.byType(BigBouncySheetButton)).dy,
      lessThanOrEqualTo(screen.height - gestureBar),
    );
  });

  testWidgets('the keyboard inset and the gesture bar never stack', (
    tester,
  ) async {
    // MediaQuery zeroes the padding an inset already covers, which is
    // what keeps the sheet from reserving the bar twice.
    const keyboard = 280.0;
    await pumpSheet(tester, fields: 2, keyboard: keyboard);
    await tester.pumpAndSettle();

    // Right above the keyboard: the button's own margin, and no more.
    final buttonBottom = tester
        .getBottomLeft(find.byType(BigBouncySheetButton))
        .dy;
    expect(
      buttonBottom,
      closeTo(screen.height - keyboard - HarvestSpacing.lg, 0.5),
    );
  });

  testWidgets('the form scrolls under a confirm button that stays put', (
    tester,
  ) async {
    const keyboard = 280.0;
    await pumpSheet(tester, fields: 12, keyboard: keyboard);
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.byType(BigBouncySheetButton));

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(BigBouncySheetButton)), before);
    // The form scrolled: its first field went up past the title.
    expect(find.text('Plant a seed').hitTestable(), findsNothing);
  });

  testWidgets('a short form still hugs the bottom of the screen', (
    tester,
  ) async {
    await pumpSheet(tester, fields: 1);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomLeft(find.byType(BigBouncySheetButton)).dy,
      lessThanOrEqualTo(screen.height),
    );
    // Shrink-wrapped, not stretched to the full screen.
    expect(
      tester.getSize(find.byType(HarvestSheet)).height,
      lessThan(screen.height),
    );
  });
}
