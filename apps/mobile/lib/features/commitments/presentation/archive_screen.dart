import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/features/commitments/presentation/seed_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Where finished and retired seeds live.
///
/// Archiving used to be a one-way door with nothing behind it: the seed
/// left the field and there was no screen that could show it again.
/// This is that screen — with the note that says why, the date it was
/// put away, and the two ways out: back to the field, or gone for good.
class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final archived = ref.watch(archivedCommitmentsProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.archiveTitle)),
      body: archived == null
          ? const Center(child: CircularProgressIndicator())
          : archived.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: l10n.archiveEmpty,
              body: l10n.archiveEmptyBody,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                HarvestSpacing.md,
                HarvestSpacing.md,
                HarvestSpacing.md,
                HarvestSpacing.lg,
              ),
              children: [
                for (final commitment in archived)
                  _ArchivedCard(
                    key: ValueKey(commitment.uuid),
                    commitment: commitment,
                  ),
              ],
            ),
    );
  }
}

class _ArchivedCard extends ConsumerWidget {
  const _ArchivedCard({required this.commitment, super.key});

  final Commitment commitment;

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(commitmentEditorProvider.notifier).restore(commitment.uuid);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.restoredToField(commitment.title))),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirm(
      context,
      title: l10n.deleteSeedTitle,
      body: l10n.deleteSeedBody(commitment.title),
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(commitmentEditorProvider.notifier)
        .hardDelete(commitment.uuid);
    messenger.showSnackBar(SnackBar(content: Text(l10n.deleted)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final archivedAt = commitment.archivedAt;

    return Card(
      margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(HarvestRadii.card),
        onTap: () => unawaited(
          context.push('${AppRoutes.field}/seed/${commitment.uuid}'),
        ),
        child: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(
                    switch (commitment.type) {
                      CommitmentType.habit => Icons.repeat,
                      CommitmentType.project => Icons.flag,
                      CommitmentType.todo => Icons.check_circle_outline,
                    },
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: HarvestSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          commitment.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (archivedAt != null)
                          Text(
                            l10n.archivedOn(
                              formatDay(context, HarvestDay.of(archivedAt)),
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (commitment.archiveNote != null) ...[
                const SizedBox(height: HarvestSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(HarvestSpacing.sm),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(HarvestRadii.chip),
                  ),
                  child: Text(
                    commitment.archiveNote!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
              const SizedBox(height: HarvestSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => unawaited(_restore(context, ref)),
                    icon: const Icon(Icons.unarchive_outlined),
                    label: Text(l10n.restoreAction),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                    onPressed: () => unawaited(_delete(context, ref)),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.deleteAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
