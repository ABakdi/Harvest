import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/text_prompt.dart';
import 'package:harvest/features/notes/data/note_folders.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:harvest/features/notes/presentation/notes_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The vault, down the side.
///
/// Everything about *which* note I am looking at lives here — folders,
/// the list, search, the trash — because the middle of the screen is
/// for one thing only: the note itself. That separation is the whole
/// point of the sidebar; a file tree in the reading column is how a
/// note-taking app becomes a file manager.
class NotesSidebar extends ConsumerStatefulWidget {
  const NotesSidebar({
    required this.openUuid,
    required this.onOpen,
    required this.onNewNote,
    required this.onOpenTrash,
    super.key,
  });

  final String? openUuid;

  /// Null closes whatever is open and shows the empty state.
  final void Function(String? uuid) onOpen;

  /// Makes a note in the given folder and opens it.
  final void Function(String folder) onNewNote;
  final VoidCallback onOpenTrash;

  @override
  ConsumerState<NotesSidebar> createState() => _NotesSidebarState();
}

class _NotesSidebarState extends ConsumerState<NotesSidebar> {
  final _search = TextEditingController();
  final _open = <String>{};
  NoteSort _sort = NoteSort.edited;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _newFolder({String parent = ''}) async {
    final l10n = AppLocalizations.of(context);
    final name = await promptForText(
      context,
      title: l10n.notesNewFolder,
      hint: l10n.notesFolderNameHint,
      prefix: parent.isEmpty ? null : '$parent/',
      confirmLabel: l10n.notesCreate,
    );
    if (name == null || name.trim().isEmpty) return;
    final path = parent.isEmpty ? name : '$parent/$name';
    await ref.read(declaredFoldersProvider.notifier).add(path);
    if (mounted) setState(() => _open.add(normalizeFolder(path)));
  }

  Future<void> _renameFolder(String folder) async {
    final l10n = AppLocalizations.of(context);
    final parent = folder.contains('/')
        ? folder.substring(0, folder.lastIndexOf('/'))
        : '';
    final name = await promptForText(
      context,
      title: l10n.notesRenameFolder,
      initial: folder.split('/').last,
      prefix: parent.isEmpty ? null : '$parent/',
    );
    if (name == null || name.trim().isEmpty) return;
    final to = normalizeFolder(parent.isEmpty ? name : '$parent/$name');
    if (to == folder) return;
    await ref.read(notesRepositoryProvider).renameFolder(folder, to);
    await ref.read(declaredFoldersProvider.notifier).rename(folder, to);
  }

  Future<void> _deleteFolder(String folder) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(notesRepositoryProvider);
    final moved = await repository.trashFolder(folder);
    await ref.read(declaredFoldersProvider.notifier).forget(folder);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.notesFolderTrashed(folder, moved))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = ref.watch(allNotesProvider).value ?? const <Note>[];
    final folders = ref.watch(noteFolderTreeProvider);
    final trashed = ref.watch(deletedNotesProvider).value ?? const <Note>[];
    final query = _search.text.trim();

    final matches = filterNotes(all, (
      search: query,
      folder: '',
      sort: _sort,
    ));

    return Drawer(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HarvestSpacing.md,
                HarvestSpacing.md,
                HarvestSpacing.sm,
                HarvestSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.notesTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.notesNewFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    onPressed: () => unawaited(_newFolder()),
                  ),
                  PopupMenuButton<NoteSort>(
                    tooltip: l10n.notesSort,
                    icon: const Icon(Icons.sort),
                    initialValue: _sort,
                    onSelected: (value) => setState(() => _sort = value),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: NoteSort.edited,
                        child: Text(l10n.notesSortEdited),
                      ),
                      PopupMenuItem(
                        value: NoteSort.created,
                        child: Text(l10n.notesSortCreated),
                      ),
                      PopupMenuItem(
                        value: NoteSort.title,
                        child: Text(l10n.notesSortTitle),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HarvestSpacing.md,
              ),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.notesSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.clearValue,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: HarvestSpacing.xs),
            Expanded(
              child: query.isNotEmpty
                  ? _results(matches)
                  : _tree(all, folders),
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: Icon(Icons.delete_outline, color: scheme.onSurfaceVariant),
              title: Text(l10n.trashTitle),
              trailing: trashed.isEmpty
                  ? null
                  : Text(
                      '${trashed.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
              onTap: widget.onOpenTrash,
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(List<Note> matches) {
    final l10n = AppLocalizations.of(context);
    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.lg),
          child: Text(
            l10n.notesNoMatch,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: HarvestSpacing.md),
      children: [for (final note in matches) _noteTile(note, depth: 0)],
    );
  }

  /// The tree: root notes first, then a folder per branch.
  Widget _tree(List<Note> all, List<String> folders) {
    final roots = folders.where((f) => !f.contains('/')).toList();
    final loose = _sorted(all.where((n) => n.folder.isEmpty).toList());

    return ListView(
      padding: const EdgeInsets.only(bottom: HarvestSpacing.md),
      children: [
        for (final folder in roots) ..._folder(folder, all, folders, 0),
        for (final note in loose) _noteTile(note, depth: 0),
        _NewHere(
          label: AppLocalizations.of(context).notesNewHere,
          depth: 0,
          onTap: () => widget.onNewNote(''),
        ),
      ],
    );
  }

  List<Widget> _folder(
    String folder,
    List<Note> all,
    List<String> folders,
    int depth,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final expanded = _open.contains(folder);
    final children = folders
        .where(
          (f) =>
              f.startsWith('$folder/') &&
              !f.substring(folder.length + 1).contains('/'),
        )
        .toList();
    final notes = _sorted(all.where((n) => n.folder == folder).toList());
    final count = all
        .where((n) => n.folder == folder || n.folder.startsWith('$folder/'))
        .length;

    return [
      InkWell(
        onTap: () => setState(() {
          if (!_open.add(folder)) _open.remove(folder);
        }),
        onLongPress: () => unawaited(_folderMenu(folder)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            HarvestSpacing.md + depth * 14,
            8,
            HarvestSpacing.sm,
            8,
          ),
          child: Row(
            children: [
              Icon(
                expanded ? Icons.expand_more : Icons.chevron_right,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
              Icon(
                expanded ? Icons.folder_open : Icons.folder,
                size: 18,
                color: scheme.tertiary,
              ),
              const SizedBox(width: HarvestSpacing.xs),
              Expanded(
                child: Text(
                  folder.split('/').last,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count > 0)
                Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              IconButton(
                tooltip: l10n.notesFolderOptions,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.more_horiz, size: 18),
                onPressed: () => unawaited(_folderMenu(folder)),
              ),
            ],
          ),
        ),
      ),
      if (expanded) ...[
        for (final child in children) ..._folder(child, all, folders, depth + 1),
        for (final note in notes) _noteTile(note, depth: depth + 1),
        _NewHere(
          label: l10n.notesNewHere,
          depth: depth + 1,
          onTap: () => widget.onNewNote(folder),
        ),
      ],
    ];
  }

  Future<void> _folderMenu(String folder) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: Text(l10n.notesNewHere),
              onTap: () => Navigator.of(context).pop('note'),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(l10n.notesNewSubfolder),
              onTap: () => Navigator.of(context).pop('folder'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(l10n.notesRenameFolder),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.notesDeleteFolder),
              subtitle: Text(l10n.notesDeleteFolderHint),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'note':
        widget.onNewNote(folder);
      case 'folder':
        await _newFolder(parent: folder);
      case 'rename':
        await _renameFolder(folder);
      case 'delete':
        await _deleteFolder(folder);
    }
  }

  List<Note> _sorted(List<Note> notes) =>
      filterNotes(notes, (search: '', folder: '', sort: _sort));

  Widget _noteTile(Note note, {required int depth}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = note.uuid == widget.openUuid;

    return InkWell(
      onTap: () => widget.onOpen(note.uuid),
      child: Container(
        color: selected ? scheme.secondaryContainer.withValues(alpha: 0.6) : null,
        padding: EdgeInsets.fromLTRB(
          HarvestSpacing.md + depth * 14,
          8,
          HarvestSpacing.md,
          8,
        ),
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: 17,
              color: selected ? scheme.secondary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: HarvestSpacing.xs),
            Expanded(
              child: Text(
                note.title.isEmpty ? l10n.notesUntitled : note.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: note.title.isEmpty ? scheme.outline : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewHere extends StatelessWidget {
  const _NewHere({
    required this.label,
    required this.depth,
    required this.onTap,
  });

  final String label;
  final int depth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          HarvestSpacing.md + depth * 14,
          8,
          HarvestSpacing.md,
          8,
        ),
        child: Row(
          children: [
            Icon(Icons.add, size: 17, color: scheme.primary),
            const SizedBox(width: HarvestSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
