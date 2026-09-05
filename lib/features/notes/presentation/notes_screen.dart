import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/harvest_fab.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:harvest/features/notes/presentation/notes_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The vault: every note, searchable, filtered by folder, sorted.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _search = TextEditingController();
  var _folder = '';
  NoteSort _sort = NoteSort.edited;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final note = await ref
        .read(notesRepositoryProvider)
        .create(folder: _folder);
    if (!mounted) return;
    await context.push('${AppRoutes.notes}/${note.uuid}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final all = ref.watch(allNotesProvider).value;
    final folders = ref.watch(noteFoldersProvider).value ?? const <String>[];

    final notes = all == null
        ? const <Note>[]
        : filterNotes(all, (
            search: _search.text,
            folder: _folder,
            sort: _sort,
          ));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notesTitle),
        actions: [
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
      floatingActionButton: HarvestFab(
        onPressed: () => unawaited(_create()),
        label: l10n.notesNew,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HarvestSpacing.md,
              HarvestSpacing.sm,
              HarvestSpacing.md,
              0,
            ),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.notesSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.text.isEmpty
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
          if (folders.isNotEmpty)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: HarvestSpacing.md,
                  vertical: HarvestSpacing.sm,
                ),
                children: [
                  ChoiceChip(
                    label: Text(l10n.notesAllFolders),
                    selected: _folder.isEmpty,
                    onSelected: (_) => setState(() => _folder = ''),
                  ),
                  for (final folder in folders)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: HarvestSpacing.xs,
                      ),
                      child: ChoiceChip(
                        avatar: const Icon(Icons.folder_outlined, size: 16),
                        label: Text(folder),
                        selected: _folder == folder,
                        onSelected: (_) => setState(() => _folder = folder),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: notes.isEmpty
                ? EmptyState(
                    icon: Icons.description_outlined,
                    title: all == null || all.isEmpty
                        ? l10n.notesEmpty
                        : l10n.notesNoMatch,
                    body: all == null || all.isEmpty
                        ? l10n.notesEmptyBody
                        : l10n.notesNoMatchBody,
                    color: theme.colorScheme.tertiary,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      HarvestSpacing.md,
                      HarvestSpacing.sm,
                      HarvestSpacing.md,
                      96,
                    ),
                    itemCount: notes.length,
                    itemBuilder: (context, index) =>
                        _NoteCard(note: notes[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = note.preview;

    return Card(
      margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(HarvestRadii.card),
        onTap: () => unawaited(
          context.push('${AppRoutes.notes}/${note.uuid}'),
        ),
        child: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(Icons.description_outlined, color: scheme.tertiary),
              const SizedBox(width: HarvestSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isEmpty ? l10n.notesUntitled : note.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: note.title.isEmpty ? scheme.outline : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (preview.isNotEmpty)
                      Text(
                        preview,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (note.folder.isNotEmpty) ...[
                          Icon(
                            Icons.folder_outlined,
                            size: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            note.folder,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: HarvestSpacing.sm),
                        ],
                        Text(
                          formatDay(
                            context,
                            HarvestDay.of(note.updatedAt),
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
