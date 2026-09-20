import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/health/data/steps_source.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/domain/steps.dart';
import 'package:harvest/features/health/domain/steps_sync.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/features/health/presentation/health_screen.dart';
import 'package:harvest/features/health/presentation/steps_history.dart';
import 'package:harvest/l10n/app_localizations.dart';

class _Day extends CurrentHarvestDay {
  _Day(this._day);
  final HarvestDay _day;
  @override
  HarvestDay build() => _day;
}

class _Pull extends StepsPull {
  @override
  Future<StepsState> build() async =>
      (status: StepsStatus.unavailable, outcome: StepsSyncOutcome.unavailable);
}

class _Goal extends StepGoal {
  @override
  Stream<int> build() => Stream.value(10000);
}

class _Stride extends StrideSetting {
  @override
  Stream<int> build() => Stream.value(75);
}

class _Unit extends WeightUnitSetting {
  @override
  Stream<WeightUnit> build() => Stream.value(WeightUnit.kg);
}

/// [[Audit-v2]] U3-12 and U3-13: the steps card fits a 360 dp phone,
/// and the thirty-day average says what it is — in both languages.
void main() {
  final today = HarvestDay.parse('2026-09-19');
  final month = [
    for (var i = 29; i >= 0; i--)
      StepDay(day: today.addDays(-i), steps: 8000 + i * 10),
  ];

  Widget card({required Widget child, Locale locale = const Locale('en')}) =>
      ProviderScope(
        overrides: [
          currentHarvestDayProvider.overrideWith(() => _Day(today)),
          stepsTodayProvider.overrideWith(
            (ref) => Stream.value(
              StepDay(day: today, steps: 123456, lastCounter: 1),
            ),
          ),
          recentStepsProvider(7).overrideWith((ref) => Stream.value(month)),
          recentStepsProvider(30).overrideWith((ref) => Stream.value(month)),
          stepsPullProvider.overrideWith(_Pull.new),
          stepGoalProvider.overrideWith(_Goal.new),
          strideSettingProvider.overrideWith(_Stride.new),
          weightUnitSettingProvider.overrideWith(_Unit.new),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      );

  testWidgets('the card fits 360 dp with six figures in it', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(card(child: const StepsCard()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('123,456'), findsOneWidget);
  });

  testWidgets('the average is a daily average, in Arabic too', (tester) async {
    await tester.pumpWidget(card(child: const StepsHistory()));
    await tester.pump();
    expect(find.text('Daily average'), findsOneWidget);
    expect(find.textContaining('7-day'), findsNothing);

    await tester.pumpWidget(
      card(child: const StepsHistory(), locale: const Locale('ar')),
    );
    await tester.pump();
    expect(find.text('المتوسط اليومي'), findsOneWidget);
  });
}
