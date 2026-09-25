import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/commitments/presentation/field_providers.dart';
import 'package:harvest/features/planner/presentation/planner_screen.dart';

class _FixedDay extends CurrentHarvestDay {
  _FixedDay(this.day);

  final HarvestDay day;

  @override
  HarvestDay build() => day;
}

void main() {
  final flexible = Commitment(
    uuid: 'gym',
    type: CommitmentType.habit,
    title: 'Gym',
    createdAt: DateTime(2026),
    schedule: const TimesPerWeekSchedule(times: 3),
  );

  Future<List<String>> tomorrowHabits(HarvestDay today, int doneThisWeek) async {
    final container = ProviderContainer(
      overrides: [
        currentHarvestDayProvider.overrideWith(() => _FixedDay(today)),
        activeCommitmentsProvider.overrideWith(
          (ref) => Stream.value([flexible]),
        ),
        lifetimeTotalsProvider.overrideWith((ref) => Stream.value(const {})),
        doneDaysThisWeekProvider.overrideWith(
          (ref) => Stream.value({'gym': doneThisWeek}),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(tomorrowPlanProvider, (_, _) {});
    addTearDown(sub.close);
    final week = container.listen(doneDaysThisWeekProvider, (_, _) {});
    addTearDown(week.close);
    await container.read(activeCommitmentsProvider.future);
    await container.read(lifetimeTotalsProvider.future);
    await container.read(doneDaysThisWeekProvider.future);
    return [
      for (final habit in container.read(tomorrowPlanProvider).habits)
        habit.uuid,
    ];
  }

  // 2026-09-23 is a Wednesday; 2026-09-27 a Sunday.
  final wednesday = HarvestDay.fromDate(DateTime(2026, 9, 23));
  final sunday = HarvestDay.fromDate(DateTime(2026, 9, 27));

  test('a flexible habit with its week done is not planned for tomorrow', () async {
    expect(await tomorrowHabits(wednesday, 3), isEmpty);
    expect(await tomorrowHabits(wednesday, 1), ['gym']);
  });

  test('a new week starts the count again', () async {
    expect(await tomorrowHabits(sunday, 3), ['gym']);
  });
}
