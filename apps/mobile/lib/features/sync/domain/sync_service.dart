import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/account/data/api_client.dart'
    show ApiException;
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/goals/data/goals_repository.dart';
import 'package:harvest/features/sync/domain/row_codec.dart';
import 'package:harvest/features/sync/domain/sync_cipher.dart';
import 'package:uuid/uuid.dart';

/// The server, as sync needs it: two verbs ([[Sync-API]]). The real one
/// goes through the API client; the tests use one in memory.
abstract interface class SyncRemote {
  /// [keyEpoch] names the key the batch's sealed records were made
  /// under; the server refuses them (`key_changed`) when it is stale.
  Future<({List<Map<String, Object?>> results, int cursor})> push(
    String deviceId,
    List<Map<String, Object?>> records, {
    int? keyEpoch,
  });

  /// With [deviceId], the server leaves out what this device wrote itself.
  Future<({List<Map<String, Object?>> records, int cursor, bool more})> pull(
    int after,
    int limit, {
    String? deviceId,
  });

  /// Says this device has sent every row it holds sealed under the key of
  /// [keyEpoch] (`POST /v1/sync/sealed`); the server deletes the rows it
  /// still kept in the clear, and answers how many went.
  Future<int> sealed(String deviceId, int keyEpoch);
}

/// The biggest push body, in bytes of its JSON (`maxPushBytes` in
/// `packages/contracts/src/sync.ts`): a batch is filled up to it.
const int maxPushBytes = 4 * 1024 * 1024;

/// A sealed write the server refused for a stale key epoch: the PIN was
/// started over on another device, and the key here is the old one.
class SyncKeyChanged implements Exception {
  const SyncKeyChanged();
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

  /// Rows waiting for a sync PIN: every row, since Phase 7, because
  /// nothing leaves the phone unsealed.
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

  /// Written before Phase 7, when the plain rows went up once on their
  /// own; kept so a join still marks the history as sent.
  static const snapshotDone = 'sync.snapshotDone';
  static const lastSyncedAt = 'sync.lastSyncedAt';
  static const invalid = 'sync.invalid';

  /// Whether every row has been sent once, sealed. Set false when a PIN
  /// is first given, so the history that waited for it goes up.
  static const privateSnapshotDone = 'sync.privateSnapshotDone';

  /// The key epoch the last full sealed send was made under. A phone
  /// from before Phase 7 has none, and so sends everything again, sealed,
  /// once ([[Phase-7-Privacy-and-Currencies]], M7.1).
  static const snapshotEpoch = 'sync.snapshotEpoch';

  /// The key epoch this phone has told the server it has sealed every
  /// row under (`POST /v1/sync/sealed`), so it is said once per key.
  static const sealedEpoch = 'sync.sealedEpoch';

  /// The clock each day of the trail last went up or came down with,
  /// Harvest Day to instant: the next copy of that day is stamped after
  /// it ([[SyncService]], the trail).
  static const trailClocks = 'sync.trailClocks';

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

  /// The history is being pulled again from nothing: the pulls ask for
  /// this device's own writes too, until they are through.
  static const rebuild = 'sync.rebuild';

  /// Set on signing in on a phone that already holds data of its own:
  /// nothing syncs until I say whether it goes into the account or the
  /// account's data replaces it (U6-05).
  static const joinPending = 'sync.joinPending';

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

  /// The key for this run; null until a sync PIN is set, and then nothing
  /// leaves the phone ([[Sync-API]]).
  SyncCipher? _cipher;
  late final Map<String, TableCodec> _codecs = codecsOf(_db);

  static const batch = 500;

  Future<SyncReport>? _running;

  // The run's bookkeeping, read at its start and written as it goes.
  var _trailClocks = <String, String>{};
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
      await _set(SyncKeys.rebuild, 'true');
    }
    _rebuilding = await _setting(SyncKeys.rebuild) == 'true';
    var pulled = await _pullAll();
    final cipher = _cipher;
    if (cipher != null &&
        (await _setting(SyncKeys.privateSnapshotDone) != 'true' ||
            await _setting(SyncKeys.snapshotEpoch) != '${cipher.epoch}')) {
      await _snapshot();
      await _set(SyncKeys.privateSnapshotDone, 'true');
      await _set(SyncKeys.snapshotEpoch, '${cipher.epoch}');
    }
    final pushed = await _pushOutbox();
    pulled += await _pullAll();
    await _saveBook();
    if (cipher != null) await _confirmSealed(cipher);
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
    final device = await deviceId();
    var merged = 0;
    while (true) {
      // What this device wrote itself it has; only a history pulled
      // again from nothing asks for its own writes back.
      final page = await _remote.pull(
        cursor,
        batch,
        deviceId: _rebuilding ? null : device,
      );
      await _db.transaction(() async {
        // One read of the outbox for the whole page, not one per row
        // (P6-06).
        _pagePending = await _pendingFor(page.records);
        try {
          for (final record in page.records) {
            if (await merge(record)) merged++;
          }
        } finally {
          _pagePending = null;
        }
      });
      cursor = page.cursor;
      await _set(SyncKeys.cursor, '$cursor');
      await _saveBook();
      if (!page.more) {
        if (_rebuilding) {
          _rebuilding = false;
          await _remove(SyncKeys.rebuild);
        }
        return merged;
      }
    }
  }

  /// Pulling the history again from nothing: this device's own writes
  /// come back too.
  var _rebuilding = false;

  /// Applies one pulled record by the server's own rule: a local row
  /// missing, or older, is overwritten; anything else stays. Returns
  /// whether anything changed.
  @visibleForTesting
  Future<bool> merge(Map<String, Object?> record) async {
    if (record['table'] == trailTable) return _mergeTrail(record);
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
    final paged = _pagePending;
    final pending = paged != null
        ? paged[id]
        : await _pendingSince(codec.name, key);
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
    // A row stored in the clear before Phase 7 comes as `data`, and is
    // taken as it always was; the next full send seals it.
    if (envelope is Map<String, Object?>) {
      // Ciphertext waits for the PIN ([[Sync-API]]); setting it re-pulls
      // everything, so nothing waiting is lost.
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
    // A path into this phone's storage that could lead out of it is not
    // taken (S6-08); the contract refuses it on push too.
    final pathColumn = switch (codec.name) {
      'memories' => 'path',
      'note_attachments' => 'storedPath',
      _ => null,
    };
    if (pathColumn != null) {
      final path = data[pathColumn];
      if (path is String && !GalleryStorage.isSafeRelative(path)) {
        debugPrint('[sync] refused a ${codec.name} row with an unsafe path');
        return false;
      }
    }

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

  /// The newest pending change per `table/key` of a page's records.
  Map<String, DateTime>? _pagePending;

  Future<Map<String, DateTime>> _pendingFor(
    List<Map<String, Object?>> records,
  ) async {
    final keys = {
      for (final record in records)
        if (record['uuid'] is String) record['uuid']! as String,
    }.toList();
    final newest = <String, DateTime>{};
    for (var i = 0; i < keys.length; i += 500) {
      final chunk = keys.sublist(
        i,
        i + 500 > keys.length ? keys.length : i + 500,
      );
      final rows = await (_db.select(
        _db.outbox,
      )..where((o) => o.rowUuid.isIn(chunk))).get();
      for (final row in rows) {
        final id = '${row.targetTable}/${row.rowUuid}';
        final seen = newest[id];
        if (seen == null || row.queuedAt.isAfter(seen)) {
          newest[id] = row.queuedAt;
        }
      }
    }
    return newest;
  }

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

  /// A device's first sync with a key sends every row it has, sealed:
  /// the outbox is an increment, and rows written before any account
  /// existed may have been capped out of it ([[ADR-005-Local-First-Sync]]).
  /// So does a phone from before Phase 7, once, to replace what it had
  /// sent in the clear; its files are asked about again too, under their
  /// new names.
  Future<void> _snapshot() async {
    final now = _clock();
    await _set(SyncKeys.checkFiles, 'true');
    for (final codec in _codecs.values) {
      final List<Map<String, Object?>> records;
      if (codec.name == pointTable) {
        // Every day goes whole now, so what the outbox held of the trail
        // has gone with it.
        await (_db.delete(
          _db.outbox,
        )..where((o) => o.targetTable.isIn([pointTable, trailTable]))).go();
        records = [
          for (final day in await _trailDays()) await _trailRecord(day),
        ];
      } else {
        records = await _snapshotOf(codec, now);
      }
      final results = await _send(await deviceId(), records);
      // A refused row is flagged like any refused change, so it is
      // counted rather than lost behind a finished snapshot (Q5-54).
      for (final result in results) {
        if (result['status'] == 'invalid') _refuse(result);
      }
      if (_keyChangedIn(results)) throw const SyncKeyChanged();
    }
  }

  /// Every row of [codec] that may leave, sealed.
  Future<List<Map<String, Object?>>> _snapshotOf(
    TableCodec codec,
    DateTime now,
  ) async {
    final rows = await codec.readAll(_db);
    final records = <Map<String, Object?>>[];
    for (var row in rows) {
      final key = codec.keyOf(row);
      if (!codec.mayLeave(key)) continue;
      if (codec.has('updated_at')) {
        // Sealed under a new key, a row must win over its own copy
        // sealed under the old one, which has the same clock: moved on
        // by a microsecond, it does, and loses to anything newer.
        final clock = codec.clockOf(row, now);
        final moved = clock.add(const Duration(microseconds: 1));
        await codec.restamp(_db, key, moved);
        row = await codec.read(_db, key) ?? row;
        // A clock pulled from ahead of this phone's has moved on with
        // it, so the next edit here still comes after (Q5-10).
        final id = '${codec.name}/$key';
        if (_ahead.containsKey(id)) _ahead[id] = isoUtc(moved);
      }
      records.add(await _record(codec, key, row, now));
    }
    return records;
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
      // The trail goes a day at a time, packed now, never a point at a
      // time ([[Phase-7-Privacy-and-Currencies]], M7.3).
      final days = <String, List<int>>{};
      for (final entry in latest.entries) {
        final (table, key) = entry.key;
        if (table != pointTable && table != trailTable) continue;
        final seqs = [
          for (final r in rows)
            if (r.targetTable == table && r.rowUuid == key) r.seq,
        ];
        if (_cipher == null) {
          heldBack++;
          continue;
        }
        final day = table == trailTable ? key : await _dayOfPoint(key);
        if (day == null) {
          // A point gone for good that no day remembers: nothing to send.
          await _drop(seqs);
          continue;
        }
        (days[day] ??= []).addAll(seqs);
      }
      for (final MapEntry(key: day, value: seqs) in days.entries) {
        final record = await _trailRecord(day);
        records.add(record);
        sent[(trailTable, record['uuid']! as String)] = seqs;
      }
      for (final entry in latest.entries) {
        final (table, key) = entry.key;
        if (table == pointTable || table == trailTable) continue;
        final codec = _codecs[table];
        final seqs = [
          for (final r in rows)
            if (r.targetTable == table && r.rowUuid == key) r.seq,
        ];
        if (codec == null || !codec.mayLeave(key)) {
          await _drop(seqs);
          continue;
        }
        // Nothing leaves unsealed: without a key every change waits.
        if (_cipher == null) {
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

      final results = await _send(device, records);
      final done = <int>[];
      var keyChanged = false;
      for (final result in results) {
        final id = (result['table']! as String, result['uuid']! as String);
        final seqs = sent[id] ?? const <int>[];
        final status = result['status'];
        if (status == 'invalid' &&
            _codesOf(result['issues']).contains('key_changed')) {
          // Sealed under a key started over elsewhere: it stays queued,
          // and goes again under the new key.
          keyChanged = true;
          continue;
        }
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
        done.addAll(seqs);
      }
      // One statement for the page's answered changes (P6-12).
      await _drop(done);
      if (keyChanged) {
        await _saveBook();
        throw const SyncKeyChanged();
      }
    }
    await _saveBook();
    return (pushed: pushed, invalid: invalid, heldBack: heldBack);
  }

  bool _keyChangedIn(List<Map<String, Object?>> results) => results.any(
    (result) => _codesOf(result['issues']).contains('key_changed'),
  );

  /// Sends [records] in batches filled up to [maxPushBytes] and at most
  /// [batch] records (Q6-03). A batch the server still finds too large
  /// (413) is halved; a single record too large for any push is refused
  /// here, with a reason, rather than blocking every change behind it.
  Future<List<Map<String, Object?>>> _send(
    String device,
    List<Map<String, Object?>> records,
  ) async {
    final results = <Map<String, Object?>>[];
    var chunk = <Map<String, Object?>>[];
    var bytes = 0;
    Future<void> flush() async {
      if (chunk.isEmpty) return;
      results.addAll(await _pushHalving(device, chunk));
      chunk = [];
      bytes = 0;
    }

    for (final record in records) {
      final size = utf8.encode(jsonEncode(record)).length + 1;
      if (size > maxPushBytes - 1024) {
        results.add(_tooLarge(record));
        continue;
      }
      if (chunk.length >= batch || bytes + size > maxPushBytes - 1024) {
        await flush();
      }
      chunk.add(record);
      bytes += size;
    }
    await flush();
    return results;
  }

  Future<List<Map<String, Object?>>> _pushHalving(
    String device,
    List<Map<String, Object?>> records,
  ) async {
    final sealed = records.any((record) => record['enc'] != null);
    try {
      final answer = await _remote.push(
        device,
        records,
        keyEpoch: sealed ? _cipher?.epoch : null,
      );
      return answer.results;
    } on ApiException catch (error) {
      if (error.status != 413) rethrow;
      if (records.length == 1) return [_tooLarge(records.single)];
      final half = records.length ~/ 2;
      return [
        ...await _pushHalving(device, records.sublist(0, half)),
        ...await _pushHalving(device, records.sublist(half)),
      ];
    }
  }

  Map<String, Object?> _tooLarge(Map<String, Object?> record) => {
    'table': record['table'],
    'uuid': record['uuid'],
    'status': 'invalid',
    'issues': [
      {
        'path': <String>[],
        'message': 'Too large for one push',
        'code': 'too_large',
      },
    ],
  };

  Future<void> _drop(List<int> seqs) async {
    for (var i = 0; i < seqs.length; i += 500) {
      final chunk = seqs.sublist(
        i,
        i + 500 > seqs.length ? seqs.length : i + 500,
      );
      await (_db.delete(_db.outbox)..where((o) => o.seq.isIn(chunk))).go();
    }
  }

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
    final cipher = _cipher!;
    final updatedAt = isoUtc(codec.clockOf(row, queuedAt));
    final deletedAt = data['deletedAt'] as String?;
    final file = codec.fileHashOf(row);
    return {
      'table': codec.name,
      'uuid': key,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
      // The clocks stay in the clear, because the server's conflict rule
      // needs them, and are bound into the seal; everything else is
      // sealed.
      'enc': await cipher.seal(codec.name, key, (
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      ), data),
      // The file's name on the server, so it can tell the file is still
      // wanted; it says nothing of what the file is.
      if (file != null) 'file': await cipher.nameOf(file),
    };
  }

  /// Once every row this phone holds has gone up sealed under this key
  /// and nothing waits, the server is told, and deletes what it still
  /// kept in the clear from before Phase 7. Said once per key epoch. A
  /// row refused for good (too large, say) does not hold it up; one
  /// refused for a reason that passes (no room, a clock ahead) does,
  /// until it has gone.
  Future<void> _confirmSealed(SyncCipher cipher) async {
    if (await _setting(SyncKeys.sealedEpoch) == '${cipher.epoch}') return;
    if (await _setting(SyncKeys.snapshotEpoch) != '${cipher.epoch}') return;
    final waiting = await (_db.select(_db.outbox)..limit(1)).getSingleOrNull();
    if (waiting != null) return;
    final passing = _refused.values.any(
      (refusal) => _codesOf(refusal).any(passingRefusals.contains),
    );
    if (passing) return;
    try {
      final dropped = await _remote.sealed(await deviceId(), cipher.epoch);
      if (dropped > 0) {
        debugPrint('[sync] sealed; the server let go of $dropped plain rows');
      }
      await _set(SyncKeys.sealedEpoch, '${cipher.epoch}');
    } on ApiException catch (error) {
      if (error.code == 'key_changed') throw const SyncKeyChanged();
      // Asked again on the next run.
      debugPrint('[sync] could not say sealed: ${error.code}');
    }
  }

  // --------------------------------------------------------------- trail

  /// The trail's table on the phone: a row a point. It is not sent any
  /// more; a push of it is refused (`retired_table`).
  static const pointTable = 'location_points';

  /// The trail on the wire: a record a day, sealed, keyed by
  /// [SyncCipher.trailKeyOf]. It has no table of its own here.
  static const trailTable = 'trail_days';

  /// The Harvest Day of a point, or null when the point is gone.
  Future<String?> _dayOfPoint(String uuid) async {
    final rows = await _db
        .customSelect(
          'SELECT harvest_day FROM location_points WHERE uuid = ?',
          variables: [Variable(uuid)],
        )
        .get();
    return rows.isEmpty ? null : rows.first.data['harvest_day'] as String?;
  }

  /// Every day the trail has a point on.
  Future<List<String>> _trailDays() async => [
    for (final row
        in await _db
            .customSelect(
              'SELECT DISTINCT harvest_day FROM location_points '
              'ORDER BY harvest_day',
            )
            .get())
      row.data['harvest_day']! as String,
  ];

  /// The clock a day of the trail goes up with: the hour it is, so the
  /// server sees a day change at most once an hour, and always after the
  /// last clock that day went up or came down with.
  DateTime _trailClock(String day) {
    final now = _clock().toUtc();
    final hour = DateTime.utc(now.year, now.month, now.day, now.hour);
    final last = DateTime.tryParse(_trailClocks[day] ?? '');
    if (last == null || hour.isAfter(last)) return hour;
    return last.add(const Duration(seconds: 1));
  }

  /// A day of the trail as one sealed record: every point of it, deleted
  /// ones too, so a delete travels; a tombstone when none is left.
  Future<Map<String, Object?>> _trailRecord(String day) async {
    final cipher = _cipher!;
    final key = await cipher.trailKeyOf(day);
    final at = _trailClock(day);
    _trailClocks[day] = isoUtc(at);
    final codec = _codecs[pointTable]!;
    final rows = await _db
        .customSelect(
          'SELECT * FROM location_points WHERE harvest_day = ? '
          'ORDER BY recorded_at',
          variables: [Variable(day)],
        )
        .get();
    if (rows.isEmpty) return _tombstone(trailTable, key, at);
    final updatedAt = isoUtc(at);
    final data = {
      'key': key,
      'harvestDay': day,
      'points': [
        for (final row in rows) codec.toData(row.data)..remove('harvestDay'),
      ],
      'updatedAt': updatedAt,
    };
    return {
      'table': trailTable,
      'uuid': key,
      'updatedAt': updatedAt,
      'deletedAt': null,
      'enc': await cipher.seal(trailTable, key, (
        updatedAt: updatedAt,
        deletedAt: null,
      ), data),
    };
  }

  /// The day a trail key names, among the days the trail has here.
  Future<String?> _dayOfTrailKey(SyncCipher cipher, String key) async {
    for (final day in await _trailDays()) {
      if (await cipher.trailKeyOf(day) == key) return day;
    }
    return null;
  }

  /// Takes a day of the trail point by point: a point missing here, or
  /// older here, is written; a point the copy lacks is kept, because only
  /// its own `deletedAt` removes it. When this phone holds anything the
  /// copy does not, the day goes up again, so the copies converge.
  Future<bool> _mergeTrail(Map<String, Object?> record) async {
    final key = record['uuid'];
    final updatedAt = record['updatedAt'];
    final cipher = _cipher;
    if (key is! String || updatedAt is! String || cipher == null) return false;
    final id = '$trailTable/$key';
    _stale.remove(id);
    if (record['purged'] == true) {
      final day = await _dayOfTrailKey(cipher, key);
      if (day == null) return false;
      await _db.customUpdate(
        'DELETE FROM location_points WHERE harvest_day = ?',
        variables: [Variable(day)],
        updates: {_db.locationPoints},
        updateKind: UpdateKind.delete,
      );
      _seenTrail(day, updatedAt);
      return true;
    }
    final envelope = record['enc'];
    if (envelope is! Map<String, Object?>) return false;
    final Map<String, Object?> data;
    try {
      data = await cipher.open(trailTable, key, (
        updatedAt: updatedAt,
        deletedAt: null,
      ), envelope);
      final day = data['harvestDay'];
      if (data['key'] != key ||
          day is! String ||
          await cipher.trailKeyOf(day) != key ||
          !sameInstant(data['updatedAt'] as String?, updatedAt) ||
          data['points'] is! List) {
        throw const UnreadableRow('not the day its key names');
      }
    } on UnreadableRow catch (unreadable) {
      debugPrint('[sync] locked a day of the trail: ${unreadable.reason}');
      _locked.add(id);
      return false;
    }
    _locked.remove(id);
    final day = data['harvestDay']! as String;
    _seenTrail(day, updatedAt);
    final codec = _codecs[pointTable]!;
    final theirs = <String, DateTime>{};
    var changed = false;
    for (final point in data['points']! as List<Object?>) {
      if (point is! Map<String, Object?>) continue;
      final uuid = point['uuid'];
      final at = DateTime.tryParse('${point['updatedAt']}');
      if (uuid is! String || at == null) continue;
      theirs[uuid] = at;
      final local = await codec.read(_db, uuid);
      if (local != null && !at.isAfter(codec.clockOf(local, at))) continue;
      await codec.upsert(_db, {...point, 'harvestDay': day});
      changed = true;
    }
    // Anything here the copy lacks, or has older, goes up again.
    final mine = await _db
        .customSelect(
          'SELECT * FROM location_points WHERE harvest_day = ?',
          variables: [Variable(day)],
        )
        .get();
    final ahead = mine.any((row) {
      final at = theirs[row.data['uuid']];
      return at == null || codec.clockOf(row.data, at).isAfter(at);
    });
    if (ahead) await _db.logChange(trailTable, day, 'update');
    return changed;
  }

  /// A day of the trail came down with [at]: the next copy sent goes
  /// after it.
  void _seenTrail(String day, String at) {
    final seen = DateTime.tryParse(at);
    final last = DateTime.tryParse(_trailClocks[day] ?? '');
    if (seen != null && (last == null || seen.isAfter(last))) {
      _trailClocks[day] = isoUtc(seen);
    }
  }

  /// Whether a change waits in the outbox to go up sealed.
  Future<bool> privatePending() async {
    final row = await (_db.select(_db.outbox)..limit(1)).getSingleOrNull();
    return row != null;
  }

  /// A PIN was just given: pull the whole history again, to open the
  /// rows the earlier pulls had to leave, and send this phone's own rows
  /// once.
  ///
  /// Every row goes up again, and every file is asked about again, under
  /// the key just set: after the PIN was started over (here or on another
  /// device) the server has none of them.
  Future<void> privateTierOpened() async {
    await _set(SyncKeys.cursor, '0');
    await _set(SyncKeys.rebuild, 'true');
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

  /// The tables whose rows are something I made, not the app's own
  /// scaffolding (built-in lists, streak rows, settings).
  static const _ownDataTables = [
    'commitments',
    'check_ins',
    'seed_notes',
    'notes',
    'goals',
    'expenses',
    'money_txns',
    'debts',
    'memories',
    'sleep_sessions',
    'body_weights',
    'workout_sessions',
    'wishlist_items',
    'saved_places',
  ];

  /// Holds sync until I say what becomes of this phone's own data, or
  /// lets it go on (U6-05).
  Future<void> holdForJoin({required bool hold}) =>
      hold ? _set(SyncKeys.joinPending, 'true') : _remove(SyncKeys.joinPending);

  Future<bool> joinPending() async =>
      await _setting(SyncKeys.joinPending) == 'true';

  /// Whether this phone holds data of its own: what a sign-in would bring
  /// into the account.
  Future<bool> hasLocalData() async {
    for (final table in _ownDataTables) {
      final rows = await _db
          .customSelect('SELECT 1 FROM "$table" LIMIT 1')
          .get();
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  /// Empties every synced table and the outbox, so the account's data
  /// comes down alone. Settings stay: they are this phone's. Only called
  /// once an archive of what was here has been saved (U6-05).
  Future<void> forgetLocalData() async {
    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await _db.transaction(() async {
        for (final codec in _codecs.values) {
          if (codec.name == 'kv_settings') continue;
          await _db.customStatement('DELETE FROM "${codec.name}"');
        }
        await _db.delete(_db.outbox).go();
      });
    } finally {
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }
    await _db.seedBuiltInLists();
    await _set(SyncKeys.cursor, '0');
    await _set(SyncKeys.snapshotDone, 'true');
    await _set(SyncKeys.privateSnapshotDone, 'true');
  }

  /// Forgets where sync was: signing out, or into another account.
  Future<void> reset() async {
    for (final key in [
      SyncKeys.cursor,
      SyncKeys.snapshotDone,
      SyncKeys.lastSyncedAt,
      SyncKeys.invalid,
      SyncKeys.privateSnapshotDone,
      SyncKeys.snapshotEpoch,
      SyncKeys.sealedEpoch,
      SyncKeys.trailClocks,
      SyncKeys.refused,
      SyncKeys.locked,
      SyncKeys.ahead,
      SyncKeys.stale,
      SyncKeys.rebuild,
      SyncKeys.joinPending,
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

    final trail = json(await _setting(SyncKeys.trailClocks));
    _trailClocks = {
      if (trail is Map<String, Object?>)
        for (final MapEntry(:key, :value) in trail.entries)
          if (value is String) key: value,
    };
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
    await _set(SyncKeys.trailClocks, jsonEncode(_trailClocks));
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
