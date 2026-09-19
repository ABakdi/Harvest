import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/portable_settings.dart';

/// The tables whose rows travel as ciphertext only ([[Sync-API]]):
/// money and location. Until a sync passphrase exists they stay home.
const privateTables = {
  'expenses',
  'money_txns',
  'debts',
  'debt_payments',
  'expense_categories',
  'location_points',
  'geotags',
  'saved_places',
};

/// Not synced: the change log itself, and the parked quests.
const unsyncedTables = {'outbox', 'quests'};

/// How one Drift table becomes records and back, read from the table's
/// own column list so a column added in a migration travels without a
/// line of code here — and the contract, which is strict about
/// columns, notices the moment the two disagree.
class TableCodec {
  TableCodec(this.table);

  final TableInfo<Table, dynamic> table;

  String get name => table.actualTableName;
  bool get private => privateTables.contains(name);

  late final List<GeneratedColumn<Object>> _columns = table.$columns;
  late final Set<String> _names = {for (final c in _columns) c.name};

  bool has(String column) => _names.contains(column);

  /// The columns a record key names, in order: most tables are keyed by
  /// `uuid`, a few by something else ([[Sync-API]]: keys that are not
  /// uuids).
  List<String> get keyColumns => switch (name) {
    'step_days' => const ['harvest_day'],
    'streaks' => const ['scope'],
    'kv_settings' => const ['key'],
    'training_maxes' => const ['program_uuid', 'exercise_id'],
    _ => const ['uuid'],
  };

  /// The record key of a row, as the outbox writes it.
  String keyOf(Map<String, Object?> sqlRow) =>
      keyColumns.map((column) => '${sqlRow[column]}').join('/');

  List<Object> keyValues(String key) => switch (keyColumns.length) {
    1 => [key],
    _ => key.split('/'),
  };

  String get _where => keyColumns.map((c) => '"$c" = ?').join(' AND ');

  /// One row by key, as SQL gives it (dates as epoch seconds), or null.
  Future<Map<String, Object?>?> read(HarvestDatabase db, String key) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM "$name" WHERE $_where',
          variables: [for (final v in keyValues(key)) Variable(v)],
          readsFrom: {table},
        )
        .get();
    return rows.isEmpty ? null : rows.first.data;
  }

  /// Every row, for a device's first sync.
  Future<List<Map<String, Object?>>> readAll(HarvestDatabase db) async {
    final rows = await db
        .customSelect('SELECT * FROM "$name"', readsFrom: {table})
        .get();
    return [for (final row in rows) row.data];
  }

  /// The row as the contract spells it: every column, camelCase, dates
  /// as ISO-8601 UTC, booleans as booleans.
  Map<String, Object?> toData(Map<String, Object?> sqlRow) => {
    for (final column in _columns)
      _camel(column.name): _toWire(column, sqlRow[column.name]),
  };

  /// The conflict clock of a row: its own `updated_at`, the ledger's
  /// `logged_at`, or — for the child rows that keep no time at all —
  /// [fallback], the moment the change was queued.
  DateTime clockOf(Map<String, Object?> sqlRow, DateTime fallback) {
    final column = has('updated_at')
        ? 'updated_at'
        : name == 'ledger'
        ? 'logged_at'
        : null;
    final value = column == null ? null : sqlRow[column];
    return value == null ? fallback : _dateOf(value);
  }

  /// Whether a row may leave the phone at all: a setting only when it
  /// is one of mine rather than the app's bookkeeping.
  bool mayLeave(String key) =>
      name != 'kv_settings' || isImportableSetting(key);

  /// Writes a pulled row, replacing what was there. Never through the
  /// repositories and never into the outbox: a pulled row is not a new
  /// change, and echoing it back would loop ([[Sync-API]]).
  Future<void> upsert(HarvestDatabase db, Map<String, Object?> data) async {
    final columns = <String>[];
    final values = <Variable<Object>>[];
    for (final column in _columns) {
      final key = _camel(column.name);
      if (!data.containsKey(key)) continue;
      columns.add(column.name);
      values.add(_toSql(column, data[key]));
    }
    final placeholders = List.filled(columns.length, '?').join(', ');
    final updates = [
      for (final c in columns)
        if (!keyColumns.contains(c)) '"$c" = excluded."$c"',
    ];
    await db.customInsert(
      'INSERT INTO "$name" (${columns.map((c) => '"$c"').join(', ')}) '
      'VALUES ($placeholders) '
      'ON CONFLICT(${keyColumns.map((c) => '"$c"').join(', ')}) '
      '${updates.isEmpty ? 'DO NOTHING' : 'DO UPDATE SET ${updates.join(', ')}'}',
      variables: values,
      updates: {table},
    );
  }

  /// A purged row goes here too ([[Sync-API]]: tombstones).
  Future<void> purge(HarvestDatabase db, String key) => db.customUpdate(
    'DELETE FROM "$name" WHERE $_where',
    variables: [for (final v in keyValues(key)) Variable(v)],
    updates: {table},
    updateKind: UpdateKind.delete,
  );

  Object? _toWire(GeneratedColumn<Object> column, Object? value) {
    if (value == null) return null;
    return switch (column.type) {
      DriftSqlType.dateTime => isoUtc(_dateOf(value)),
      DriftSqlType.bool => value == 1 || value == true,
      DriftSqlType.double => (value as num).toDouble(),
      DriftSqlType.int || DriftSqlType.bigInt => (value as num).toInt(),
      _ => value,
    };
  }

  Variable<Object> _toSql(GeneratedColumn<Object> column, Object? value) {
    if (value == null) return const Variable(null);
    return switch (column.type) {
      DriftSqlType.dateTime => Variable<DateTime>(
        DateTime.parse(value as String),
      ),
      DriftSqlType.bool => Variable<bool>(value as bool),
      // Mongo hands 212.0 back as 212: a real is a real either way.
      DriftSqlType.double => Variable<double>((value as num).toDouble()),
      DriftSqlType.int => Variable<int>((value as num).toInt()),
      _ => Variable<String>(value as String),
    };
  }
}

/// Drift keeps dates as epoch seconds unless told otherwise.
DateTime _dateOf(Object value) => switch (value) {
  final DateTime date => date,
  final int seconds => DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ),
  final String text => DateTime.parse(text),
  _ => throw ArgumentError('Not a date: $value'),
};

/// An instant as the wire wants it: UTC, with a `Z`.
String isoUtc(DateTime value) => value.toUtc().toIso8601String();

String _camel(String snake) {
  final parts = snake.split('_');
  return parts.first +
      parts
          .skip(1)
          .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
          .join();
}

/// Every synced table's codec, by name.
Map<String, TableCodec> codecsOf(HarvestDatabase db) => {
  for (final table in db.allTables)
    if (!unsyncedTables.contains(table.actualTableName))
      table.actualTableName: TableCodec(table),
};
