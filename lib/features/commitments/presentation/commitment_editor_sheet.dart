import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

Future<void> showCommitmentEditor(
  BuildContext context, {
  Commitment? existing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(HarvestRadii.sheet),
    ),
  ),
  builder: (_) => _EditorSheet(existing: existing),
);

/// How far ahead a date picker lets a seed be planted.
const planningHorizon = Duration(days: 365 * 3);

enum _ScheduleKind { daily, weekly, interval, timesPerWeek }

class _EditorSheet extends ConsumerStatefulWidget {
  const _EditorSheet({this.existing});

  /// Non-null puts the sheet in edit mode: type is fixed, fields are
  /// prefilled, and saving updates instead of creating.
  final Commitment? existing;

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

  // Advanced options (checkpoint gap G4).
  final _noteController = TextEditingController();
  TimeOfDay? _remindAt;
  HarvestDay? _deadline;
  HarvestDay? _customDueDay;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;
    _type = existing.type;
    _titleController.text = existing.title;
    _noteController.text = existing.note ?? '';
    _deadline = existing.deadline;
    if (SettingsRepository.parseTime(existing.remindAt) case final time?) {
      _remindAt = TimeOfDay(hour: time.$1, minute: time.$2);
    }
    _totalController.text = '${existing.totalTarget ?? ''}';
    _dailyController.text = '${existing.dailyCommitment ?? ''}';
    // Keep the planned day exactly as it was: today/tomorrow use the
    // chips, anything else stays a custom date (never silently moved).
    final today = HarvestDay.today();
    final due = existing.dueDay;
    if (due == null || due.compareTo(today) <= 0) {
      _dueToday = true;
    } else if (due == today.next) {
      _dueToday = false;
    } else {
      _customDueDay = due;
    }
    switch (existing.schedule) {
      case DailySchedule():
        _scheduleKind = _ScheduleKind.daily;
      case WeeklySchedule(:final weekdays):
        _scheduleKind = _ScheduleKind.weekly;
        _weekdays
          ..clear()
          ..addAll(weekdays);
      case IntervalSchedule(:final everyDays):
        _scheduleKind = _ScheduleKind.interval;
        _intervalDays = everyDays;
      case TimesPerWeekSchedule(:final times):
        _scheduleKind = _ScheduleKind.timesPerWeek;
        _timesPerWeek = times;
      case null:
        break;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    _dailyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? get _remindAtString => _remindAt == null
      ? null
      : SettingsRepository.formatTime(_remindAt!.hour, _remindAt!.minute);

  String? get _noteOrNull {
    final note = _noteController.text.trim();
    return note.isEmpty ? null : note;
  }

  HarvestDay get _todoDueDay =>
      _customDueDay ??
      (_dueToday ? HarvestDay.today() : HarvestDay.today().next);

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
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await _persist(editor, title);
      navigator.pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.checkInFailed)));
    }
  }

  Future<void> _persist(CommitmentEditor editor, String title) async {
    if (_editing) {
      await _saveEdit(editor, title);
      return;
    }

    switch (_type) {
      case CommitmentType.habit:
        final schedule = switch (_scheduleKind) {
          _ScheduleKind.daily => const DailySchedule(),
          _ScheduleKind.weekly => WeeklySchedule(weekdays: {..._weekdays}),
          _ScheduleKind.interval => IntervalSchedule(
            everyDays: _intervalDays,
            anchorDay: HarvestDay.today(),
          ),
          _ScheduleKind.timesPerWeek => TimesPerWeekSchedule(
            times: _timesPerWeek,
          ),
        };
        await editor.createHabit(
          title: title,
          schedule: schedule,
          note: _noteOrNull,
          remindAt: _remindAtString,
        );
      case CommitmentType.project:
        await editor.createProject(
          title: title,
          totalTarget: int.parse(_totalController.text),
          dailyCommitment: int.parse(_dailyController.text),
          note: _noteOrNull,
          remindAt: _remindAtString,
          deadline: _deadline,
        );
      case CommitmentType.todo:
        await editor.createTodo(
          title: title,
          dueDay: _todoDueDay,
          note: _noteOrNull,
          remindAt: _remindAtString,
        );
    }
  }

  Future<void> _saveEdit(CommitmentEditor editor, String title) async {
    final existing = widget.existing!;
    final schedule = switch (_scheduleKind) {
      _ScheduleKind.daily => const DailySchedule(),
      _ScheduleKind.weekly => WeeklySchedule(weekdays: {..._weekdays}),
      _ScheduleKind.interval => IntervalSchedule(
        everyDays: _intervalDays,
        anchorDay: existing.schedule is IntervalSchedule
            ? (existing.schedule! as IntervalSchedule).anchorDay
            : HarvestDay.today(),
      ),
      _ScheduleKind.timesPerWeek => TimesPerWeekSchedule(times: _timesPerWeek),
    };
    await editor.updateCommitment(
      previousRemindAt: existing.remindAt,
      existing.copyWith(
        title: title,
        schedule: existing.type == CommitmentType.habit ? schedule : null,
        totalTarget: int.tryParse(_totalController.text),
        dailyCommitment: int.tryParse(_dailyController.text),
        dueDay: existing.type == CommitmentType.todo ? _todoDueDay : null,
        note: _noteOrNull,
        remindAt: _remindAtString,
        deadline: existing.type == CommitmentType.project ? _deadline : null,
        clearNote: _noteOrNull == null,
        clearRemindAt: _remindAtString == null,
        clearDeadline:
            existing.type != CommitmentType.project || _deadline == null,
      ),
    );
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
              _editing ? l10n.editSeed : l10n.addCommitment,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: HarvestSpacing.md),
            if (!_editing)
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
              ),
            ),
            const SizedBox(height: HarvestSpacing.md),
            ...switch (_type) {
              CommitmentType.habit => _habitFields(l10n),
              CommitmentType.project => _projectFields(l10n),
              CommitmentType.todo => _todoFields(l10n),
            },
            const SizedBox(height: HarvestSpacing.sm),
            _advancedSection(l10n),
            const SizedBox(height: HarvestSpacing.md),
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
      onSelectionChanged: (s) => setState(() => _scheduleKind = s.first),
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
    // Monday-first row of localized weekday chips; intl lists Sunday first.
    final names = DateFormat.E(locale).dateSymbols.STANDALONESHORTWEEKDAYS;
    return Wrap(
      spacing: HarvestSpacing.xs,
      children: [
        for (var i = 0; i < 7; i++)
          FilterChip(
            label: Text(names[(i + 1) % 7]),
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
      ),
    ),
    const SizedBox(height: HarvestSpacing.md),
    TextField(
      controller: _dailyController,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: l10n.dailyCommitmentLabel,
      ),
    ),
  ];

  Widget _advancedSection(AppLocalizations l10n) {
    final locale = Localizations.localeOf(context).toString();
    String dayLabel(HarvestDay? day) => day == null
        ? l10n.notSet
        : DateFormat.MMMd(locale).format(
            DateTime(day.year, day.month, day.day),
          );

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      title: Text(
        l10n.advancedOptions,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      children: [
        TextField(
          controller: _noteController,
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(
            labelText: l10n.seedNoteLabel,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.alarm),
          title: Text(l10n.remindMeAt),
          subtitle: Text(
            _remindAt == null ? l10n.notSet : _remindAt!.format(context),
          ),
          trailing: _remindAt == null
              ? null
              : IconButton(
                  tooltip: l10n.clearValue,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _remindAt = null),
                ),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _remindAt ?? const TimeOfDay(hour: 18, minute: 0),
            );
            if (picked != null) setState(() => _remindAt = picked);
          },
        ),
        if (_type == CommitmentType.project)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined),
            title: Text(l10n.deadlineLabel),
            subtitle: Text(dayLabel(_deadline)),
            trailing: _deadline == null
                ? null
                : IconButton(
                    tooltip: l10n.clearValue,
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _deadline = null),
                  ),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: now,
                firstDate: now,
                lastDate: now.add(planningHorizon),
              );
              if (picked != null) {
                setState(() => _deadline = HarvestDay.fromDate(picked));
              }
            },
          ),
        const SizedBox(height: HarvestSpacing.sm),
      ],
    );
  }

  List<Widget> _todoFields(AppLocalizations l10n) => [
    Text(l10n.dueLabel),
    const SizedBox(height: HarvestSpacing.sm),
    Wrap(
      spacing: HarvestSpacing.xs,
      children: [
        ChoiceChip(
          label: Text(l10n.dueToday),
          selected: _customDueDay == null && _dueToday,
          onSelected: (_) => setState(() {
            _dueToday = true;
            _customDueDay = null;
          }),
        ),
        ChoiceChip(
          label: Text(l10n.dueTomorrow),
          selected: _customDueDay == null && !_dueToday,
          onSelected: (_) => setState(() {
            _dueToday = false;
            _customDueDay = null;
          }),
        ),
        ChoiceChip(
          avatar: const Icon(Icons.event, size: 18),
          label: Text(
            _customDueDay == null
                ? l10n.pickDate
                : DateFormat.MMMd(
                    Localizations.localeOf(context).toString(),
                  ).format(
                    DateTime(
                      _customDueDay!.year,
                      _customDueDay!.month,
                      _customDueDay!.day,
                    ),
                  ),
          ),
          selected: _customDueDay != null,
          onSelected: (_) async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: now,
              lastDate: now.add(planningHorizon),
            );
            if (picked != null) {
              setState(() => _customDueDay = HarvestDay.fromDate(picked));
            }
          },
        ),
      ],
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
              tooltip: AppLocalizations.of(context).decrease,
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: HarvestSpacing.xs),
            IconButton.filledTonal(
              tooltip: AppLocalizations.of(context).increase,
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}
