import 'dart:async';

import 'package:flutter/material.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The rest between sets, counted down.
///
/// Starts itself when a set is ticked, because the moment I have any
/// intention of starting a timer is the moment I have just finished a
/// set. It can be dismissed for the session without changing the
/// program: a day where I am in a hurry is not a reason to rewrite what
/// the program asks for.
class RestTimerController extends ChangeNotifier {
  Timer? _ticker;
  DateTime? _endsAt;
  int _seconds = 0;

  bool get running => _endsAt != null;
  int get totalSeconds => _seconds;

  Duration get remaining {
    final endsAt = _endsAt;
    if (endsAt == null) return Duration.zero;
    final left = endsAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  double get fraction =>
      _seconds == 0 ? 0 : 1 - (remaining.inMilliseconds / (_seconds * 1000));

  void start(int seconds) {
    if (seconds <= 0) return;
    _seconds = seconds;
    _endsAt = DateTime.now().add(Duration(seconds: seconds));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (remaining == Duration.zero) {
        HarvestHaptics.thud().ignore();
        stop();
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  /// Another minute, because sometimes it is that kind of set.
  void extend(int seconds) {
    final endsAt = _endsAt;
    if (endsAt == null) return;
    _seconds += seconds;
    _endsAt = endsAt.add(Duration(seconds: seconds));
    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// The bar that appears while resting, and nothing at all when not.
class RestTimerBar extends StatelessWidget {
  const RestTimerBar({required this.controller, super.key});

  final RestTimerController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.running) return const SizedBox.shrink();
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final left = controller.remaining;
      final minutes = left.inMinutes;
      final seconds = left.inSeconds % 60;

      return Material(
        color: scheme.secondaryContainer,
        // The gesture bar sits exactly where the dismiss button does,
        // and a mistap there leaves the workout.
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              HarvestSpacing.md,
              HarvestSpacing.sm,
              HarvestSpacing.sm,
              HarvestSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: scheme.onSecondaryContainer),
                const SizedBox(width: HarvestSpacing.sm),
                Text(
                  '$minutes:${seconds.toString().padLeft(2, '0')}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: HarvestSpacing.md),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: controller.fraction.clamp(0, 1),
                      minHeight: 6,
                      backgroundColor: scheme.onSecondaryContainer.withValues(
                        alpha: 0.2,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => controller.extend(30),
                  child: Text(l10n.gymRestPlus(30)),
                ),
                IconButton(
                  tooltip: l10n.gymRestSkip,
                  icon: const Icon(Icons.close),
                  onPressed: controller.stop,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
