import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/features/commitments/presentation/field_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:table_calendar/table_calendar.dart';

/// One thing happening on a calendar day.
class _CalendarEntry {
  const _CalendarEntry(this.commitment, {this.isDeadline = false});

  final Commitment commitment;
  final bool isDeadline;
}

/// Month calendar populated from every schedule (checkpoint gap G3).
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

  List<_CalendarEntry> _entriesFor(
    List<Commitment> commitments,
    HarvestDay day,
  ) {
    final entries = <_CalendarEntry>[];
    for (final commitment in commitments) {
      switch (commitment.type) {
        case CommitmentType.habit:
          if (!commitment.isPaused && commitment.schedule!.isDueOn(day)) {
            entries.add(_CalendarEntry(commitment));
          }
        case CommitmentType.project:
          entries.add(_CalendarEntry(commitment));
        case CommitmentType.todo:
          if (commitment.dueDay == day) {
            entries.add(_CalendarEntry(commitment));
          }
      }
      if (commitment.deadline == day) {
        entries.add(_CalendarEntry(commitment, isDeadline: true));
      }
    }
    return entries;
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
    final commitments =
        ref.watch(activeCommitmentsProvider).value ?? const [];
    final selectedDay = HarvestDay.of(
      DateTime(_selected.year, _selected.month, _selected.day, 12),
    );
    final entries = _entriesFor(commitments, selectedDay);
    final today = HarvestDay.today();
    final isFuture = selectedDay.compareTo(today) >= 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarTitle)),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(HarvestSpacing.md),
            child: TableCalendar<void>(
              locale: locale,
              firstDay: DateTime(2024),
              lastDay: DateTime.now().add(const Duration(days: 365 * 3)),
              focusedDay: _focused,
              selectedDayPredicate: (day) => isSameDay(day, _selected),
              onDaySelected: (selected, focused) => setState(() {
                _selected = selected;
                _focused = focused;
              }),
              onPageChanged: (focused) => _focused = focused,
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableCalendarFormats: const {
                CalendarFormat.month: 'month',
              },
              eventLoader: (day) {
                final harvestDay =
                    HarvestDay.of(DateTime(day.year, day.month, day.day, 12));
                return List<void>.filled(
                  _entriesFor(commitments, harvestDay).length,
                  null,
                );
              },
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
                          color: Colors.white,
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
                titleTextStyle: theme.textTheme.titleMedium!
                    .copyWith(fontWeight: FontWeight.w800),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: theme.textTheme.bodyMedium!,
                weekendTextStyle: theme.textTheme.bodyMedium!,
                outsideTextStyle: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                HarvestSpacing.md,
                0,
                HarvestSpacing.md,
                HarvestSpacing.lg,
              ),
              children: [
                if (isFuture)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: HarvestSpacing.sm),
                    child: TextField(
                      controller: _quickAdd,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          unawaited(_addTodo(selectedDay)),
                      decoration: InputDecoration(
                        hintText: l10n.calAddForDay,
                        prefixIcon: const Icon(Icons.add),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(HarvestRadii.button),
                        ),
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
