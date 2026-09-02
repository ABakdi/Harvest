import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

Future<void> showCommitmentEditor(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HarvestRadii.sheet),
        ),
      ),
      builder: (_) => const _EditorSheet(),
    );

enum _ScheduleKind { daily, weekly, interval, timesPerWeek }

class _EditorSheet extends ConsumerStatefulWidget {
  const _EditorSheet();

  @override
  ConsumerState<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends ConsumerState<_EditorSheet> {
  final _titleController = TextEditingController();
  CommitmentType _type = CommitmentType.habit;
  _ScheduleKind _scheduleKind = _ScheduleKind.daily;
  final _weekdays = <int>{DateTime.monday, DateTime.wednesday, DateTime.friday};
  var _intervalDays = 2;
  var _timesPerWeek = 3;
  final _totalController = TextEditingController();
  final _dailyController = TextEditingController();
  var _dueToday = true;
  var _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    _dailyController.dispose();
    super.dispose();
  }

  bool get _valid {
    if (_titleController.text.trim().isEmpty) return false;
    if (_type == CommitmentType.project) {
      final total = int.tryParse(_totalController.text) ?? 0;
      final daily = int.tryParse(_dailyController.text) ?? 0;
      return total > 0 && daily > 0;
    }
    if (_type == CommitmentType.habit &&
        _scheduleKind == _ScheduleKind.weekly) {
      return _weekdays.isNotEmpty;
    }
    return true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final editor = ref.read(commitmentEditorProvider.notifier);
    final title = _titleController.text.trim();
    switch (_type) {
      case CommitmentType.habit:
        final schedule = switch (_scheduleKind) {
          _ScheduleKind.daily => const DailySchedule(),
          _ScheduleKind.weekly => WeeklySchedule(weekdays: {..._weekdays}),
          _ScheduleKind.interval => IntervalSchedule(
              everyDays: _intervalDays,
              anchorDay: HarvestDay.today(),
            ),
          _ScheduleKind.timesPerWeek =>
            TimesPerWeekSchedule(times: _timesPerWeek),
        };
        await editor.createHabit(title: title, schedule: schedule);
      case CommitmentType.project:
        await editor.createProject(
          title: title,
          totalTarget: int.parse(_totalController.text),
          dailyCommitment: int.parse(_dailyController.text),
        );
      case CommitmentType.todo:
        await editor.createTodo(
          title: title,
          dueDay:
              _dueToday ? HarvestDay.today() : HarvestDay.today().next,
        );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(HarvestSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.addCommitment,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: HarvestSpacing.md),
            SegmentedButton<CommitmentType>(
              segments: [
                ButtonSegment(
                  value: CommitmentType.habit,
                  label: Text(l10n.typeHabit),
                  icon: const Icon(Icons.repeat),
                ),
                ButtonSegment(
                  value: CommitmentType.project,
                  label: Text(l10n.typeProject),
                  icon: const Icon(Icons.flag),
                ),
                ButtonSegment(
                  value: CommitmentType.todo,
                  label: Text(l10n.typeTodo),
                  icon: const Icon(Icons.check),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: HarvestSpacing.md),
            TextField(
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.titleLabel,
                hintText: switch (_type) {
                  CommitmentType.habit => l10n.titleHintHabit,
                  CommitmentType.project => l10n.titleHintProject,
                  CommitmentType.todo => l10n.titleHintTodo,
                },
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HarvestRadii.button),
                ),
              ),
            ),
            const SizedBox(height: HarvestSpacing.md),
            ...switch (_type) {
              CommitmentType.habit => _habitFields(l10n),
              CommitmentType.project => _projectFields(l10n),
              CommitmentType.todo => _todoFields(l10n),
            },
            const SizedBox(height: HarvestSpacing.lg),
            BigBouncySheetButton(
              onPressed: _valid && !_saving ? _save : null,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _habitFields(AppLocalizations l10n) => [
        Text(l10n.scheduleLabel),
        const SizedBox(height: HarvestSpacing.sm),
        SegmentedButton<_ScheduleKind>(
          segments: [
            ButtonSegment(
              value: _ScheduleKind.daily,
              label: Text(l10n.scheduleDaily),
            ),
            ButtonSegment(
              value: _ScheduleKind.weekly,
              label: Text(l10n.scheduleWeekly),
            ),
            ButtonSegment(
              value: _ScheduleKind.interval,
              label: Text(l10n.scheduleInterval),
            ),
            ButtonSegment(
              value: _ScheduleKind.timesPerWeek,
              label: Text(l10n.scheduleTimesPerWeek),
            ),
          ],
          selected: {_scheduleKind},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              setState(() => _scheduleKind = s.first),
        ),
        const SizedBox(height: HarvestSpacing.md),
        ...switch (_scheduleKind) {
          _ScheduleKind.daily => const <Widget>[],
          _ScheduleKind.weekly => [_weekdayPicker()],
          _ScheduleKind.interval => [
              _Stepper(
                label: l10n.everyDaysLabel(_intervalDays),
                value: _intervalDays,
                min: 2,
                max: 30,
                onChanged: (v) => setState(() => _intervalDays = v),
              ),
            ],
          _ScheduleKind.timesPerWeek => [
              _Stepper(
                label: l10n.timesPerWeekLabel(_timesPerWeek),
                value: _timesPerWeek,
                min: 1,
                max: 6,
                onChanged: (v) => setState(() => _timesPerWeek = v),
              ),
            ],
        },
      ];

  Widget _weekdayPicker() {
    final locale = Localizations.localeOf(context).toString();
    // Monday-first row of localized weekday chips.
    final monday = DateTime(2026, 9, 7);
    return Wrap(
      spacing: HarvestSpacing.xs,
      children: [
        for (var i = 0; i < 7; i++)
          FilterChip(
            label: Text(
              DateFormat.E(locale).format(monday.add(Duration(days: i))),
            ),
            selected: _weekdays.contains(i + 1),
            onSelected: (selected) => setState(() {
              if (selected) {
                _weekdays.add(i + 1);
              } else {
                _weekdays.remove(i + 1);
              }
            }),
          ),
      ],
    );
  }

  List<Widget> _projectFields(AppLocalizations l10n) => [
        TextField(
          controller: _totalController,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.totalTargetLabel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HarvestRadii.button),
            ),
          ),
        ),
        const SizedBox(height: HarvestSpacing.md),
        TextField(
          controller: _dailyController,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.dailyCommitmentLabel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HarvestRadii.button),
            ),
          ),
        ),
      ];

  List<Widget> _todoFields(AppLocalizations l10n) => [
        Text(l10n.dueLabel),
        const SizedBox(height: HarvestSpacing.sm),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(l10n.dueToday)),
            ButtonSegment(value: false, label: Text(l10n.dueTomorrow)),
          ],
          selected: {_dueToday},
          onSelectionChanged: (s) => setState(() => _dueToday = s.first),
        ),
      ];
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: HarvestSpacing.xs),
            IconButton.filledTonal(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}
