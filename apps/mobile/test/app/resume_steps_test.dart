import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/health/data/steps_source.dart';
import 'package:harvest/features/health/domain/steps_sync.dart';
import 'package:harvest/features/health/presentation/health_providers.dart';

class _NoSteps implements StepsSource {
  @override
  Future<StepsStatus> status() async => StepsStatus.unavailable;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<StepsTotals> totals(List<StepsWindow> windows) async =>
      const StepsDenied();

  @override
  Future<int?> counter() async => null;

  @override
  Future<void> openHealthConnect() async {}
}

/// Coming back to the app pulls the steps with nothing on screen
/// listening to the step goal. That pull used to read the goal's own
/// provider, which was disposed while still loading and failed every
/// resume with a StateError.
void main() {
  late HarvestDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        stepsSourceProvider.overrideWithValue(_NoSteps()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('the resume pull does not need the goal to be watched', () async {
    await container.read(stepsPullProvider.future);
    await container.read(stepsPullProvider.notifier).refresh();
    await container.read(stepsPullProvider.notifier).refresh();
    expect(
      container.read(stepsPullProvider).value?.outcome,
      StepsSyncOutcome.unavailable,
    );
  });
}
