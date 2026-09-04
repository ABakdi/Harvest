import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Archiving asks one question: why?
///
/// A shelf of titles with dates tells me nothing six months later. The
/// note is the difference between "Read Atomic Habits" sitting in the
/// archive and "finished it, moving on to the next one".
Future<bool> showArchiveSheet(BuildContext context, Commitment commitment) =>
    showHarvestSheet<bool>(
      context,
      builder: (_) => _ArchiveSheet(commitment: commitment),
    ).then((archived) => archived ?? false);

class _ArchiveSheet extends ConsumerStatefulWidget {
  const _ArchiveSheet({required this.commitment});

  final Commitment commitment;

  @override
  ConsumerState<_ArchiveSheet> createState() => _ArchiveSheetState();
}

class _ArchiveSheetState extends ConsumerState<_ArchiveSheet> {
  final _controller = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _archive() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final note = _controller.text.trim();
    await ref
        .read(commitmentEditorProvider.notifier)
        .archive(widget.commitment.uuid, note: note.isEmpty ? null : note);
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return HarvestSheet(
      title: l10n.archiveAction,
      subtitle: l10n.archiveSheetBody(widget.commitment.title),
      actionLabel: l10n.archiveAction,
      onAction: _saving ? null : () => unawaited(_archive()),
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.archiveNoteLabel,
            hintText: l10n.archiveNoteHint,
            counterText: '',
          ),
        ),
      ],
    );
  }
}
