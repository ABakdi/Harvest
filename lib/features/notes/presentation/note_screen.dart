import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/presentation/markdown_view.dart';
import 'package:harvest/features/notes/presentation/notes_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// One note: written as text, read as markdown.
///
/// There is no Save button and there never will be — the note saves as
/// it is typed, debounced, the way the day notes already do. Nothing in
/// this app should have a save you can miss.
class NoteScreen extends ConsumerStatefulWidget {
  const NoteScreen({required this.uuid, super.key});

  final String uuid;

  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  Timer? _debounce;
  var _loaded = false;
  var _editing = true;

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _queueSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    await ref
        .read(notesRepositoryProvider)
        .update(widget.uuid, title: _title.text, body: _body.text);
  }

  /// Tapping a `[[link]]`: go there, or offer to write it.
  Future<void> _followLink(String title) async {
    final repository = ref.read(notesRepositoryProvider);
    final existing = await repository.byTitle(title);
    if (!mounted) return;
    if (existing != null) {
      await context.push('${AppRoutes.notes}/${existing.uuid}');
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
    await context.push('${AppRoutes.notes}/${note.uuid}');
  }

  Future<void> _moveToFolder() async {
    final l10n = AppLocalizations.of(context);
    final note = ref.read(noteProvider(widget.uuid)).value;
    final controller = TextEditingController(text: note?.folder ?? '');
    final folder = await showHarvestSheet<String>(
      context,
      builder: (context) => HarvestSheet(
        title: l10n.notesFolder,
        subtitle: l10n.notesFolderHint,
        actionLabel: l10n.save,
        onAction: () => Navigator.of(context).pop(controller.text.trim()),
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: l10n.notesFolder),
          ),
        ],
      ),
    );
    controller.dispose();
    if (folder == null) return;
    await ref
        .read(notesRepositoryProvider)
        .update(widget.uuid, folder: folder.replaceAll(RegExp(r'^/+|/+$'), ''));
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
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
    await repository.remove(widget.uuid);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.deleted),
        action: SnackBarAction(
          label: l10n.undoAction,
          onPressed: () => unawaited(repository.restore(widget.uuid)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final note = ref.watch(noteProvider(widget.uuid)).value;
    final backlinkList =
        ref.watch(backlinksProvider(widget.uuid)).value ?? const [];
    final outgoing =
        ref.watch(outgoingLinksProvider(widget.uuid)).value ?? const [];
    final unresolved = {
      for (final link in outgoing)
        if (link.uuid == null) link.title,
    };

    if (note == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.notesTitle)),
        body: EmptyState(
          icon: Icons.description_outlined,
          title: l10n.notesGone,
          body: l10n.notesGoneBody,
        ),
      );
    }
    if (!_loaded) {
      _title.text = note.title;
      _body.text = note.body;
      _loaded = true;
      // A note opened with nothing in it is one I just made.
      _editing = note.body.isEmpty;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          note.title.isEmpty ? l10n.notesUntitled : note.title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: _editing ? l10n.notesRead : l10n.notesEdit,
            icon: Icon(_editing ? Icons.visibility_outlined : Icons.edit),
            onPressed: () {
              if (_editing) unawaited(_save());
              // Reading is reading: the keyboard and the caret both go
              // away rather than hovering over a rendered page.
              FocusScope.of(context).unfocus();
              setState(() => _editing = !_editing);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) => switch (value) {
              'folder' => unawaited(_moveToFolder()),
              _ => unawaited(_delete()),
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'folder', child: Text(l10n.notesFolder)),
              PopupMenuItem(value: 'delete', child: Text(l10n.deleteAction)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.md,
          HarvestSpacing.md,
          HarvestSpacing.md,
          HarvestSpacing.xl,
        ),
        children: [
          TextField(
            controller: _title,
            onChanged: (_) => _queueSave(),
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
          const SizedBox(height: HarvestSpacing.sm),
          if (_editing)
            TextField(
              controller: _body,
              onChanged: (_) => _queueSave(),
              maxLines: null,
              minLines: 14,
              keyboardType: TextInputType.multiline,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintText: l10n.notesBodyHint,
              ),
            )
          else
            MarkdownView(
              source: note.body,
              unresolved: unresolved,
              onWikiLink: (title) => unawaited(_followLink(title)),
            ),
          if (backlinkList.isNotEmpty) ...[
            const Divider(height: HarvestSpacing.xl),
            Text(
              l10n.notesBacklinks(backlinkList.length),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: HarvestSpacing.xs),
            for (final source in backlinkList)
              Card(
                margin: const EdgeInsets.only(bottom: HarvestSpacing.xs),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.subdirectory_arrow_left, size: 20),
                  title: Text(
                    source.title.isEmpty ? l10n.notesUntitled : source.title,
                  ),
                  onTap: () => unawaited(
                    context.push('${AppRoutes.notes}/${source.uuid}'),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
