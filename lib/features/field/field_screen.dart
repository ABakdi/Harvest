import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/celebration.dart';
import 'package:harvest/core/ui/widgets/crop_card.dart';
import 'package:harvest/core/ui/widgets/deadline_countdown.dart';
import 'package:harvest/core/ui/widgets/harvest_fab.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/core/ui/widgets/streak_flame.dart';
import 'package:harvest/core/ui/widgets/xp_bar.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/features/commitments/presentation/commitment_editor_sheet.dart';
import 'package:harvest/features/commitments/presentation/crop_options_sheet.dart';
import 'package:harvest/features/commitments/presentation/field_providers.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/presentation/budget_colors.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/gamification/data/gamification_repository.dart';
import 'package:harvest/features/gamification/presentation/streak_sheet.dart';
import 'package:harvest/features/planner/presentation/planner_screen.dart';
import 'package:harvest/features/pomodoro/presentation/mini_timer_chip.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class FieldScreen extends ConsumerWidget {
  const FieldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(todayFieldProvider);
    final xp = ref.watch(xpTotalProvider).value ?? 0;
    final streak = ref.watch(globalStreakProvider).value;
    final budget = ref.watch(budgetSnapshotProvider);
    final currency =
        ref.watch(financeSettingsProvider).value?.defaultCurrency ??
        Currency.dzd;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => unawaited(context.push(AppRoutes.calendar)),
          ),
          const MiniTimerChip(),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: HarvestSpacing.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(HarvestRadii.button),
              onTap: () => unawaited(showStreakSheet(context)),
              child: Padding(
                padding: const EdgeInsets.all(HarvestSpacing.xs),
                child: StreakFlame(days: streak?.current ?? 0),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: HarvestFab(
        onPressed: () => unawaited(showCommitmentEditor(context)),
        label: l10n.addCommitment,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HarvestSpacing.md,
            ),
            child: _FieldHeader(
              xp: xp,
              rankLabel: _rankLabel(l10n, FarmerRank.forXp(xp)),
              budget: budget,
              currency: currency,
            ),
          ),
          const SizedBox(height: HarvestSpacing.sm),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                HarvestSpacing.md,
                HarvestSpacing.sm,
                HarvestSpacing.md,
                96,
              ),
              children: [
                if (items.isEmpty)
                  const _EmptyField()
                else
                  for (final item in items)
                    _CropTile(item: item)
                        .animate()
                        .fadeIn(duration: 220.ms)
                        .slideY(begin: 0.05, curve: Curves.easeOut),
                const SizedBox(height: HarvestSpacing.sm),
                const _TomorrowCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _rankLabel(AppLocalizations l10n, FarmerRank rank) => switch (rank) {
    FarmerRank.sprout => l10n.rankSprout,
    FarmerRank.seedling => l10n.rankSeedling,
    FarmerRank.gardener => l10n.rankGardener,
    FarmerRank.harvester => l10n.rankHarvester,
    FarmerRank.masterFarmer => l10n.rankMasterFarmer,
  };
}

/// Rank, XP and the budget pulse in one card at the top of the field.
class _FieldHeader extends StatelessWidget {
  const _FieldHeader({
    required this.xp,
    required this.rankLabel,
    required this.budget,
    required this.currency,
  });

  final int xp;
  final String rankLabel;
  final BudgetSnapshot? budget;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snap = budget;
    final toNext = FarmerRank.xpPerRank - xp % FarmerRank.xpPerRank;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            XpBar(
              xp: xp,
              xpPerRank: FarmerRank.xpPerRank,
              rankLabel: rankLabel,
            ),
            const SizedBox(height: HarvestSpacing.xs),
            Text(
              l10n.nextRankIn(toNext),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.55),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (snap != null) ...[
              const Divider(height: HarvestSpacing.lg),
              InkWell(
                borderRadius: BorderRadius.circular(HarvestRadii.chip),
                onTap: () => context.go(AppRoutes.finances),
                child: Row(
                  children: [
                    IconBadge(
                      Icons.payments,
                      color: budgetColor(scheme, snap.status),
                      size: 32,
                      iconSize: 18,
                    ),
                    const SizedBox(width: HarvestSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.budgetFloating(
                          formatAmount(snap.spentToday, currency),
                          formatAmount(snap.floatingDailyLimit, currency),
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: scheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
      subtitle: _subtitle(context, l10n),
      urgent: _overdue,
      extra: commitment.deadline != null && !item.isDone && !_overdue
          ? DeadlineCountdown(deadline: commitment.deadline!)
          : null,
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
      onLongPress: () => unawaited(showCropOptions(context, commitment)),
    );
  }

  bool get _overdue {
    final deadline = item.commitment.deadline;
    return deadline != null &&
        !item.isDone &&
        deadline.compareTo(HarvestDay.today()) < 0;
  }

  String _subtitle(BuildContext context, AppLocalizations l10n) {
    final commitment = item.commitment;
    final locale = Localizations.localeOf(context).toString();
    String dayText(HarvestDay day) =>
        DateFormat.MMMd(locale).format(DateTime(day.year, day.month, day.day));
    final deadline = commitment.deadline;
    final deadlineText = deadline == null
        ? null
        : _overdue
        ? l10n.overdueBy(dayText(deadline))
        : l10n.dueOn(dayText(deadline));

    final base = switch (commitment.type) {
      CommitmentType.project => l10n.projectSubtitle(
        item.totalLogged,
        commitment.totalTarget ?? 0,
        item.loggedToday,
        commitment.dailyCommitment ?? 0,
      ),
      CommitmentType.habit =>
        commitment.isPaused ? l10n.pausedLabel : l10n.typeHabit,
      CommitmentType.todo => commitment.note ?? l10n.typeTodo,
    };
    return deadlineText == null ? base : '$base · $deadlineText';
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(checkInControllerProvider.notifier);
    final commitment = item.commitment;

    if (commitment.isPaused) {
      await showCropOptions(context, commitment);
      return;
    }

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
      if (context.mounted) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          showCheckInBurst(
            context,
            box.localToGlobal(box.size.center(Offset.zero)),
          );
        }
      }
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
    final navigator = Navigator.of(context, rootNavigator: true);
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
            bottom:
                MediaQuery.viewInsetsOf(sheetContext).bottom +
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
                    borderRadius: BorderRadius.circular(HarvestRadii.button),
                  ),
                ),
              ),
              const SizedBox(height: HarvestSpacing.lg),
              FilledButton(
                onPressed: () async {
                  final quantity = int.tryParse(quantityController.text) ?? 0;
                  if (quantity <= 0) return;
                  Navigator.of(sheetContext).pop();
                  final result = await controller.checkIn(
                    commitment,
                    quantity: quantity,
                  );
                  final logged = switch (result) {
                    CheckInSuccess(:final quantityLogged) => quantityLogged,
                    CheckInCapped(:final quantityLogged) => quantityLogged,
                  };
                  final completed =
                      logged > 0 &&
                      item.totalLogged + logged >=
                          (commitment.totalTarget ?? 0);
                  if (completed) {
                    await _celebrateCompletion(
                      ref,
                      navigator,
                      item.totalLogged + logged,
                    );
                    return;
                  }
                  final message = switch (result) {
                    CheckInSuccess(:final xpEarned) => l10n.xpEarned(xpEarned),
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

  /// The 100% moment: a celebration dialog, then the crop retires to
  /// the barn (auto-archive) with its history intact.
  Future<void> _celebrateCompletion(
    WidgetRef ref,
    NavigatorState navigator,
    int total,
  ) async {
    final context = navigator.context;
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.projectDoneTitle),
        content: Text(
          l10n.projectDoneBody(item.commitment.title, total),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.toTheBarn),
          ),
        ],
      ),
    );
    await ref
        .read(commitmentEditorProvider.notifier)
        .archive(item.commitment.uuid);
  }
}

/// Tomorrow at a glance, and the way into the evening plan — a card at
/// the foot of the field rather than a hidden pull gesture.
class _TomorrowCard extends ConsumerWidget {
  const _TomorrowCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plan = ref.watch(tomorrowPlanProvider);
    final locale = Localizations.localeOf(context).toString();
    final tomorrow = HarvestDay.today().next;
    final summary = plan.habits.isEmpty && plan.todos.isEmpty
        ? l10n.tomorrowNothing
        : '${l10n.tomorrowHabits(plan.habits.length)} · '
              '${l10n.tomorrowTodos(plan.todos.length)}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(context.push(AppRoutes.planner)),
        child: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.md),
          child: Row(
            children: [
              IconBadge(Icons.bedtime_outlined, color: scheme.tertiary),
              const SizedBox(width: HarvestSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.tomorrowTitle} · ${DateFormat.MMMEd(locale).format(
                        DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
                      )}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HarvestSpacing.sm),
              Text(
                l10n.planTomorrow,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.primary),
            ],
          ),
        ),
      ),
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
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.xl,
          HarvestSpacing.xl * 2,
          HarvestSpacing.xl,
          HarvestSpacing.xl,
        ),
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
