import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

Future<void> showAlbumSheet(BuildContext context, {Album? existing}) =>
    showHarvestSheet<void>(
      context,
      builder: (_) => _AlbumSheet(existing: existing),
    );

enum _ScheduleKind { none, daily, weekly, interval, timesPerWeek }

/// Making or editing an album.
///
/// The schedule is the whole point of the sheet: an album with one is a
/// seed on the field, and an album without one is a shoebox. Everything
/// else here is a name and a reminder.
class _AlbumSheet extends ConsumerStatefulWidget {
  const _AlbumSheet({this.existing});

  final Album? existing;

  @override
  ConsumerState<_AlbumSheet> createState() => _AlbumSheetState();
}

class _AlbumSheetState extends ConsumerState<_AlbumSheet> {
  final _name = TextEditingController();
  final _note = TextEditingController();
  _ScheduleKind _kind = _ScheduleKind.daily;
  final _weekdays = <int>{DateTime.monday, DateTime.wednesday, DateTime.friday};
  var _intervalDays = 7;
  var _timesPerWeek = 3;
  TimeOfDay? _remindAt;
  var _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;
    _name.text = existing.name;
    _note.text = existing.note ?? '';
    if (SettingsRepository.parseTime(existing.remindAt) case final time?) {
      _remindAt = TimeOfDay(hour: time.$1, minute: time.$2);
    }
    switch (existing.schedule) {
      case null:
        _kind = _ScheduleKind.none;
      case DailySchedule():
        _kind = _ScheduleKind.daily;
      case WeeklySchedule(:final weekdays):
        _kind = _ScheduleKind.weekly;
        _weekdays
          ..clear()
          ..addAll(weekdays);
      case IntervalSchedule(:final everyDays):
        _kind = _ScheduleKind.interval;
        _intervalDays = everyDays;
      case TimesPerWeekSchedule(:final times):
        _kind = _ScheduleKind.timesPerWeek;
        _timesPerWeek = times;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  String? get _remindAtString => _remindAt == null
      ? null
      : SettingsRepository.formatTime(_remindAt!.hour, _remindAt!.minute);

  Schedule? get _schedule => switch (_kind) {
    _ScheduleKind.none => null,
    _ScheduleKind.daily => const DailySchedule(),
    _ScheduleKind.weekly => WeeklySchedule(weekdays: {..._weekdays}),
    _ScheduleKind.interval => IntervalSchedule(
      everyDays: _intervalDays,
      anchorDay: widget.existing?.schedule is IntervalSchedule
          ? (widget.existing!.schedule! as IntervalSchedule).anchorDay
          : widget.existing?.startDay ?? HarvestDay.today(),
    ),
    _ScheduleKind.timesPerWeek => TimesPerWeekSchedule(times: _timesPerWeek),
  };

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      !(_kind == _ScheduleKind.weekly && _weekdays.isEmpty);

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final repository = ref.read(galleryRepositoryProvider);
    final note = _note.text.trim();
    final existing = widget.existing;
    if (existing == null) {
      await repository.createAlbum(
        name: _name.text,
        schedule: _schedule,
        remindAt: _remindAtString,
        note: note.isEmpty ? null : note,
      );
    } else {
      await repository.updateAlbum(
        Album(
          uuid: existing.uuid,
          name: _name.text.trim(),
          createdAt: existing.createdAt,
          schedule: _schedule,
          remindAt: _remindAtString,
          note: note.isEmpty ? null : note,
        ),
      );
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HarvestSheet(
      title: _editing ? l10n.galleryEditAlbum : l10n.galleryNewAlbum,
      subtitle: l10n.galleryAlbumHint,
      actionLabel: _editing ? l10n.save : l10n.galleryCreateAlbum,
      onAction: _valid && !_saving ? _save : null,
      children: [
        TextField(
          controller: _name,
          autofocus: !_editing,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.galleryAlbumName,
            hintText: l10n.galleryAlbumNameHint,
          ),
        ),
        const SizedBox(height: HarvestSpacing.md),
        Text(l10n.gallerySchedule),
        const SizedBox(height: HarvestSpacing.xs),
        Text(
          l10n.gallerySeedHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        Wrap(
          spacing: HarvestSpacing.xs,
          children: [
            for (final kind in _ScheduleKind.values)
              ChoiceChip(
                label: Text(switch (kind) {
                  _ScheduleKind.none => l10n.galleryScheduleNone,
                  _ScheduleKind.daily => l10n.scheduleDaily,
                  _ScheduleKind.weekly => l10n.scheduleWeekly,
                  _ScheduleKind.interval => l10n.scheduleInterval,
                  _ScheduleKind.timesPerWeek => l10n.scheduleTimesPerWeek,
                }),
                selected: _kind == kind,
                onSelected: (_) => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: HarvestSpacing.md),
        ...switch (_kind) {
          _ScheduleKind.none || _ScheduleKind.daily => const <Widget>[],
          _ScheduleKind.weekly => [_weekdayPicker()],
          _ScheduleKind.interval => [
            _Stepper(
              label: l10n.everyDaysLabel(_intervalDays),
              value: _intervalDays,
              min: 2,
              max: 60,
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
        if (_kind != _ScheduleKind.none)
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
                initialTime: _remindAt ?? const TimeOfDay(hour: 20, minute: 0),
              );
              if (picked != null) setState(() => _remindAt = picked);
            },
          ),
        TextField(
          controller: _note,
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(labelText: l10n.seedNoteLabel),
        ),
        const SizedBox(height: HarvestSpacing.sm),
      ],
    );
  }

  Widget _weekdayPicker() {
    final locale = Localizations.localeOf(context).toString();
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
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: value > min ? () => onChanged(value - 1) : null,
      ),
      IconButton(
        icon: const Icon(Icons.add_circle_outline),
        onPressed: value < max ? () => onChanged(value + 1) : null,
      ),
    ],
  );
}
