import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/celebration.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/core/ui/widgets/text_prompt.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/commitment_editor_sheet.dart';
import 'package:harvest/features/goals/data/goals_repository.dart';
import 'package:harvest/features/goals/domain/goal.dart';
import 'package:harvest/features/goals/presentation/goal_editor_sheet.dart';
import 'package:harvest/features/goals/presentation/goals_board.dart';
import 'package:harvest/features/goals/presentation/goals_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

enum _GoalAction { edit, achieve, reopen, drop, delete }

enum _ItemAction { edit, plant, delete }

/// One goal, whole: why, what it takes, the steps, and the seeds.
class GoalScreen extends ConsumerWidget {
  const GoalScreen({required this.uuid, super.key});

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(goalProvider(uuid));
    final view = async.value;

    if (view == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.isLoading ? const SizedBox.shrink() : const SizedBox(),
      );
    }
    final goal = view.goal;
    final today = ref.watch(currentHarvestDayProvider);
    final seeds = ref.watch(goalSeedsProvider(uuid)).value ?? const [];
    final left = goal.daysLeft(today);

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title),
        actions: [
          PopupMenuButton<_GoalAction>(
            tooltip: l10n.goalOptions,
            onSelected: (action) =>
                unawaited(_onGoalAction(context, ref, view, action)),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _GoalAction.edit,
                child: Text(l10n.goalEdit),
              ),
              if (goal.isActive)
                PopupMenuItem(
                  value: _GoalAction.achieve,
                  child: Text(l10n.goalMarkAchieved),
                )
              else
                PopupMenuItem(
                  value: _GoalAction.reopen,
                  child: Text(l10n.goalReopen),
                ),
              if (goal.isActive)
                PopupMenuItem(
                  value: _GoalAction.drop,
                  child: Text(l10n.goalDrop),
                ),
              PopupMenuItem(
                value: _GoalAction.delete,
                child: Text(l10n.goalDelete),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.md,
          HarvestSpacing.sm,
          HarvestSpacing.md,
          HarvestSpacing.xl,
        ),
        children: [
          if (goal.targetDay != null)
            Text(
              [
                formatDay(context, goal.targetDay!, weekday: true),
                if (left != null && goal.isActive && left >= 0)
                  l10n.goalDaysLeft(left),
                if (left != null && goal.isActive && left < 0)
                  l10n.goalDaysPast(-left),
              ].join(' · '),
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
          if (goal.why.isNotEmpty) ...[
            const SizedBox(height: HarvestSpacing.sm),
            Text(goal.why, style: theme.textTheme.bodyLarge),
          ],
          if (goal.statusNote != null && !goal.isActive) ...[
            const SizedBox(height: HarvestSpacing.sm),
            Text(
              goal.statusNote!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (view.complete && goal.isActive) ...[
            const SizedBox(height: HarvestSpacing.md),
            FilledButton.icon(
              onPressed: () => unawaited(
                _onGoalAction(context, ref, view, _GoalAction.achieve),
              ),
              icon: const Icon(Icons.emoji_events_outlined),
              label: Text(l10n.goalMarkAchieved),
            ),
          ],
          SectionHeader(l10n.goalNeeds),
          _ItemList(
            goal: goal,
            items: view.needs.toList(),
            kind: GoalItemKind.need,
            addLabel: l10n.goalAddNeed,
          ),
          SectionHeader(l10n.goalSteps),
          _ItemList(
            goal: goal,
            items: view.steps.toList(),
            kind: GoalItemKind.step,
            addLabel: l10n.goalAddStep,
          ),
          if (seeds.isNotEmpty) ...[
            SectionHeader(l10n.goalSeeds),
            Wrap(
              spacing: HarvestSpacing.xs,
              runSpacing: HarvestSpacing.xs,
              children: [for (final seed in seeds) SeedChip(seed: seed)],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onGoalAction(
    BuildContext context,
    WidgetRef ref,
    GoalView view,
    _GoalAction action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(goalsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    switch (action) {
      case _GoalAction.edit:
        await showGoalEditor(context, existing: view.goal);
      case _GoalAction.achieve:
        await repository.achieve(uuid);
        await HarvestHaptics.thud();
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
          SnackBar(content: Text(l10n.goalAchievedToast(goalAchievedXp))),
        );
      case _GoalAction.reopen:
        await repository.reopen(uuid);
      case _GoalAction.drop:
        final note = await promptForText(
          context,
          title: l10n.goalDropTitle,
          hint: l10n.goalDropNoteHint,
          confirmLabel: l10n.goalDrop,
        );
        if (note == null) return;
        await repository.drop(
          uuid,
          note: note.trim().isEmpty ? null : note.trim(),
        );
      case _GoalAction.delete:
        final ok = await confirm(
          context,
          title: l10n.goalDelete,
          body: view.goal.title,
          confirmLabel: l10n.goalDelete,
        );
        if (!ok) return;
        await repository.delete(uuid);
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.goalDeleted),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => unawaited(repository.restore(uuid)),
            ),
          ),
        );
    }
  }
}

/// One section of a goal: its items, ticked and reordered in place, and
/// a line at the foot to add one more.
class _ItemList extends ConsumerStatefulWidget {
  const _ItemList({
    required this.goal,
    required this.items,
    required this.kind,
    required this.addLabel,
  });

  final Goal goal;
  final List<GoalItem> items;
  final GoalItemKind kind;
  final String addLabel;

  @override
  ConsumerState<_ItemList> createState() => _ItemListState();
}

class _ItemListState extends ConsumerState<_ItemList> {
  final _add = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _add.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _add.text.trim();
    if (body.isEmpty) return;
    _add.clear();
    await ref
        .read(goalsRepositoryProvider)
        .addItem(widget.goal.uuid, body: body, kind: widget.kind);
    // Keep the keyboard up: a list is written a line after another.
    _focus.requestFocus();
  }

  Future<void> _onAction(GoalItem item, _ItemAction action) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(goalsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case _ItemAction.edit:
        final body = await promptForText(
          context,
          title: l10n.goalEditItem,
          initial: item.body,
        );
        if (body == null || body.trim().isEmpty) return;
        await repository.editItem(
          item.uuid,
          body: body.trim(),
          note: item.note,
        );
      case _ItemAction.plant:
        final seed = await showCommitmentEditor(
          context,
          initialTitle: item.body,
          initialType: item.kind == GoalItemKind.step
              ? CommitmentType.todo
              : CommitmentType.habit,
          goalUuid: widget.goal.uuid,
        );
        if (seed == null) return;
        await repository.linkItem(item.uuid, seed.uuid);
        messenger.showSnackBar(SnackBar(content: Text(l10n.goalPlanted)));
      case _ItemAction.delete:
        await repository.deleteItem(item.uuid);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.goalItemRemoved),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => unawaited(repository.restoreItem(item.uuid)),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final repository = ref.read(goalsRepositoryProvider);
    final items = widget.items;

    return Column(
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: items.length,
          onReorderItem: (from, to) {
            final uuids = [for (final item in items) item.uuid];
            final moved = uuids.removeAt(from);
            uuids.insert(to, moved);
            unawaited(repository.reorderItems(uuids));
          },
          itemBuilder: (context, i) {
            final item = items[i];
            return ListTile(
              key: ValueKey(item.uuid),
              contentPadding: EdgeInsets.zero,
              leading: Checkbox(
                value: item.isDone,
                onChanged: (done) {
                  unawaited(HarvestHaptics.tick());
                  unawaited(repository.setDone(item.uuid, done: done ?? false));
                },
              ),
              title: Text(
                item.body,
                style: item.isDone
                    ? theme.textTheme.bodyLarge?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              subtitle: item.isPlanted ? Text(l10n.goalPlanted) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<_ItemAction>(
                    tooltip: l10n.goalItemOptions,
                    onSelected: (action) => unawaited(_onAction(item, action)),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: _ItemAction.edit,
                        child: Text(l10n.goalEditItem),
                      ),
                      if (!item.isPlanted)
                        PopupMenuItem(
                          value: _ItemAction.plant,
                          child: Text(l10n.goalPlant),
                        ),
                      PopupMenuItem(
                        value: _ItemAction.delete,
                        child: Text(l10n.goalItemRemoved),
                      ),
                    ],
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.all(HarvestSpacing.sm),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        TextField(
          controller: _add,
          focusNode: _focus,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => unawaited(_submit()),
          decoration: InputDecoration(
            counterText: '',
            prefixIcon: const Icon(Icons.add),
            hintText: widget.addLabel,
            border: InputBorder.none,
          ),
        ),
      ],
    );
  }
}
