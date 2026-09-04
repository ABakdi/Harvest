import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/commitments/data/seed_notes_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/seed_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Today's note on a seed, with the last one I wrote quoted above it.
///
/// This is the whole point of day-keyed notes: I open the book, the
/// sheet tells me I stopped on page 143, and I write down where I stop
/// today. Tomorrow it says 178 and today's is still in the timeline.
Future<void> showSeedNoteSheet(BuildContext context, Commitment commitment) =>
    showHarvestSheet<void>(
      context,
      builder: (_) => _SeedNoteSheet(commitment: commitment),
    );

class _SeedNoteSheet extends ConsumerStatefulWidget {
  const _SeedNoteSheet({required this.commitment});

  final Commitment commitment;

  @override
  ConsumerState<_SeedNoteSheet> createState() => _SeedNoteSheetState();
}

class _SeedNoteSheetState extends ConsumerState<_SeedNoteSheet> {
  final _controller = TextEditingController();
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final day = ref.read(currentHarvestDayProvider);
    final today = await ref
        .read(seedNotesRepositoryProvider)
        .noteOn(widget.commitment.uuid, day);
    if (!mounted) return;
    setState(() {
      _controller.text = today?.body ?? '';
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await ref
        .read(seedNotesRepositoryProvider)
        .write(
          commitmentUuid: widget.commitment.uuid,
          day: ref.read(currentHarvestDayProvider),
          body: _controller.text,
        );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = ref.watch(currentHarvestDayProvider);
    final notes = ref.watch(seedNotesProvider(widget.commitment.uuid)).value;
    final previous = notes
        ?.where((note) => note.day.compareTo(today) < 0)
        .firstOrNull;

    return HarvestSheet(
      title: l10n.seedNotesTitle,
      subtitle: widget.commitment.title,
      actionLabel: l10n.save,
      onAction: _loaded ? () => unawaited(_save()) : null,
      children: [
        if (previous != null) ...[
          _PreviousNote(
            when: formatDay(context, previous.day),
            body: previous.body,
          ),
          const SizedBox(height: HarvestSpacing.md),
        ],
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: SeedNotesRepository.maxLength,
          decoration: InputDecoration(
            labelText: l10n.noteForDay(formatDay(context, today)),
            hintText: l10n.seedNoteHint,
            counterText: '',
          ),
        ),
        Text(
          l10n.seedNotesExplainer,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The last thing I wrote here, quoted — the reason to open the sheet.
class _PreviousNote extends StatelessWidget {
  const _PreviousNote({required this.when, required this.body});

  final String when;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(HarvestSpacing.md),
      decoration: BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(HarvestRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 14, color: scheme.tertiary),
              const SizedBox(width: 4),
              Text(
                l10n.lastTimeOn(when),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.tertiary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
