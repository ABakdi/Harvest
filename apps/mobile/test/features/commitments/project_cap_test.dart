import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';

/// A project never takes more than it asks for in all: 100 of 100 is
/// done, never 160 of 100, and a daily commitment over the total is
/// refused at planting ([[Business-Rules]] #2). The whole cap is pinned
/// by `over-log.json`; these are the edges around it.
void main() {
  final book = Commitment(
    uuid: 'book',
    type: CommitmentType.project,
    title: 'Book',
    createdAt: DateTime(2026, 9),
    totalTarget: 100,
    dailyCommitment: 10,
  );

  test('the room today is the lower of the two caps', () {
    expect(book.roomToday(0), 20);
    expect(book.roomToday(0, totalLogged: 95), 5);
    expect(book.roomToday(15, totalLogged: 30), 5);
    expect(book.roomToday(5, totalLogged: 100), 0);
  });

  test('a daily commitment over the total is refused', () {
    expect(Commitment.validProjectTargets(100, 10), isTrue);
    expect(Commitment.validProjectTargets(100, 100), isTrue);
    expect(Commitment.validProjectTargets(10, 20), isFalse);
    expect(Commitment.validProjectTargets(0, 1), isFalse);
  });

  test('a cut log says what it dropped', () async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.commitments)
        .insert(
          CommitmentsCompanion.insert(
            uuid: book.uuid,
            type: book.type.name,
            title: book.title,
            dailyCommitment: const Value(10),
            totalTarget: const Value(100),
          ),
        );
    final day = HarvestDay.parse('2026-09-19');
    await db
        .into(db.checkIns)
        .insert(
          CheckInsCompanion.insert(
            uuid: 'earlier',
            commitmentUuid: book.uuid,
            harvestDay: day.previous.key,
            quantity: const Value(95),
          ),
        );

    final result = await CheckInService(
      db,
      StreakService(db),
    ).checkIn(book, quantity: 20, day: day);

    expect(result, isA<CheckInCapped>());
    final capped = result as CheckInCapped;
    expect(capped.quantityLogged, 5);
    expect(capped.dropped, 15);
  });
}
