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
    // Phase 1 wires the real reset here: streak evaluation, freeze
    // consumption, quest generation, notification scheduling.
    return true;
  });
}
