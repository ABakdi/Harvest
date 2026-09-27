import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/goals/data/goals_repository.dart';
import 'package:harvest/features/sync/domain/row_codec.dart';
import 'package:harvest/features/sync/domain/sync_cipher.dart';
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
    this.locked = 0,
    this.refusedFor = const {},
  });

  final int pulled;
  final int pushed;

  /// Rows the server refused. They leave the outbox, are remembered and
  /// counted, and go again only when they change again ([[Sync-API]]).
  final int invalid;

  /// Private-tier rows waiting for a sync passphrase.
  final int heldBack;

  /// Sealed rows the key could not open: sealed by 3.0.0's key, or not
  /// what they claim to be. Counted, never fatal.
  final int locked;

  /// The reasons the server gave for the refused rows, by issue code
  /// (`quota_exceeded`, `clock_ahead`, `clock_too_far`, …), so the
  /// account screen can say why in words.
  final Set<String> refusedFor;
  final DateTime at;
}

/// Refusals that can pass on their own: an account with room again, a
/// clock put right. Rows refused only for these go again an hour later.
const passingRefusals = {'quota_exceeded', 'clock_ahead', 'clock_too_far'};

/// Sync bookkeeping, kept in `kv_settings` under keys that never leave
/// the phone themselves.
abstract final class SyncKeys {
  static const cursor = 'sync.cursor';
  static const deviceId = 'sync.deviceId';
  static const snapshotDone = 'sync.snapshotDone';
  static const lastSyncedAt = 'sync.lastSyncedAt';
  static const invalid = 'sync.invalid';

  /// Whether the private tables' rows have been sent once, sealed. Set
  /// false when a passphrase is first given, so the history that waited
  /// for it goes up.
  static const privateSnapshotDone = 'sync.privateSnapshotDone';

  /// The rows the server refused, `table/key` to its reasons: the
  /// outbox's invalid flag. They are not tried again until they change.
  static const refused = 'sync.refused';

  /// Sealed rows that would not open, as `table/key`.
  static const locked = 'sync.locked';

  /// Rows pulled with a clock ahead of this phone's, `table/key` to that
  /// clock: an edit made here since is stamped just after it rather than
  /// before it, so it is not refused as stale.
  static const ahead = 'sync.ahead';

  /// Rows a push found stale that the pulls have not brought back yet:
  /// the next run pulls the history again and takes the server's copy.
  static const stale = 'sync.stale';

  /// Set when the server may lack files this phone has already named:
  /// after an archive is restored, or on a new account or server. The
  /// next file pass asks about every named file, not only new ones.
  static const checkFiles = 'sync.checkFiles';

  /// Written by 3.0.0 to choose between choosing a PIN and entering one;
  /// the server's key check decides that now.
  static const legacySealedSeen = 'sync.sealedSeen';
}

/// Drains the outbox and merges the server's rows ([[Sync-API]]).
///
/// The order is the page's: pull first, so a stale local edit loses to
/// a newer remote one before it is even sent; push; pull again for what
/// landed meanwhile. Only one sync runs at a time.
class SyncService {
  SyncService(
    this._db,
    this._remote, {
    DateTime Function()? clock,
    Future<SyncCipher?> Function()? cipher,
    this.onPurged,
  }) : _clock = clock ?? DateTime.now,
       _cipherOf = cipher ?? (() async => null);

  final HarvestDatabase _db;
  final SyncRemote _remote;
  final DateTime Function() _clock;
  final Future<SyncCipher?> Function() _cipherOf;

  /// Told about each row a pulled purge removed, as it was: what the
  /// row held on disk (a picture, a recording) can go too ([[Sync-API]]:
  /// tombstones).
  final Future<void> Function(String table, Map<String, Object?> row)? onPurged;

  /// The private tier's key for this run; null until a passphrase is set,
  /// and then money and places stay home ([[Sync-API]]).
  SyncCipher? _cipher;
  late final Map<String, TableCodec> _codecs = codecsOf(_db);

  static const batch = 500;

  Future<SyncReport>? _running;

  // The run's bookkeeping, read at its start and written as it goes.
  var _refused = <String, Object?>{};
  var _locked = <String>{};
  var _ahead = <String, String>{};
  var _stale = <String>{};
  final _purged = <(String, Map<String, Object?>)>[];

  /// Whether this run merged a goal item: a parent's stored tick is
  /// then settled again from its subtasks (Q5-44).
  var _goalItemsTouched = false;

  Future<SyncReport> run() => _running ??= _run().whenComplete(
    () => _running = null,
  );

  /// Waits for a run already going, if there is one, however it ends.
  Future<void> idle() async {
    final running = _running;
    if (running == null) return;
    try {
      await running;
    } on Object {
      return;
    }
  }

  Future<SyncReport> _run() async {
    _cipher = await _cipherOf();
    await _loadBook();
    await _retryPassing();
    if (_stale.isNotEmpty) {
      // A push found the server's copy newer and no pull has brought it
      // since: it is behind the cursor, so the history comes again.
      await _set(SyncKeys.cursor, '0');
    }
    var pulled = await _pullAll();
    if (await _setting(SyncKeys.snapshotDone) != 'true') {
      await _snapshot(private: false);
      await _set(SyncKeys.snapshotDone, 'true');
    }
    if (_cipher != null &&
        await _setting(SyncKeys.privateSnapshotDone) != 'true') {
      await _snapshot(private: true);
      await _set(SyncKeys.privateSnapshotDone, 'true');
    }
    final pushed = await _pushOutbox();
    pulled += await _pullAll();
    await _saveBook();
    await _releasePurged();
    if (_goalItemsTouched) {
      _goalItemsTouched = false;
      await GoalsRepository(_db).settleAllParents();
    }
    final at = _clock();
    await _set(SyncKeys.lastSyncedAt, at.toUtc().toIso8601String());
    return SyncReport(
      pulled: pulled,
      pushed: pushed.pushed,
      invalid: _refused.length,
      refusedFor: {
        for (final value in _refused.values) ..._codesOf(value),
      },
      heldBack: pushed.heldBack,
      locked: _locked.length,
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
      await _saveBook();
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
    final updatedAt = record['updatedAt'];
    if (codec == null || key is! String || updatedAt is! String) return false;
    if (!codec.mayLeave(key)) return false;
    final id = '${codec.name}/$key';
    final stamp = DateTime.parse(updatedAt);
    // Pushed and found stale: the server's copy is the one to keep,
    // even when its clock only ties with this one's.
    final takeTies = _stale.remove(id);

    final local = await codec.read(_db, key);
    final pending = await _pendingSince(codec.name, key);
    if (!_wins(codec, local, stamp, pending, takeTies: takeTies)) {
      return false;
    }

    if (codec.name == 'goal_items') _goalItemsTouched = true;
    if (record['purged'] == true) {
      if (local == null) return false;
      await codec.purge(_db, key);
      _purged.add((codec.name, local));
      _locked.remove(id);
      return true;
    }

    var data = record['data'];
    final envelope = record['enc'];
    if (envelope is Map<String, Object?>) {
      // Ciphertext waits for the passphrase ([[Sync-API]]: private tier);
      // setting it re-pulls everything, so nothing waiting is lost.
      final cipher = _cipher;
      if (cipher == null) return false;
      final deletedAt = record['deletedAt'] as String?;
      try {
        final opened = await cipher.open(codec.name, key, (
          updatedAt: updatedAt,
          deletedAt: deletedAt,
        ), envelope);
        if (!_sameClocks(codec, opened, updatedAt, deletedAt)) {
          throw const UnreadableRow("the row's clocks are not the record's");
        }
        data = opened;
      } on UnreadableRow catch (unreadable) {
        // Never fatal and never a reason to doubt a key that passed
        // the account's check ([[Sync-API]]): the row is parked as
        // locked and the rest of the history goes on.
        debugPrint('[sync] locked ${codec.name}: ${unreadable.reason}');
        _locked.add(id);
        return false;
      }
    }
    if (data is! Map<String, Object?>) return false;

    await codec.upsert(_db, data);
    _locked.remove(id);
    // A clock ahead of this phone's: an edit made here before this
    // phone's clock catches up must still come after it.
    if (stamp.isAfter(_clock())) {
      _ahead[id] = isoUtc(stamp);
    } else {
      _ahead.remove(id);
    }
    return true;
  }

  /// Whether a pulled change at [stamp] replaces what is here.
  ///
  /// - A row with its own clock: when that clock is older.
  /// - A row with none (payments, program slots…): the server's copy is
  ///   the one every device converges on, unless this phone changed it
  ///   since [stamp] and has not sent that yet ([[Sync-API]], Q5-07).
  /// - A row that is not here: unless its delete is still waiting to go
  ///   up, and was made after [stamp] (Q5-09).
  bool _wins(
    TableCodec codec,
    Map<String, Object?>? local,
    DateTime stamp,
    DateTime? pending, {
    required bool takeTies,
  }) {
    if (local == null || !_ownClock(codec)) {
      return pending == null || stamp.isAfter(pending);
    }
    final mine = codec.clockOf(local, stamp);
    return takeTies ? !mine.isAfter(stamp) : stamp.isAfter(mine);
  }

  bool _ownClock(TableCodec codec) =>
      codec.has('updated_at') || codec.name == 'ledger';

  /// The newest change to one row still waiting in the outbox, or null.
  /// Compared here rather than by SQL's `MAX`, which reads a stored
  /// date only to the second.
  Future<DateTime?> _pendingSince(String table, String key) async {
    final rows = await (_db.select(
      _db.outbox,
    )..where((o) => o.targetTable.equals(table) & o.rowUuid.equals(key))).get();
    DateTime? newest;
    for (final row in rows) {
      if (newest == null || row.queuedAt.isAfter(newest)) newest = row.queuedAt;
    }
    return newest;
  }

  /// Whether an opened row's own clocks are the record's, where its
  /// table keeps them: an older ciphertext offered under a newer clock
  /// is not the newer row ([[Sync-API]]: private tier).
  bool _sameClocks(
    TableCodec codec,
    Map<String, Object?> data,
    String updatedAt,
    String? deletedAt,
  ) {
    bool same(Object? value, String? expected) =>
        (value == null || value is String) &&
        sameInstant(value as String?, expected);
    if (codec.has('updated_at') && !same(data['updatedAt'], updatedAt)) {
      return false;
    }
    if (codec.has('deleted_at') && !same(data['deletedAt'], deletedAt)) {
      return false;
    }
    return true;
  }

  Future<void> _releasePurged() async {
    final release = onPurged;
    final purged = [..._purged];
    _purged.clear();
    if (release == null) return;
    for (final (table, row) in purged) {
      try {
        await release(table, row);
      } on Object catch (error) {
        debugPrint('[sync] could not release a $table file: $error');
      }
    }
  }

  // ---------------------------------------------------------------- push

  /// A device's first sync sends every row it has: the outbox is an
  /// increment, and rows written before any account existed may have
  /// been capped out of it ([[ADR-005-Local-First-Sync]]).
  Future<void> _snapshot({required bool private}) async {
    final now = _clock();
    for (final codec in _codecs.values) {
      if (codec.private != private) continue;
      final rows = await codec.readAll(_db);
      final records = <Map<String, Object?>>[];
      for (var row in rows) {
        final key = codec.keyOf(row);
        if (!codec.mayLeave(key)) continue;
        if (private && codec.has('updated_at')) {
          // Sealed under a new key, a row must win over its own copy
          // sealed under the old one, which has the same clock: moved on
          // by a microsecond, it does, and loses to anything newer.
          final clock = codec.clockOf(row, now);
          await codec.restamp(
            _db,
            key,
            clock.add(const Duration(microseconds: 1)),
          );
          row = await codec.read(_db, key) ?? row;
        }
        records.add(await _record(codec, key, row, now));
      }
      for (var i = 0; i < records.length; i += batch) {
        final page = records.sublist(
          i,
          i + batch > records.length ? records.length : i + batch,
        );
        final answer = await _remote.push(await deviceId(), page);
        // A refused row is flagged like any refused change, so it is
        // counted rather than lost behind a finished snapshot (Q5-54).
        for (final result in answer.results) {
          if (result['status'] == 'invalid') _refuse(result);
        }
      }
    }
  }

  void _refuse(Map<String, Object?> result) {
    final id = '${result['table']}/${result['uuid']}';
    debugPrint('[sync] refused $id: ${result['issues']}');
    _refused[id] = {
      'issues': result['issues'],
      'at': _clock().toUtc().toIso8601String(),
    };
  }

  static Set<String> _codesOf(Object? refusal) {
    final issues = refusal is Map<String, Object?>
        ? refusal['issues']
        : refusal;
    return {
      if (issues is List)
        for (final issue in issues)
          if (issue is Map && issue['code'] is String) issue['code'] as String,
    };
  }

  /// Rows refused only for a reason that can pass (no room, a clock
  /// ahead) go again once an hour has gone by, rather than waiting for
  /// an edit that may never come.
  Future<void> _retryPassing() async {
    final hourAgo = _clock().subtract(const Duration(hours: 1));
    final again = <String>[];
    for (final MapEntry(:key, :value) in _refused.entries) {
      final codes = _codesOf(value);
      if (codes.isEmpty || !codes.every(passingRefusals.contains)) continue;
      final at = value is Map<String, Object?>
          ? DateTime.tryParse('${value['at']}')
          : null;
      if (at != null && at.isAfter(hourAgo)) continue;
      again.add(key);
    }
    for (final id in again) {
      final cut = id.indexOf('/');
      if (cut < 0) continue;
      _refused.remove(id);
      await _db.logChange(
        id.substring(0, cut),
        id.substring(cut + 1),
        'update',
      );
    }
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
        final seqs = [
          for (final r in rows)
            if (r.targetTable == table && r.rowUuid == key) r.seq,
        ];
        if (codec == null || !codec.mayLeave(key)) {
          await _drop(seqs);
          continue;
        }
        if (codec.private && _cipher == null) {
          heldBack++;
          continue;
        }
        final queuedAt = _after('$table/$key', entry.value.queuedAt);
        var row = await codec.read(_db, key);
        if (row != null) row = await _stampAfter(codec, key, row);
        records.add(
          row == null
              // A delete is stamped when it was made, like any change,
              // and after any clock this row has had here (Q5-09).
              ? _tombstone(table, key, queuedAt)
              : await _record(codec, key, row, queuedAt),
        );
        sent[entry.key] = seqs;
      }
      if (records.isEmpty) continue;

      final answer = await _remote.push(device, records);
      for (final result in answer.results) {
        final id = (result['table']! as String, result['uuid']! as String);
        final seqs = sent[id] ?? const <int>[];
        final status = result['status'];
        if (status == 'invalid') {
          // Flagged, not retried every run: it goes again when it
          // changes again ([[Sync-API]], Q5-54).
          invalid++;
          _refuse(result);
        } else {
          pushed++;
          _refused.remove('${id.$1}/${id.$2}');
          _ahead.remove('${id.$1}/${id.$2}');
          // The server's copy won (Q5-10): the pull that follows takes
          // it, even on a tie, and the next run pulls again if it is
          // behind the cursor.
          if (status == 'stale') _stale.add('${id.$1}/${id.$2}');
        }
        await (_db.delete(_db.outbox)..where((o) => o.seq.isIn(seqs))).go();
      }
    }
    await _saveBook();
    return (pushed: pushed, invalid: invalid, heldBack: heldBack);
  }

  Future<void> _drop(List<int> seqs) =>
      (_db.delete(_db.outbox)..where((o) => o.seq.isIn(seqs))).go();

  /// [at], or just after the clock a pulled copy of the row had when
  /// that is later: a clock stays monotonic per row even when another
  /// device's runs ahead of this one's (Q5-10).
  DateTime _after(String id, DateTime at) {
    final seen = _ahead[id];
    if (seen == null) return at;
    final floor = DateTime.parse(seen).add(const Duration(microseconds: 1));
    return floor.isAfter(at) ? floor : at;
  }

  /// A row whose own clock is not after the clock a pulled copy of it
  /// had is written again just after that clock, quietly, so the record
  /// and the row keep telling the same story (Q5-10).
  Future<Map<String, Object?>> _stampAfter(
    TableCodec codec,
    String key,
    Map<String, Object?> row,
  ) async {
    final seen = _ahead['${codec.name}/$key'];
    if (seen == null || !codec.has('updated_at')) return row;
    final floor = DateTime.parse(seen);
    if (codec.clockOf(row, floor).isAfter(floor)) return row;
    await codec.restamp(_db, key, floor.add(const Duration(microseconds: 1)));
    return await codec.read(_db, key) ?? row;
  }

  Future<Map<String, Object?>> _record(
    TableCodec codec,
    String key,
    Map<String, Object?> row,
    DateTime queuedAt,
  ) async {
    final data = codec.toData(row);
    final cipher = _cipher;
    final updatedAt = isoUtc(codec.clockOf(row, queuedAt));
    final deletedAt = data['deletedAt'] as String?;
    return {
      'table': codec.name,
      'uuid': key,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
      // The clocks stay in the clear, because the server's conflict rule
      // needs them, and are bound into the seal; everything else of a
      // private row is sealed.
      if (codec.private && cipher != null)
        'enc': await cipher.seal(codec.name, key, (
          updatedAt: updatedAt,
          deletedAt: deletedAt,
        ), data)
      else
        'data': data,
    };
  }

  /// Whether a private row waits in the outbox to go up sealed.
  Future<bool> privatePending() async {
    final row =
        await (_db.select(_db.outbox)
              ..where((o) => o.targetTable.isIn(privateTables))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// A passphrase was just given: pull the whole history again, to open
  /// the private rows the earlier pulls had to leave, and send this
  /// phone's own private rows once.
  ///
  /// Every private row goes up again, and every file is asked about
  /// again, under the key just set: after the PIN was started over
  /// (here or on another device) the server has none of them.
  Future<void> privateTierOpened() async {
    await _set(SyncKeys.cursor, '0');
    await _set(SyncKeys.privateSnapshotDone, 'false');
    await _set(SyncKeys.checkFiles, 'true');
    await _remove(SyncKeys.locked);
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
      SyncKeys.privateSnapshotDone,
      SyncKeys.refused,
      SyncKeys.locked,
      SyncKeys.ahead,
      SyncKeys.stale,
      SyncKeys.legacySealedSeen,
    ]) {
      await _remove(key);
    }
    // Another account, or another server, has none of the files yet.
    await _set(SyncKeys.checkFiles, 'true');
  }

  Future<void> _loadBook() async {
    Object? json(String? raw) {
      if (raw == null) return null;
      try {
        return jsonDecode(raw);
      } on FormatException {
        return null;
      }
    }

    final refused = json(await _setting(SyncKeys.refused));
    _refused = refused is Map<String, Object?> ? {...refused} : {};
    final locked = json(await _setting(SyncKeys.locked));
    _locked = locked is List ? {...locked.whereType<String>()} : {};
    final stale = json(await _setting(SyncKeys.stale));
    _stale = stale is List ? {...stale.whereType<String>()} : {};
    final ahead = json(await _setting(SyncKeys.ahead));
    // An entry goes when its row is sent or pulled again; one left a
    // month is a row nobody touched since, and is let go.
    final month = _clock().subtract(const Duration(days: 30));
    _ahead = {
      if (ahead is Map<String, Object?>)
        for (final MapEntry(:key, :value) in ahead.entries)
          if (value is String &&
              DateTime.tryParse(value)?.isAfter(month) == true)
            key: value,
    };
    _purged.clear();
  }

  Future<void> _saveBook() async {
    await _set(SyncKeys.refused, jsonEncode(_refused));
    await _set(SyncKeys.invalid, '${_refused.length}');
    await _set(SyncKeys.locked, jsonEncode([..._locked]));
    await _set(SyncKeys.ahead, jsonEncode(_ahead));
    await _set(SyncKeys.stale, jsonEncode([..._stale]));
  }

  Future<String?> _setting(String key) async {
    final row = await (_db.select(
      _db.kvSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    final raw = row.valueJson;
    if (!raw.startsWith('"')) return raw;
    try {
      final value = jsonDecode(raw);
      return value is String ? value : raw;
    } on FormatException {
      return raw.endsWith('"') ? raw.substring(1, raw.length - 1) : raw;
    }
  }

  Future<void> _set(String key, String value) => _db
      .into(_db.kvSettings)
      .insertOnConflictUpdate(
        KvSettingsCompanion.insert(
          key: key,
          valueJson: jsonEncode(value),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> _remove(String key) =>
      (_db.delete(_db.kvSettings)..where((s) => s.key.equals(key))).go();
}
