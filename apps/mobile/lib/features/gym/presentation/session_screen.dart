import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/core/ui/widgets/text_prompt.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
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

  @override
  void dispose() {
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
        ],
      ),
      // The three things I touch mid-session — the rest, the clock and
      // Finish — in the one place a thumb is between sets: the bottom.
      // Finish is the most consequential button on the screen and had
      // sat beside an overflow menu at the top ([[Checkpoint-7]]).
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RestTimerBar(controller: _rest, safe: false),
          _SessionBar(
            session: session,
            onPause: () => unawaited(_togglePause(session)),
            onFinish: () => unawaited(_finish(session)),
          ),
        ],
      ),
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
    // The album is looked up while `ref` still works: the picture is
    // offered after this screen has gone.
    final album = outcome.albumUuid == null
        ? null
        : await ref
              .read(galleryRepositoryProvider)
              .albumOnce(
                outcome.albumUuid!,
              );
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
    if (album != null) {
      unawaited(_offerPicture(navigator, album));
    }
  }

  /// The picture, asked for once, on the way out.
  ///
  /// Offered rather than demanded, and never in the middle of a set:
  /// the whole reason the preference exists is that a prompt at the
  /// wrong moment gets dismissed forever.
  ///
  /// Asked from the navigator's own context, which outlives this
  /// route: by the time I answer, the session screen is gone, and a
  /// sheet opened from its context would open nowhere ([[Audit-v2]]
  /// U3-03).
  static Future<void> _offerPicture(
    NavigatorState navigator,
    Album album,
  ) async {
    final context = navigator.context;
    final l10n = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l10n.gymPictureNow,
      body: l10n.gymPictureNowBody,
      confirmLabel: l10n.gymPictureYes,
    );
    if (!ok || !navigator.mounted) return;
    await showCaptureSheet(navigator.context, album: album);
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

/// The session's bottom bar: the clock, which is also the pause button,
/// and Finish.
/// The elapsed time, ticking on its own.
///
/// It used to be a timer on the whole screen, so every second rebuilt
/// every exercise card and every set row — during a workout, for a
/// number two centimetres wide ([[Audit-v2]] U3-07). Now the second
/// hand is the only thing that redraws.
class _Clock extends StatefulWidget {
  const _Clock({required this.session, this.style});

  final WorkoutSession session;
  final TextStyle? style;

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.session.elapsed;
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return Text(
      '$minutes:${seconds.toString().padLeft(2, '0')}',
      style: widget.style,
    );
  }
}

class _SessionBar extends StatelessWidget {
  const _SessionBar({
    required this.session,
    required this.onPause,
    required this.onFinish,
  });

  final WorkoutSession session;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paused = session.paused;

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            HarvestSpacing.sm,
            HarvestSpacing.sm,
            HarvestSpacing.md,
            HarvestSpacing.sm,
          ),
          child: Row(
            children: [
              // Tapping the time stops the clock; tapping it again
              // starts it. A queue for the rack or a phone call is not
              // training time ([[Checkpoint-6]]).
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Tooltip(
                    message: paused ? l10n.gymResumeClock : l10n.gymPause,
                    child: Material(
                      color: paused
                          ? scheme.tertiaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onPause,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: HarvestSpacing.sm,
                            vertical: HarvestSpacing.xs,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                paused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded,
                                color: paused
                                    ? scheme.onTertiaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: HarvestSpacing.xs),
                              _Clock(
                                session: session,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  fontWeight: FontWeight.w800,
                                  color: paused
                                      ? scheme.onTertiaryContainer
                                      : scheme.onSurface,
                                ),
                              ),
                              if (paused) ...[
                                const SizedBox(width: HarvestSpacing.sm),
                                Text(
                                  l10n.gymPaused,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onTertiaryContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: Text(l10n.gymFinish),
              ),
            ],
          ),
        ),
      ),
    );
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
                                      '${formatLoad(context, set.weightGrams, unit)}×${set.reps}',
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
                          _recordsLine(context, l10n, records!, unit),
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
    BuildContext context,
    AppLocalizations l10n,
    ExerciseRecords records,
    WeightUnit unit,
  ) {
    final heaviest = records.heaviest!;
    final parts = [
      '${formatLoad(context, heaviest.weightGrams, unit)}×${heaviest.reps}',
      // Rounded like a load (rule Y8): an estimate to two decimals is
      // precision it does not have.
      if (records.bestSetEstimate != null)
        l10n.gymBestEstimate(
          formatLoad(context, roundLoad(records.bestSetEstimate!), unit),
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
              unitLabel(context, unit),
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
