import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/platform/secret_store.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';

class _Secrets implements SecretStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String? value) async =>
      value == null ? _values.remove(key) : _values[key] = value;
}

/// The server's address is built into the app ([[Checkpoint-12]]
/// B12-02): every request goes there from the first one, and an address
/// typed into an earlier version is let go.
void main() {
  ProviderContainer containerOf(HarvestDatabase db) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(_Secrets()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('every request goes to the built-in server', () async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = containerOf(db);
    expect(harvestServerUrl, 'https://harvest.abakdi.com');
    expect(
      container.read(apiClientProvider).baseUrl(),
      Uri.parse('https://harvest.abakdi.com'),
    );
    final account = await container.read(accountControllerProvider.future);
    expect(account.serverUrl, harvestServerUrl);
  });

  test('an address kept by an earlier version is let go', () async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final settings = SettingsRepository(db);
    await settings.setString(
      AccountKeys.serverUrl,
      'https://harvest.example.org',
    );
    final container = containerOf(db);
    await container.read(accountControllerProvider.future);
    expect(await settings.getString(AccountKeys.serverUrl), isNull);
    expect(
      container.read(apiClientProvider).baseUrl().host,
      'harvest.abakdi.com',
    );
  });
}
