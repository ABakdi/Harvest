import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/health/data/health_repository.dart';
import 'package:harvest/features/health/data/steps_source.dart';
import 'package:harvest/features/health/domain/steps_sync.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/features/widget/data/home_widget_gateway.dart';
import 'package:harvest/features/widget/domain/widget_service.dart';
import 'package:workmanager/workmanager.dart';

/// The 3 AM day-reset background job (business rule #1).
///
/// The background run is an optimization: the same reconciliation is
/// executed lazily on app open, and the logic is idempotent per Harvest
/// Day, so a skipped run never corrupts state. The first run is aimed at
/// the next 3 AM and repeats daily from there.
abstract final class DayResetJob {
  static const taskName = 'harvest.dayReset';

  static Future<void> register({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final nextReset = HarvestDay.of(at).next.startsAt;
    await Workmanager().initialize(_dispatcher);
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(hours: 24),
      initialDelay: nextReset.difference(at),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}

@pragma('vm:entry-point')
void _dispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != DayResetJob.taskName) return true;
    DartPluginRegistrant.ensureInitialized();
    // Runs in a background isolate: open a fresh database connection,
    // judge the completed days, and close it again. A failure is logged
    // and the run is still reported done — the app repeats the same
    // work on open, so retry storms would only cost battery.
    final db = HarvestDatabase();
    try {
      final streaks = StreakService(db);
      await streaks.reconcile();
      await _closeSteps(db);
      await NotificationPlanner(db, NotificationService(), streaks).planToday();
      // A new Harvest Day resets today's count: the widget must not
      // spend the morning showing yesterday's.
      await WidgetService(db, HomeWidgetBridge()).refresh();
    } on Object catch (error) {
      debugPrint('[day reset] failed: ${error.runtimeType}');
    } finally {
      await db.close();
    }
    return true;
  });
}

/// The day that just ended gets its final step count and its goal
/// paid, whether or not the app was opened that evening
/// ([[Checkpoint-8]]). Best effort: a phone with no source, or one
/// that will not be read in the background, is not a failed reset.
Future<void> _closeSteps(HarvestDatabase db) async {
  try {
    final settings = SettingsRepository(db);
    final health = await settings.getString(FeatureKeys.health);
    if (health != 'true') return;
    final goal = int.tryParse(
      await settings.getString(HealthKeys.stepGoal) ?? '',
    );
    final outcome = await StepsSync(
      HealthRepository(db),
      const ChannelStepsSource(),
    ).closeDay(ended: HarvestDay.today().previous, goal: goal ?? 0);
    debugPrint('[day reset] steps: ${outcome.name}');
  } on Object catch (error) {
    debugPrint('[day reset] steps not closed: ${error.runtimeType}');
  }
}
