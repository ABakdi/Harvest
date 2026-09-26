import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notes_providers.g.dart';

/// How the list is ordered.
enum NoteSort { edited, created, title }

@riverpod
Stream<List<Note>> allNotes(Ref ref) =>
    ref.watch(notesRepositoryProvider).watchAll();

@riverpod
Stream<List<String>> noteFolders(Ref ref) =>
    ref.watch(notesRepositoryProvider).watchFolders();

/// What is in the trash.
@riverpod
Stream<List<Note>> deletedNotes(Ref ref) =>
    ref.watch(notesRepositoryProvider).watchDeleted();

@riverpod
Stream<Note?> note(Ref ref, String uuid) =>
    ref.watch(notesRepositoryProvider).watchOne(uuid);

@riverpod
Stream<List<Note>> backlinks(Ref ref, String uuid) =>
    ref.watch(notesRepositoryProvider).watchBacklinks(uuid);

@riverpod
Stream<List<({String title, String? uuid})>> outgoingLinks(
  Ref ref,
  String uuid,
) => ref.watch(notesRepositoryProvider).watchOutgoing(uuid);

/// What the list is narrowed to.
typedef NoteQuery = ({String search, String folder, NoteSort sort});

/// The notes matching a query, sorted.
///
/// Search reads the title and the body, because "the note where I wrote
/// about the car" is the question actually asked of a vault.
List<Note> filterNotes(List<Note> notes, NoteQuery query) {
  final needle = query.search.trim().toLowerCase();
  final matched = notes.where((note) {
    if (query.folder.isNotEmpty &&
        note.folder != query.folder &&
        !note.folder.startsWith('${query.folder}/')) {
      return false;
    }
    if (needle.isEmpty) return true;
    return note.title.toLowerCase().contains(needle) ||
        note.body.toLowerCase().contains(needle);
  }).toList();

  return matched
    ..sort(switch (query.sort) {
      NoteSort.edited => (a, b) => b.updatedAt.compareTo(a.updatedAt),
      NoteSort.created => (a, b) => b.createdAt.compareTo(a.createdAt),
      NoteSort.title => (a, b) =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    });
}
