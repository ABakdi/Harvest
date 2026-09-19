import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/assist/domain/assist.dart';
import 'package:harvest/features/assist/domain/prompts.dart';
import 'package:harvest/features/assist/presentation/assist_sheet.dart';
import 'package:harvest/features/notes/data/note_attachments.dart';
import 'package:harvest/features/notes/data/note_folders.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/data/voice_gateways.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:harvest/features/notes/domain/note_pdf.dart';
import 'package:harvest/features/notes/domain/voice.dart';
import 'package:harvest/features/notes/presentation/editing_focus.dart';
import 'package:harvest/features/notes/presentation/live_markdown_controller.dart';
import 'package:harvest/features/notes/presentation/markdown_toolbar.dart';
import 'package:harvest/features/notes/presentation/note_editor.dart';
import 'package:harvest/features/notes/presentation/note_trash_screen.dart';
import 'package:harvest/features/notes/presentation/notes_providers.dart';
import 'package:harvest/features/notes/presentation/notes_sidebar.dart';
import 'package:harvest/features/notes/presentation/voice_widgets.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:printing/printing.dart';

/// The vault: the tree down the side, one note in the middle.
///
/// The sidebar is a drawer rather than a permanent column because this
/// is a phone — but it is the same idea, and the middle of the screen
/// never becomes a file list.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({this.initialUuid, this.title, this.tabs, super.key});

  /// The title and tabs of the paired screen this is half of, when it
  /// is one ([[Checkpoint-6]]); on its own it names itself.
  final String? title;
  final PreferredSizeWidget? tabs;

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
    if (_open != null) _remember(_open);
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

  /// The note I was last in, if it is still there; the latest otherwise.
  Future<void> _openLatest() async {
    final settings = ref.read(settingsRepositoryProvider);
    final remembered = await settings.getString(SettingKeys.recordsNote);
    final notes = await ref.read(notesRepositoryProvider).watchAll().first;
    if (!mounted || notes.isEmpty || _open != null) return;
    final last = notes.where((note) => note.uuid == remembered).firstOrNull;
    setState(() => _open = (last ?? notes.first).uuid);
  }

  /// Written on every change, so a cold start lands on the same note
  /// ([[Checkpoint-7]]).
  void _remember(String? uuid) {
    final settings = ref.read(settingsRepositoryProvider);
    unawaited(
      uuid == null
          ? settings.remove(SettingKeys.recordsNote)
          : settings.setString(SettingKeys.recordsNote, uuid),
    );
  }

  void _show(String? uuid) {
    setState(() => _open = uuid);
    _remember(uuid);
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

  /// The three-second path: a note named by the minute, recording at
  /// once ([[Notes]] — voice notes).
  Future<void> _newVoiceNote(String folder) async {
    final note = await ref
        .read(notesRepositoryProvider)
        .create(
          title: voiceNoteTitle(DateTime.now()),
          folder: normalizeFolder(folder),
        );
    if (!mounted) return;
    _show(note.uuid);
    // After the editor for the new note has taken the controller.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _record(note.uuid);
  }

  /// Records into the open note and drops its embed at the caret.
  Future<void> _record(String noteUuid) async {
    final attachment = await showRecordingSheet(context, noteUuid: noteUuid);
    if (attachment == null || !mounted) return;
    _insertAtCaret(audioEmbed(attachment.fileName), ownLine: true);
  }

  /// Dictation: the phone's recogniser, words at the caret (N10).
  Future<void> _dictate() async {
    final dictation = ref.read(dictationProvider);
    if (_dictating) {
      await dictation.stop();
      setState(() => _dictating = false);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!await dictation.available()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.voiceNoDictation)));
      return;
    }
    if (!mounted) return;
    setState(() => _dictating = true);
    await dictation.listen(
      localeId: Localizations.localeOf(context).toLanguageTag(),
      onWords: (words, {required done}) {
        if (!done || !mounted) return;
        if (words.trim().isNotEmpty) _insertAtCaret(words.trim());
        setState(() => _dictating = false);
      },
    );
  }

  var _dictating = false;

  /// Types [text] at the caret, as a line of its own when asked.
  void _insertAtCaret(String text, {bool ownLine = false}) {
    final value = _body.value;
    final at = value.selection.isValid
        ? value.selection.end.clamp(0, value.text.length)
        : value.text.length;
    final before = value.text.substring(0, at);
    final after = value.text.substring(at);
    final lead = ownLine && before.isNotEmpty && !before.endsWith('\n')
        ? '\n'
        : (!ownLine &&
                  before.isNotEmpty &&
                  !before.endsWith(' ') &&
                  !before.endsWith('\n')
              ? ' '
              : '');
    final tail = ownLine && !after.startsWith('\n') ? '\n' : '';
    final inserted = '$lead$text$tail';
    _body.value = TextEditingValue(
      text: '$before$inserted$after',
      selection: TextSelection.collapsed(offset: at + inserted.length),
    );
  }

  /// Assist on this note: pick an action, see what is sent, then
  /// Insert, Replace or Copy ([[Notes]] N8, N9).
  Future<void> _assist() async {
    final value = _body.value;
    final selection = value.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final action = await pickAssistAction(context, hasSelection: hasSelection);
    if (action == null || !mounted) return;
    final fromSelection = hasSelection && actsOnSelection(action);
    final text = fromSelection ? selection.textInside(value.text) : value.text;
    final caret = selection.isValid
        ? selection.end.clamp(0, value.text.length)
        : value.text.length;
    final outcome = await showAssistSheet(
      context,
      action: action,
      text: text,
      upToCaret: value.text.substring(0, caret),
      fromSelection: fromSelection,
    );
    if (outcome == null || !mounted) return;
    if (outcome.replace && fromSelection) {
      final replaced =
          selection.textBefore(value.text) +
          outcome.text +
          selection.textAfter(value.text);
      _body.value = TextEditingValue(
        text: replaced,
        selection: TextSelection.collapsed(
          offset: selection.start + outcome.text.length,
        ),
      );
    } else if (action == AssistAction.summarise) {
      // A summary goes on top, where it will be read first.
      _body.value = TextEditingValue(
        text: '> ${outcome.text.replaceAll('\n', '\n> ')}\n\n${value.text}',
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      _insertAtCaret(outcome.text, ownLine: true);
    }
  }

  /// Sends one recording to the assist and puts its words under it, as
  /// a quote, the recording kept (N10).
  Future<void> _transcribe(NoteAttachment recording) async {
    final file = await ref
        .read(attachmentStorageProvider)
        .fileOf(recording.storedPath);
    if (!file.existsSync() || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final outcome = await showAssistSheet(
      context,
      action: AssistAction.transcribe,
      text: '',
      audio: AssistAudio(bytes: bytes, mimeType: 'audio/mp4'),
    );
    if (outcome == null || !mounted) return;
    final text = _body.text;
    final embed = audioEmbed(recording.fileName);
    final at = text.indexOf(embed);
    final quote = '> ${outcome.text.replaceAll('\n', '\n> ')}';
    if (at < 0) {
      _insertAtCaret(quote, ownLine: true);
      return;
    }
    final end = at + embed.length;
    final next = '${text.substring(0, end)}\n$quote${text.substring(end)}';
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: end + 1 + quote.length),
    );
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
    _remember(null);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note == null
                  ? widget.title ?? l10n.notesTitle
                  : note.title.isEmpty
                  ? l10n.notesUntitled
                  : note.title,
              overflow: TextOverflow.ellipsis,
            ),
            // With the Records tabs under the title, the folder has to
            // live up here instead ([[Checkpoint-8]]).
            if (note != null && note.folder.isNotEmpty && widget.tabs != null)
              Text(
                note.folder,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.voiceNew,
            icon: const Icon(Icons.mic_none),
            onPressed: () => unawaited(_newVoiceNote(note?.folder ?? '')),
          ),
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
                'record' => unawaited(_record(note.uuid)),
                'assist' => unawaited(_assist()),
                'read' => unawaited(
                  showReadAloudSheet(context, markdown: _body.text),
                ),
                _ => unawaited(_delete(note)),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'assist',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text(l10n.assistTitle),
                  ),
                ),
                PopupMenuItem(
                  value: 'record',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mic_none),
                    title: Text(l10n.voiceRecord),
                  ),
                ),
                PopupMenuItem(
                  value: 'read',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.record_voice_over_outlined),
                    title: Text(l10n.readAloud),
                  ),
                ),
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
        // The Records tabs stay whether a note is open or not: hiding
        // them behind an open note made the gallery unreachable to
        // anyone who did not know to close the note first
        // ([[Checkpoint-8]]). Alone, Notes shows the folder here.
        bottom:
            widget.tabs ??
            (note == null || note.folder.isEmpty
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
                  )),
      ),
      bottomNavigationBar: writing && note != null
          ? MarkdownToolbar(
              controller: _body,
              onRecord: () => unawaited(_record(note.uuid)),
              onDictate: () => unawaited(_dictate()),
              dictating: _dictating,
            )
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
              onTranscribe: (recording) => unawaited(_transcribe(recording)),
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
