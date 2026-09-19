import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/due.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/features/commitments/presentation/commitment_editor_sheet.dart';
import 'package:harvest/features/commitments/presentation/crop_options_sheet.dart';
import 'package:harvest/features/commitments/presentation/field_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:table_calendar/table_calendar.dart';

/// One thing happening on a calendar day.
class _CalendarEntry {
  const _CalendarEntry(this.commitment, {this.isDeadline = false});

  final Commitment commitment;
  final bool isDeadline;
}

/// The month of habits due, to-dos planned and deadlines set. Projects
/// are implicitly daily and stay off the grid so the badge keeps
/// meaning something (checkpoint gap G3, then U-13).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focused;
  late DateTime _selected;
  final _quickAdd = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focused = DateTime.now();
    _selected = _focused;
  }

  @override
  void dispose() {
    _quickAdd.dispose();
    super.dispose();
  }

  static List<_CalendarEntry> _entriesFor(
    List<Commitment> commitments,
    HarvestDay day,
  ) {
    final entries = <_CalendarEntry>[];
    for (final commitment in commitments) {
      switch (commitment.type) {
        case CommitmentType.habit:
          if (isDueOn(commitment, day)) entries.add(_CalendarEntry(commitment));
        case CommitmentType.todo:
          if (commitment.dueDay == day) entries.add(_CalendarEntry(commitment));
        case CommitmentType.project:
          break;
      }
      if (commitment.deadline == day) {
        entries.add(_CalendarEntry(commitment, isDeadline: true));
      }
    }
    return entries;
  }

  /// Entry counts for every day the grid can show around [focused],
  /// computed once per build instead of once per cell per frame.
  static Map<HarvestDay, int> _countsAround(
    List<Commitment> commitments,
    DateTime focused,
  ) {
    final first = HarvestDay.fromDate(DateTime(focused.year, focused.month))
        .addDays(-7);
    final counts = <HarvestDay, int>{};
    for (var i = 0; i < 7 * 8; i++) {
      final day = first.addDays(i);
      final n = _entriesFor(commitments, day).length;
      if (n > 0) counts[day] = n;
    }
    return counts;
  }

  Future<void> _addTodo(HarvestDay day) async {
    final title = _quickAdd.text.trim();
    if (title.isEmpty) return;
    _quickAdd.clear();
    await ref
        .read(commitmentEditorProvider.notifier)
        .createTodo(title: title, dueDay: day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final commitments = ref.watch(activeCommitmentsProvider).value ?? const [];
    final today = ref.watch(currentHarvestDayProvider);
    final selectedDay = HarvestDay.fromDate(_selected);
    final entries = _entriesFor(commitments, selectedDay);
    final counts = _countsAround(commitments, _focused);
    final isFuture = selectedDay.compareTo(today) >= 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarTitle)),
      // One scroll view, not a grid above an expanded list: the quick-add
      // field raises the keyboard, and a fixed-height month grid over a
      // shrunken body is exactly how a column overflows.
      body: ListView(
        padding: const EdgeInsets.only(bottom: HarvestSpacing.lg),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Card(
            margin: const EdgeInsets.all(HarvestSpacing.md),
            child: TableCalendar<void>(
              locale: locale,
              firstDay: today.addDays(-planningHorizon.inDays).toDateTime(),
              lastDay: today.addDays(planningHorizon.inDays).toDateTime(),
              focusedDay: _focused,
              selectedDayPredicate: (day) => isSameDay(day, _selected),
              onDaySelected: (selected, focused) => setState(() {
                _selected = selected;
                _focused = focused;
              }),
              onPageChanged: (focused) => setState(() => _focused = focused),
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableCalendarFormats: {
                CalendarFormat.month: l10n.rangeMonth,
              },
              eventLoader: (day) => List<void>.filled(
                counts[HarvestDay.fromDate(day)] ?? 0,
                null,
              ),
              calendarBuilders: CalendarBuilders(
                // A count badge reads better than a pile of dots (P1).
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  return PositionedDirectional(
                    bottom: 2,
                    end: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${events.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                },
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: theme.textTheme.bodyMedium!,
                weekendTextStyle: theme.textTheme.bodyMedium!,
                outsideTextStyle: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  gradient: theme.primaryGradient,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HarvestSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isFuture)
                  Padding(
                    padding: const EdgeInsets.only(bottom: HarvestSpacing.sm),
                    child: TextField(
                      controller: _quickAdd,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => unawaited(_addTodo(selectedDay)),
                      decoration: InputDecoration(
                        hintText: l10n.calAddForDay,
                        prefixIcon: const Icon(Icons.add),
                      ),
                    ),
                  ),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(HarvestSpacing.lg),
                    child: Text(
                      l10n.calNothingDue,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  )
                else
                  for (final entry in entries)
                    Card(
                      key: ValueKey(
                        '${entry.commitment.uuid}-${entry.isDeadline}',
                      ),
                      margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
                      child: ListTile(
                        leading: Icon(
                          entry.isDeadline
                              ? Icons.flag
                              : switch (entry.commitment.type) {
                                  CommitmentType.habit => Icons.repeat,
                                  CommitmentType.project => Icons.flag_outlined,
                                  CommitmentType.todo =>
                                    Icons.check_circle_outline,
                                },
                          color: entry.isDeadline
                              ? theme.colorScheme.error
                              : theme.colorScheme.secondary,
                        ),
                        title: Text(
                          entry.isDeadline
                              ? l10n.calDeadline(entry.commitment.title)
                              : entry.commitment.title,
                        ),
                        subtitle: entry.commitment.note == null
                            ? null
                            : Text(entry.commitment.note!),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onTap: () => unawaited(
                          showCropOptions(context, entry.commitment),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
