import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/health/data/sleep_repository.dart';
import 'package:harvest/features/health/domain/sleep.dart';
import 'package:harvest/features/health/presentation/sleep_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The morning retrospective.
///
/// Three questions, asked once, answerable in about eight seconds by
/// someone who is not yet awake. Everything is pre-filled with the
/// likeliest answer, so the honest path for a normal night is: open,
/// tap the stars, done.
Future<bool> showSleepSheet(
  BuildContext context, {
  HarvestDay? forDay,
}) async =>
    await showHarvestSheet<bool>(
      context,
      builder: (_) => _SleepSheet(day: forDay ?? HarvestDay.today()),
    ) ??
    false;

class _SleepSheet extends ConsumerStatefulWidget {
  const _SleepSheet({required this.day});

  final HarvestDay day;

  @override
  ConsumerState<_SleepSheet> createState() => _SleepSheetState();
}

class _SleepSheetState extends ConsumerState<_SleepSheet> {
  /// Minutes past midnight I fell asleep, allowed to be negative — the
  /// evening before is where most of them are.
  int? _asleep;
  int? _woke;
  int? _stars;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final targets = ref.watch(sleepTargetsProvider).value;
    final existing = ref
        .watch(sleepNightsProvider)
        .value
        ?.where(
          (night) => night.day == widget.day,
        );
    final already = existing == null || existing.isEmpty
        ? null
        : existing.first;

    final cycle = targets?.forMorning(widget.day);
    final defaultAsleep = cycle == null
        ? -60
        : bedtimeFor(widget.day, targets!).difference(_midnight).inMinutes;
    final defaultWoke = cycle == null
        ? 7 * 60
        : alarmFor(widget.day, targets!).difference(_midnight).inMinutes;

    final asleep =
        _asleep ??
        (already == null
            ? defaultAsleep
            : already.fellAsleepAt.difference(_midnight).inMinutes);
    final woke =
        _woke ??
        (already == null
            ? defaultWoke
            : already.wokeAt.difference(_midnight).inMinutes);
    final stars = _stars ?? already?.restedStars;
    final slept = Duration(minutes: woke - asleep);

    return HarvestSheet(
      title: l10n.sleepTitle,
      subtitle: l10n.sleepSubtitle,
      actionLabel: l10n.sleepSave,
      onAction: _saving || slept <= Duration.zero
          ? null
          : () => unawaited(_save(asleep: asleep, woke: woke, stars: stars)),
      children: [
        Center(
          child: Text(
            _lengthLabel(context, slept),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.secondary,
            ),
          ),
        ),
        const SizedBox(height: HarvestSpacing.md),
        _TimeSlider(
          label: l10n.sleepFellAsleep,
          value: asleep.toDouble(),
          // From eight in the evening to eleven the next morning: wide
          // enough for a night shift, narrow enough to be draggable.
          min: -4 * 60,
          max: 11 * 60,
          onChanged: (value) => setState(() => _asleep = value.round()),
        ),
        _TimeSlider(
          label: l10n.sleepWoke,
          value: woke.toDouble(),
          min: -4 * 60,
          max: 15 * 60,
          onChanged: (value) => setState(() => _woke = value.round()),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        Text(
          l10n.sleepRested,
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                iconSize: 34,
                onPressed: () {
                  HarvestHaptics.tick().ignore();
                  // Tapping the star you already chose takes it back:
                  // "I would rather not say" stays reachable.
                  setState(() => _stars = stars == star ? null : star);
                },
                icon: Icon(
                  stars != null && star <= stars
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: stars != null && star <= stars
                      ? scheme.tertiary
                      : scheme.outline,
                ),
              ),
          ],
        ),
      ],
    );
  }

  DateTime get _midnight =>
      DateTime(widget.day.year, widget.day.month, widget.day.day);

  static String _lengthLabel(BuildContext context, Duration slept) {
    final l10n = AppLocalizations.of(context);
    return l10n.sleepLength(slept.inHours, slept.inMinutes % 60);
  }

  Future<void> _save({
    required int asleep,
    required int woke,
    required int? stars,
  }) async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final targets = ref.read(sleepTargetsProvider).value;

    final first = await ref
        .read(sleepRepositoryProvider)
        .log(
          day: widget.day,
          fellAsleepAt: _midnight.add(Duration(minutes: asleep)),
          wokeAt: _midnight.add(Duration(minutes: woke)),
          targetMinutes: targets?.targetMinutesFor(widget.day) ?? 8 * 60,
          restedStars: stars,
        );

    // The XP is paid by the write itself, in the same transaction as
    // the night — this only has to say so.
    if (first) await HarvestHaptics.thud();
    navigator.pop(first);
  }
}

/// A time of day, dragged. The label reads as a clock; the value is
/// minutes from midnight and may be negative, because "half eleven
/// last night" is a perfectly ordinary answer to when I fell asleep.
class _TimeSlider extends StatelessWidget {
  const _TimeSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text(
              clockLabel(value.round()),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          // Five minutes: finer than anyone remembers, coarse enough
          // that the thumb lands where you meant it to.
          divisions: ((max - min) / 5).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// `23:15` from minutes past midnight, wrapping either way.
String clockLabel(int minutes) {
  final wrapped = minutes % (24 * 60);
  final positive = wrapped < 0 ? wrapped + 24 * 60 : wrapped;
  final hour = positive ~/ 60;
  final minute = positive % 60;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}
