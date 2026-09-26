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

  int get stored => _rows.length;
  Map<String, Object?>? row(String table, String key) => _rows[(table, key)];

  @override
  Future<({List<Map<String, Object?>> results, int cursor})> push(
    String deviceId,
    List<Map<String, Object?>> records,
  ) async {
    final results = <Map<String, Object?>>[];
    for (final record in records) {
      final id = (record['table']! as String, record['uuid']! as String);
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
