import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/crop_card.dart';
import 'package:harvest/core/ui/widgets/streak_flame.dart';
import 'package:harvest/core/ui/widgets/xp_bar.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/features/commitments/presentation/commitment_editor_sheet.dart';
import 'package:harvest/features/commitments/presentation/field_providers.dart';
import 'package:harvest/features/gamification/data/gamification_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';

class FieldScreen extends ConsumerWidget {
  const FieldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(todayFieldProvider);
    final xp = ref.watch(xpTotalProvider).value ?? 0;
    final streak = ref.watch(globalStreakProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: HarvestSpacing.md),
            child: StreakFlame(days: streak?.current ?? 0),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(showCommitmentEditor(context)),
        icon: const Icon(Icons.add),
        label: Text(l10n.addCommitment),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HarvestSpacing.md,
            ),
            child: XpBar(
              xp: xp,
              xpPerRank: FarmerRank.xpPerRank,
              rankLabel: _rankLabel(l10n, FarmerRank.forXp(xp)),
            ),
          ),
          const SizedBox(height: HarvestSpacing.sm),
          Expanded(
            child: items.isEmpty
                ? const _EmptyField()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      HarvestSpacing.md,
                      HarvestSpacing.sm,
                      HarvestSpacing.md,
                      96,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        _CropTile(item: items[index]),
                  ),
          ),
        ],
      ),
    );
  }

  String _rankLabel(AppLocalizations l10n, FarmerRank rank) =>
      switch (rank) {
        FarmerRank.sprout => l10n.rankSprout,
        FarmerRank.seedling => l10n.rankSeedling,
        FarmerRank.gardener => l10n.rankGardener,
        FarmerRank.harvester => l10n.rankHarvester,
        FarmerRank.masterFarmer => l10n.rankMasterFarmer,
      };
}

class _CropTile extends ConsumerWidget {
  const _CropTile({required this.item});

  final FieldItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final commitment = item.commitment;

    return CropCard(
      title: commitment.title,
      subtitle: _subtitle(l10n),
      icon: switch (commitment.type) {
        CommitmentType.habit => Icons.repeat,
        CommitmentType.project => Icons.flag,
        CommitmentType.todo => Icons.check_circle_outline,
      },
      done: item.isDone,
      progress: commitment.type == CommitmentType.project
          ? item.projectProgress
          : null,
      onTap: () => unawaited(_onTap(context, ref)),
    );
  }

  String _subtitle(AppLocalizations l10n) {
    final commitment = item.commitment;
    switch (commitment.type) {
      case CommitmentType.project:
        return l10n.projectSubtitle(
          item.totalLogged,
          commitment.totalTarget ?? 0,
          item.loggedToday,
          commitment.dailyCommitment ?? 0,
        );
      case CommitmentType.habit:
        return l10n.typeHabit;
      case CommitmentType.todo:
        return l10n.typeTodo;
    }
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(checkInControllerProvider.notifier);
    final commitment = item.commitment;

    // Done already → offer same-day undo.
    if (item.isDone && item.loggedToday > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.undoCheckInTitle),
          content: Text(l10n.undoCheckInBody(commitment.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.undo),
            ),
          ],
        ),
      );
      if (confirmed ?? false) await controller.undoToday(commitment);
      return;
    }

    if (commitment.type == CommitmentType.project) {
      if (!context.mounted) return;
      await _showQuantitySheet(context, ref);
      return;
    }

    final result = await controller.checkIn(commitment);
    if (result is CheckInSuccess) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.xpEarned(result.xpEarned)),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _showQuantitySheet(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(checkInControllerProvider.notifier);
    final commitment = item.commitment;
    final remaining = commitment.maxUnitsPerDay - item.loggedToday;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HarvestRadii.sheet),
        ),
      ),
      builder: (sheetContext) {
        final quantityController = TextEditingController(
          text: '${commitment.dailyCommitment ?? 1}',
        );
        return Padding(
          padding: EdgeInsets.only(
            left: HarvestSpacing.lg,
            right: HarvestSpacing.lg,
            top: HarvestSpacing.lg,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom +
                HarvestSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.logProgressTitle,
                style: Theme.of(sheetContext).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: HarvestSpacing.md),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.logQuantityLabel,
                  helperText: l10n.logRemainingToday(remaining),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(HarvestRadii.button),
                  ),
                ),
              ),
              const SizedBox(height: HarvestSpacing.lg),
              FilledButton(
                onPressed: () async {
                  final quantity =
                      int.tryParse(quantityController.text) ?? 0;
                  if (quantity <= 0) return;
                  Navigator.of(sheetContext).pop();
                  final result =
                      await controller.checkIn(commitment, quantity: quantity);
                  final message = switch (result) {
                    CheckInSuccess(:final xpEarned) =>
                      l10n.xpEarned(xpEarned),
                    CheckInCapped(quantityLogged: 0) => l10n.cappedMessage,
                    CheckInCapped(:final xpEarned) =>
                      '${l10n.xpEarned(xpEarned)} · ${l10n.cappedMessage}',
                  };
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(message),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(l10n.log),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyField extends StatelessWidget {
  const _EmptyField();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grass, size: 96, color: theme.colorScheme.secondary)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.06, 1.06),
                  duration: 1800.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: HarvestSpacing.lg),
            Text(
              l10n.fieldEmptyTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HarvestSpacing.sm),
            Text(
              l10n.fieldEmptyBody,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
