import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/features/pomodoro/domain/pomodoro_service.dart';
import 'package:harvest/features/pomodoro/presentation/pomodoro_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({this.commitment, super.key});

  /// The crop this session waters; null for a free session.
  final Commitment? commitment;

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(ref.read(pomodoroControllerProvider.notifier).evaluate());
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final snapshot = ref.watch(pomodoroControllerProvider).value;
    final controller = ref.read(pomodoroControllerProvider.notifier);
    const config = PomodoroController.config;

    final phase = snapshot?.phase ?? PomodoroPhase.focus;
    final total = config.of(phase);
    final remaining = snapshot == null
        ? total
        : _clampDuration(snapshot.remaining(DateTime.now()), total);
    final isBreak = phase != PomodoroPhase.focus;
    final waitingNextFocus = snapshot != null &&
        !snapshot.isRunning &&
        !isBreak &&
        !snapshot.userPaused;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pomodoroTitle),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(HarvestSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.commitment?.title ?? l10n.freeSession,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HarvestSpacing.lg),
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: total.inSeconds == 0
                            ? 0
                            : remaining.inSeconds / total.inSeconds,
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                        backgroundColor:
                            theme.colorScheme.onSurface.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(
                          isBreak
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _format(remaining),
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          waitingNextFocus
                              ? l10n.breakOverReady
                              : switch (phase) {
                                  PomodoroPhase.focus => l10n.phaseFocus,
                                  PomodoroPhase.shortBreak =>
                                    l10n.phaseShortBreak,
                                  PomodoroPhase.longBreak =>
                                    l10n.phaseLongBreak,
                                },
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: HarvestSpacing.md),
              _BlockDots(
                done: snapshot?.blocksDone ?? 0,
                perLong: config.blocksPerLongBreak,
              ),
              const SizedBox(height: HarvestSpacing.xl),
              ..._buttons(context, l10n, snapshot, controller),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buttons(
    BuildContext context,
    AppLocalizations l10n,
    PomodoroSnapshot? snapshot,
    PomodoroController controller,
  ) {
    if (snapshot == null) {
      return [
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          onPressed: () => unawaited(
            controller.start(commitmentUuid: widget.commitment?.uuid),
          ),
          label: Text(l10n.startFocus),
        ),
      ];
    }

    final buttons = <Widget>[];
    if (snapshot.isRunning) {
      buttons.add(
        FilledButton.tonalIcon(
          icon: const Icon(Icons.pause),
          onPressed: () => unawaited(controller.pause()),
          label: Text(l10n.pause),
        ),
      );
    } else {
      buttons.add(
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          onPressed: () => unawaited(controller.resume()),
          label: Text(snapshot.blocksDone > 0 && !snapshot.isRunning
              ? l10n.startFocus
              : l10n.resume),
        ),
      );
    }
    buttons
      ..add(const SizedBox(height: HarvestSpacing.sm))
      ..add(
        TextButton(
          onPressed: () => unawaited(_finish(context)),
          child: Text(
            snapshot.blocksDone > 0 ? l10n.finishSession : l10n.abandonSession,
          ),
        ),
      );
    if (snapshot.blocksDone == 0) {
      buttons.add(
        Text(
          l10n.abandonBody,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return buttons;
  }

  Future<void> _finish(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final controller = ref.read(pomodoroControllerProvider.notifier);
    final commitmentUuid = await controller.finish();

    // A fruitful session attached to a habit/to-do checks it in directly;
    // projects get a nudge to log their quantity on the field.
    final commitment = widget.commitment;
    if (commitmentUuid != null && commitment != null) {
      if (commitment.type == CommitmentType.project) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.pomodoroLogPrompt)),
        );
      } else {
        final result = await ref
            .read(checkInControllerProvider.notifier)
            .checkIn(commitment);
        if (result is CheckInSuccess) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.xpEarned(result.xpEarned))),
          );
        }
      }
    }
    router.pop();
  }

  Duration _clampDuration(Duration value, Duration max) {
    if (value.isNegative) return Duration.zero;
    return value > max ? max : value;
  }

  String _format(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _BlockDots extends StatelessWidget {
  const _BlockDots({required this.done, required this.perLong});

  final int done;
  final int perLong;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inCycle = done % perLong;
    final filled = inCycle == 0 && done > 0 ? perLong : inCycle;

    return Semantics(
      label: AppLocalizations.of(context).blocksDone(done),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < perLong; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.circle,
                size: 12,
                color: i < filled
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.15),
              ),
            ),
        ],
      ),
    );
  }
}
