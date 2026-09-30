import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/ui/keyboard_reveal.dart';

/// Once the keyboard has finished opening, the field being typed into
/// is in view with room under it for what follows — the next field,
/// the button ([[Checkpoint-12]] B12-01). The text field alone only ever
/// brought its caret's line into view.
void main() {
  const keyboard = 300.0;

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => KeyboardReveal(child: child!),
        home: Scaffold(
          body: ListView(
            children: [
              for (var i = 0; i < 20; i++)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(key: ValueKey('field $i')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openKeyboard(WidgetTester tester) async {
    final ratio = tester.view.devicePixelRatio;
    // The keyboard comes up over a few frames, as on a phone.
    for (final step in [0.3, 0.7, 1.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard * step * ratio);
      await tester.pump(const Duration(milliseconds: 16));
    }
    // It holds still: the watcher's turn.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  testWidgets('brings the focused field into view with room below it', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await pumpForm(tester);
    final field = find.byKey(const ValueKey('field 8'));
    await tester.tap(field);
    await tester.pump();

    await openKeyboard(tester);

    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final visibleBottom = screen - keyboard;
    final bottom = tester.getBottomLeft(field).dy;
    expect(bottom, lessThanOrEqualTo(visibleBottom - KeyboardReveal.below + 1));
    expect(tester.getTopLeft(field).dy, greaterThanOrEqualTo(0));
  });

  testWidgets('leaves a scroll made by hand alone afterwards', (tester) async {
    addTearDown(tester.view.reset);
    await pumpForm(tester);
    await tester.tap(find.byKey(const ValueKey('field 8')));
    await tester.pump();
    await openKeyboard(tester);

    // Scrolled back up by hand, with the keyboard still up.
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      position,
    );
  });

  testWidgets('does nothing without a text field in focus', (tester) async {
    addTearDown(tester.view.reset);
    await pumpForm(tester);
    await openKeyboard(tester);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      0,
    );
  });
}
