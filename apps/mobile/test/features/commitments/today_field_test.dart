import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/field_providers.dart';

void main() {
  Commitment todo(String id, HarvestDay dueDay) => Commitment(
    uuid: id,
    type: CommitmentType.todo,
    title: id,
    createdAt: DateTime(2026),
    dueDay: dueDay,
  );

  test('future-planted to-dos stay off today (checkpoint P2)', () async {
    final today = HarvestDay.today();
    final container = ProviderContainer(
      overrides: [
        activeCommitmentsProvider.overrideWith(
          (ref) => Stream.value([
            todo('today', today),
            todo('overdue', today.previous),
            todo('tomorrow', today.next),
            todo('nextWeek', today.next.next.next),
          ]),
        ),
        loggedTodayProvider.overrideWith((ref) => Stream.value(const {})),
        lifetimeTotalsProvider.overrideWith((ref) => Stream.value(const {})),
        doneDaysThisWeekProvider.overrideWith((ref) => Stream.value(const {})),
      ],
    );
    addTearDown(container.dispose);

    // Hold subscriptions so the auto-dispose providers stay alive,
    // then let the stream overrides emit.
    final sub = container.listen(todayFieldProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(activeCommitmentsProvider.future);
    await container.read(loggedTodayProvider.future);
    await container.read(lifetimeTotalsProvider.future);
    await container.read(doneDaysThisWeekProvider.future);

    final items = container.read(todayFieldProvider);
    final ids = items.map((item) => item.commitment.uuid).toSet();
    expect(ids, {'today', 'overdue'});
  });
}
