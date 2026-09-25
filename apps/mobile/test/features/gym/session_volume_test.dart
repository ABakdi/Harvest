import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/gym/domain/session.dart';
import 'package:harvest/features/gym/presentation/weight_text.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// A session's volume agrees with its rows ([[Gym]] rule Y8): five sets
/// that each read 132.25 lb came to "661.5 lb", added up from the
/// stored grams and rounded once at the end.
void main() {
  WorkoutSet set(int grams, int reps, {bool done = true}) => WorkoutSet(
    uuid: 's$grams$reps$done',
    sessionExerciseUuid: 'e',
    position: 0,
    weightGrams: grams,
    reps: reps,
    done: done,
  );

  test('pounds add up from the loads the rows show', () {
    // 60 kg reads as 132.25 lb.
    final sets = [set(60000, 5)];
    expect(shownVolume(sets, WeightUnit.lb), 661.25);
  });

  test('kilos add up as stored, and undone sets count for nothing', () {
    final sets = [set(60000, 5), set(62500, 3), set(100000, 5, done: false)];
    expect(shownVolume(sets, WeightUnit.kg), 487.5);
  });

  testWidgets('the summary text reads 661.25 lb', (tester) async {
    late String text;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            text = formatVolume(context, [set(60000, 5)], WeightUnit.lb);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(text, '661.25 lb');
  });
}
