import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/export/domain/export_service.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// "My data": one button that drops the whole database in Downloads as
/// a spreadsheet with its formulas already wired up.
class ExportCard extends ConsumerWidget {
  const ExportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(exportControllerProvider);
    final running = status is ExportRunning;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.table_chart_outlined),
                const SizedBox(width: HarvestSpacing.md),
                Expanded(child: Text(l10n.exportTitle)),
              ],
            ),
            const SizedBox(height: HarvestSpacing.xs),
            Text(l10n.exportBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: HarvestSpacing.md),
            FilledButton.icon(
              onPressed: running
                  ? null
                  : () => unawaited(
                      ref.read(exportControllerProvider.notifier).run(),
                    ),
              icon: running
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(running ? l10n.exportRunning : l10n.exportAction),
            ),
            if (_message(l10n, status) case final message?) ...[
              const SizedBox(height: HarvestSpacing.sm),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: status is ExportFailed
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

  String? _message(AppLocalizations l10n, ExportStatus status) =>
      switch (status) {
        ExportSaved(:final path) => l10n.exportSaved(path),
        ExportFailed(reason: 'permission') => l10n.exportFailedPermission,
        ExportFailed(reason: 'unsupported') => l10n.exportFailedUnsupported,
        ExportFailed() => l10n.exportFailed,
        ExportIdle() || ExportRunning() => null,
      };
}
