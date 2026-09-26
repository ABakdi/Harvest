import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/presentation/gallery_providers.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';

/// Gallery rule G3: a scheduled album stands on the field. A program's
/// album does not, even with a schedule: the program's seed is the card.
void main() {
  Album album(String uuid) => Album(
    uuid: uuid,
    name: uuid,
    createdAt: DateTime(2026),
    schedule: const DailySchedule(),
  );

  test('a scheduled album is due, a program-bound one is not', () async {
    final container = ProviderContainer(
      overrides: [
        albumsProvider.overrideWith(
          (ref) => Stream.value([album('garden'), album('gym')]),
        ),
        albumCountsTodayProvider.overrideWith((ref) => Stream.value({})),
        albumDoneDaysThisWeekProvider.overrideWith((ref) => Stream.value({})),
        programsProvider.overrideWith(
          (ref) => Stream.value([
            const Program(uuid: 'ppl', name: 'PPL', albumUuid: 'gym'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(albumsDueTodayProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(albumsProvider.future);
    await container.read(albumCountsTodayProvider.future);
    await container.read(albumDoneDaysThisWeekProvider.future);
    await container.read(programsProvider.future);

    final due = container.read(albumsDueTodayProvider);
    expect([for (final entry in due) entry.album.uuid], ['garden']);
  });
}
