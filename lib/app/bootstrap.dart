import 'dart:async';

import 'package:harvest/app/router.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/core/platform/reminder_actions.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/pomodoro/presentation/pomodoro_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bootstrap.g.dart';

/// Startup work: the lazy, idempotent day reconciliation that backs up
/// the 3 AM background job (business rule #1).
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
  notifications.onTap = (route) =>
      ref.read(routerProvider).go(_routeFor(route));
  // A snooze tapped while the app is open; the closed-app case runs in
  // its own isolate (reminderBackgroundHandler).
  notifications.onSnooze = (response) =>
      SnoozeStore(ref.read(databaseProvider)).snooze(response, notifications);
  await ref.read(streakServiceProvider).reconcile();
  await ref.read(notificationPlannerProvider).planToday();

  // Launched by tapping a reminder while closed: land where it points.
  final launchRoute = await notifications.launchRoute();
  if (launchRoute != null) ref.read(routerProvider).go(_routeFor(launchRoute));
}

String _routeFor(String route) => switch (route) {
  'planner' => AppRoutes.planner,
  'finances' => AppRoutes.finances,
  _ => AppRoutes.field,
};
