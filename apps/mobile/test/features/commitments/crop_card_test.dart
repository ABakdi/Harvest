import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/ui/widgets/crop_card.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// A seed's page is one tap away: the card opens it, the round button
/// checks in — as on the web, where the title links to the page.
void main() {
  testWidgets('the card opens the seed and the round button checks in', (
    tester,
  ) async {
    var opened = 0;
    var checked = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CropCard(
            title: 'Read',
            subtitle: '20 of 100',
            icon: Icons.flag,
            done: false,
            progress: 0.2,
            onTap: () => checked++,
            onOpen: () => opened++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expect((opened, checked), (1, 0));

    await tester.tap(find.bySemanticsLabel('Check in Read'));
    await tester.pumpAndSettle();
    expect((opened, checked), (1, 1));
  });

  testWidgets('without a page to open, the whole card still checks in', (
    tester,
  ) async {
    var checked = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CropCard(
            title: 'Walk',
            subtitle: 'Every day',
            icon: Icons.repeat,
            done: false,
            onTap: () => checked++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Walk'));
    await tester.pumpAndSettle();
    expect(checked, 1);
  });
}
