import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/domain/daily_cycle.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'daily_cycle_service.g.dart';

/// Settings keys for the daily cycle.
abstract final class CycleKeys {
  static const bedTime = 'cycle.bedTime';
  static const wakeTime = 'cycle.wakeTime';
}

/// One reminder that would now go off while I am asleep.
typedef SleepClash = ({
  /// `seed` or `debt` — which table the row is in.
  String kind,
  String uuid,
  String title,
  (int, int) at,
  (int, int) movedTo,
});

/// The daily cycle: reading it, changing it, and moving whatever the
/// change would have buried in the middle of the night.
class DailyCycleService {
  DailyCycleService(this._db)
    : _settings = SettingsRepository(_db),
      _commitments = CommitmentsRepository(_db),
      _vault = VaultRepository(_db);

  final HarvestDatabase _db;
  final SettingsRepository _settings;
  final CommitmentsRepository _commitments;
  final VaultRepository _vault;

  Future<DailyCycle> read() async => DailyCycle(
    bedTime:
        await _settings.getTime(CycleKeys.bedTime) ??
        DailyCycle.fallback.bedTime,
    wakeTime:
        await _settings.getTime(CycleKeys.wakeTime) ??
        DailyCycle.fallback.wakeTime,
  );

  Future<void> write(DailyCycle cycle) async {
    await _settings.setTime(
      CycleKeys.bedTime,
      cycle.bedTime.$1,
      cycle.bedTime.$2,
    );
    await _settings.setTime(
      CycleKeys.wakeTime,
      cycle.wakeTime.$1,
      cycle.wakeTime.$2,
    );
  }

  /// Every reminder the new night would swallow, with where it would go
  /// if it were moved.
  ///
  /// "Where it would go" is one rule: a reminder keeps its distance from
  /// waking. Something set for two hours after I get up stays two hours
  /// after I get up, whatever time that now is.
  Future<List<SleepClash>> clashes({
    required DailyCycle from,
    required DailyCycle to,
  }) async {
    final found = <SleepClash>[];

    for (final seed in await _commitments.activeOnce()) {
      final at = SettingsRepository.parseTime(seed.remindAt);
      if (at == null || !to.covers(at)) continue;
      found.add((
        kind: 'seed',
        uuid: seed.uuid,
        title: seed.title,
        at: at,
        movedTo: from.shiftedWith(to, at),
      ));
    }

    final debts = await (_db.select(
      _db.debts,
    )..where((d) => d.settledAt.isNull() & d.deletedAt.isNull())).get();
    for (final debt in debts) {
      final at =
          SettingsRepository.parseTime(debt.remindAt) ?? ReminderDefaults.debt;
      if (!to.covers(at)) continue;
      found.add((
        kind: 'debt',
        uuid: debt.uuid,
        title: debt.person,
        at: at,
        movedTo: from.shiftedWith(to, at),
      ));
    }

    return found;
  }

  /// Moves the reminders in [clashes] to where [clashes] said they
  /// would go, and replans so the change is live tonight rather than
  /// after the next reset.
  Future<void> shift(List<SleepClash> clashes) async {
    for (final clash in clashes) {
      final at = SettingsRepository.formatTime(
        clash.movedTo.$1,
        clash.movedTo.$2,
      );
      if (clash.kind == 'seed') {
        await _commitments.setRemindAt(clash.uuid, at);
      } else {
        await _vault.setDebtRemindAt(clash.uuid, at);
      }
    }
  }
}

@Riverpod(keepAlive: true)
DailyCycleService dailyCycleService(Ref ref) =>
    DailyCycleService(ref.watch(databaseProvider));

/// The cycle as the settings screen sees it, live.
@riverpod
Stream<DailyCycle> dailyCycle(Ref ref) => ref
    .watch(settingsRepositoryProvider)
    .watchAll(const [CycleKeys.bedTime, CycleKeys.wakeTime])
    .map(
      (values) => DailyCycle(
        bedTime:
            SettingsRepository.parseTime(values[CycleKeys.bedTime]) ??
            DailyCycle.fallback.bedTime,
        wakeTime:
            SettingsRepository.parseTime(values[CycleKeys.wakeTime]) ??
            DailyCycle.fallback.wakeTime,
      ),
    );
