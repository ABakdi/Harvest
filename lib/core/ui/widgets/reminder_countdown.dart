import 'dart:async';

import 'package:flutter/material.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Below this much remaining time the reminder ticks by the second.
const reminderTickingThreshold = Duration(minutes: 5);

/// The next occurrence of the wall-clock time [hour]:[minute] at or
/// after [from] — today's if it is still ahead, tomorrow's if it has
/// already gone by.
DateTime nextOccurrence(int hour, int minute, DateTime from) {
  final today = DateTime(from.year, from.month, from.day, hour, minute);
  return today.isAfter(from)
      ? today
      : DateTime(from.year, from.month, from.day + 1, hour, minute);
}

/// Pure formatter for the time left until a reminder rings: hours and
/// minutes while distant, M:SS in the last five minutes, "now" as it
/// lands. Unit suffixes are injected so they localize.
String formatReminderRemaining(
  Duration remaining, {
  String hours = 'h',
  String minutes = 'm',
  String now = 'now',
}) {
  String two(int value) => value.toString().padLeft(2, '0');
  if (remaining.isNegative || remaining.inSeconds == 0) return now;
  if (remaining <= reminderTickingThreshold) {
    return '${remaining.inMinutes}:${two(remaining.inSeconds % 60)}';
  }
  if (remaining.inHours >= 1) {
    return '${remaining.inHours}$hours ${remaining.inMinutes % 60}$minutes';
  }
  return '${remaining.inMinutes}$minutes';
}

/// The live "rings in…" chip on a seed's card. A reminder I set is a
/// promise the card should keep in front of me, so it counts down
/// rather than sitting there as a static time.
class ReminderCountdown extends StatefulWidget {
  const ReminderCountdown({
    required this.hour,
    required this.minute,
    this.silenced = false,
    super.key,
  });

  final int hour;
  final int minute;

  /// The seed is done for the day: the time is shown, quietly, but it
  /// no longer counts down — nothing is going to ring.
  final bool silenced;

  @override
  State<ReminderCountdown> createState() => _ReminderCountdownState();
}

class _ReminderCountdownState extends State<ReminderCountdown> {
  Timer? _ticker;
  Duration? _period;

  Duration get _remaining => nextOccurrence(
    widget.hour,
    widget.minute,
    DateTime.now(),
  ).difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    if (!widget.silenced) _arm();
  }

  @override
  void didUpdateWidget(ReminderCountdown old) {
    super.didUpdateWidget(old);
    if (widget.silenced) {
      _ticker?.cancel();
      _ticker = null;
      _period = null;
    } else {
      _arm();
    }
  }

  /// Ticks every second in the last five minutes, else once a minute;
  /// the timer is only replaced when the cadence actually changes.
  void _arm() {
    final period = _remaining <= reminderTickingThreshold
        ? const Duration(seconds: 1)
        : const Duration(minutes: 1);
    if (period == _period && _ticker != null) return;
    _period = period;
    _ticker?.cancel();
    _ticker = Timer.periodic(period, (_) {
      if (!mounted) return;
      setState(_arm);
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
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;

    if (widget.silenced) {
      return _Chip(
        icon: Icons.notifications_off_outlined,
        label: TimeOfDay(
          hour: widget.hour,
          minute: widget.minute,
        ).format(context),
        color: scheme.onSurfaceVariant,
      );
    }

    final remaining = _remaining;
    final ticking = remaining <= reminderTickingThreshold;
    final left = formatReminderRemaining(
      remaining,
      hours: l10n.unitHours,
      minutes: l10n.unitMinutes,
      now: l10n.reminderNow,
    );
    return _Chip(
      icon: Icons.alarm,
      // "rings in now" is not a sentence: as it lands the chip just
      // says the word.
      label: left == l10n.reminderNow ? left : l10n.reminderRingsIn(left),
      color: ticking ? scheme.primary : scheme.tertiary,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          label,
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
