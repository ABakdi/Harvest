import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';

/// [[Audit-v2]] U3-11: trashing a folder takes its notes, and says
/// which ones, so the undo brings back exactly those.
void main() {
  test('it names what it trashed, and nothing else comes back', () async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final notes = NotesRepository(db);

    final kept = await notes.create(title: 'Elsewhere');
    final one = await notes.create(title: 'Sleep', folder: 'Health');
    final two = await notes.create(title: 'Runs', folder: 'Health/Logs');
    final alreadyGone = await notes.create(title: 'Old', folder: 'Health');
    await notes.remove(alreadyGone.uuid);

    final trashed = await notes.trashFolder('Health');
    expect(trashed.toSet(), {one.uuid, two.uuid});

    final live = await notes.watchAll().first;
    expect(live.map((n) => n.uuid), [kept.uuid]);

    for (final uuid in trashed) {
      await notes.restore(uuid);
    }
    final back = await notes.watchAll().first;
    expect(back.map((n) => n.uuid).toSet(), {kept.uuid, one.uuid, two.uuid});
  });
}
