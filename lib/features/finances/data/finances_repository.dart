import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
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

  Stream<List<Expense>> watchDay(HarvestDay day) =>
      (_db.select(_db.expenses)
            ..where((e) => e.harvestDay.equals(day.key) & e.deletedAt.isNull())
            ..orderBy([(e) => OrderingTerm.desc(e.loggedAt)]))
          .watch()
          .map((rows) => rows.map(_toDomain).toList());

  /// Every expense in [day]'s calendar month.
  Stream<List<Expense>> watchMonth(HarvestDay day) {
    final prefix = day.key.substring(0, 7);
    final query = _db.select(_db.expenses)
      ..where(
        (e) => e.harvestDay.like('$prefix%') & e.deletedAt.isNull(),
      );
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Every expense in [weekStart]'s week.
  Stream<List<Expense>> watchWeek(HarvestDay weekStart) {
    final days = <String>[];
    var d = weekStart;
    for (var i = 0; i < 7; i++) {
      days.add(d.key);
      d = d.next;
    }
    final query = _db.select(_db.expenses)
      ..where((e) => e.harvestDay.isIn(days) & e.deletedAt.isNull());
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Every expense in a span, both ends included.
  Stream<List<Expense>> watchRange(HarvestDay from, HarvestDay to) {
    final query = _db.select(_db.expenses)
      ..where(
        (e) =>
            e.harvestDay.isBiggerOrEqualValue(from.key) &
            e.harvestDay.isSmallerOrEqualValue(to.key) &
            e.deletedAt.isNull(),
      );
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// User-created categories, newest last.
  Stream<List<CustomCategory>> watchCategories() =>
      (_db.select(_db.expenseCategories)
            ..where((c) => c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.updatedAt)]))
          .watch()
          .map(
            (rows) => rows
                .map(
                  (row) => CustomCategory(
                    uuid: row.uuid,
                    name: row.name,
                    icon: row.icon,
                  ),
                )
                .toList(),
          );

  Future<void> createCategory({
    required String name,
    required String icon,
  }) async {
    final uuid = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.expenseCategories)
          .insert(
            ExpenseCategoriesCompanion.insert(
              uuid: uuid,
              name: name,
              icon: icon,
            ),
          );
      await _db
          .into(_db.outbox)
          .insert(
            OutboxCompanion.insert(
              targetTable: 'expense_categories',
              rowUuid: uuid,
              op: 'insert',
            ),
          );
    });
  }

  Future<void> deleteCategory(String uuid) => _db.transaction(() async {
    await (_db.update(
      _db.expenseCategories,
    )..where((c) => c.uuid.equals(uuid))).write(
      ExpenseCategoriesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _db
        .into(_db.outbox)
        .insert(
          OutboxCompanion.insert(
            targetTable: 'expense_categories',
            rowUuid: uuid,
            op: 'delete',
          ),
        );
  });

  /// Smart repeats: an (amount, category) pair logged on each of the
  /// three days before [day] — and not yet today — becomes a suggestion.
  Future<RepeatSuggestion?> repeatSuggestion(HarvestDay day) async {
    final days = [
      day.previous,
      day.previous.previous,
      day.previous.previous.previous,
    ];
    final rows =
        await (_db.select(_db.expenses)..where(
              (e) =>
                  e.harvestDay.isIn([day.key, ...days.map((d) => d.key)]) &
                  e.deletedAt.isNull(),
            ))
            .get();

    final byDay = <String, Set<(int, String, String)>>{};
    final notes = <(int, String, String), String?>{};
    for (final row in rows) {
      final key = (row.amountMinor, row.currency, row.category);
      byDay.putIfAbsent(row.harvestDay, () => {}).add(key);
      notes[key] = row.note;
    }
    final today = byDay[day.key] ?? const <(int, String, String)>{};
    for (final key in byDay[days[0].key] ?? const <(int, String, String)>{}) {
      final onAllThree = days.every(
        (d) => (byDay[d.key] ?? const <(int, String, String)>{}).contains(key),
      );
      if (onAllThree && !today.contains(key)) {
        return RepeatSuggestion(
          amountMinor: key.$1,
          currency: Currency.fromCode(key.$2),
          category: key.$3,
          note: notes[key],
        );
      }
    }
    return null;
  }

  // --------------------------------------------------------------- writes

  /// Logs an expense and returns its uuid; the first log of a Harvest
  /// Day earns XP.
  Future<String> log({
    required int amountMinor,
    required String category,
    Currency currency = Currency.dzd,
    String? note,
    HarvestDay? day,
  }) async {
    final harvestDay = day ?? HarvestDay.today();
    final uuid = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.expenses)
          .insert(
            ExpensesCompanion.insert(
              uuid: uuid,
              amountMinor: amountMinor,
              currency: Value(currency.code),
              category: category,
              note: Value(note),
              harvestDay: harvestDay.key,
            ),
          );
      await _appendOutbox(uuid, 'insert');

      final reason = 'expenses:${harvestDay.key}';
      final existing =
          await (_db.select(_db.ledger)
                ..where((l) => l.reason.equals(reason))
                ..limit(1))
              .getSingleOrNull();
      if (existing == null) {
        await _db
            .into(_db.ledger)
            .insert(
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
    return uuid;
  }

  /// Same-day correction: edits an entry in place.
  Future<void> updateExpense({
    required String uuid,
    required int amountMinor,
    required String category,
    Currency currency = Currency.dzd,
    String? note,
  }) => _db.transaction(() async {
    await (_db.update(_db.expenses)..where((e) => e.uuid.equals(uuid))).write(
      ExpensesCompanion(
        amountMinor: Value(amountMinor),
        currency: Value(currency.code),
        category: Value(category),
        note: Value(note),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _appendOutbox(uuid, 'update');
  });

  /// Hard-deletes expenses and categories soft-deleted longer than
  /// [olderThan] ago — "delete" must eventually mean gone.
  Future<void> purgeDeleted({required Duration olderThan}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    await _db.transaction(() async {
      await (_db.delete(
        _db.expenses,
      )..where((e) => e.deletedAt.isSmallerThanValue(cutoff))).go();
      await (_db.delete(
        _db.expenseCategories,
      )..where((c) => c.deletedAt.isSmallerThanValue(cutoff))).go();
    });
  }

  /// Same-day correction: soft-deletes the entry (history stays truthful).
  Future<void> remove(String uuid) => _db.transaction(() async {
    await (_db.update(_db.expenses)..where((e) => e.uuid.equals(uuid))).write(
      ExpensesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _appendOutbox(uuid, 'delete');
  });

  /// Puts back an entry removed by mistake (the Undo in the snackbar).
  Future<void> restore(String uuid) => _db.transaction(() async {
    await (_db.update(_db.expenses)..where((e) => e.uuid.equals(uuid))).write(
      ExpensesCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _appendOutbox(uuid, 'update');
  });

  /// One expense by uuid, deleted or not — the undo path needs it.
  Future<Expense?> byUuid(String uuid) async {
    final row =
        await (_db.select(_db.expenses)
              ..where((e) => e.uuid.equals(uuid))
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<void> _appendOutbox(String uuid, String op) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(
          targetTable: 'expenses',
          rowUuid: uuid,
          op: op,
        ),
      );

  Expense _toDomain(ExpenseRow row) => Expense(
    uuid: row.uuid,
    amountMinor: row.amountMinor,
    currency: Currency.fromCode(row.currency),
    category: row.category,
    day: HarvestDay.parse(row.harvestDay),
    loggedAt: row.loggedAt,
    note: row.note,
  );
}

@Riverpod(keepAlive: true)
FinancesRepository financesRepository(Ref ref) =>
    FinancesRepository(ref.watch(databaseProvider));
