import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/platform/secret_store.dart';
import 'package:harvest/features/account/domain/account.dart';

class _Secrets implements SecretStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String? value) async =>
      value == null ? _values.remove(key) : _values[key] = value;
}

/// A server typed into the sign-in form is where that very sign-in
/// goes: the first tap used to reach an empty address and fail.
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
}
