import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/goals/domain/goal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'goals_repository.g.dart';

/// Goals and what they take ([[Goals]]).
///
/// A goal is judged by nothing (GL1): nothing here reads a check-in to
/// decide anything, and nothing here writes to a seed. The one place a
/// seed reaches back is the check-in service ticking a planted to-do's
/// item (GL3), and it does that in its own transaction.
class GoalsRepository {
  GoalsRepository(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------- reads

  /// Fires on any write to goals or their items: a goal is a handful
  /// of rows, and re-reading both is simpler than joining two streams.
  Stream<void> _changes() => _db
      .customSelect('SELECT 1', readsFrom: {_db.goals, _db.goalItems})
      .watch();

  /// Every goal with its items, board order. Deleted ones are gone.
  Stream<List<GoalView>> watchAll() => _changes().asyncMap((_) async {
    final rows =
        await (_db.select(_db.goals)
              ..where((g) => g.deletedAt.isNull())
              ..orderBy([
                (g) => OrderingTerm.asc(g.position),
                (g) => OrderingTerm.asc(g.createdAt),
              ]))
            .get();
    final items = await _itemsFor(rows.map((row) => row.uuid).toList());
    return [
      for (final row in rows)
        GoalView(goal: _toGoal(row), items: items[row.uuid] ?? const []),
    ];
  });

  /// One goal, live; null once it is deleted.
  Stream<GoalView?> watchOne(String uuid) => _changes().asyncMap((_) async {
    final row = await (_db.select(
      _db.goals,
    )..where((g) => g.uuid.equals(uuid))).getSingleOrNull();
    if (row == null || row.deletedAt != null) return null;
    final items = await _itemsFor([uuid]);
    return GoalView(goal: _toGoal(row), items: items[uuid] ?? const []);
  });

  /// Active goals, for the seed editor's "Serves" picker.
  Future<List<Goal>> activeOnce() async {
    final rows =
        await (_db.select(_db.goals)
              ..where(
                (g) => g.deletedAt.isNull() & g.status.equals('active'),
              )
              ..orderBy([(g) => OrderingTerm.asc(g.position)]))
            .get();
    return rows.map(_toGoal).toList();
  }

  Future<Map<String, List<GoalItem>>> _itemsFor(List<String> goalUuids) async {
    if (goalUuids.isEmpty) return const {};
    final rows =
        await (_db.select(_db.goalItems)
              ..where(
                (i) => i.goalUuid.isIn(goalUuids) & i.deletedAt.isNull(),
              )
              ..orderBy([
                (i) => OrderingTerm.asc(i.kind),
                (i) => OrderingTerm.asc(i.position),
                (i) => OrderingTerm.asc(i.createdAt),
              ]))
            .get();
    final byGoal = <String, List<GoalItem>>{};
    for (final row in rows) {
      final item = _toItem(row);
      if (item != null) (byGoal[row.goalUuid] ??= []).add(item);
    }
    return byGoal;
  }

  // --------------------------------------------------------------- goals

  Future<Goal> create({
    required String title,
    String why = '',
    HarvestDay? targetDay,
  }) => _db.transaction(() async {
    final position = await _nextGoalPosition();
    final uuid = _uuid.v4();
    await _db
        .into(_db.goals)
        .insert(
          GoalsCompanion.insert(
            uuid: uuid,
            title: title,
            why: Value(why),
            targetDay: Value(targetDay?.key),
            position: Value(position),
          ),
        );
    await _db.logChange('goals', uuid, 'insert');
    return Goal(
      uuid: uuid,
      title: title,
      why: why,
      targetDay: targetDay,
      position: position,
      createdAt: DateTime.now(),
    );
  });

  Future<void> update(Goal goal) => _write(
    goal.uuid,
    GoalsCompanion(
      title: Value(goal.title),
      why: Value(goal.why),
      targetDay: Value(goal.targetDay?.key),
    ),
  );

  /// Board order, as dragged.
  Future<void> reorder(List<String> uuids) => _db.transaction(() async {
    for (final (i, uuid) in uuids.indexed) {
      await _write(uuid, GoalsCompanion(position: Value(i)));
    }
  });

  /// Marks a goal achieved and pays for it, once (GL4). Achieving is
  /// always my tap; nothing calls this on its own.
  Future<void> achieve(String uuid, {DateTime? at}) =>
      _db.transaction(() async {
        final now = at ?? DateTime.now();
        await _write(
          uuid,
          GoalsCompanion(
            status: const Value('achieved'),
            achievedAt: Value(now),
          ),
        );
        if (await _xpNet(uuid) <= 0) {
          await _db.insertLedger(
            LedgerCompanion.insert(
              uuid: _uuid.v4(),
              kind: 'xp',
              delta: goalAchievedXp,
              reason: 'goal:$uuid',
              harvestDay: HarvestDay.of(now).key,
            ),
          );
        }
      });

  /// Back to active. What achieving paid is taken back with a mirror
  /// row, the way an undone check-in is.
  Future<void> reopen(String uuid) => _db.transaction(() async {
    await _write(
      uuid,
      const GoalsCompanion(
        status: Value('active'),
        achievedAt: Value(null),
        statusNote: Value(null),
      ),
    );
    if (await _xpNet(uuid) > 0) {
      await _db.insertLedger(
        LedgerCompanion.insert(
          uuid: _uuid.v4(),
          kind: 'xp',
          delta: -goalAchievedXp,
          reason: 'goal-undo:$uuid',
          harvestDay: HarvestDay.today().key,
        ),
      );
    }
  });

  /// Dropping is not failing, and costs nothing. Its seeds keep going
  /// (GL5).
  Future<void> drop(String uuid, {String? note}) => _write(
    uuid,
    GoalsCompanion(status: const Value('dropped'), statusNote: Value(note)),
  );

  /// Soft delete, with its items (GL7). [restore] undoes it.
  Future<void> delete(String uuid) => _setDeleted(uuid, DateTime.now());
  Future<void> restore(String uuid) => _setDeleted(uuid, null);

  /// Items go with the goal and come back with it — only the ones that
  /// went *with* it, which share its deletion stamp. An item deleted on
  /// its own before stays deleted.
  Future<void> _setDeleted(String uuid, DateTime? at) =>
      _db.transaction(() async {
        final goal = await (_db.select(
          _db.goals,
        )..where((g) => g.uuid.equals(uuid))).getSingleOrNull();
        if (goal == null) return;
        final stamp = at ?? goal.deletedAt;
        final items =
            await (_db.select(_db.goalItems)..where(
                  (i) =>
                      i.goalUuid.equals(uuid) &
                      (at != null
                          ? i.deletedAt.isNull()
                          : i.deletedAt.equalsNullable(stamp)),
                ))
                .get();
        await _write(uuid, GoalsCompanion(deletedAt: Value(at)));
        for (final item in items) {
          await _writeItem(item.uuid, GoalItemsCompanion(deletedAt: Value(at)));
        }
      });

  // --------------------------------------------------------------- items

  Future<GoalItem> addItem(
    String goalUuid, {
    required String body,
    GoalItemKind kind = GoalItemKind.step,
  }) => _db.transaction(() async {
    final position = await _nextItemPosition(goalUuid, kind);
    final uuid = _uuid.v4();
    await _db
        .into(_db.goalItems)
        .insert(
          GoalItemsCompanion.insert(
            uuid: uuid,
            goalUuid: goalUuid,
            body: body,
            kind: Value(kind.name),
            position: Value(position),
          ),
        );
    await _db.logChange('goal_items', uuid, 'insert');
    return GoalItem(
      uuid: uuid,
      goalUuid: goalUuid,
      kind: kind,
      body: body,
      position: position,
    );
  });

  Future<void> editItem(String uuid, {required String body, String? note}) =>
      _writeItem(
        uuid,
        GoalItemsCompanion(body: Value(body), note: Value(note)),
      );

  /// Ticks or un-ticks by hand.
  Future<void> setDone(String uuid, {required bool done, DateTime? at}) =>
      _writeItem(
        uuid,
        GoalItemsCompanion(
          doneAt: Value(done ? (at ?? DateTime.now()) : null),
        ),
      );

  /// One section's order, as dragged.
  Future<void> reorderItems(List<String> uuids) => _db.transaction(() async {
    for (final (i, uuid) in uuids.indexed) {
      await _writeItem(uuid, GoalItemsCompanion(position: Value(i)));
    }
  });

  Future<void> deleteItem(String uuid, {DateTime? at}) => _writeItem(
    uuid,
    GoalItemsCompanion(deletedAt: Value(at ?? DateTime.now())),
  );
  Future<void> restoreItem(String uuid) =>
      _writeItem(uuid, const GoalItemsCompanion(deletedAt: Value(null)));

  /// The item was planted as [commitmentUuid].
  Future<void> linkItem(String uuid, String commitmentUuid) => _writeItem(
    uuid,
    GoalItemsCompanion(commitmentUuid: Value(commitmentUuid)),
  );

  // ------------------------------------------------------------- helpers

  Future<void> _write(String uuid, GoalsCompanion changes) =>
      _db.transaction(() async {
        await (_db.update(_db.goals)..where((g) => g.uuid.equals(uuid))).write(
          changes.copyWith(updatedAt: Value(DateTime.now())),
        );
        await _db.logChange('goals', uuid, 'update');
      });

  Future<void> _writeItem(String uuid, GoalItemsCompanion changes) =>
      _db.transaction(() async {
        await (_db.update(
          _db.goalItems,
        )..where((i) => i.uuid.equals(uuid))).write(
          changes.copyWith(updatedAt: Value(DateTime.now())),
        );
        await _db.logChange('goal_items', uuid, 'update');
      });

  /// What achieving this goal has paid, net of its mirror rows.
  Future<int> _xpNet(String uuid) async {
    final rows =
        await (_db.select(_db.ledger)..where(
              (l) =>
                  l.reason.equals('goal:$uuid') |
                  l.reason.equals('goal-undo:$uuid'),
            ))
            .get();
    return rows.fold<int>(0, (sum, row) => sum + row.delta);
  }

  Future<int> _nextGoalPosition() async {
    final max = _db.goals.position.max();
    final value = await (_db.selectOnly(
      _db.goals,
    )..addColumns([max])).map((row) => row.read(max)).getSingleOrNull();
    return (value ?? -1) + 1;
  }

  Future<int> _nextItemPosition(String goalUuid, GoalItemKind kind) async {
    final max = _db.goalItems.position.max();
    final value =
        await (_db.selectOnly(_db.goalItems)
              ..addColumns([max])
              ..where(
                _db.goalItems.goalUuid.equals(goalUuid) &
                    _db.goalItems.kind.equals(kind.name),
              ))
            .map((row) => row.read(max))
            .getSingleOrNull();
    return (value ?? -1) + 1;
  }

  static Goal _toGoal(GoalRow row) => Goal(
    uuid: row.uuid,
    title: row.title,
    why: row.why,
    targetDay: HarvestDay.tryParse(row.targetDay),
    status:
        GoalStatus.values.where((s) => s.name == row.status).firstOrNull ??
        GoalStatus.active,
    statusNote: row.statusNote,
    achievedAt: row.achievedAt,
    position: row.position,
    createdAt: row.createdAt,
  );

  static GoalItem? _toItem(GoalItemRow row) {
    final kind = GoalItemKind.values
        .where((k) => k.name == row.kind)
        .firstOrNull;
    if (kind == null) {
      debugPrint('[goals] unknown item kind for ${row.uuid}');
      return null;
    }
    return GoalItem(
      uuid: row.uuid,
      goalUuid: row.goalUuid,
      kind: kind,
      body: row.body,
      note: row.note,
      doneAt: row.doneAt,
      position: row.position,
      commitmentUuid: row.commitmentUuid,
    );
  }
}

@Riverpod(keepAlive: true)
GoalsRepository goalsRepository(Ref ref) =>
    GoalsRepository(ref.watch(databaseProvider));
