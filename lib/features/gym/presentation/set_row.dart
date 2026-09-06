import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
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
  final void Function(int grams) onPlates;

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

  String _weightText() => widget.set.weightGrams == 0
      ? ''
      : widget.unit
            .from(widget.set.weightGrams)
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');

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
    return value == null ? 0 : roundLoad(widget.unit.toGrams(value));
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

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.secondary,
          content: Text(
            beaten.contains(RecordKind.heaviest)
                ? l10n.gymRecordHeaviest(
                    formatLoad(_enteredGrams, widget.unit),
                  )
                : l10n.gymRecordEstimated(
                    formatLoad(
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: set.openEnded
                  ? scheme.secondary
                  : Colors.transparent,
              child: Text(
                // The open set is the one that decides whether the
                // weight goes up, so it gets a letter, not a number.
                set.openEnded ? 'P' : '${set.position + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: set.openEnded
                      ? scheme.onSecondary
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              // Tapping the target opens the plates for it: the number
              // on the left is exactly the number I have to load.
              onTap: _enteredGrams > 0
                  ? () => widget.onPlates(_enteredGrams)
                  : null,
              child: Text(
                set.targetLabel == null
                    ? '—'
                    : _prettyTarget(set.targetLabel!, widget.unit),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
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
            width: 44,
            child: IconButton(
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

  /// `83.25×5` from the stored label, in whatever unit is on screen.
  static String _prettyTarget(String label, WeightUnit unit) {
    if (unit == WeightUnit.kg || !label.contains('×')) return label;
    final parts = label.split('×');
    final kg = double.tryParse(parts.first);
    if (kg == null) return label;
    return '${formatLoad((kg * 1000).round(), unit)}×${parts.last}';
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
