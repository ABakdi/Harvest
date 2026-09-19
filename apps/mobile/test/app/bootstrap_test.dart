import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/app/bootstrap.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';

/// Startup must never be hostage to the platform. In a test there is no
/// notification plugin at all, which is the same shape as a wedged one.
void main() {
  late HarvestDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('finishes even though the notification layer answers nothing', () async {
    await container
        .read(appBootstrapProvider.future)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => fail('startup waited on the platform'),
        );
  });

  test('judges the day before it returns', () async {
    // Nothing has been judged yet; after startup the marker is set, so a
    // check-in cannot land against an unjudged day.
    expect(await StreakService(db).currentGlobal(), 0);
    await container.read(appBootstrapProvider.future);

    final marker =
        await (db.select(db.kvSettings)
              ..where((s) => s.key.equals(StreakService.lastJudgedKey)))
            .getSingleOrNull();
    expect(marker, isNotNull, reason: 'reconcile ran and recorded its day');
  });

  test('a failed step is reported rather than swallowed', () async {
    await container.read(appBootstrapProvider.future);
    // The reminder and launch-route steps need a platform that is not
    // there; startup records that instead of failing or hanging.
    expect(container.read(bootstrapStatusProvider), isNotNull);
  });

  test('reminder routes map to app routes, unknown ones go home', () {
    expect(routeFor(ReminderRoutes.planner), '/field/planner');
    expect(routeFor(ReminderRoutes.finances), '/finances');
    expect(routeFor(ReminderRoutes.field), '/field');
    expect(routeFor('something else'), '/field');
  });
}
