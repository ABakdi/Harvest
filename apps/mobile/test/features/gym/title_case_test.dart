import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/gym/domain/exercise.dart';

/// Catalogue names read as titles, initialisms in capitals: "Barbell
/// Jm Bench Press" was a name nobody writes.
void main() {
  test('initialisms stay in capitals', () {
    expect(titleCase('barbell jm bench press'), 'Barbell JM Bench Press');
    expect(titleCase('ez barbell close-grip curl'), 'EZ Barbell Close-Grip Curl');
    expect(titleCase('barbell full squat (side pov)'), 'Barbell Full Squat (Side POV)');
    expect(
      titleCase('cable reverse grip triceps pushdown (sz-bar) (with arm blaster)'),
      'Cable Reverse Grip Triceps Pushdown (SZ-Bar) (With Arm Blaster)',
    );
  });

  test('short words are not initialisms', () {
    expect(titleCase('3/4 sit-up'), '3/4 Sit-Up');
    expect(titleCase('barbell squat (on knees)'), 'Barbell Squat (On Knees)');
    expect(titleCase('barbell standing ab rollerout'), 'Barbell Standing Ab Rollerout');
    expect(titleCase('lever t bar row'), 'Lever T Bar Row');
  });
}
