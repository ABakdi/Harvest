import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/theme.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/calendar/presentation/calendar_screen.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/field_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:table_calendar/table_calendar.dart';

/// Today in readable ink when another day is picked, and room under the
/// last row so its badges are not cut by the card's corners.
void main() {
  testWidgets('today reads in the page ink, and the grid has a floor', (
    tester,
  ) async {
    final today = HarvestDay.today();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeCommitmentsProvider.overrideWith(
            (ref) => Stream.value(const <Commitment>[]),
          ),
          currentHarvestDayProvider.overrideWithBuild((ref, _) => today),
        ],
        child: MaterialApp(
          theme: HarvestTheme.light(ThemePreset.harvest),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CalendarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Pick another day, so today is only "today", not the selection.
    final other = today.day == 15 ? '16' : '15';
    await tester.tap(find.text(other).first);
    await tester.pumpAndSettle();

    final scheme = Theme.of(tester.element(find.byType(CalendarScreen)))
        .colorScheme;
    final label = tester.widget<Text>(find.text('${today.day}').first);
    expect(label.style?.color, scheme.onSurface);

    final floor = find.ancestor(
      of: find.byType(TableCalendar<void>),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding == const EdgeInsets.only(bottom: HarvestSpacing.sm),
      ),
    );
    expect(floor, findsOneWidget);
  });
}
