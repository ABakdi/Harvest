import 'dart:async';

import 'package:flutter/material.dart';
import 'package:harvest/core/domain/harvest_day.dart';

/// Below this much remaining time the countdown ticks by the second.
const deadlineTickingThreshold = Duration(hours: 3);

/// Pure formatter for the countdown (unit-tested): days+hours while
/// distant, hours+minutes inside a day, H:MM:SS in the final stretch,
/// empty once overdue.
String formatDeadlineRemaining(Duration remaining) {
  String two(int value) => value.toString().padLeft(2, '0');
  if (remaining.isNegative) return '';
  if (remaining <= deadlineTickingThreshold) {
    return '${two(remaining.inHours)}:'
        '${two(remaining.inMinutes % 60)}:'
        '${two(remaining.inSeconds % 60)}';
  }
  if (remaining.inDays >= 1) {
    return '${remaining.inDays}d ${remaining.inHours % 24}h';
  }
  return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
}

/// Live time-left readout for a deadline (checkpoint P3):
/// days+hours while distant, hours+minutes inside a day, and a
/// second-by-second ticking clock once 3 hours or less remain.
class DeadlineCountdown extends StatefulWidget {
  const DeadlineCountdown({required this.deadline, super.key});

  /// The deadline day; time runs out when its Harvest Day ends.
  final HarvestDay deadline;

  @override
  State<DeadlineCountdown> createState() => _DeadlineCountdownState();
}

class _DeadlineCountdownState extends State<DeadlineCountdown> {
  Timer? _ticker;

  Duration get _remaining =>
      widget.deadline.next.startsAt.difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    _ticker?.cancel();
    final remaining = _remaining;
    // Tick every second in the final stretch, else once a minute.
    final period = remaining <= deadlineTickingThreshold
        ? const Duration(seconds: 1)
        : const Duration(minutes: 1);
    _ticker = Timer.periodic(period, (_) {
      if (!mounted) return;
      setState(_schedule);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _remaining;
    final ticking =
        !remaining.isNegative && remaining <= deadlineTickingThreshold;
    final text = formatDeadlineRemaining(remaining);
    if (text.isEmpty) return const SizedBox.shrink();

    final color =
        ticking ? theme.colorScheme.error : theme.colorScheme.tertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.hourglass_bottom, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
