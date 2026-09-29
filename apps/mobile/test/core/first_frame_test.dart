import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/main.dart';

void main() {
  testWidgets('the first frame needs nothing from the platform (P6-13)', (
    tester,
  ) async {
    await tester.pumpWidget(const StartingApp());
    final box = tester.widget<ColoredBox>(find.byType(ColoredBox));
    expect(box.color, StartingApp.color);
  });

  testWidgets('data that cannot be opened says so, with Try again (S6-05)', (
    tester,
  ) async {
    var tried = 0;
    await tester.pumpWidget(DataUnavailableApp(onRetry: () => tried++));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_clock_outlined), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(tried, 1);
  });
}
