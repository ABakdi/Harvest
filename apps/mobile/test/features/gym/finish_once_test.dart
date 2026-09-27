import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';

/// A double tap on Start or Finish does the thing once ([[Gym]] Y3,
/// Y4; [[Audit-v3]] Q5-39).
void main() {
  late HarvestDatabase db;
  late ProgramsRepository programs;
  late SessionsRepository sessions;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    programs = ProgramsRepository(db);
    sessions = SessionsRepository(db);
  });

  tearDown(() async => db.close());

  Future<({Program program, ProgramDay day})> aDay() async {
    final program = await programs.createProgram(name: 'nSuns');
    final day = await programs.addDay(program.uuid, name: 'Day 1');
    final slot = await programs.addSlot(day.uuid, exerciseId: '0025');
    await programs.addTargetSet(slot.uuid, reps: 5, weightGrams: 100000);
    final fresh = (await programs.once(program.uuid))!;
    return (program: fresh, day: fresh.days.single);
  }

  test('two Starts at once open one session', () async {
    final made = await aDay();
    final both = await Future.wait([
      for (var i = 0; i < 2; i++)
        sessions.start(
          day: made.day,
          programUuid: made.program.uuid,
          title: 'Day 1',
        ),
    ]);
    expect(both.first.uuid, both.last.uuid);
    final rows = await db.select(db.workoutSessions).get();
    expect(rows, hasLength(1));
  });

  test('a second Finish changes nothing', () async {
    final made = await aDay();
    final session = await sessions.start(
      day: made.day,
      programUuid: made.program.uuid,
      title: 'Day 1',
    );
    expect(await sessions.finish(session.uuid), isTrue);
    final ended = (await sessions.once(session.uuid))!.endedAt;
    expect(
      await sessions.finish(session.uuid, at: DateTime(2020)),
      isFalse,
    );
    expect((await sessions.once(session.uuid))!.endedAt, ended);
  });
}
