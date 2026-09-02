import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'finances_repository.g.dart';

/// XP for logging the day's expenses (paid once per day).
const expenseLogXp = 10;

class FinancesRepository {
  FinancesRepository(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------- reads

  Stream<List<Expense>> watchDay(HarvestDay day) => (_db.select(_db.expenses)
        ..where((e) => e.harvestDay.equals(day.key) & e.deletedAt.isNull())
        ..orderBy([(e) => OrderingTerm.desc(e.loggedAt)]))
      .watch()
      .map((rows) => rows.map(_toDomain).toList());

  /// Total per day for [day]'s calendar month (keys are day strings).
  Stream<Map<String, int>> watchMonthTotals(HarvestDay day) {
    final prefix = day.key.substring(0, 7);
    final query = _db.select(_db.expenses)
      ..where(
        (e) => e.harvestDay.like('$prefix%') & e.deletedAt.isNull(),
      );
    return query.watch().map((rows) {
      final totals = <String, int>{};
      for (final row in rows) {
        totals.update(
          row.harvestDay,
          (v) => v + row.amountMinor,
          ifAbsent: () => row.amountMinor,
        );
      }
      return totals;
    });
  }

  /// Total per category for [day]'s calendar month.
  Stream<Map<ExpenseCategory, int>> watchMonthByCategory(HarvestDay day) {
    final prefix = day.key.substring(0, 7);
    final query = _db.select(_db.expenses)
      ..where(
        (e) => e.harvestDay.like('$prefix%') & e.deletedAt.isNull(),
      );
    return query.watch().map((rows) {
      final totals = <ExpenseCategory, int>{};
      for (final row in rows) {
        final category = ExpenseCategory.values.byName(row.category);
        totals.update(
          category,
          (v) => v + row.amountMinor,
          ifAbsent: () => row.amountMinor,
        );
      }
      return totals;
    });
  }

  /// Smart repeats: an (amount, category) pair logged on each of the
  /// three days before [day] — and not yet today — becomes a suggestion.
  Future<RepeatSuggestion?> repeatSuggestion(HarvestDay day) async {
    final days = [day.previous, day.previous.previous,
        day.previous.previous.previous];
    final rows = await (_db.select(_db.expenses)
          ..where(
            (e) =>
                e.harvestDay.isIn([day.key, ...days.map((d) => d.key)]) &
                e.deletedAt.isNull(),
          ))
        .get();

    final byDay = <String, Set<(int, String)>>{};
    final notes = <(int, String), String?>{};
    for (final row in rows) {
      final key = (row.amountMinor, row.category);
      byDay.putIfAbsent(row.harvestDay, () => {}).add(key);
      notes[key] = row.note;
    }
    final today = byDay[day.key] ?? const <(int, String)>{};
    for (final key in byDay[days[0].key] ?? const <(int, String)>{}) {
      final onAllThree = days.every(
        (d) => (byDay[d.key] ?? const <(int, String)>{}).contains(key),
      );
      if (onAllThree && !today.contains(key)) {
        return RepeatSuggestion(
          amountMinor: key.$1,
          category: ExpenseCategory.values.byName(key.$2),
          note: notes[key],
        );
      }
    }
    return null;
  }

  // --------------------------------------------------------------- writes

  /// Logs an expense; the first log of a Harvest Day earns XP.
  Future<void> log({
    required int amountMinor,
    required ExpenseCategory category,
    String? note,
    HarvestDay? day,
  }) async {
    final harvestDay = day ?? HarvestDay.today();
    final uuid = _uuid.v4();
    await _db.transaction(() async {
      await _db.into(_db.expenses).insert(
            ExpensesCompanion.insert(
              uuid: uuid,
              amountMinor: amountMinor,
              category: category.name,
              note: Value(note),
              harvestDay: harvestDay.key,
            ),
          );
      await _appendOutbox(uuid, 'insert');

      final reason = 'expenses:${harvestDay.key}';
      final existing = await (_db.select(_db.ledger)
            ..where((l) => l.reason.equals(reason))
            ..limit(1))
          .getSingleOrNull();
      if (existing == null) {
        await _db.into(_db.ledger).insert(
              LedgerCompanion.insert(
                uuid: _uuid.v4(),
                kind: 'xp',
                delta: expenseLogXp,
                reason: reason,
                harvestDay: harvestDay.key,
              ),
            );
      }
    });
  }

  /// Same-day correction: soft-deletes the entry (history stays truthful).
  Future<void> remove(String uuid) => _db.transaction(() async {
        await (_db.update(_db.expenses)..where((e) => e.uuid.equals(uuid)))
            .write(
          ExpensesCompanion(
            deletedAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _appendOutbox(uuid, 'delete');
      });

  Future<void> _appendOutbox(String uuid, String op) =>
      _db.into(_db.outbox).insert(
            OutboxCompanion.insert(
              targetTable: 'expenses',
              rowUuid: uuid,
              op: op,
            ),
          );

  Expense _toDomain(ExpenseRow row) => Expense(
        uuid: row.uuid,
        amountMinor: row.amountMinor,
        category: ExpenseCategory.values.byName(row.category),
        day: HarvestDay.parse(row.harvestDay),
        loggedAt: row.loggedAt,
        note: row.note,
      );
}

@Riverpod(keepAlive: true)
FinancesRepository financesRepository(Ref ref) =>
    FinancesRepository(ref.watch(databaseProvider));
