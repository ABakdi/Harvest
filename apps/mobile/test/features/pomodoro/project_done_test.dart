import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/project_done.dart';

/// A project that reaches its target from the focus timer is the same
/// 100% moment as one reached from the field ([[Audit-v3]] Q5-28).
void main() {
  test('reaching the target is the moment, from wherever', () {
    final project = Commitment(
      uuid: 'p',
      title: 'Read 300 pages',
      type: CommitmentType.project,
      totalTarget: 300,
      dailyCommitment: 10,
      createdAt: DateTime(2026, 9),
    );
    expect(projectReached(project, 290, 10), isTrue);
    expect(projectReached(project, 290, 9), isFalse);
    expect(projectReached(project, 300, 0), isFalse);
  });

  test('a capped log counts what went in and says what did not', () {
    expect(
      projectLogOf(
        const CheckInCapped(xpEarned: 5, quantityLogged: 10, dropped: 20),
      ),
      (logged: 10, dropped: 20),
    );
  });
}
