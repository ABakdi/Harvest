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
import 'package:harvest/l10n/app_localizations.dart';

import '../../support/fake_steps.dart';

class _Day extends CurrentHarvestDay {
  _Day(this._day);
  final HarvestDay _day;
  @override
  HarvestDay build() => _day;
}

/// Health Connect, not allowed, and a prompt that comes back "no".
class _Pull extends StepsPull {
  @override
  Future<StepsState> build() async => (
    status: const StepsStatus(
      backend: StepsBackend.healthConnect,
      granted: false,
    ),
    outcome: StepsSyncOutcome.needsPermission,
  );

  @override
  Future<bool> connect() async => false;
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

class _Source extends FakeStepsSource {
  int opened = 0;

  @override
  Future<void> openHealthConnect() async => opened++;
}

void main() {
  final today = HarvestDay.parse('2026-09-19');

  testWidgets('a refused Connect points at Health Connect settings instead '
      'of round the same button', (tester) async {
    final source = _Source();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentHarvestDayProvider.overrideWith(() => _Day(today)),
          stepsSourceProvider.overrideWithValue(source),
          stepsTodayProvider.overrideWith((ref) => Stream.value(null)),
          recentStepsProvider(7).overrideWith(
            (ref) => Stream.value(const <StepDay>[]),
          ),
          stepsPullProvider.overrideWith(_Pull.new),
          stepGoalProvider.overrideWith(_Goal.new),
          strideSettingProvider.overrideWith(_Stride.new),
          weightUnitSettingProvider.overrideWith(_Unit.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: StepsCard())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Connect'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.textContaining("Health Connect's settings"), findsOneWidget);
    expect(find.textContaining('Tap Connect to ask again'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(SnackBarAction),
        matching: find.text('Health Connect settings'),
      ),
    );
    await tester.pump();
    expect(source.opened, 1);
  });

  test('too few readings for a trend is plain text, not the accent', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.brown);
    expect(
      weightTrendColor(scheme, hasTrend: false),
      scheme.onSurfaceVariant,
    );
    expect(weightTrendColor(scheme, hasTrend: true), scheme.primary);
  });
}
