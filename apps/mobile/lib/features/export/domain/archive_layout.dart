import 'package:harvest/features/notes/domain/note.dart';
import 'package:path/path.dart' as p;

/// Where everything sits inside the archive (ADR-007).
///
/// One place decides these paths, because two have to agree exactly:
/// the writer that puts a file in the zip, and the sheet row that says
/// where it went. A drift between them is a browsable tree pointing at
/// nothing.
abstract final class ArchivePaths {
  static const workbook = 'harvest.xlsx';
  static const notes = 'notes';
  static const gallery = 'gallery';
}

/// `notes/Health/Sleep log.md` — the folder structure the app shows,
/// with the title as the filename, sanitised.
///
/// Collisions are possible (`Q4: what now?` and `Q4- what now?` land on
/// the same name), so [taken] carries what has already been used inside
/// the archive and a suffix is added rather than a file lost.
String notePath({
  required String title,
  required String folder,
  required Set<String> taken,
}) {
  final base = safeFileName(title.trim().isEmpty ? 'Untitled' : title);
  final directory = _safeFolder(folder);
  var candidate = p.posix.join(ArchivePaths.notes, directory, '$base.md');
  var suffix = 2;
  while (!taken.add(candidate)) {
    candidate = p.posix.join(
      ArchivePaths.notes,
      directory,
      '$base ($suffix).md',
    );
    suffix++;
  }
  return candidate;
}

/// `notes/Health/2026-09-18 0712.m4a` — a recording sits in the same
/// folder as its note's `.md`, under the name the body embeds, so
/// `![[fileName]]` resolves when the vault is opened in Obsidian
/// ([[Notes]] N7).
///
/// The name is only changed when it has to be: made safe, and numbered
/// when something in the archive already answers to it. A renamed file
/// no longer resolves from the embed, but it is still in the archive,
/// and the sheet still says which recording it is.
String attachmentPath({
  required String notePath,
  required String fileName,
  required Set<String> taken,
}) {
  final directory = p.posix.dirname(notePath);
  final name = safeFileName(fileName);
  final extension = p.posix.extension(name);
  final stem = p.posix.basenameWithoutExtension(name);
  var candidate = p.posix.join(directory, name);
  var suffix = 2;
  while (!taken.add(candidate)) {
    candidate = p.posix.join(directory, '$stem ($suffix)$extension');
    suffix++;
  }
  return candidate;
}

/// `gallery/Gym/2026-09-01.jpg` — one folder per album, files named by
/// their day, numbered when a day holds more than one.
String memoryPath({
  required String albumName,
  required String day,
  required String storedPath,
  required Set<String> taken,
}) {
  final album = safeFileName(
    albumName.trim().isEmpty ? 'Album' : albumName.trim(),
  );
  final extension = p.extension(storedPath).toLowerCase();
  var candidate = p.posix.join(ArchivePaths.gallery, album, '$day$extension');
  var suffix = 2;
  while (!taken.add(candidate)) {
    candidate = p.posix.join(
      ArchivePaths.gallery,
      album,
      '$day-$suffix$extension',
    );
    suffix++;
  }
  return candidate;
}

/// The album's own folder inside the archive, for the sheet to name.
String albumFolder(String albumName) => p.posix.join(
  ArchivePaths.gallery,
  safeFileName(albumName.trim().isEmpty ? 'Album' : albumName.trim()),
);

/// Every segment of a note's folder path, made safe, empties dropped.
String _safeFolder(String folder) => folder
    .split('/')
    .map((segment) => segment.trim())
    .where((segment) => segment.isNotEmpty)
    .map(safeFileName)
    .join('/');
