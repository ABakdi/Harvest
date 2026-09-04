import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/core/platform/reminder_actions.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/pomodoro/presentation/pomodoro_controller.dart';
import 'package:harvest/features/widget/domain/widget_actions.dart';
import 'package:harvest/features/widget/domain/widget_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bootstrap.g.dart';

/// Soft-deleted rows are kept this long for undo and future sync, then
/// removed for good.
const purgeAfter = Duration(days: 30);

/// The last startup step that failed, as a short description — shown
/// quietly in Settings so a broken row never fails silently.
@Riverpod(keepAlive: true)
class BootstrapStatus extends _$BootstrapStatus {
  @override
  String? build() => null;

  void report(String step, Object error) {
    debugPrint('[bootstrap] $step failed: ${error.runtimeType}');
    state = '$step: ${error.runtimeType}';
  }
}

/// Startup work: the lazy, idempotent day reconciliation that backs up
/// the 3 AM background job (business rule #1), today's reminders, and
/// housekeeping. Each step is isolated — one bad row must not take the
/// others down.
@Riverpod(keepAlive: true)
Future<void> appBootstrap(Ref ref) async {
  ref.read(notificationServiceProvider).onAction = (actionId) {
    final pomodoro = ref.read(pomodoroControllerProvider.notifier);
    switch (actionId) {
      case PomodoroActions.pause:
        unawaited(pomodoro.pause());
      case PomodoroActions.abandon:
        unawaited(pomodoro.abandon());
    }
  };
  final notifications = ref.read(notificationServiceProvider);
  // Assigned separately (no cascade): the snooze handler refers back to
  // the service itself.
  // ignore: cascade_invocations
  notifications.onTap = (route) => ref.read(routerProvider).go(routeFor(route));
  // A snooze tapped while the app is open; the closed-app case runs in
  // its own isolate (reminderBackgroundHandler).
  notifications.onSnooze = (response) =>
      SnoozeStore(ref.read(databaseProvider)).snooze(response, notifications);

  final status = ref.read(bootstrapStatusProvider.notifier);

  /// Runs one startup step. A failure is recorded, not thrown — and if
  /// the app went away while the step was in flight (hot restart, or
  /// shutdown), the result is dropped rather than written to a
  /// container that no longer exists.
  Future<void> step(String name, Future<void> Function() run) async {
    try {
      await run();
    } on Object catch (error) {
      if (!ref.mounted) return;
      status.report(name, error);
    }
  }

  // Only the day's verdict is awaited: it is local, fast, and a
  // check-in tapped before it lands would count against the wrong day.
  await step('reconcile', ref.read(streakServiceProvider).reconcile);

  // Everything else touches the platform or does housekeeping. It must
  // never hold the first frame hostage — a wedged platform channel
  // would otherwise leave a blank screen forever.
  unawaited(
    step('reminders', ref.read(notificationPlannerProvider).planToday),
  );
  unawaited(step('widget', ref.read(widgetServiceProvider).refresh));
  unawaited(
    step(
      'widget actions',
      ref.read(pendingWidgetActionProvider.notifier).listen,
    ),
  );
  unawaited(
    step('purge', () async {
      await ref
          .read(commitmentsRepositoryProvider)
          .purgeDeleted(olderThan: purgeAfter);
      await ref
          .read(financesRepositoryProvider)
          .purgeDeleted(olderThan: purgeAfter);
      await ref
          .read(vaultRepositoryProvider)
          .purgeDeleted(olderThan: purgeAfter);
    }),
  );
  unawaited(
    step('launch route', () async {
      // Launched by tapping a reminder while closed: land where it points.
      final launchRoute = await notifications.launchRoute();
      if (launchRoute != null) {
        ref.read(routerProvider).go(routeFor(launchRoute));
      }
    }),
  );
}

/// The app route behind a reminder route; anything unknown goes home.
String routeFor(String route) => switch (route) {
  ReminderRoutes.planner => AppRoutes.planner,
  ReminderRoutes.finances => AppRoutes.finances,
  _ => AppRoutes.field,
};
