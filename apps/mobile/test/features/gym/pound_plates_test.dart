import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/gym/domain/plates.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/domain/session.dart';
import 'package:harvest/features/gym/presentation/plate_sheet.dart';
import 'package:harvest/features/gym/presentation/set_row.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

class _Unit extends WeightUnitSetting {
  _Unit(this.unit);

  final WeightUnit unit;

  @override
  Stream<WeightUnit> build() => Stream.value(unit);
}

/// Pounds are first-class ([[Gym]] rule Y8): a pound gym's bar and
/// plates, loads that read back as the pounds typed, and a target under
/// the bar that says the bar is heavier than asked.
void main() {
  test('135 lb is stored so it reads back as 135', () {
    final grams = roundLoad(WeightUnit.lb.toGrams(135), unit: WeightUnit.lb);
    expect(WeightUnit.lb.from(grams), closeTo(135, 0.001));
    // Rounded in kilos it would come back as 135.03.
    expect(
      WeightUnit.lb.from(roundLoad(WeightUnit.lb.toGrams(135))),
      isNot(
        closeTo(135, 0.01),
      ),
    );
  });

  test('a percentage resolves in pounds', () {
    const set = TargetSet(uuid: 't', position: 0, reps: 5, percentTenths: 750);
    final grams = set.resolve(
      trainingMaxGrams: gramsOfPounds(225),
      unit: WeightUnit.lb,
    )!;
    // 168.75 lb is not a load 2.5 lb plates can make; 170 is (G5-13).
    expect(WeightUnit.lb.from(grams), closeTo(170, 0.001));
    expect(
      platesFor(
        grams,
        barGrams: barIn(defaultBarGrams, WeightUnit.lb),
        unit: WeightUnit.lb,
      ).shortfallGrams,
      0,
    );
  });

  test('a slot on the default bar is a 45 lb bar in pounds', () {
    expect(barIn(defaultBarGrams, WeightUnit.lb), gramsOfPounds(45));
    expect(barIn(defaultBarGrams, WeightUnit.kg), defaultBarGrams);
    final plan = platesFor(
      gramsOfPounds(225),
      barGrams: barIn(defaultBarGrams, WeightUnit.lb),
      unit: WeightUnit.lb,
    );
    expect(plan.stacks, [(grams: gramsOfPounds(45), perSide: 2)]);
    expect(plan.shortfallGrams, 0);
  });

  Future<void> open(
    WidgetTester tester,
    WeightUnit unit, {
    required int target,
    int bar = defaultBarGrams,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [weightUnitSettingProvider.overrideWith(() => _Unit(unit))],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showPlates(context, targetGrams: target, barGrams: bar),
                child: const Text('plates'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('plates'));
    await tester.pumpAndSettle();
  }

  testWidgets('a pound gym loads 45s on a 45 lb bar', (tester) async {
    await open(tester, WeightUnit.lb, target: gramsOfPounds(135));
    expect(find.text('Per side, on a 45 lb bar'), findsOneWidget);
    expect(find.text('1 × 45 lb'), findsOneWidget);
  });

  testWidgets('under the bar, the bar says how much it is over', (
    tester,
  ) async {
    await open(tester, WeightUnit.lb, target: gramsOfPounds(40));
    expect(find.text('Just the bar'), findsOneWidget);
    expect(
      find.text('Lighter than the bar: the bar alone is 5 lb over.'),
      findsOneWidget,
    );
  });

  testWidgets('and in kilos too', (tester) async {
    await open(tester, WeightUnit.kg, target: 15000);
    expect(
      find.text('Lighter than the bar: the bar alone is 5 kg over.'),
      findsOneWidget,
    );
  });

  testWidgets('exactly the bar is just the bar, nothing over', (
    tester,
  ) async {
    await open(tester, WeightUnit.kg, target: 20000);
    expect(find.text('Just the bar'), findsOneWidget);
    expect(find.textContaining('over'), findsNothing);
  });

  testWidgets('a row shown in kilos before the unit arrived stays 135 lb', (
    tester,
  ) async {
    final set = WorkoutSet(
      uuid: 's',
      sessionExerciseUuid: 'e',
      position: 0,
      weightGrams: gramsOfPounds(135),
      reps: 5,
      targetLabel: '61.23×5',
    );
    const exercise = SessionExercise(
      uuid: 'e',
      sessionUuid: 'w',
      position: 0,
      exerciseId: '0025',
    );
    Widget row(WeightUnit unit) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SetRow(
            set: set,
            number: 1,
            exercise: exercise,
            unit: unit,
            onTicked: () {},
            onPlates: null,
          ),
        ),
      ),
    );
    await tester.pumpWidget(row(WeightUnit.kg));
    expect(find.text('61.23'), findsOneWidget);
    await tester.pumpWidget(row(WeightUnit.lb));
    // Re-read from the row, not from the kilos' two decimals (135.03).
    expect(find.text('135'), findsOneWidget);
    // The stored label reads back in pounds too.
    expect(find.text('135×5'), findsOneWidget);
  });

  testWidgets('a set is numbered by its place, not its position (Q5-46)', (
    tester,
  ) async {
    // Set 2 was dropped (Y13): the one left at position 2 is the
    // second set on screen, not the third.
    const set = WorkoutSet(
      uuid: 's',
      sessionExerciseUuid: 'e',
      position: 2,
      weightGrams: 60000,
      reps: 5,
    );
    const exercise = SessionExercise(
      uuid: 'e',
      sessionUuid: 'w',
      position: 0,
      exerciseId: '0025',
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SetRow(
              set: set,
              number: 2,
              exercise: exercise,
              unit: WeightUnit.kg,
              onTicked: () {},
              onPlates: null,
            ),
          ),
        ),
      ),
    );
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });
}
