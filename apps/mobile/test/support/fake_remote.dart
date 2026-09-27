import 'dart:typed_data';

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

  /// Records the next push will refuse, by table.
  final refuse = <String>{};

  /// Every record ever offered, as `table/uuid`, in order.
  final offered = <String>[];

  int get stored => _rows.length;

  /// Drops every record of [tables], as starting the PIN over does on
  /// the server.
  void dropTables(Set<String> tables) {
    _rows.removeWhere((id, _) => tables.contains(id.$1));
    _bySeq.removeWhere((_, id) => tables.contains(id.$1));
  }

  Map<String, Object?>? row(String table, String key) => _rows[(table, key)];

  @override
  Future<({List<Map<String, Object?>> results, int cursor})> push(
    String deviceId,
    List<Map<String, Object?>> records,
  ) async {
    final results = <Map<String, Object?>>[];
    for (final record in records) {
      final id = (record['table']! as String, record['uuid']! as String);
      offered.add('${id.$1}/${id.$2}');
      if (refuse.contains(id.$1)) {
        results.add({'table': id.$1, 'uuid': id.$2, 'status': 'invalid'});
        continue;
      }
      final stored = _rows[id];
      final incoming = DateTime.parse(record['updatedAt']! as String);
      if (stored != null &&
          !incoming.isAfter(DateTime.parse(stored['updatedAt']! as String))) {
        results.add({'table': id.$1, 'uuid': id.$2, 'status': 'stale'});
        continue;
      }
      final seq = ++_seq;
      _rows[id] = {...record, 'seq': seq};
      _bySeq.removeWhere((_, value) => value == id);
      _bySeq[seq] = id;
      results.add({'table': id.$1, 'uuid': id.$2, 'status': 'applied'});
    }
    return (results: results, cursor: _seq);
  }

  @override
  Future<({List<Map<String, Object?>> records, int cursor, bool more})> pull(
    int after,
    int limit,
  ) async {
    final seqs = _bySeq.keys.where((s) => s > after).toList()..sort();
    final page = seqs.take(limit).toList();
    return (
      records: [for (final s in page) _rows[_bySeq[s]]!],
      cursor: page.isEmpty ? after : page.last,
      more: seqs.length > limit,
    );
  }
}

/// The key routes in memory ([[Sync-API]], `contracts/sync-key.ts`): one
/// account's salt and key share, and the first key check a device
/// stores. [raced] stores another device's check just before this one's
/// arrives, as a second device choosing at the same moment would.
class FakeSyncKeys implements SyncKeyRemote {
  FakeSyncKeys({this.salt = 'the-account-salt', Uint8List? keyShare})
    : keyShare = keyShare ?? Uint8List.fromList(List.generate(32, (i) => i));

  final String salt;
  Uint8List keyShare;

  /// The account's password, for starting over.
  String password = 'the password';

  /// Told when the PIN is started over, to drop what the server kept.
  void Function()? onStartOver;
  Map<String, Object?>? check;
  Map<String, Object?>? raced;
  int fetches = 0;

  /// Set to make every call fail, as a server out of reach does.
  ApiException? failure;

  @override
  Future<SyncKeyShare> fetch() async {
    if (failure case final failure?) throw failure;
    fetches++;
    return SyncKeyShare(salt: salt, keyShare: keyShare, check: check);
  }

  @override
  Future<Map<String, Object?>?> putCheck(Map<String, Object?> sent) async {
    if (failure case final failure?) throw failure;
    if (raced case final other?) {
      check ??= other;
      raced = null;
    }
    if (check case final stored?) return stored;
    check = sent;
    return null;
  }

  @override
  Future<void> startOver(String given) async {
    if (failure case final failure?) throw failure;
    if (given != password) {
      throw const ApiException('forbidden', 403, 'Wrong password');
    }
    check = null;
    // A new share, as the server makes on the next ask.
    keyShare = Uint8List.fromList([for (final b in keyShare) (b + 101) % 256]);
    onStartOver?.call();
  }
}
