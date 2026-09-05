import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/notes/data/note_folders.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:harvest/features/notes/domain/note_pdf.dart';
import 'package:harvest/features/notes/presentation/editing_focus.dart';
import 'package:harvest/features/notes/presentation/live_markdown_controller.dart';
import 'package:harvest/features/notes/presentation/markdown_toolbar.dart';
import 'package:harvest/features/notes/presentation/note_editor.dart';
import 'package:harvest/features/notes/presentation/note_trash_screen.dart';
import 'package:harvest/features/notes/presentation/notes_providers.dart';
import 'package:harvest/features/notes/presentation/notes_sidebar.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:printing/printing.dart';

/// The vault: the tree down the side, one note in the middle.
///
/// The sidebar is a drawer rather than a permanent column because this
/// is a phone — but it is the same idea, and the middle of the screen
/// never becomes a file list.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({this.initialUuid, super.key});

  /// Opened from a deep link, or from a `[[link]]` followed elsewhere.
  final String? initialUuid;

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _body = LiveMarkdownController();
  String? _open;

  @override
  void initState() {
    super.initState();
    _open = widget.initialUuid;
    // Open whatever I was last writing rather than an empty page.
    if (_open == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openLatest());
    }
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _openLatest() async {
    final notes = await ref.read(notesRepositoryProvider).watchAll().first;
    if (!mounted || notes.isEmpty || _open != null) return;
    setState(() => _open = notes.first.uuid);
  }

  void _show(String? uuid) {
    setState(() => _open = uuid);
    if (_scaffold.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _newNote(String folder) async {
    final note = await ref
        .read(notesRepositoryProvider)
        .create(folder: normalizeFolder(folder));
    if (!mounted) return;
    _show(note.uuid);
  }

  Future<void> _moveToFolder(Note note) async {
    final known = ref.read(noteFolderTreeProvider);
    final folder = await showHarvestSheet<String>(
      context,
      builder: (_) => _FolderSheet(initial: note.folder, known: known),
    );
    if (folder == null) return;
    await ref
        .read(notesRepositoryProvider)
        .update(note.uuid, folder: normalizeFolder(folder));
  }

  Future<void> _sharePdf(Note note) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final when = formatDay(context, HarvestDay.of(note.updatedAt));
    final subtitle = note.folder.isEmpty ? when : '${note.folder} · $when';
    try {
      final bytes = await noteToPdf(note, subtitle: subtitle);
      await Printing.sharePdf(bytes: bytes, filename: pdfFileName(note));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.notesPdfFailed)));
    }
  }

  Future<void> _delete(Note note) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(notesRepositoryProvider);
    final ok = await confirm(
      context,
      title: l10n.notesDeleteTitle,
      body: l10n.notesDeleteBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!ok) return;
    await repository.remove(note.uuid);
    if (!mounted) return;
    setState(() => _open = null);
    _openLatest().ignore();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.notesMovedToTrash),
          action: SnackBarAction(
            label: l10n.undoAction,
            onPressed: () => unawaited(repository.restore(note.uuid)),
          ),
        ),
      );
  }

  void _openTrash() {
    Navigator.of(context)
      ..pop()
      ..push(
        MaterialPageRoute<void>(builder: (_) => const NoteTrashScreen()),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final open = _open;
    final note = open == null ? null : ref.watch(noteProvider(open)).value;
    final writing = ref.watch(writingNoteProvider);

    return Scaffold(
      key: _scaffold,
      drawer: NotesSidebar(
        openUuid: _open,
        onOpen: _show,
        onNewNote: (folder) => unawaited(_newNote(folder)),
        onOpenTrash: _openTrash,
      ),
      appBar: AppBar(
        title: Text(
          note == null
              ? l10n.notesTitle
              : note.title.isEmpty
              ? l10n.notesUntitled
              : note.title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: l10n.notesNew,
            icon: const Icon(Icons.add),
            onPressed: () => unawaited(_newNote(note?.folder ?? '')),
          ),
          if (note != null)
            PopupMenuButton<String>(
              onSelected: (value) => switch (value) {
                'folder' => unawaited(_moveToFolder(note)),
                'pdf' => unawaited(_sharePdf(note)),
                _ => unawaited(_delete(note)),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'folder',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(l10n.notesMoveToFolder),
                  ),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(l10n.notesSharePdf),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_outline),
                    title: Text(l10n.deleteAction),
                  ),
                ),
              ],
            ),
        ],
        bottom: note == null || note.folder.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(22),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      HarvestSpacing.md,
                      0,
                      HarvestSpacing.md,
                      6,
                    ),
                    child: Text(
                      note.folder,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
      ),
      bottomNavigationBar: writing && note != null
          ? MarkdownToolbar(controller: _body)
          : null,
      body: note == null
          ? EmptyState(
              icon: Icons.description_outlined,
              title: l10n.notesEmpty,
              body: l10n.notesEmptyBody,
              color: theme.colorScheme.tertiary,
              action: FilledButton.icon(
                onPressed: () => unawaited(_newNote('')),
                icon: const Icon(Icons.add),
                label: Text(l10n.notesNew),
              ),
            )
          : NoteEditor(
              key: ValueKey(note.uuid),
              uuid: note.uuid,
              controller: _body,
              onOpen: _show,
            ),
    );
  }
}

/// Where a note lives: typed, or picked from the folders that exist.
///
/// A sheet rather than a dialog because it may be a long list, and its
/// own widget because it owns a controller — one disposed the instant
/// the sheet's future completes is still attached to a route that is
/// mid-animation, and Flutter is right to complain about that.
class _FolderSheet extends StatefulWidget {
  const _FolderSheet({required this.initial, required this.known});

  final String initial;
  final List<String> known;

  @override
  State<_FolderSheet> createState() => _FolderSheetState();
}

class _FolderSheetState extends State<_FolderSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HarvestSheet(
      title: l10n.notesFolder,
      subtitle: l10n.notesFolderHint,
      actionLabel: l10n.save,
      onAction: () => Navigator.of(context).pop(_controller.text),
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.notesFolder,
            hintText: l10n.notesFolderNameHint,
          ),
        ),
        if (widget.known.isNotEmpty) ...[
          const SizedBox(height: HarvestSpacing.md),
          Wrap(
            spacing: HarvestSpacing.xs,
            runSpacing: HarvestSpacing.xs,
            children: [
              ActionChip(
                label: Text(l10n.notesAllFolders),
                onPressed: () => Navigator.of(context).pop(''),
              ),
              for (final path in widget.known)
                ActionChip(
                  avatar: const Icon(Icons.folder_outlined, size: 15),
                  label: Text(path),
                  onPressed: () => Navigator.of(context).pop(path),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
