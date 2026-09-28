import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/sync/domain/sync_service.dart';

/// The server's sync rules in memory: last writer wins by `updatedAt`,
/// equal stamps are stale, every applied write takes the next sequence.
/// Two phones pointed at one of these converge the way two phones on
/// the real server do.
class FakeRemote implements SyncRemote {
  final _rows = <(String, String), Map<String, Object?>>{};
  var _seq = 0;
  final _bySeq = <int, (String, String)>{};
  final _writtenBy = <(String, String), String>{};

  /// Records the next push will refuse, by table.
  final refuse = <String>{};

  /// Every record ever offered, as `table/uuid`, in order.
  final offered = <String>[];

  /// The account's key epoch: a sealed record pushed under another one
  /// comes back `key_changed` ([[Sync-API]], S6-07).
  int Function() epoch = () => 1;

  /// Every push body's size in records, in order.
  final batches = <int>[];

  /// When set, a push of more records than this answers 413.
  int? tooLargeOver;

  int get stored => _rows.length;

  /// Drops every record of [tables], as starting the PIN over does on
  /// the server.
  void dropTables(Set<String> tables) {
    _rows.removeWhere((id, _) => tables.contains(id.$1));
    _bySeq.removeWhere((_, id) => tables.contains(id.$1));
  }

  /// Drops every record, as starting the PIN over does on the server
  /// now that every row is sealed.
  void dropAll() {
    _rows.clear();
    _bySeq.clear();
  }

  Map<String, Object?>? row(String table, String key) => _rows[(table, key)];

  /// Stores [record] as the server kept it before Phase 7 (in the clear,
  /// or a point of the trail sealed on its own), written by another
  /// device.
  void seedPlain(Map<String, Object?> record) {
    final id = (record['table']! as String, record['uuid']! as String);
    final seq = ++_seq;
    _rows[id] = {...record, 'seq': seq};
    _writtenBy[id] = 'a-device-from-before';
    _bySeq.removeWhere((_, value) => value == id);
    _bySeq[seq] = id;
  }

  /// The rows still kept in the clear.
  int get plain => _rows.values.where((row) => row['data'] != null).length;

  /// Every `POST /v1/sync/sealed`, as its key epoch, in order.
  final sealedCalls = <int>[];

  @override
  Future<int> sealed(String deviceId, int keyEpoch) async {
    if (keyEpoch != epoch()) throw const ApiException('key_changed', 409);
    sealedCalls.add(keyEpoch);
    final gone = [
      for (final MapEntry(:key, :value) in _rows.entries)
        if (value['data'] != null || key.$1 == 'location_points') key,
    ];
    for (final id in gone) {
      _rows.remove(id);
      _bySeq.removeWhere((_, value) => value == id);
    }
    return gone.length;
  }

  @override
  Future<({List<Map<String, Object?>> results, int cursor})> push(
    String deviceId,
    List<Map<String, Object?>> records, {
    int? keyEpoch,
  }) async {
    final over = tooLargeOver;
    if (over != null && records.length > over) {
      throw const ApiException('payload_too_large', 413);
    }
    batches.add(records.length);
    final results = <Map<String, Object?>>[];
    for (final record in records) {
      final id = (record['table']! as String, record['uuid']! as String);
      offered.add('${id.$1}/${id.$2}');
      if (refuse.contains(id.$1)) {
        results.add({'table': id.$1, 'uuid': id.$2, 'status': 'invalid'});
        continue;
      }
      if (id.$1 == 'location_points' && record['purged'] != true) {
        results.add({
          'table': id.$1,
          'uuid': id.$2,
          'status': 'invalid',
          'issues': [
            {
              'path': ['table'],
              'message': 'retired',
              'code': 'retired_table',
            },
          ],
        });
        continue;
      }
      if (record['data'] != null || record['enc'] == null) {
        if (record['purged'] != true) {
          results.add({
            'table': id.$1,
            'uuid': id.$2,
            'status': 'invalid',
            'issues': [
              {
                'path': ['data'],
                'message': 'travels sealed',
                'code': 'sealed_required',
              },
            ],
          });
          continue;
        }
      }
      if (record['enc'] != null && keyEpoch != epoch()) {
        results.add({
          'table': id.$1,
          'uuid': id.$2,
          'status': 'invalid',
          'issues': [
            {'path': <String>[], 'message': 'stale key', 'code': 'key_changed'},
          ],
        });
        continue;
      }
      final stored = _rows[id];
      final incoming = DateTime.parse(record['updatedAt']! as String);
      final storedAt = stored == null
          ? null
          : DateTime.parse(stored['updatedAt']! as String);
      // A sealed copy replaces one kept in the clear at the same clock.
      final sealsPlain =
          stored?['data'] != null &&
          record['enc'] != null &&
          !incoming.isBefore(storedAt!);
      if (stored != null && !sealsPlain && !incoming.isAfter(storedAt!)) {
        results.add({'table': id.$1, 'uuid': id.$2, 'status': 'stale'});
        continue;
      }
      final seq = ++_seq;
      _rows[id] = {...record, 'seq': seq};
      _writtenBy[id] = deviceId;
      _bySeq.removeWhere((_, value) => value == id);
      _bySeq[seq] = id;
      results.add({'table': id.$1, 'uuid': id.$2, 'status': 'applied'});
    }
    return (results: results, cursor: _seq);
  }

  /// Every pull's `deviceId`, in order.
  final pulledAs = <String?>[];

  @override
  Future<({List<Map<String, Object?>> records, int cursor, bool more})> pull(
    int after,
    int limit, {
    String? deviceId,
  }) async {
    pulledAs.add(deviceId);
    final seqs = _bySeq.keys.where((s) => s > after).toList()..sort();
    final page = seqs.take(limit).toList();
    return (
      records: [
        for (final s in page)
          // The device's own writes are left out, the cursor still moves.
          if (deviceId == null || _writtenBy[_bySeq[s]] != deviceId)
            _rows[_bySeq[s]]!,
      ],
      cursor: page.isEmpty ? after : page.last,
      more: seqs.length > limit,
    );
  }
}

/// The key routes in memory ([[Sync-API]], `contracts/sync-key.ts`): one
/// account's salt, key share, PIN verifier, key check and epoch, and the
/// limit on wrong tries. [raced] is another device's PIN, set just
/// before this one's arrives, as a second device choosing at the same
/// moment would.
class FakeSyncKeys implements SyncKeyRemote {
  FakeSyncKeys({this.salt = 'the-account-salt', Uint8List? keyShare})
    : keyShare = keyShare ?? Uint8List.fromList(List.generate(32, (i) => i));

  final String salt;
  Uint8List keyShare;
  String? verifier;
  Map<String, Object?>? check;
  int epoch = 1;
  ({String verifier, Map<String, Object?> check})? raced;

  /// The account's password, for starting over.
  String password = 'the password';

  /// Wrong tries allowed before the pause, and those made.
  int tries = 5;
  int wrong = 0;

  /// Told when the PIN is started over, to drop what the server kept.
  void Function()? onStartOver;
  int fetches = 0;

  /// Set to make every call fail, as a server out of reach does.
  ApiException? failure;

  @override
  Future<SyncKeyState> fetch() async {
    if (failure case final failure?) throw failure;
    fetches++;
    return SyncKeyState(
      salt: salt,
      epoch: epoch,
      keyShare: verifier == null ? keyShare : null,
    );
  }

  @override
  Future<SyncUnlock> unlock(String proof) async {
    if (failure case final failure?) throw failure;
    final stored = verifier;
    if (stored == null) throw const SyncPinChosen();
    if (wrong >= tries) {
      throw const SyncPinLimited(retryAfter: Duration(minutes: 15));
    }
    final digest = await Sha256().hash(base64Decode(proof));
    final hex = [
      for (final b in digest.bytes) b.toRadixString(16).padLeft(2, '0'),
    ].join();
    if (hex != stored) {
      wrong++;
      throw SyncPinRefused(triesLeft: tries - wrong);
    }
    wrong = 0;
    return (keyShare: keyShare, check: check!, epoch: epoch);
  }

  @override
  Future<int?> setPin(
    String sentVerifier,
    Map<String, Object?> sentCheck,
  ) async {
    if (failure case final failure?) throw failure;
    if (raced case final other?) {
      verifier ??= other.verifier;
      check ??= other.check;
      raced = null;
    }
    if (verifier != null) return null;
    verifier = sentVerifier;
    check = sentCheck;
    return epoch;
  }

  @override
  Future<void> startOver(String given) async {
    if (failure case final failure?) throw failure;
    if (given != password) {
      throw const ApiException('forbidden', 403, 'Wrong password');
    }
    verifier = null;
    check = null;
    epoch++;
    // A new share, as the server makes on the next ask.
    keyShare = Uint8List.fromList([for (final b in keyShare) (b + 101) % 256]);
    onStartOver?.call();
  }
}
