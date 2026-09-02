import 'package:harvest/app/router.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/features/gamification/domain/quest_service.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bootstrap.g.dart';

/// Startup work: the lazy, idempotent day reconciliation that backs up
/// the 3 AM background job (business rule #1).
@Riverpod(keepAlive: true)
Future<void> appBootstrap(Ref ref) async {
  ref.read(notificationServiceProvider).onTap = (payload) {
    final router = ref.read(routerProvider);
    switch (payload) {
      case 'planner':
        router.go(AppRoutes.planner);
      case 'finances':
        router.go(AppRoutes.finances);
      default:
        router.go(AppRoutes.field);
    }
  };
  await ref.read(streakServiceProvider).reconcile();
  await ref.read(questServiceProvider).ensureGenerated(HarvestDay.today());
  await ref.read(notificationPlannerProvider).planToday();
}
