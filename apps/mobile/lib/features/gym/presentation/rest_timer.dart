import 'dart:async';

import 'package:flutter/material.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/l10n_loader.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/platform/notifications.dart';
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
  RestTimerController({this.alerts});

  /// Where the rest is shown when the screen is not. Null in tests and
  /// anywhere the shade is not wanted.
  final RestAlerts? alerts;

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
        // The phone is in my hand and the bar has already buzzed, so
        // the alarm behind this has nothing left to announce.
        stop();
      } else {
        notifyListeners();
      }
    });
    alerts?.show(_endsAt!).ignore();
    notifyListeners();
  }

  /// Another minute, because sometimes it is that kind of set.
  void extend(int seconds) {
    final endsAt = _endsAt;
    if (endsAt == null) return;
    _seconds += seconds;
    _endsAt = endsAt.add(Duration(seconds: seconds));
    alerts?.show(_endsAt!).ignore();
    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    alerts?.clear().ignore();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    alerts?.clear().ignore();
    super.dispose();
  }
}

/// The rest, outside the app.
///
/// A rest timer that dies with the screen is a rest timer I check by
/// waking the phone, which is exactly what a set break is not for
/// ([[Gym]], [[Audit-v2]] P3-01). The countdown goes in the shade,
/// driven by the system's own chronometer so nothing has to tick, and
/// an alarm rings at zero even with the phone locked in a pocket.
abstract interface class RestAlerts {
  Future<void> show(DateTime until);
  Future<void> clear();
}

/// Reserved notification ids for the two halves of the rest.
abstract final class RestNotifications {
  static const ongoing = 9101;
  static const over = 9102;
}

class NotificationRestAlerts implements RestAlerts {
  const NotificationRestAlerts(this._notifications, this._db);

  final NotificationService _notifications;
  final HarvestDatabase _db;

  @override
  Future<void> show(DateTime until) async {
    final l10n = await localizationsFromSettings(_db);
    await _notifications.showCountdown(
      id: RestNotifications.ongoing,
      channelId: NotificationChannels.pomodoro,
      title: l10n.gymResting,
      until: until,
    );
    await _notifications.cancel(RestNotifications.over);
    await _notifications.schedule(
      id: RestNotifications.over,
      channelId: NotificationChannels.pomodoro,
      title: l10n.gymRestOverTitle,
      body: l10n.gymRestOverBody,
      when: until,
      snoozeLabels: const [],
    );
  }

  @override
  Future<void> clear() async {
    await _notifications.cancel(RestNotifications.ongoing);
    await _notifications.cancel(RestNotifications.over);
  }
}

/// The bar that appears while resting, and nothing at all when not.
class RestTimerBar extends StatelessWidget {
  const RestTimerBar({required this.controller, this.safe = true, super.key});

  final RestTimerController controller;

  /// Whether the bar clears the gesture area itself. False when
  /// something else sits under it and does.
  final bool safe;

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
          bottom: safe,
          child: Padding(
            // The dismiss button is tighter to its edge than the
            // label is to the other, so the sides are start and end
            // rather than left and right ([[Audit-v2]] U3-20).
            padding: const EdgeInsetsDirectional.fromSTEB(
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
