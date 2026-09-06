import 'dart:convert';

import 'package:harvest/features/notes/presentation/notes_providers.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'note_folders.g.dart';

/// Folders I have made but not filled yet.
///
/// A folder is still "a path, nothing more" ([[Notes]]): the truth
/// about where a note lives is the note's own `folder` column, and the
/// export writes the tree from those paths. This list only remembers
/// the folders that have no note in them yet, so making one in the
/// sidebar and filling it a minute later is possible at all.
///
/// It rides in `kv_settings`, which means it goes out in the archive
/// and comes back with it for free — a folder is not worth a table.
abstract final class NoteFolderKeys {
  static const declared = 'notes.folders';
}

@riverpod
class DeclaredFolders extends _$DeclaredFolders {
  @override
  Stream<List<String>> build() => ref
      .watch(settingsRepositoryProvider)
      .watchAll([NoteFolderKeys.declared])
      .map((values) => decodeFolders(values[NoteFolderKeys.declared]));

  Future<void> add(String path) async {
    final cleaned = normalizeFolder(path);
    if (cleaned.isEmpty) return;
    final current = state.value ?? const <String>[];
    if (current.contains(cleaned)) return;
    await _write([...current, cleaned]);
  }

  /// Forgets [path] and everything under it.
  Future<void> forget(String path) async {
    final current = state.value ?? const <String>[];
    await _write([
      for (final folder in current)
        if (folder != path && !folder.startsWith('$path/')) folder,
    ]);
  }

  Future<void> rename(String from, String to) async {
    final current = state.value ?? const <String>[];
    await _write([
      for (final folder in current)
        if (folder == from)
          to
        else if (folder.startsWith('$from/'))
          to + folder.substring(from.length)
        else
          folder,
    ]);
  }

  Future<void> _write(List<String> folders) async {
    final unique = folders.where((f) => f.isNotEmpty).toSet().toList()..sort();
    await ref
        .read(settingsRepositoryProvider)
        .setString(NoteFolderKeys.declared, jsonEncode(unique));
  }
}

/// Every folder the sidebar shows: the ones holding notes, the ones I
/// made and have not filled, and every parent of both.
///
/// It watches both sources rather than reading one inside the other's
/// stream — a folder made a second ago has no notes in it yet, and that
/// is precisely the folder that has to appear.
@riverpod
List<String> noteFolderTree(Ref ref) {
  final fromNotes = ref.watch(noteFoldersProvider).value ?? const <String>[];
  final declared = ref.watch(declaredFoldersProvider).value ?? const <String>[];
  final all = <String>{};
  for (final folder in [...fromNotes, ...declared]) {
    final parts = folder.split('/');
    for (var i = 1; i <= parts.length; i++) {
      all.add(parts.take(i).join('/'));
    }
  }
  return all.toList()..sort();
}

/// `/Health//Sleep/` → `Health/Sleep`.
String normalizeFolder(String path) => path
    .split('/')
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .join('/');

List<String> decodeFolders(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (entry is String && entry.isNotEmpty) entry,
    ]..sort();
  } on FormatException {
    return const [];
  }
}
