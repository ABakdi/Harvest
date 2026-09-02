import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/pomodoro/domain/pomodoro_service.dart';
import 'package:harvest/features/pomodoro/presentation/pomodoro_controller.dart';

/// Small live countdown shown in the field app bar while a session is
/// active — proof the timer is still ticking (checkpoint gap G1).
class MiniTimerChip extends ConsumerStatefulWidget {
  const MiniTimerChip({super.key});

  @override
  ConsumerState<MiniTimerChip> createState() => _MiniTimerChipState();
}

class _MiniTimerChipState extends ConsumerState<MiniTimerChip> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
      unawaited(ref.read(pomodoroControllerProvider.notifier).evaluate());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(pomodoroControllerProvider).value;
    final theme = Theme.of(context);

    if (snapshot == null) {
      return IconButton(
        icon: const Icon(Icons.timer_outlined),
        onPressed: () => unawaited(context.push(AppRoutes.pomodoro)),
      );
    }

    final remaining = snapshot.remaining(DateTime.now());
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    final minutes = clamped.inMinutes.toString().padLeft(2, '0');
    final seconds = (clamped.inSeconds % 60).toString().padLeft(2, '0');
    final isBreak = snapshot.phase != PomodoroPhase.focus;
    final color =
        isBreak ? theme.colorScheme.secondary : theme.colorScheme.primary;

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
