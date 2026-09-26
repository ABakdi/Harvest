import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/goals/data/goals_repository.dart';
import 'package:harvest/features/goals/domain/goal.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Writes a goal down, or edits [existing]. Returns the goal it made.
Future<Goal?> showGoalEditor(BuildContext context, {Goal? existing}) =>
    showHarvestSheet<Goal>(
      context,
      builder: (_) => _GoalEditorSheet(existing: existing),
    );

class _GoalEditorSheet extends ConsumerStatefulWidget {
  const _GoalEditorSheet({this.existing});

  final Goal? existing;

  @override
  ConsumerState<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends ConsumerState<_GoalEditorSheet> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _why = TextEditingController(text: widget.existing?.why);
  late HarvestDay? _targetDay = widget.existing?.targetDay;
  var _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _why.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final today = HarvestDay.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: (_targetDay ?? today.addDays(30)).toDateTime(),
      firstDate: today.toDateTime(),
      lastDate: today.addDays(365 * 10).toDateTime(),
    );
    if (picked == null) return;
    setState(() => _targetDay = HarvestDay.fromDate(picked));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final repository = ref.read(goalsRepositoryProvider);
    final title = _title.text.trim();
    final why = _why.text.trim();
    final existing = widget.existing;
    if (existing == null) {
      final goal = await repository.create(
        title: title,
        why: why,
        targetDay: _targetDay,
      );
      navigator.pop(goal);
      return;
    }
    await repository.update(
      existing.copyWith(
        title: title,
        why: why,
        targetDay: _targetDay,
        clearTargetDay: _targetDay == null,
      ),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final day = _targetDay;
    return HarvestSheet(
      title: widget.existing == null ? l10n.goalNew : l10n.goalEdit,
      actionLabel: l10n.save,
      onAction: _title.text.trim().isEmpty || _saving
          ? null
          : () => unawaited(_save()),
      children: [
        TextField(
          controller: _title,
          autofocus: widget.existing == null,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.goalTitleLabel,
            hintText: l10n.goalTitleHint,
            counterText: '',
          ),
        ),
        const SizedBox(height: HarvestSpacing.md),
        TextField(
          controller: _why,
          minLines: 2,
          maxLines: 5,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.goalWhyLabel,
            hintText: l10n.goalWhyHint,
            counterText: '',
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(l10n.goalTargetDay),
          subtitle: Text(
            day == null
                ? l10n.goalNoTargetDay
                : formatDay(context, day, weekday: true),
          ),
          trailing: day == null
              ? null
              : IconButton(
                  tooltip: l10n.goalNoTargetDay,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _targetDay = null),
                ),
          onTap: () => unawaited(_pickDay()),
        ),
      ],
    );
  }
}
