import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/platform/secret_store.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Secrets implements SecretStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String? value) async =>
      value == null ? _values.remove(key) : _values[key] = value;
}

/// The sync and file routes are paced per account: a `429` is waited
/// out, as long as `Retry-After` says, rather than failing the sync.
void main() {
  ApiClient client(
    List<http.Response> answers,
    List<Duration> waited,
  ) {
    var asked = 0;
    return ApiClient(
      baseUrl: () => Uri.parse('https://harvest.example.org'),
      tokens: TokenStore(_Secrets())..access = 'token',
      client: MockClient((_) async => answers[asked++]),
      pause: (wait) async => waited.add(wait),
    );
  }

  test('waits as long as Retry-After says, then asks again', () async {
    final waited = <Duration>[];
    final api = client([
      http.Response('{}', 429, headers: {'retry-after': '7'}),
      http.Response('{"records":[],"cursor":0,"more":false}', 200),
    ], waited);
    final json = await api.get('/v1/sync/pull');
    expect(json['more'], isFalse);
    expect(waited, [const Duration(seconds: 7)]);
  });

  test('never waits past a minute, and gives up after a few tries', () async {
    final waited = <Duration>[];
    final slow = http.Response(
      '{"error":{"code":"rate_limited","message":"slow down"}}',
      429,
      headers: {'retry-after': '3600'},
    );
    final api = client([slow, slow, slow, slow], waited);
    await expectLater(
      api.post('/v1/files/missing', {'hashes': <String>[]}),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 429)),
    );
    expect(waited, [ApiClient.longestWait, ApiClient.longestWait]);
  });
}
