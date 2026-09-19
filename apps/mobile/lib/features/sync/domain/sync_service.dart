import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/sync/domain/row_codec.dart';
import 'package:uuid/uuid.dart';

/// The server, as sync needs it: two verbs ([[Sync-API]]). The real one
/// goes through the API client; the tests use one in memory.
abstract interface class SyncRemote {
  Future<({List<Map<String, Object?>> results, int cursor})> push(
    String deviceId,
    List<Map<String, Object?>> records,
  );

  Future<({List<Map<String, Object?>> records, int cursor, bool more})> pull(
    int after,
    int limit,
  );
}

/// What one sync did, for the account screen.
@immutable
class SyncReport {
  const SyncReport({
    required this.pulled,
    required this.pushed,
    required this.invalid,
    required this.heldBack,
    required this.at,
  });

  final int pulled;
  final int pushed;

  /// Rows the server refused; kept in the outbox and counted, never
  /// retried blindly.
  final int invalid;

  /// Private-tier rows waiting for a sync passphrase.
  final int heldBack;
  final DateTime at;
}

/// Sync bookkeeping, kept in `kv_settings` under keys that never leave
/// the phone themselves.
abstract final class SyncKeys {
  static const cursor = 'sync.cursor';
  static const deviceId = 'sync.deviceId';
  static const snapshotDone = 'sync.snapshotDone';
  static const lastSyncedAt = 'sync.lastSyncedAt';
  static const invalid = 'sync.invalid';
}

/// Drains the outbox and merges the server's rows ([[Sync-API]]).
///
/// The order is the page's: pull first, so a stale local edit loses to
/// a newer remote one before it is even sent; push; pull again for what
/// landed meanwhile. Only one sync runs at a time.
class SyncService {
  SyncService(this._db, this._remote, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final HarvestDatabase _db;
  final SyncRemote _remote;
  final DateTime Function() _clock;
  late final Map<String, TableCodec> _codecs = codecsOf(_db);

  static const batch = 500;

  Future<SyncReport>? _running;

  Future<SyncReport> run() => _running ??= _run().whenComplete(
    () => _running = null,
  );

  Future<SyncReport> _run() async {
    var pulled = await _pullAll();
    if (await _setting(SyncKeys.snapshotDone) != 'true') {
      await _snapshot();
    }
    final pushed = await _pushOutbox();
    pulled += await _pullAll();
    final at = _clock();
    await _set(SyncKeys.lastSyncedAt, at.toUtc().toIso8601String());
    return SyncReport(
      pulled: pulled,
      pushed: pushed.pushed,
      invalid: pushed.invalid,
      heldBack: pushed.heldBack,
      at: at,
    );
  }

  // ---------------------------------------------------------------- pull

  Future<int> _pullAll() async {
    var cursor = int.tryParse(await _setting(SyncKeys.cursor) ?? '') ?? 0;
    var merged = 0;
    while (true) {
      final page = await _remote.pull(cursor, batch);
      await _db.transaction(() async {
        for (final record in page.records) {
          if (await merge(record)) merged++;
        }
      });
      cursor = page.cursor;
      await _set(SyncKeys.cursor, '$cursor');
      if (!page.more) return merged;
    }
  }

  /// Applies one pulled record by the server's own rule: a local row
  /// missing, or older, is overwritten; anything else stays. Returns
  /// whether anything changed.
  @visibleForTesting
  Future<bool> merge(Map<String, Object?> record) async {
    final codec = _codecs[record['table']];
    final key = record['uuid'];
    if (codec == null || key is! String) return false;
    if (record['purged'] == true) {
      await codec.purge(_db, key);
      return true;
    }
    final data = record['data'];
    // Ciphertext waits for the passphrase ([[Sync-API]]: private tier).
    if (data is! Map<String, Object?>) return false;
    if (!codec.mayLeave(key)) return false;

    final local = await codec.read(_db, key);
    if (local != null) {
      final remote = DateTime.parse(record['updatedAt']! as String);
      final ownClock = codec.has('updated_at') || codec.name == 'ledger';
      if (ownClock && !remote.isAfter(codec.clockOf(local, remote))) {
        return false;
      }
    }
    await codec.upsert(_db, data);
    return true;
  }

  // ---------------------------------------------------------------- push

  /// A device's first sync sends every row it has: the outbox is an
  /// increment, and rows written before any account existed may have
  /// been capped out of it ([[ADR-005-Local-First-Sync]]).
  Future<void> _snapshot() async {
    final now = _clock();
    for (final codec in _codecs.values) {
      if (codec.private) continue;
      final rows = await codec.readAll(_db);
      final records = <Map<String, Object?>>[];
      for (final row in rows) {
        final key = codec.keyOf(row);
        if (!codec.mayLeave(key)) continue;
        records.add(_record(codec, key, row, now));
      }
      for (var i = 0; i < records.length; i += batch) {
        final page = records.sublist(
          i,
          i + batch > records.length ? records.length : i + batch,
        );
        await _remote.push(await deviceId(), page);
      }
    }
    await _set(SyncKeys.snapshotDone, 'true');
  }

  Future<({int pushed, int invalid, int heldBack})> _pushOutbox() async {
    var pushed = 0;
    var invalid = 0;
    var heldBack = 0;
    final device = await deviceId();
    var after = 0;
    while (true) {
      final rows =
          await (_db.select(_db.outbox)
                ..where((o) => o.seq.isBiggerThanValue(after))
                ..orderBy([(o) => OrderingTerm.asc(o.seq)])
                ..limit(batch))
              .get();
      if (rows.isEmpty) break;
      after = rows.last.seq;

      // Several changes to one row are one record: the row as it is now.
      final latest = <(String, String), OutboxData>{};
      for (final row in rows) {
        latest[(row.targetTable, row.rowUuid)] = row;
      }
      final records = <Map<String, Object?>>[];
      final sent = <(String, String), List<int>>{};
      for (final entry in latest.entries) {
        final (table, key) = entry.key;
        final codec = _codecs[table];
        if (codec == null || !codec.mayLeave(key)) {
          await _drop(
            rows.where((r) => r.targetTable == table && r.rowUuid == key),
          );
          continue;
        }
        if (codec.private) {
          heldBack++;
          continue;
        }
        final row = await codec.read(_db, key);
        records.add(
          row == null
              // A delete is a new event: stamped now, to the microsecond,
              // so it can never tie with the write it undoes.
              ? _tombstone(table, key, _clock())
              : _record(codec, key, row, entry.value.queuedAt),
        );
        sent[entry.key] = [
          for (final r in rows)
            if (r.targetTable == table && r.rowUuid == key) r.seq,
        ];
      }
      if (records.isEmpty) continue;

      final answer = await _remote.push(device, records);
      for (final result in answer.results) {
        final id = (result['table']! as String, result['uuid']! as String);
        final status = result['status'];
        if (status == 'invalid') {
          invalid++;
          debugPrint('[sync] refused ${id.$1}: ${result['issues']}');
          continue;
        }
        pushed++;
        final seqs = sent[id] ?? const <int>[];
        await (_db.delete(_db.outbox)..where((o) => o.seq.isIn(seqs))).go();
      }
    }
    await _set(SyncKeys.invalid, '$invalid');
    return (pushed: pushed, invalid: invalid, heldBack: heldBack);
  }

  Future<void> _drop(Iterable<OutboxData> rows) =>
      (_db.delete(_db.outbox)..where(
            (o) => o.seq.isIn([for (final r in rows) r.seq]),
          ))
          .go();

  Map<String, Object?> _record(
    TableCodec codec,
    String key,
    Map<String, Object?> row,
    DateTime queuedAt,
  ) {
    final data = codec.toData(row);
    return {
      'table': codec.name,
      'uuid': key,
      'updatedAt': isoUtc(codec.clockOf(row, queuedAt)),
      'deletedAt': data['deletedAt'],
      'data': data,
    };
  }

  /// A row the outbox names and the database no longer has: it was
  /// hard-deleted, and the other devices must purge it too.
  Map<String, Object?> _tombstone(String table, String key, DateTime at) => {
    'table': table,
    'uuid': key,
    'updatedAt': isoUtc(at),
    'deletedAt': isoUtc(at),
    'purged': true,
  };

  // ------------------------------------------------------------- settings

  /// This install's id, made once.
  Future<String> deviceId() async {
    final existing = await _setting(SyncKeys.deviceId);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await _set(SyncKeys.deviceId, id);
    return id;
  }

  /// Forgets where sync was: signing out, or into another account.
  Future<void> reset() async {
    for (final key in [
      SyncKeys.cursor,
      SyncKeys.snapshotDone,
      SyncKeys.lastSyncedAt,
      SyncKeys.invalid,
    ]) {
      await (_db.delete(_db.kvSettings)..where((s) => s.key.equals(key))).go();
    }
  }

  Future<String?> _setting(String key) async {
    final row = await (_db.select(
      _db.kvSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    final raw = row.valueJson;
    return raw.startsWith('"') && raw.endsWith('"')
        ? raw.substring(1, raw.length - 1)
        : raw;
  }

  Future<void> _set(String key, String value) => _db
      .into(_db.kvSettings)
      .insertOnConflictUpdate(
        KvSettingsCompanion.insert(
          key: key,
          valueJson: '"$value"',
          updatedAt: Value(DateTime.now()),
        ),
      );
}
