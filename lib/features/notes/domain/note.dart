import 'package:meta/meta.dart';

/// One markdown note.
///
/// The body is the truth (rule N2): the folder is a string, the links
/// are re-derived from the text on every write, and nothing about a
/// note needs Harvest to be readable.
@immutable
class Note {
  const Note({
    required this.uuid,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.folder = '',
  });

  final String uuid;
  final String title;
  final String folder;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Folder plus title, the way the export lays it out.
  String get path => folder.isEmpty ? title : '$folder/$title';

  /// The first line of prose, for the list. Headings, bullets and
  /// quote markers are stripped so the preview reads like a sentence.
  String get preview {
    for (final raw in body.split('\n')) {
      final line = raw
          .replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '')
          .replaceFirst(RegExp(r'^\s{0,3}[-*+]\s+(\[[ xX]\]\s+)?'), '')
          .replaceFirst(RegExp(r'^\s{0,3}>\s?'), '')
          .trim();
      if (line.isNotEmpty) return line;
    }
    return '';
  }

  Note copyWith({
    String? title,
    String? folder,
    String? body,
    DateTime? updatedAt,
  }) => Note(
    uuid: uuid,
    title: title ?? this.title,
    folder: folder ?? this.folder,
    body: body ?? this.body,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// A `[[link]]` as written in a body.
@immutable
class NoteLink {
  const NoteLink({required this.title, required this.start, required this.end});

  final String title;
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is NoteLink &&
      other.title == title &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(title, start, end);
}

/// Every `[[wiki link]]` in [body], in the order they appear.
///
/// Deliberately forgiving in one direction and strict in another: the
/// title is trimmed so `[[ Reading ]]` finds the same note as
/// `[[Reading]]`, but a bracket pair spanning a newline is not a link,
/// because a note that accidentally links half a paragraph is worse
/// than one that misses an edge case.
List<NoteLink> linksIn(String body) {
  final found = <NoteLink>[];
  final pattern = RegExp(r'\[\[([^\[\]\n]+)\]\]');
  for (final match in pattern.allMatches(body)) {
    final title = match.group(1)!.trim();
    if (title.isEmpty) continue;
    found.add(NoteLink(title: title, start: match.start, end: match.end));
  }
  return found;
}

/// A filename that survives every platform, with the real title kept
/// in the workbook beside it (ADR-007 rule 4).
String safeFileName(String title) {
  final cleaned = title
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final trimmed = cleaned.replaceAll(RegExp(r'^\.+'), '').trim();
  if (trimmed.isEmpty) return 'untitled';
  return trimmed.length > 120 ? trimmed.substring(0, 120).trim() : trimmed;
}
