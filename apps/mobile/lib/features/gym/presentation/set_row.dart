import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/celebration.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/domain/session.dart';
import 'package:harvest/features/gym/presentation/weight_text.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// One row of the session screen.
///
/// The whole design is in this widget: the weight and the reps are
/// already filled in from the target, so a set that went to plan is
/// **one tap** on the tick. A set that did not is two taps and a
/// number. Everything else — the plate calculator, the record
/// announcement — hangs off that tick.
class SetRow extends ConsumerStatefulWidget {
  const SetRow({
    required this.set,
    required this.exercise,
    required this.unit,
    required this.onTicked,
    required this.onPlates,
    super.key,
  });

  final WorkoutSet set;
  final SessionExercise exercise;
  final WeightUnit unit;

  /// Fired after a set is ticked, so the rest timer can start itself.
  final VoidCallback onTicked;

  /// Opens the plate calculator for the entered weight. Null where
  /// there is no bar to load, and then the target is just a label.
  final void Function(int grams)? onPlates;

  @override
  ConsumerState<SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<SetRow> {
  late final TextEditingController _weight = TextEditingController(
    text: _weightText(),
  );
  late final TextEditingController _reps = TextEditingController(
    text: widget.set.reps == 0 ? '' : '${widget.set.reps}',
  );
  String? _lastWeight;
  String? _lastReps;
  final GlobalKey _tick = GlobalKey();

  /// Rounded through the shared rule, so 60 kg is 132.25 in a pound
  /// box, as the target says, and not 132.28 ([[Gym]] rule Y8).
  String _weightText() => widget.set.weightGrams == 0
      ? ''
      : loadField(widget.set.weightGrams, widget.unit);

  @override
  void didUpdateWidget(SetRow old) {
    super.didUpdateWidget(old);
    // The database is the truth, but it must not fight the keyboard:
    // the fields are only re-read when the row's own values changed
    // somewhere other than here.
    if (old.set.weightGrams != widget.set.weightGrams &&
        _weight.text == _lastWeight) {
      _weight.text = _weightText();
    }
    // The unit can arrive after the row was built — the session opened
    // from the field before anything had read it — and a number shown
    // in kilograms under a pound header would be logged as pounds. What
    // is in the field is converted, not thrown away ([[Audit-v2]] U3-14).
    if (old.unit != widget.unit) {
      // A field still showing the row is re-read from the row, not from
      // its two decimals: 135 lb first shown as 61.24 kg stays 135 lb
      // ([[Gym]] rule Y8).
      final untouched =
          _weight.text ==
          (old.set.weightGrams == 0
              ? ''
              : loadField(old.set.weightGrams, old.unit));
      final typed = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
      final grams = typed == null || untouched
          ? widget.set.weightGrams
          : roundLoad(old.unit.toGrams(typed), unit: old.unit);
      _weight.text = grams == 0 ? '' : loadField(grams, widget.unit);
    }
    if (old.set.reps != widget.set.reps && _reps.text == _lastReps) {
      _reps.text = widget.set.reps == 0 ? '' : '${widget.set.reps}';
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  int get _enteredGrams {
    final value = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    return value == null
        ? 0
        : roundLoad(widget.unit.toGrams(value), unit: widget.unit);
  }

  int get _enteredReps => int.tryParse(_reps.text.trim()) ?? 0;

  /// Ticking is the whole interaction, so it does four things at once:
  /// writes the set, starts the rest, checks the records, and says so.
  Future<void> _toggle() async {
    final repository = ref.read(sessionsRepositoryProvider);
    final wasDone = widget.set.done;

    if (wasDone) {
      await repository.logSet(
        widget.set.uuid,
        weightGrams: _enteredGrams,
        reps: _enteredReps,
        done: false,
      );
      return;
    }

    // Records as they stood *before* this set, so a set cannot beat
    // itself.
    final before = await repository.records(widget.exercise.exerciseId);
    await repository.logSet(
      widget.set.uuid,
      weightGrams: _enteredGrams,
      reps: _enteredReps,
    );
    await HarvestHaptics.thud();
    widget.onTicked();

    final beaten = recordsBeatenBy(
      widget.set.copyWith(
        weightGrams: _enteredGrams,
        reps: _enteredReps,
        done: true,
      ),
      before,
    );
    if (beaten.isEmpty || !mounted) return;

    // A record is the moment the feature exists for, so it borrows the
    // Field's check-in burst — from the tick, where the thumb is — and
    // the words stay up long enough to be read between sets
    // ([[Checkpoint-7]]).
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final box = _tick.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      showCheckInBurst(
        context,
        box.localToGlobal(box.size.center(Offset.zero)),
        icon: Icons.emoji_events_rounded,
        color: scheme.tertiary,
        particles: 12,
      );
    }
    unawaited(HarvestHaptics.thud());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: scheme.secondary,
          duration: const Duration(seconds: 6),
          content: Text(
            beaten.contains(RecordKind.heaviest)
                ? l10n.gymRecordHeaviest(
                    formatLoad(context, _enteredGrams, widget.unit),
                  )
                : l10n.gymRecordEstimated(
                    formatLoad(
                      context,
                      estimatedOneRepMax(
                            weightGrams: _enteredGrams,
                            reps: _enteredReps,
                          ) ??
                          _enteredGrams,
                      widget.unit,
                    ),
                  ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final set = widget.set;
    final done = set.done;
    final grams = _enteredGrams;
    final plates = grams > 0 && widget.onPlates != null
        ? () => widget.onPlates!(grams)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // A set I added by mistake, or one the program asked for and
          // my shoulder did not: held down, it offers to go
          // ([[Audit-v2]] P3-03). A long press, because a workout is
          // tapped at speed and nothing here should be one slip from
          // deleting a row.
          GestureDetector(
            onLongPress: () => unawaited(_drop(context)),
            child: SizedBox(
              width: 30,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: set.openEnded
                    ? scheme.secondary
                    : Colors.transparent,
                child: Text(
                  // The open set is the one that decides whether the
                  // weight goes up, so it gets a badge, not a number —
                  // and the badge says what the set asks ([[Checkpoint-7]]).
                  set.openEnded ? '1+' : '${set.position + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: set.openEnded ? 10 : null,
                    fontWeight: FontWeight.w800,
                    color: set.openEnded
                        ? scheme.onSecondary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              // Tapping the target opens the plates for it: the number
              // on the left is exactly the number I have to load.
              onTap: plates,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      set.targetLabel == null
                          ? '—'
                          : _prettyTarget(
                              context,
                              set.targetLabel!,
                              widget.unit,
                            ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // ...and says so: a label that happened to be a button
                  // was a calculator nobody found ([[Gym]] Y9).
                  if (plates != null)
                    IconButton(
                      tooltip: l10n.gymPlates,
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      color: scheme.secondary,
                      icon: const Icon(Icons.calculate_outlined),
                      onPressed: plates,
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: _Field(
              controller: _weight,
              enabled: !done,
              onChanged: (value) => _lastWeight = value,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 52,
            child: _Field(
              controller: _reps,
              enabled: !done,
              onChanged: (value) => _lastReps = value,
              hint: set.openEnded ? '1+' : null,
            ),
          ),
          SizedBox(
            width: HarvestSpacing.tap,
            child: IconButton(
              key: _tick,
              tooltip: done ? l10n.gymUntick : l10n.gymTick,
              onPressed: () => unawaited(_toggle()),
              icon: Icon(
                done ? Icons.check_circle : Icons.check_circle_outline,
                color: done ? scheme.secondary : scheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Drops this set, after asking.
  Future<void> _drop(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(sessionsRepositoryProvider);
    unawaited(HarvestHaptics.tick());
    final sure = await confirm(
      context,
      title: l10n.gymDropSet,
      body: l10n.gymDropSetBody,
      confirmLabel: l10n.gymDropSet,
      destructive: true,
    );
    if (!sure) return;
    await repository.removeSet(widget.set.uuid);
    messenger.showSnackBar(SnackBar(content: Text(l10n.gymSetDropped)));
  }

  /// `83.25×5` from the stored label, in whatever unit is on screen —
  /// and without the `.00` the label is stored with, which is a
  /// spreadsheet's idea of a weight. Read back in the unit on screen,
  /// so 135 lb stored as `61.23` shows as 135 ([[Gym]] rule Y8).
  static String _prettyTarget(
    BuildContext context,
    String label,
    WeightUnit unit,
  ) {
    final grams = storedLabelGrams(label, unit);
    if (grams == null) return label;
    // The load without its unit: `83.25×5` reads as one thing, and the
    // unit is already on the row above it.
    final load = formatNumber(
      context,
      unit.from(shownGrams(grams, unit)),
      decimals: 2,
    );
    return '$load×${label.split('×').last}';
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    this.hint,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,+]'))],
      textAlign: TextAlign.center,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        filled: true,
        fillColor: enabled
            ? scheme.surfaceContainerHighest
            : scheme.secondary.withValues(alpha: 0.12),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: HarvestSpacing.xs,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HarvestRadii.chip),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
