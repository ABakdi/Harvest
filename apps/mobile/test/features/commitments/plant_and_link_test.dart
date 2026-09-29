import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/goals/data/goals_repository.dart';

/// Planting from a goal or a list writes the seed and its link in one
/// transaction: a failed link leaves no seed behind ([[Audit-v3]] Q5-41).
void main() {
  late HarvestDatabase db;

  setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('the seed and its link land together', () async {
    final goals = GoalsRepository(db);
    final goal = await goals.create(title: 'Move');
    final item = await goals.addItem(goal.uuid, body: 'Book the van');
    final seed = await CommitmentsRepository(db).create(
      type: CommitmentType.todo,
      title: 'Book the van',
      dueDay: HarvestDay.today(),
      goalUuid: goal.uuid,
      alongside: (seed) => goals.linkItem(item.uuid, seed.uuid),
    );
    final row = await (db.select(
      db.goalItems,
    )..where((i) => i.uuid.equals(item.uuid))).getSingle();
    expect(row.commitmentUuid, seed.uuid);
  });

  test('a link that fails takes the seed back with it', () async {
    await expectLater(
      CommitmentsRepository(db).create(
        type: CommitmentType.todo,
        title: 'Book the van',
        dueDay: HarvestDay.today(),
        alongside: (_) => throw StateError('the link did not write'),
      ),
      throwsStateError,
    );
    expect(await db.select(db.commitments).get(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
  });
}
