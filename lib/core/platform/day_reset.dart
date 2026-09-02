import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/gamification/domain/quest_service.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:workmanager/workmanager.dart';

/// The 3 AM day-reset background job (business rule #1).
///
/// The background run is an optimization: the same reconciliation is
/// executed lazily on app open, and the logic is idempotent per Harvest
/// Day, so a skipped run never corrupts state.
abstract final class DayResetJob {
  static const taskName = 'harvest.dayReset';

  static Future<void> register() async {
    await Workmanager().initialize(_dispatcher);
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(hours: 6),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}

@pragma('vm:entry-point')
void _dispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Runs in a background isolate: open a fresh database connection,
    // judge the completed days, and close it again.
    final db = HarvestDatabase();
    try {
      await StreakService(db).reconcile();
      await QuestService(db).ensureGenerated(HarvestDay.today());
    } finally {
      await db.close();
    }
    return true;
  });
}
