import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/features/commitments/presentation/field_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'planner_screen.g.dart';

/// Commitments relevant to tomorrow: habits due, and planned to-dos.
@riverpod
({List<Commitment> habits, List<Commitment> todos}) tomorrowPlan(Ref ref) {
  final commitments = ref.watch(activeCommitmentsProvider).value ?? const [];
  final totals = ref.watch(lifetimeTotalsProvider).value ?? const {};
  final tomorrow = HarvestDay.today().next;

  final habits = <Commitment>[];
  final todos = <Commitment>[];
  for (final commitment in commitments) {
    switch (commitment.type) {
      case CommitmentType.habit:
        // Flexible schedules count as due unless the week is done.
        if (commitment.schedule!.isDueOn(tomorrow)) habits.add(commitment);
      case CommitmentType.todo:
        final done = (totals[commitment.uuid] ?? 0) > 0;
        if (!done && commitment.dueDay == tomorrow) todos.add(commitment);
      case CommitmentType.project:
        break; // projects are implicitly daily
    }
  }
  return (habits: habits, todos: todos);
}

/// The evening ritual: set tomorrow's to-dos before sleep.
class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    _controller.clear();
    await ref.read(commitmentEditorProvider.notifier).createTodo(
          title: title,
          dueDay: HarvestDay.today().next,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final plan = ref.watch(tomorrowPlanProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.plannerTitle)),
      body: ListView(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        children: [
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => unawaited(_add()),
            decoration: InputDecoration(
              hintText: l10n.plannerAddHint,
              prefixIcon: const Icon(Icons.add),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HarvestRadii.button),
              ),
            ),
          ),
          const SizedBox(height: HarvestSpacing.lg),
          if (plan.todos.isEmpty && plan.habits.isEmpty)
            Padding(
              padding: const EdgeInsets.all(HarvestSpacing.lg),
              child: Text(
                l10n.plannerEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          if (plan.todos.isNotEmpty) ...[
            Text(
              l10n.plannerTodos,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: HarvestSpacing.sm),
            for (final todo in plan.todos)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(todo.title),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => unawaited(
                      ref
                          .read(commitmentEditorProvider.notifier)
                          .archive(todo.uuid),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: HarvestSpacing.lg),
          ],
          if (plan.habits.isNotEmpty) ...[
            Text(
              l10n.plannerHabitsDue,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: HarvestSpacing.sm),
            for (final habit in plan.habits)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.repeat),
                  title: Text(habit.title),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
