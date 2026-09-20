import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/celebration.dart';
import 'package:harvest/core/ui/widgets/crop_card.dart';
import 'package:harvest/core/ui/widgets/deadline_countdown.dart';
import 'package:harvest/core/ui/widgets/harvest_fab.dart';
import 'package:harvest/core/ui/widgets/harvest_tabs.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/core/ui/widgets/reminder_countdown.dart';
import 'package:harvest/core/ui/widgets/streak_flame.dart';
import 'package:harvest/core/ui/widgets/xp_bar.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/due.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/features/commitments/presentation/commitment_editor_sheet.dart';
import 'package:harvest/features/commitments/presentation/crop_options_sheet.dart';
import 'package:harvest/features/commitments/presentation/field_providers.dart';
import 'package:harvest/features/commitments/presentation/quantity_sheet.dart';
import 'package:harvest/features/commitments/presentation/schedule_label.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/presentation/budget_colors.dart';
import 'package:harvest/features/finances/presentation/choice_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/presentation/album_crop_tile.dart';
import 'package:harvest/features/gallery/presentation/gallery_providers.dart';
import 'package:harvest/features/gamification/data/gamification_repository.dart';
import 'package:harvest/features/gamification/presentation/gamification_providers.dart';
import 'package:harvest/features/gamification/presentation/streak_sheet.dart';
import 'package:harvest/features/goals/presentation/goal_editor_sheet.dart';
import 'package:harvest/features/goals/presentation/goals_board.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/domain/session_finisher.dart';
import 'package:harvest/features/gym/presentation/session_start.dart';
import 'package:harvest/features/health/presentation/sleep_providers.dart';
import 'package:harvest/features/planner/presentation/planner_screen.dart';
import 'package:harvest/features/pomodoro/presentation/mini_timer_chip.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Clearance under the list so the floating action never covers a crop.
const _fabClearance = 96.0;

class FieldScreen extends ConsumerStatefulWidget {
  const FieldScreen({super.key});

  @override
  ConsumerState<FieldScreen> createState() => _FieldScreenState();
}

/// Today and Goals ([[Goals]]): the field where I act, and the board
/// where I plan. One screen, because the board is where the field's
/// seeds come from.
class _FieldScreenState extends ConsumerState<FieldScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    // The floating button follows the tab: a seed on Today, a goal on
    // the board.
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final streak = ref.watch(globalStreakProvider).value;
    final onGoals = _tabs.index == 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.calendarTitle,
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => unawaited(context.push(AppRoutes.calendar)),
          ),
          IconButton(
            tooltip: l10n.archiveTitle,
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => unawaited(context.push(AppRoutes.archive)),
          ),
          const MiniTimerChip(),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: HarvestSpacing.sm),
            child: Tooltip(
              message: l10n.streakSheetTitle,
              child: InkWell(
                borderRadius: BorderRadius.circular(HarvestRadii.button),
                onTap: () => unawaited(showStreakSheet(context)),
                child: SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HarvestSpacing.sm,
                    ),
                    child: Center(
                      child: StreakFlame(days: streak?.current ?? 0),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: HarvestTabs(
          controller: _tabs,
          tabs: [
            (icon: Icons.grass_outlined, label: l10n.fieldTabToday),
            (icon: Icons.flag_outlined, label: l10n.fieldTabGoals),
          ],
        ),
      ),
      floatingActionButton: HarvestFab(
        onPressed: () => unawaited(
          onGoals ? showGoalEditor(context) : showCommitmentEditor(context),
        ),
        label: onGoals ? l10n.goalNew : l10n.addCommitment,
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _TodayTab(),
          GoalsBoard(),
        ],
      ),
    );
  }
}

/// The day's crops under the rank, XP and budget header.
class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(todayFieldProvider);
    // Scheduled albums are seeds too (rule G3) — but only when the
    // gallery is on, and only then is anything even queried.
    final albums = ref.watch(galleryEnabledProvider)
        ? ref.watch(albumsDueTodayProvider)
        : const <({Album album, bool done})>[];
    final xp = ref.watch(xpTotalProvider).value ?? 0;
    final budget = ref.watch(budgetSnapshotProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HarvestSpacing.md),
          child: _FieldHeader(
            xp: xp,
            rankLabel: _rankLabel(l10n, FarmerRank.forXp(xp)),
            budget: budget,
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              HarvestSpacing.md,
              HarvestSpacing.sm,
              HarvestSpacing.md,
              _fabClearance,
            ),
            children: [
              if (items.isEmpty && albums.isEmpty)
                const _EmptyField()
              else ...[
                for (final item in items)
                  _CropTile(key: ValueKey(item.commitment.uuid), item: item)
                      // Keyed on the wrapper too: done crops sort
                      // down, and an unkeyed Animate would rebuild the
                      // tile mid-check-in ([[Audit-v2]] U3-09).
                      .animate(key: ValueKey('anim:${item.commitment.uuid}'))
                      .fadeIn(duration: 220.ms)
                      .slideY(begin: 0.05, curve: Curves.easeOut),
                for (final entry in albums)
                  AlbumCropTile(
                        key: ValueKey('album:${entry.album.uuid}'),
                        album: entry.album,
                        done: entry.done,
                      )
                      .animate()
                      .fadeIn(duration: 220.ms)
                      .slideY(begin: 0.05, curve: Curves.easeOut),
              ],
              const SizedBox(height: HarvestSpacing.sm),
              const _TomorrowCard(),
            ],
          ),
        ),
      ],
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

/// Rank, XP and the day's two gauges in one card at the top of the
/// field: what is left to spend, and what is owed in sleep.
class _FieldHeader extends ConsumerWidget {
  const _FieldHeader({
    required this.xp,
    required this.rankLabel,
    required this.budget,
  });

  final int xp;
  final String rankLabel;
  final BudgetSnapshot? budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snap = budget;
    final currency = ref.watch(defaultCurrencyProvider);
    // The second pillar's pulse, promised on this header since the
    // first draft of [[Dashboard-and-Widgets]] ([[Audit-v2]] P3-09).
    // Nothing owed is not news, so it shows only when there is a debt.
    final debt = ref.watch(healthEnabledProvider)
        ? ref.watch(sleepDebtNowProvider).value
        : null;

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
                        _budgetLine(l10n, snap, currency),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ],
            if (debt != null && debt.minutes > 0) ...[
              Divider(height: snap == null ? HarvestSpacing.lg : 0),
              InkWell(
                borderRadius: BorderRadius.circular(HarvestRadii.chip),
                onTap: () => context.go(AppRoutes.body),
                child: Row(
                  children: [
                    IconBadge(
                      Icons.bedtime_outlined,
                      color: scheme.tertiary,
                      size: 32,
                      iconSize: 18,
                    ),
                    const SizedBox(width: HarvestSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.sleepOwedLine(
                          debt.minutes ~/ 60,
                          debt.minutes % 60,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The same headline the Granary shows: what is left (or over) today.
  String _budgetLine(
    AppLocalizations l10n,
    BudgetSnapshot snap,
    Currency currency,
  ) {
    final left = snap.floatingDailyLimit - snap.spentToday;
    return left >= 0
        ? l10n.budgetLeftToday(formatAmount(left, currency))
        : l10n.budgetOverToday(formatAmount(-left, currency));
  }
}

class _CropTile extends ConsumerWidget {
  const _CropTile({required this.item, super.key});

  final FieldItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final commitment = item.commitment;
    final today = ref.watch(currentHarvestDayProvider);
    final busy = ref.watch(checkInControllerProvider).isLoading;
    final overdue = _overdue(today);
    final dayNote = ref.watch(todayNotesProvider).value?[commitment.uuid];
    final remindAt = SettingsRepository.parseTime(commitment.remindAt);
    // A habit a program is bound to is the program's to check in: the
    // card says so, and a tap leads to the session ([[Gym]] rule Y12).
    final program = commitment.type == CommitmentType.habit
        ? ref.watch(programForCommitmentProvider(commitment.uuid)).value
        : null;

    return CropCard(
      title: commitment.title,
      subtitle: _subtitle(context, l10n, today, overdue, program),
      urgent: overdue,
      note: commitment.note,
      dayNote: dayNote,
      reminder: remindAt == null
          ? null
          : ReminderCountdown(
              hour: remindAt.$1,
              minute: remindAt.$2,
              silenced: item.isDone,
            ),
      extra: commitment.deadline != null && !item.isDone && !overdue
          ? DeadlineCountdown(deadline: commitment.deadline!)
          : null,
      icon: switch (commitment.type) {
        CommitmentType.habit when program != null => Icons.fitness_center,
        CommitmentType.habit => Icons.repeat,
        CommitmentType.project => Icons.flag,
        CommitmentType.todo => Icons.check_circle_outline,
      },
      done: item.isDone,
      busy: busy,
      progress: commitment.type == CommitmentType.project
          ? item.projectProgress
          : null,
      onTap: () => unawaited(_onTap(context, ref, program)),
      onOptions: () => unawaited(showCropOptions(context, commitment)),
    );
  }

  /// A project past its deadline, or a to-do past its planned day.
  bool _overdue(HarvestDay today) {
    final commitment = item.commitment;
    if (item.isDone) return false;
    final deadline = commitment.deadline;
    if (deadline != null && deadline.compareTo(today) < 0) return true;
    return isOverdueOn(commitment, today, totalLogged: item.totalLogged);
  }

  /// What the seed asks of me: its schedule, its planned day, or its
  /// project progress — never just the word "habit".
  String _subtitle(
    BuildContext context,
    AppLocalizations l10n,
    HarvestDay today,
    bool overdue,
    Program? program,
  ) {
    final commitment = item.commitment;
    switch (commitment.type) {
      case CommitmentType.project:
        final base = l10n.projectSubtitle(
          item.totalLogged,
          commitment.totalTarget ?? 0,
          item.loggedToday,
          commitment.dailyCommitment ?? 0,
        );
        final deadline = commitment.deadline;
        if (deadline == null) return base;
        final when = formatDay(context, deadline);
        return '$base · ${overdue ? l10n.overdueBy(when) : l10n.dueOn(when)}';
      case CommitmentType.habit:
        if (commitment.isPaused) return l10n.pausedLabel;
        final schedule = scheduleLabel(context, l10n, commitment.schedule);
        // The program's name, unless the seed already carries it.
        return program == null || program.name == commitment.title
            ? schedule
            : '$schedule · ${program.name}';
      case CommitmentType.todo:
        final due = commitment.dueDay;
        if (overdue && due != null) {
          return l10n.overdueBy(formatDay(context, due));
        }
        return due == null || due == today
            ? l10n.dueToday
            : l10n.plannedFor(formatDay(context, due));
    }
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    Program? program,
  ) async {
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
      if (confirmed ?? false) {
        await controller.undoToday(commitment);
        // A hand tick of a gym seed wrote an empty session; it goes with
        // the tick ([[Audit-v2]] B3-04).
        if (program != null) {
          await ref
              .read(sessionsRepositoryProvider)
              .discardBareOn(program.uuid, ref.read(currentHarvestDayProvider));
        }
      }
      _reportError(ref, messenger, l10n);
      return;
    }

    if (commitment.type == CommitmentType.project) {
      if (!context.mounted) return;
      await _logProject(context, ref);
      return;
    }

    // A gym seed is checked in by a session, never by a bare tick: the
    // streak must not move without the log knowing why ([[Gym]] Y12).
    if (program != null) {
      if (!context.mounted) return;
      await _gymSeed(context, ref, program);
      return;
    }

    final result = await controller.checkIn(commitment);
    _reportError(ref, messenger, l10n);
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

  /// The two honest ways to tick a gym seed: start the session, or say
  /// I went and logged nothing — which is still a session, finished on
  /// the spot, so history and the streak agree ([[Checkpoint-7]]).
  Future<void> _gymSeed(
    BuildContext context,
    WidgetRef ref,
    Program program,
  ) async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final start = await showChoiceSheet<bool>(
      context,
      title: item.commitment.title,
      options: [
        ChoiceOption(
          value: true,
          label: l10n.gymSeedStart,
          hint: l10n.gymSeedStartHint,
          icon: Icons.play_arrow_rounded,
        ),
        ChoiceOption(
          value: false,
          label: l10n.gymSeedBare,
          hint: l10n.gymSeedBareHint,
          icon: Icons.check_rounded,
          color: scheme.secondary,
        ),
      ],
    );
    if (start == null || !context.mounted) return;
    if (start) {
      // This seed's program, not every program: a session of another one
      // would never check this seed in ([[Audit-v2]] B3-10).
      await startSession(context, ref, only: program);
      return;
    }

    // The bare session is the day that was up next, so "Up next" moves
    // on as if I had logged it ([[Audit-v2]] B3-03).
    final sessions = ref.read(sessionsRepositoryProvider);
    final next = await sessions.nextDay(program);
    final session = await sessions.startFreeform(
      title: next?.name ?? l10n.gymSeedBare,
      programUuid: program.uuid,
      dayUuid: next?.uuid,
    );
    final outcome = await ref.read(sessionFinisherProvider).finish(session);
    unawaited(HarvestHaptics.thud());
    if (outcome.xpEarned == 0) return;
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
        content: Text(l10n.xpEarned(outcome.xpEarned)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _reportError(
    WidgetRef ref,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
  ) {
    if (ref.read(checkInControllerProvider).hasError) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.checkInFailed)));
    }
  }

  Future<void> _logProject(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final commitment = item.commitment;

    final result = await showQuantitySheet(context, ref, item: item);
    if (result == null) return;
    final logged = switch (result) {
      CheckInSuccess(:final quantityLogged) => quantityLogged,
      CheckInCapped(:final quantityLogged) => quantityLogged,
    };
    final completed =
        logged > 0 &&
        item.totalLogged + logged >= (commitment.totalTarget ?? 0);
    if (completed) {
      await _celebrateCompletion(ref, navigator, item.totalLogged + logged);
      return;
    }
    final message = switch (result) {
      CheckInSuccess(:final xpEarned) => l10n.xpEarned(xpEarned),
      CheckInCapped(quantityLogged: 0) => l10n.cappedMessage,
      CheckInCapped(:final xpEarned) =>
        '${l10n.xpEarned(xpEarned)} · ${l10n.cappedMessage}',
    };
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  /// The 100% moment: a celebration dialog, then the crop is archived
  /// with its history intact.
  Future<void> _celebrateCompletion(
    WidgetRef ref,
    NavigatorState navigator,
    int total,
  ) async {
    // Taken before the dialog: the tile may be gone by the time it
    // closes, and its `ref` with it.
    final editor = ref.read(commitmentEditorProvider.notifier);
    final context = navigator.context;
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.projectDoneTitle),
        content: Text(l10n.projectDoneBody(item.commitment.title, total)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.toTheBarn),
          ),
        ],
      ),
    );
    await editor.archive(item.commitment.uuid);
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
    final tomorrow = ref.watch(currentHarvestDayProvider).next;
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
                      '${l10n.tomorrowTitle} · '
                      '${formatDay(context, tomorrow, weekday: true)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
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
