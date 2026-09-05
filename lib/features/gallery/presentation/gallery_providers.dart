import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gallery_providers.g.dart';

@riverpod
Stream<List<Album>> albums(Ref ref) =>
    ref.watch(galleryRepositoryProvider).watchAlbums();

@riverpod
Stream<Album?> album(Ref ref, String uuid) =>
    ref.watch(galleryRepositoryProvider).watchAlbum(uuid);

@riverpod
Stream<List<Memory>> albumMemories(Ref ref, String uuid) =>
    ref.watch(galleryRepositoryProvider).watchMemories(uuid);

/// What is in the gallery trash.
@riverpod
Stream<List<Memory>> deletedMemories(Ref ref) =>
    ref.watch(galleryRepositoryProvider).watchDeletedMemories();

@riverpod
Stream<List<Album>> deletedAlbums(Ref ref) =>
    ref.watch(galleryRepositoryProvider).watchDeletedAlbums();

@riverpod
Stream<List<AlbumSummary>> albumSummaries(Ref ref) => ref
    .watch(galleryRepositoryProvider)
    .watchSummaries(ref.watch(currentHarvestDayProvider));

/// Memories added per album today — the field's version of "done".
@riverpod
Stream<Map<String, int>> albumCountsToday(Ref ref) => ref
    .watch(galleryRepositoryProvider)
    .watchCountsOn(ref.watch(currentHarvestDayProvider));

/// Distinct days per album this week, for times-per-week schedules.
@riverpod
Stream<Map<String, int>> albumDoneDaysThisWeek(Ref ref) => ref
    .watch(galleryRepositoryProvider)
    .watchDoneDaysThisWeek(ref.watch(currentHarvestDayProvider));

/// The scheduled albums due today, with whether they have been fed.
///
/// This is what puts an album on the field: it is the album's answer to
/// `todayFieldProvider`, computed with the same rules.
@riverpod
List<({Album album, bool done})> albumsDueToday(Ref ref) {
  final today = ref.watch(currentHarvestDayProvider);
  final all = ref.watch(albumsProvider).value ?? const <Album>[];
  final counts = ref.watch(albumCountsTodayProvider).value ?? const {};
  final weekDone = ref.watch(albumDoneDaysThisWeekProvider).value ?? const {};

  final due = <({Album album, bool done})>[];
  for (final album in all) {
    if (!album.isScheduled) continue;
    final done = (counts[album.uuid] ?? 0) > 0;
    // Anything fed today stays visible, the way a checked crop does.
    final isDue =
        done ||
        album.isDueOn(today, doneDaysThisWeek: weekDone[album.uuid] ?? 0);
    if (isDue) due.add((album: album, done: done));
  }
  return due;
}
