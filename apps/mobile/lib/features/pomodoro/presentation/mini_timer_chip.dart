import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/pomodoro/domain/pomodoro_service.dart';
import 'package:harvest/features/pomodoro/presentation/pomodoro_clock.dart';
import 'package:harvest/features/pomodoro/presentation/pomodoro_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Small live countdown shown in the field app bar while a session is
/// active — proof the timer is still ticking (checkpoint gap G1).
class MiniTimerChip extends ConsumerWidget {
  const MiniTimerChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final snapshot = ref.watch(pomodoroControllerProvider).value;
    final theme = Theme.of(context);

    if (snapshot == null) {
      return IconButton(
        tooltip: l10n.focusTimer,
        icon: const Icon(Icons.timer_outlined),
        onPressed: () => unawaited(context.push(AppRoutes.pomodoro)),
      );
    }
    if (snapshot.isRunning) {
      // Ticking rebuilds this chip alone; the controller advances once.
      ref
        ..watch(pomodoroClockProvider)
        ..listen(pomodoroClockProvider, (_, _) {
          unawaited(ref.read(pomodoroControllerProvider.notifier).evaluate());
        });
    }

    final remaining = snapshot.remaining(DateTime.now());
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    final minutes = clamped.inMinutes.toString().padLeft(2, '0');
    final seconds = (clamped.inSeconds % 60).toString().padLeft(2, '0');
    final isBreak = snapshot.phase != PomodoroPhase.focus;
    final color = isBreak
        ? theme.colorScheme.secondary
        : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: HarvestSpacing.xs),
      child: ActionChip(
        avatar: Icon(
          snapshot.isRunning ? Icons.timer : Icons.pause,
          size: 16,
          color: color,
        ),
        label: Text(
          '$minutes:$seconds',
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        onPressed: () => unawaited(context.push(AppRoutes.pomodoro)),
      ),
    );
  }
}
