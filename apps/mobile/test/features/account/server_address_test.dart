import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/platform/secret_store.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
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

/// A server typed into the sign-in form is where that very sign-in
/// goes: the first tap used to reach an empty address and fail. And
/// signing in again after a session ended, to the server already saved:
/// the first request of a start must go to that server, not to the
/// built-in default, even when nothing had asked for the address yet.
void main() {
  test('a new server address is used at once', () async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(_Secrets()),
      ],
    );
    addTearDown(container.dispose);
    final api = container.read(apiClientProvider);
    await container.read(accountControllerProvider.future);

    // Not waited for: the database answers on its own time, and the
    // request right after must not depend on it.
    final saving = container
        .read(accountControllerProvider.notifier)
        .setServerUrl(' https://harvest.example.com ');
    expect(api.baseUrl(), Uri.parse('https://harvest.example.com'));
    await saving;
    expect(api.baseUrl(), Uri.parse('https://harvest.example.com'));
  });

  test('a request waits for the saved address to be read', () async {
    final address = ServerAddress();
    final asked = <Uri>[];
    final api = ApiClient(
      baseUrl: () => address.value,
      ready: () => address.loaded.future,
      tokens: TokenStore(_Secrets()),
      client: MockClient((request) async {
        asked.add(request.url);
        return http.Response('{"ok":true}', 200);
      }),
    );
    final sent = api.postAnonymous('/v1/auth/login', {'email': 'a@b.co'});
    await Future<void>.delayed(Duration.zero);
    expect(asked, isEmpty, reason: 'nothing goes before the address');
    address.set('https://harvest.example.org');
    await sent;
    expect(
      asked.single.toString(),
      'https://harvest.example.org/v1/auth/login',
    );
  });

  test('the provider reads the saved address before it is used', () async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await SettingsRepository(
      db,
    ).setString(AccountKeys.serverUrl, 'https://harvest.example.org');
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(_Secrets()),
      ],
    );
    addTearDown(container.dispose);
    final address = container.read(serverAddressProvider);
    await address.loaded.future;
    expect(address.value.host, 'harvest.example.org');
  });
}
