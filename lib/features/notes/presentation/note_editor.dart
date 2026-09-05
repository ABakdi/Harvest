import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:harvest/features/notes/presentation/editing_focus.dart';
import 'package:harvest/features/notes/presentation/live_markdown_controller.dart';
import 'package:harvest/features/notes/presentation/notes_providers.dart';
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
    super.key,
  });

  final String uuid;

  /// Following a `[[link]]` opens another note in the same place.
  final void Function(String uuid) onOpen;

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

  late final NotesRepository _repository = ref.read(
    notesRepositoryProvider,
  );

  @override
  void initState() {
    super.initState();
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
      _repository
          .update(widget.uuid, title: _title.text, body: _lastBody)
          .ignore();
    }
    _title.dispose();
    // Leaving the editor puts the toolbar away with it.
    ref.read(writingNoteProvider.notifier).set(false);
    super.dispose();
  }

  void _onFocusChanged() =>
      ref.read(writingNoteProvider.notifier).set(_bodyFocus.hasFocus);

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
    await ref
        .read(notesRepositoryProvider)
        .update(widget.uuid, title: _title.text, body: widget.controller.text);
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
