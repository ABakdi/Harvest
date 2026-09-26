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

enum _ItemAction { edit, plant, addSubtask, moveUnder, lift, delete }

/// One goal, whole: why, its requirements, its tasks with their
/// subtasks, and the seeds.
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
            view: view,
            kind: GoalItemKind.need,
            addLabel: l10n.goalAddNeed,
          ),
          SectionHeader(l10n.goalSteps),
          _ItemList(
            view: view,
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
            // An action is an offer for a few seconds, not a fixture.
            persist: false,
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

/// One section of a goal: its items, ticked and reordered in place,
/// each with its subtasks indented beneath it (GL8), and a line at the
/// foot to add one more.
class _ItemList extends ConsumerStatefulWidget {
  const _ItemList({
    required this.view,
    required this.kind,
    required this.addLabel,
  });

  final GoalView view;
  final GoalItemKind kind;
  final String addLabel;

  @override
  ConsumerState<_ItemList> createState() => _ItemListState();
}

class _ItemListState extends ConsumerState<_ItemList> {
  final _add = TextEditingController();
  final _focus = FocusNode();

  /// The item whose "Add a subtask" line was asked for from its menu,
  /// before it has any subtask to keep the line open.
  String? _adding;

  Goal get _goal => widget.view.goal;

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
        .addItem(_goal.uuid, body: body, kind: widget.kind);
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
          goalUuid: _goal.uuid,
        );
        if (seed == null) return;
        await repository.linkItem(item.uuid, seed.uuid);
        messenger.showSnackBar(SnackBar(content: Text(l10n.goalPlanted)));
      case _ItemAction.addSubtask:
        setState(() => _adding = item.uuid);
      case _ItemAction.moveUnder:
        final parent = await _pickParent(item);
        if (parent == null) return;
        await repository.moveUnder(item.uuid, parent.uuid);
      case _ItemAction.lift:
        await repository.liftItem(item.uuid);
      case _ItemAction.delete:
        final subtasks = widget.view.subtasksOf(item.uuid).length;
        await repository.deleteItem(item.uuid);
        messenger.showSnackBar(
          SnackBar(
            // An action is an offer for a few seconds, not a fixture.
            persist: false,
            content: Text(
              subtasks == 0
                  ? l10n.goalItemRemoved
                  : l10n.goalItemRemovedWithSubtasks(subtasks),
            ),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => unawaited(repository.restoreItem(item.uuid)),
            ),
          ),
        );
    }
  }

  /// The items of this section [item] could go under: every other one
  /// at the top level.
  List<GoalItem> _parentsFor(GoalItem item) => [
    for (final other in widget.view.outline.top(widget.kind))
      if (other.uuid != item.uuid && other.parentUuid == null) other,
  ];

  Future<GoalItem?> _pickParent(GoalItem item) {
    final l10n = AppLocalizations.of(context);
    return showDialog<GoalItem>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.goalMoveUnderTitle),
        children: [
          for (final other in _parentsFor(item))
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(other),
              child: Text(other.body),
            ),
        ],
      ),
    );
  }

  Widget _tile(GoalItem item, {required int index}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final repository = ref.read(goalsRepositoryProvider);
    final view = widget.view;
    // A subtask whose parent is gone is drawn at the top, and can
    // still be lifted to stand there for good.
    final isSubtask = item.parentUuid != null;
    final subtasks = view.subtasksOf(item.uuid);
    final done = view.isDone(item);
    final details = [
      if (subtasks.isNotEmpty)
        l10n.goalSubtaskProgress(
          subtasks.where((s) => s.isDone).length,
          subtasks.length,
        ),
      if (item.isPlanted) l10n.goalPlanted,
    ];
    return ListTile(
      key: ValueKey(item.uuid),
      contentPadding: EdgeInsets.zero,
      dense: isSubtask,
      leading: Checkbox(
        value: done,
        onChanged: (value) {
          unawaited(HarvestHaptics.tick());
          unawaited(repository.setDone(item.uuid, done: value ?? false));
        },
      ),
      title: Text(
        item.body,
        style: done
            ? theme.textTheme.bodyLarge?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
      ),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
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
              if (!isSubtask)
                PopupMenuItem(
                  value: _ItemAction.addSubtask,
                  child: Text(l10n.goalAddSubtask),
                ),
              if (!isSubtask &&
                  subtasks.isEmpty &&
                  _parentsFor(item).isNotEmpty)
                PopupMenuItem(
                  value: _ItemAction.moveUnder,
                  child: Text(l10n.goalMoveUnder),
                ),
              if (isSubtask)
                PopupMenuItem(
                  value: _ItemAction.lift,
                  child: Text(
                    widget.kind == GoalItemKind.step
                        ? l10n.goalLiftStep
                        : l10n.goalLiftNeed,
                  ),
                ),
              PopupMenuItem(
                value: _ItemAction.delete,
                child: Text(l10n.removeAction),
              ),
            ],
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(HarvestSpacing.sm),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
    );
  }

  /// An item's subtasks, dragged among themselves only, and the line
  /// that adds one more.
  Widget _subtasks(GoalItem item) {
    final repository = ref.read(goalsRepositoryProvider);
    final subtasks = widget.view.subtasksOf(item.uuid);
    final adding = _adding == item.uuid;
    if (subtasks.isEmpty && !adding) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: HarvestSpacing.xl),
      child: Column(
        children: [
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: subtasks.length,
            onReorderItem: (from, to) {
              final uuids = [for (final s in subtasks) s.uuid];
              final moved = uuids.removeAt(from);
              uuids.insert(to, moved);
              unawaited(repository.reorderItems(uuids));
            },
            itemBuilder: (context, i) => _tile(subtasks[i], index: i),
          ),
          _SubtaskField(
            key: ValueKey('add-${item.uuid}'),
            parentUuid: item.uuid,
            autofocus: adding,
            onDone: () {
              if (_adding == item.uuid) setState(() => _adding = null);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.read(goalsRepositoryProvider);
    final items = widget.view.outline.top(widget.kind);

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
            return Column(
              key: ValueKey(item.uuid),
              mainAxisSize: MainAxisSize.min,
              children: [_tile(item, index: i), _subtasks(item)],
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

/// The line under an item's subtasks that adds one more.
class _SubtaskField extends ConsumerStatefulWidget {
  const _SubtaskField({
    required this.parentUuid,
    required this.autofocus,
    required this.onDone,
    super.key,
  });

  final String parentUuid;
  final bool autofocus;

  /// Called once a subtask was added, or the line was left empty.
  final VoidCallback onDone;

  @override
  ConsumerState<_SubtaskField> createState() => _SubtaskFieldState();
}

class _SubtaskFieldState extends ConsumerState<_SubtaskField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty) {
      widget.onDone();
      return;
    }
    _controller.clear();
    await ref
        .read(goalsRepositoryProvider)
        .addSubtask(widget.parentUuid, body: body);
    widget.onDone();
    // A task is broken down a line after another.
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      maxLength: 200,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => unawaited(_submit()),
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        counterText: '',
        isDense: true,
        prefixIcon: const Icon(Icons.subdirectory_arrow_right, size: 18),
        hintText: l10n.goalAddSubtask,
        border: InputBorder.none,
      ),
    );
  }
}
