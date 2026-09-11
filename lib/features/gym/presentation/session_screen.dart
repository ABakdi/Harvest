import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/core/ui/widgets/text_prompt.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/presentation/capture_sheet.dart';
import 'package:harvest/features/gym/data/exercises_repository.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/domain/session.dart';
import 'package:harvest/features/gym/domain/session_finisher.dart';
import 'package:harvest/features/gym/presentation/exercise_picker.dart';
import 'package:harvest/features/gym/presentation/plate_sheet.dart';
import 'package:harvest/features/gym/presentation/rest_field.dart';
import 'package:harvest/features/gym/presentation/rest_timer.dart';
import 'package:harvest/features/gym/presentation/set_row.dart';
import 'package:harvest/features/gym/presentation/weight_text.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The workout, in progress.
///
/// The only screen in this app designed to be used one-handed,
/// sweating, in a hurry. Everything about it follows from that: the
/// targets are already in the boxes, so a set that went to plan is one
/// tap on the tick; a set that did not is two taps and a number. That
/// ratio is the whole design.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({required this.uuid, super.key});

  final String uuid;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  final _rest = RestTimerController();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // The elapsed time is a clock, not a state change, so it ticks
    // itself rather than waiting on the database.
    _clock = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    _rest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = ref.watch(sessionProvider(widget.uuid)).value;
    final unit = ref.watch(weightUnitSettingProvider).value ?? WeightUnit.kg;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.gymSession)),
        body: Center(child: Text(l10n.gymSessionGone)),
      );
    }

    final elapsed = session.elapsed;

    // Leaving is not discarding: the session keeps running, and the
    // gym offers to resume it. Nothing here needs confirming on the
    // way out, because every set was written the moment it was ticked.
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.title ?? l10n.gymSession,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              l10n.gymSessionProgress(session.doneSets, session.totalSets),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          // The clock is the pause button: tapping the time stops it,
          // tapping it again starts it. A queue for the rack or a phone
          // call is not training time ([[Checkpoint-6]]).
          Center(
            child: Tooltip(
              message: session.paused ? l10n.gymResumeClock : l10n.gymPause,
              child: Material(
                color: session.paused
                    ? scheme.tertiaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => unawaited(_togglePause(session)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HarvestSpacing.sm,
                      vertical: HarvestSpacing.xs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          session.paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          size: 20,
                          color: session.paused
                              ? scheme.onTertiaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _clockLabel(elapsed),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                            fontWeight: session.paused ? FontWeight.w800 : null,
                            color: session.paused
                                ? scheme.onTertiaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => switch (value) {
              'note' => unawaited(_sessionNote(session)),
              'add' => unawaited(_addExercise(session)),
              _ => unawaited(_discard(session)),
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'note', child: Text(l10n.gymSessionNote)),
              PopupMenuItem(value: 'add', child: Text(l10n.gymAddExercise)),
              PopupMenuItem(
                value: 'discard',
                child: Text(l10n.gymDiscardSession),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: HarvestSpacing.sm),
            child: FilledButton(
              onPressed: () => unawaited(_finish(session)),
              child: Text(l10n.gymFinish),
            ),
          ),
        ],
      ),
      bottomNavigationBar: RestTimerBar(controller: _rest),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.sm,
          HarvestSpacing.sm,
          HarvestSpacing.sm,
          HarvestSpacing.xl,
        ),
        children: [
          if ((session.note ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HarvestSpacing.sm,
                0,
                HarvestSpacing.sm,
                HarvestSpacing.sm,
              ),
              child: Text(
                session.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final (index, exercise) in session.exercises.indexed)
            _ExerciseCard(
              key: ValueKey(exercise.uuid),
              exercise: exercise,
              number: index + 1,
              unit: unit,
              rest: _rest,
            ),
        ],
      ),
    );
  }

  static String _clockLabel(Duration elapsed) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _togglePause(WorkoutSession session) async {
    final repository = ref.read(sessionsRepositoryProvider);
    await HarvestHaptics.tick();
    if (session.paused) {
      await repository.resume(session.uuid);
    } else {
      await repository.pause(session.uuid);
    }
  }

  Future<void> _sessionNote(WorkoutSession session) async {
    final l10n = AppLocalizations.of(context);
    final note = await promptForText(
      context,
      title: l10n.gymSessionNote,
      initial: session.note ?? '',
      hint: l10n.gymSessionNoteHint,
    );
    if (note == null) return;
    await ref
        .read(sessionsRepositoryProvider)
        .setSessionNote(session.uuid, note.trim().isEmpty ? null : note.trim());
  }

  Future<void> _addExercise(WorkoutSession session) async {
    final exercise = await pickExercise(context);
    if (exercise == null) return;
    await ref
        .read(sessionsRepositoryProvider)
        .addExercise(session.uuid, exerciseId: exercise.id);
  }

  Future<void> _finish(WorkoutSession session) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    // Sets on exercises I skipped were never going to happen; the
    // rest are the ones worth a question.
    final planned = session.exercises
        .where((exercise) => !exercise.skipped)
        .fold(0, (sum, exercise) => sum + exercise.sets.length);
    final left = planned - session.doneSets;
    if (session.doneSets == 0) {
      final ok = await confirm(
        context,
        title: l10n.gymFinishEmptyTitle,
        body: l10n.gymFinishEmptyBody,
        confirmLabel: l10n.gymFinish,
      );
      if (!ok) return;
    } else if (left > 0) {
      // Finishing is what checks the habit in, so leaving sets behind
      // is a choice to make with the eyes open ([[Checkpoint-6]]).
      final ok = await confirm(
        context,
        title: l10n.gymFinishIncompleteTitle,
        body: l10n.gymFinishIncompleteBody(left, planned),
        confirmLabel: l10n.gymFinish,
      );
      if (!ok) return;
    }
    // Finishing is the only thing that checks the habit in: starting
    // is an intention and abandoning is a Tuesday ([[Gym]] rule Y4).
    final outcome = await ref.read(sessionFinisherProvider).finish(session);
    await HarvestHaptics.thud();
    navigator.pop();

    if (!mounted) return;
    if (outcome.xpEarned > 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.gymCheckedIn(outcome.xpEarned))),
        );
    }
    if (outcome.albumUuid != null) {
      await _offerPicture(outcome.albumUuid!);
    }
  }

  /// The picture, asked for once, on the way out.
  ///
  /// Offered rather than demanded, and never in the middle of a set:
  /// the whole reason the preference exists is that a prompt at the
  /// wrong moment gets dismissed forever.
  Future<void> _offerPicture(String albumUuid) async {
    final l10n = AppLocalizations.of(context);
    final album = await ref
        .read(galleryRepositoryProvider)
        .albumOnce(
          albumUuid,
        );
    if (album == null || !mounted) return;

    final ok = await confirm(
      context,
      title: l10n.gymPictureNow,
      body: l10n.gymPictureNowBody,
      confirmLabel: l10n.gymPictureYes,
    );
    if (!ok || !mounted) return;
    await showCaptureSheet(context, album: album);
  }

  Future<void> _discard(WorkoutSession session) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final ok = await confirm(
      context,
      title: l10n.gymDiscardSession,
      body: l10n.gymDiscardBody(session.doneSets),
      confirmLabel: l10n.gymDiscardSession,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(sessionsRepositoryProvider).discard(session.uuid);
    navigator.pop();
  }
}

/// One exercise and its sets.
class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.number,
    required this.unit,
    required this.rest,
    super.key,
  });

  final SessionExercise exercise;
  final int number;
  final WeightUnit unit;
  final RestTimerController rest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final named = ref.watch(exerciseByIdProvider(exercise.exerciseId)).value;
    final planned = exercise.replaced
        ? ref.watch(exerciseByIdProvider(exercise.plannedExerciseId!)).value
        : null;
    final last = ref.watch(lastTimeProvider(exercise.exerciseId)).value;
    final records = ref
        .watch(exerciseRecordsProvider(exercise.exerciseId))
        .value;
    final usesBar = named?.usesBar ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$number',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: HarvestSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        named?.name ?? l10n.gymUnknownExercise,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: exercise.skipped
                              ? scheme.onSurfaceVariant
                              : scheme.secondary,
                          decoration: exercise.skipped
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // History has to be able to say what the day was
                      // meant to be (rule Y7).
                      if (planned != null)
                        Text(
                          l10n.gymInsteadOf(planned.name),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      // The only number that matters while deciding
                      // what to put on the bar.
                      if (last != null && last.isNotEmpty)
                        Text(
                          l10n.gymLastTime(
                            last
                                .map(
                                  (set) =>
                                      '${formatLoad(set.weightGrams, unit)}×${set.reps}',
                                )
                                .join('  '),
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      // The record to beat, in the place the decision
                      // is made — announcing a PR after the set is
                      // only half the loop ([[Checkpoint-6]]).
                      if (records?.heaviest != null)
                        Text(
                          _recordsLine(l10n, records!, unit),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Always offered, even when the program says nothing
                // about rest: wanting a timer is a fact about the set
                // I just did, not about how the program was written.
                IconButton(
                  tooltip: l10n.gymRest,
                  icon: const Icon(Icons.timer_outlined),
                  onPressed: () =>
                      rest.start(exercise.restSeconds ?? defaultRestSeconds),
                  onLongPress: () => unawaited(_setRest(context, ref)),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => switch (value) {
                    'swap' => unawaited(_swap(context, ref)),
                    'skip' => unawaited(
                      ref
                          .read(sessionsRepositoryProvider)
                          .skipExercise(
                            exercise.uuid,
                            skipped: !exercise.skipped,
                          ),
                    ),
                    'rest' => unawaited(_setRest(context, ref)),
                    'note' => unawaited(_note(context, ref)),
                    _ => unawaited(
                      ref
                          .read(sessionsRepositoryProvider)
                          .addSet(exercise.uuid),
                    ),
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'set', child: Text(l10n.gymAddSet)),
                    PopupMenuItem(value: 'swap', child: Text(l10n.gymSwap)),
                    PopupMenuItem(
                      value: 'skip',
                      child: Text(
                        exercise.skipped ? l10n.gymUnskip : l10n.gymSkip,
                      ),
                    ),
                    PopupMenuItem(value: 'rest', child: Text(l10n.gymRest)),
                    PopupMenuItem(value: 'note', child: Text(l10n.gymNote)),
                  ],
                ),
              ],
            ),
            if ((exercise.note ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  exercise.note!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (!exercise.skipped) ...[
              const Divider(height: HarvestSpacing.md),
              _SetHeader(unit: unit),
              for (final set in exercise.sets)
                SetRow(
                  key: ValueKey(set.uuid),
                  set: set,
                  exercise: exercise,
                  unit: unit,
                  onTicked: () =>
                      rest.start(exercise.restSeconds ?? defaultRestSeconds),
                  onPlates: usesBar
                      ? (grams) => unawaited(
                          showPlates(
                            context,
                            targetGrams: grams,
                            barGrams: exercise.barGrams,
                          ),
                        )
                      : null,
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => unawaited(
                    ref.read(sessionsRepositoryProvider).addSet(exercise.uuid),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.gymAddSet),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// `Best: 100 kg×5 · est. 116 kg` — the heaviest set and the best
  /// estimated single, the estimate labelled as one (rule Y6).
  static String _recordsLine(
    AppLocalizations l10n,
    ExerciseRecords records,
    WeightUnit unit,
  ) {
    final heaviest = records.heaviest!;
    final parts = [
      '${formatLoad(heaviest.weightGrams, unit)}×${heaviest.reps}',
      // Rounded like a load (rule Y8): an estimate to two decimals is
      // precision it does not have.
      if (records.bestSetEstimate != null)
        l10n.gymBestEstimate(
          formatLoad(roundLoad(records.bestSetEstimate!), unit),
        ),
    ];
    return l10n.gymBestLine(parts.join(' · '));
  }

  Future<void> _swap(BuildContext context, WidgetRef ref) async {
    final replacement = await pickExercise(context);
    if (replacement == null) return;
    await ref
        .read(sessionsRepositoryProvider)
        .replaceExercise(exercise.uuid, exerciseId: replacement.id);
  }

  /// The rest for this exercise, for today.
  Future<void> _setRest(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final current = exercise.restSeconds ?? defaultRestSeconds;
    final chosen = await showHarvestSheet<int>(
      context,
      builder: (sheetContext) => HarvestSheet(
        title: l10n.gymRest,
        children: [
          RestField(
            seconds: current,
            onChanged: (seconds) => Navigator.of(sheetContext).pop(seconds),
          ),
          const SizedBox(height: HarvestSpacing.sm),
        ],
      ),
    );
    if (chosen == null) return;
    await ref
        .read(sessionsRepositoryProvider)
        .setExerciseRest(exercise.uuid, chosen);
  }

  Future<void> _note(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final note = await promptForText(
      context,
      title: l10n.gymNote,
      initial: exercise.note ?? '',
    );
    if (note == null) return;
    await ref
        .read(sessionsRepositoryProvider)
        .setExerciseNote(
          exercise.uuid,
          note.trim().isEmpty ? null : note.trim(),
        );
  }
}

class _SetHeader extends StatelessWidget {
  const _SetHeader({required this.unit});

  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              l10n.gymSetColumn,
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(child: Text(l10n.gymTargetColumn, style: style)),
          // Centred, because the boxes underneath are: a heading that
          // does not sit over its column is worse than no heading.
          SizedBox(
            width: 72,
            child: Text(
              unit.suffix,
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 52,
            child: Text(
              l10n.gymRepsColumn,
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}
