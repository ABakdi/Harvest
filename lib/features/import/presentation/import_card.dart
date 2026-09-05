import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';
import 'package:harvest/features/import/domain/archive_reader.dart';
import 'package:harvest/features/import/domain/import_service.dart';
import 'package:harvest/features/import/presentation/import_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Putting an archive back.
///
/// It reads the zip, says exactly what it is about to do, and waits.
/// Nothing local is ever deleted for being missing from the archive,
/// and the card says so before the button is pressed (ADR-007).
class ImportCard extends ConsumerWidget {
  const ImportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(importControllerProvider);
    final busy = state is ImportReading || state is ImportApplying;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.unarchive_outlined),
                const SizedBox(width: HarvestSpacing.md),
                Expanded(child: Text(l10n.importTitle)),
              ],
            ),
            const SizedBox(height: HarvestSpacing.xs),
            Text(l10n.importBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: HarvestSpacing.md),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => unawaited(
                      ref.read(importControllerProvider.notifier).choose(),
                    ),
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.folder_open_outlined),
              label: Text(
                state is ImportApplying
                    ? l10n.importApplying
                    : state is ImportReading
                    ? l10n.importReading
                    : l10n.importAction,
              ),
            ),
            if (state is ImportReady) ...[
              const SizedBox(height: HarvestSpacing.md),
              _Preview(state: state),
              const SizedBox(height: HarvestSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () =>
                          ref.read(importControllerProvider.notifier).reset(),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: HarvestSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => unawaited(
                        ref.read(importControllerProvider.notifier).apply(),
                      ),
                      child: Text(l10n.importConfirm),
                    ),
                  ),
                ],
              ),
            ],
            if (_message(l10n, state) case final message?) ...[
              const SizedBox(height: HarvestSpacing.sm),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: state is ImportFailed
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _message(AppLocalizations l10n, ImportState state) => switch (state) {
    ImportDone(:final preview) => l10n.importDone(
      totalOf(preview).added,
      totalOf(preview).updated,
    ),
    ImportFailed(problem: ArchiveProblem.notHarvest) => l10n.importNotHarvest,
    ImportFailed(problem: ArchiveProblem.unreadable) => l10n.importUnreadable,
    ImportFailed(problem: ArchiveProblem.badWorkbook) => l10n.importBadWorkbook,
    ImportFailed() => l10n.importFailed,
    ImportIdle() || ImportReading() || ImportApplying() || ImportReady() =>
      null,
  };
}

/// The preview: what is new, what would be updated, per sheet.
class _Preview extends StatelessWidget {
  const _Preview({required this.state});

  final ImportReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = state.preview;
    final total = totalOf(preview);

    // Sheets that would do nothing are left out — a preview is meant
    // to be read, and thirteen rows of zero is not.
    final changed = preview.tables.entries
        .where((e) => e.value.added > 0 || e.value.updated > 0)
        .toList();

    return Container(
      padding: const EdgeInsets.all(HarvestSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(HarvestRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            l10n.importSummary(total.added, total.updated),
            style: theme.textTheme.bodyMedium,
          ),
          if (preview.files > 0)
            Text(
              l10n.importFiles(preview.newFiles, preview.files),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          if (changed.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: HarvestSpacing.xs),
              child: Text(
                l10n.importNothingToDo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            const Divider(height: HarvestSpacing.lg),
            for (final entry in changed)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(_sheetLabel(l10n, entry.key))),
                    Text(
                      l10n.importRowCounts(
                        entry.value.added,
                        entry.value.updated,
                      ),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: HarvestSpacing.xs),
          Text(
            l10n.importNeverDeletes,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _sheetLabel(AppLocalizations l10n, String sheet) => switch (sheet) {
    SheetNames.seeds => l10n.sheetSeeds,
    SheetNames.checkIns => l10n.sheetCheckIns,
    SheetNames.seedNotes => l10n.sheetSeedNotes,
    SheetNames.expenses => l10n.sheetExpenses,
    SheetNames.money => l10n.sheetMoney,
    SheetNames.debts => l10n.sheetDebts,
    SheetNames.debtPayments => l10n.sheetDebtPayments,
    SheetNames.focus => l10n.sheetFocus,
    SheetNames.ledger => l10n.sheetLedger,
    SheetNames.settings => l10n.sheetSettings,
    SheetNames.notes => l10n.sheetNotes,
    SheetNames.albums => l10n.sheetAlbums,
    SheetNames.memories => l10n.sheetMemories,
    _ => sheet,
  };
}
