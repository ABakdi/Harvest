import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/features/notes/data/note_attachments.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:harvest/features/notes/domain/voice.dart';
import 'package:harvest/features/notes/presentation/editing_focus.dart';
import 'package:harvest/features/notes/presentation/live_markdown_controller.dart';
import 'package:harvest/features/notes/presentation/notes_providers.dart';
import 'package:harvest/features/notes/presentation/voice_widgets.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// One note, written and read in the same place.
///
/// There is no Read button and no Edit button: the body renders as
/// markdown and shows its syntax on whichever line the caret is on
/// ([[LiveMarkdownController]]). What is left is a page and a caret,
/// which is what writing wants.
class NoteEditor extends ConsumerStatefulWidget {
  const NoteEditor({
    required this.uuid,
    required this.onOpen,
    required this.controller,
    this.onTranscribe,
    super.key,
  });

  final String uuid;

  /// Following a `[[link]]` opens another note in the same place.
  final void Function(String uuid) onOpen;

  /// Offered on each recording when the assist can transcribe.
  final void Function(NoteAttachment recording)? onTranscribe;

  /// Owned by the screen, so the toolbar above the keyboard and the
  /// text field are talking about the same caret.
  final LiveMarkdownController controller;

  @override
  ConsumerState<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<NoteEditor> {
  final _title = TextEditingController();
  final _bodyFocus = FocusNode();
  Timer? _debounce;
  String? _loaded;
  String _lastBody = '';

  // Taken while the widget is alive: `dispose` runs after the element
  // is unmounted, and by then `ref` refuses every call ([[Audit-v2]]
  // U3-01). What the last save and the toolbar need is kept here.
  late final NotesRepository _repository;
  late final NoteAttachmentsRepository _attachments;
  late final WritingNote _writing;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(notesRepositoryProvider);
    _attachments = ref.read(noteAttachmentsRepositoryProvider);
    _writing = ref.read(writingNoteProvider.notifier);
    // Redraws on every caret move: which line shows its syntax is a
    // function of the selection, so the selection has to repaint.
    widget.controller.addListener(_onSelectionChanged);
    _bodyFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSelectionChanged);
    _bodyFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    // A save still on the clock when the note is closed is a save that
    // has to happen anyway: switching notes must not be a way to lose
    // the last half-second of typing.
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      final uuid = widget.uuid;
      final body = _lastBody;
      final attachments = _attachments;
      _repository
          .update(uuid, title: _title.text, body: body)
          .then((_) => attachments.reconcile(uuid, body))
          .ignore();
    }
    _title.dispose();
    // Leaving the editor puts the toolbar away with it — after the
    // frame, since providers may not change while the tree finalizes.
    final writing = _writing;
    unawaited(Future.microtask(writing.release));
    super.dispose();
  }

  void _onFocusChanged() => _writing.set(_bodyFocus.hasFocus);

  /// Fires for a caret move *and* for an edit.
  ///
  /// Both matter: which line shows its syntax is a function of the
  /// selection, so the field has to repaint; and the toolbar edits the
  /// body through the controller, which never calls `onChanged` — so
  /// this is also where an autosave has to be queued, or every table
  /// and every bold the toolbar inserts is lost on the way out.
  void _onSelectionChanged() {
    final body = widget.controller.text;
    if (body != _lastBody) {
      _lastBody = body;
      _queueSave();
    }
    setState(() {});
  }

  void _queueSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    if (!mounted) return;
    final body = widget.controller.text;
    await _repository.update(widget.uuid, title: _title.text, body: body);
    // A recording whose line was deleted goes to the trash with this
    // save; one pasted back comes out of it.
    await _attachments.reconcile(widget.uuid, body);
  }

  /// Tapping a `[[link]]`: go there, or offer to write it.
  Future<void> _followLink(String title) async {
    final repository = ref.read(notesRepositoryProvider);
    final existing = await repository.byTitle(title);
    if (!mounted) return;
    if (existing != null) {
      widget.onOpen(existing.uuid);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final make = await confirm(
      context,
      title: l10n.notesCreateLinkTitle(title),
      body: l10n.notesCreateLinkBody,
      confirmLabel: l10n.notesCreate,
    );
    if (!make || !mounted) return;
    final note = await repository.create(title: title);
    if (!mounted) return;
    widget.onOpen(note.uuid);
  }

  /// The `[[links]]` on the caret's line, so they can be followed by
  /// tapping a chip rather than by hitting a word in a text field.
  List<String> _linksOnLine(String body) {
    final selection = widget.controller.selection;
    if (!selection.isValid) return const [];
    final start =
        body.lastIndexOf('\n', selection.start == 0 ? 0 : selection.start - 1) +
        1;
    final next = body.indexOf('\n', selection.end);
    final line = body.substring(start, next < 0 ? body.length : next);
    return [for (final link in linksIn(line)) link.title];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final note = ref.watch(noteProvider(widget.uuid)).value;
    final backlinks =
        ref.watch(backlinksProvider(widget.uuid)).value ?? const <Note>[];

    if (note == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.xl),
          child: Text(
            l10n.notesGoneBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (_loaded != note.uuid) {
      _loaded = note.uuid;
      _title.text = note.title;
      _lastBody = note.body;
      // Detached while it is filled: setting the text notifies, the
      // listener calls setState, and setState during build is a rebuild
      // every frame — which starves the whole app, snack bar timers
      // and all.
      widget.controller
        ..removeListener(_onSelectionChanged)
        ..text = note.body
        ..addListener(_onSelectionChanged);
    }

    final links = _linksOnLine(widget.controller.text);
    // Recordings show in the order the body embeds them, and only while
    // it does: the embed line is the truth (N7).
    final embedded = audioEmbedsIn(widget.controller.text);
    final stored = {
      for (final attachment
          in ref.watch(noteAttachmentsProvider(widget.uuid)).value ??
              const <NoteAttachment>[])
        attachment.fileName.toLowerCase(): attachment,
    };
    final recordings = [
      for (final name in embedded) ?stored[name.toLowerCase()],
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              HarvestSpacing.lg,
              HarvestSpacing.md,
              HarvestSpacing.lg,
              HarvestSpacing.xl,
            ),
            children: [
              TextField(
                controller: _title,
                onChanged: (_) => _queueSave(),
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  hintText: l10n.notesTitleHint,
                ),
              ),
              Divider(height: HarvestSpacing.lg, color: scheme.outlineVariant),
              TextField(
                controller: widget.controller,
                focusNode: _bodyFocus,
                maxLines: null,
                minLines: 16,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  hintText: l10n.notesBodyHint,
                ),
              ),
              if (recordings.isNotEmpty) ...[
                const SizedBox(height: HarvestSpacing.md),
                for (final recording in recordings)
                  RecordingPlayer(
                    key: ValueKey(recording.uuid),
                    attachment: recording,
                    onTranscribe: widget.onTranscribe == null
                        ? null
                        : () => widget.onTranscribe!(recording),
                  ),
              ],
              if (links.isNotEmpty) ...[
                const SizedBox(height: HarvestSpacing.sm),
                Wrap(
                  spacing: HarvestSpacing.xs,
                  children: [
                    for (final title in links)
                      ActionChip(
                        avatar: const Icon(Icons.north_east, size: 15),
                        label: Text(title),
                        onPressed: () => unawaited(_followLink(title)),
                      ),
                  ],
                ),
              ],
              if (backlinks.isNotEmpty) ...[
                const SizedBox(height: HarvestSpacing.lg),
                Text(
                  l10n.notesBacklinks(backlinks.length),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: HarvestSpacing.xs),
                Wrap(
                  spacing: HarvestSpacing.xs,
                  runSpacing: HarvestSpacing.xs,
                  children: [
                    for (final source in backlinks)
                      ActionChip(
                        avatar: const Icon(
                          Icons.subdirectory_arrow_left,
                          size: 15,
                        ),
                        label: Text(
                          source.title.isEmpty
                              ? l10n.notesUntitled
                              : source.title,
                        ),
                        onPressed: () => widget.onOpen(source.uuid),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
