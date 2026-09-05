import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/settings/domain/daily_cycle.dart';
import 'package:harvest/features/settings/domain/daily_cycle_service.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// When I sleep and when I wake, and what that means for everything the
/// app was going to say to me in between.
///
/// Changing either time is the interesting part: reminders that would
/// now go off in the middle of the night are found, listed by name, and
/// moved only if I say so — each one keeping its own distance from
/// waking, so a thing I do two hours after getting up stays two hours
/// after getting up.
class DailyCycleCard extends ConsumerWidget {
  const DailyCycleCard({super.key});

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref, {
    required DailyCycle current,
    required bool bed,
  }) async {
    final start = bed ? current.bedTime : current.wakeTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.$1, minute: start.$2),
    );
    if (picked == null || !context.mounted) return;

    final next = bed
        ? current.copyWith(bedTime: (picked.hour, picked.minute))
        : current.copyWith(wakeTime: (picked.hour, picked.minute));
    if (next == current) return;

    final service = ref.read(dailyCycleServiceProvider);
    await service.write(next);

    final clashes = await service.clashes(from: current, to: next);
    if (clashes.isEmpty || !context.mounted) {
      await ref.read(notificationPlannerProvider).planToday();
      return;
    }

    final move = await _askToMove(context, clashes);
    if (move) await service.shift(clashes);
    await ref.read(notificationPlannerProvider).planToday();
  }

  Future<bool> _askToMove(
    BuildContext context,
    List<SleepClash> clashes,
  ) async {
    final l10n = AppLocalizations.of(context);
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cycleClashTitle(clashes.length)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.cycleClashBody),
            const SizedBox(height: HarvestSpacing.sm),
            for (final clash in clashes.take(6))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.cycleClashMove(
                    clash.title,
                    _label(context, clash.at),
                    _label(context, clash.movedTo),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (clashes.length > 6)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.cycleClashMore(clashes.length - 6),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cycleClashKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.cycleClashShift),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  static String _label(BuildContext context, (int, int) time) =>
      TimeOfDay(hour: time.$1, minute: time.$2).format(context);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cycle = ref.watch(dailyCycleProvider).value ?? DailyCycle.fallback;
    final hours = cycle.sleep.inMinutes / 60;
    final short = cycle.isShort;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: Text(l10n.cycleBedTime),
            trailing: Text(_label(context, cycle.bedTime)),
            onTap: () => unawaited(
              _pick(context, ref, current: cycle, bed: true),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: Text(l10n.cycleWakeTime),
            trailing: Text(_label(context, cycle.wakeTime)),
            onTap: () => unawaited(
              _pick(context, ref, current: cycle, bed: false),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HarvestSpacing.md,
              0,
              HarvestSpacing.md,
              HarvestSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  short ? Icons.warning_amber : Icons.nights_stay_outlined,
                  size: 18,
                  color: short
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: HarvestSpacing.sm),
                Expanded(
                  child: Text(
                    short
                        ? l10n.cycleTooShort(_hours(hours))
                        : cycle.meetsRecommendation
                        ? l10n.cycleGood(_hours(hours))
                        : l10n.cycleBelowTarget(_hours(hours)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: short
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: short ? FontWeight.w800 : null,
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

  /// "7" for a round night, "7.5" for half an hour more.
  static String _hours(double hours) => hours == hours.roundToDouble()
      ? hours.round().toString()
      : hours.toStringAsFixed(1);
}
