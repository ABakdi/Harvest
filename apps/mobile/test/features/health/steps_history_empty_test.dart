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
import 'package:harvest/features/health/presentation/steps_history.dart';
import 'package:harvest/l10n/app_localizations.dart';

class _Day extends CurrentHarvestDay {
  _Day(this._day);
  final HarvestDay _day;
  @override
  HarvestDay build() => _day;
}

class _Pull extends StepsPull {
  _Pull(this._outcome);
  final StepsSyncOutcome _outcome;
  @override
  Future<StepsState> build() async =>
      (status: StepsStatus.unavailable, outcome: _outcome);
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

/// An empty "Your steps" card asks for Connect only while it has not
/// been tapped: once the phone reads steps it said "Tap Connect on the
/// steps card." to someone who just had.
void main() {
  final today = HarvestDay.parse('2026-09-19');

  Future<void> pump(WidgetTester tester, StepsSyncOutcome outcome) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentHarvestDayProvider.overrideWith(() => _Day(today)),
            recentStepsProvider(
              30,
            ).overrideWith((ref) => Stream.value(const <StepDay>[])),
            stepsPullProvider.overrideWith(() => _Pull(outcome)),
            stepGoalProvider.overrideWith(_Goal.new),
            strideSettingProvider.overrideWith(_Stride.new),
            weightUnitSettingProvider.overrideWith(_Unit.new),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: StepsHistory()),
          ),
        ),
      );

  testWidgets('connected, it says the days are still to come', (
    tester,
  ) async {
    await pump(tester, StepsSyncOutcome.synced);
    await tester.pumpAndSettle();
    expect(find.text('No steps counted yet'), findsOneWidget);
    expect(find.text('Tap Connect on the steps card.'), findsNothing);
    expect(
      find.text("Each day's count lands here once the day is over."),
      findsOneWidget,
    );
  });

  testWidgets('not connected, it points at Connect', (tester) async {
    await pump(tester, StepsSyncOutcome.needsPermission);
    await tester.pumpAndSettle();
    expect(find.text('Tap Connect on the steps card.'), findsOneWidget);
  });
}
