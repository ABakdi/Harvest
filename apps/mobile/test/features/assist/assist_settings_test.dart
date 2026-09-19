import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/assist/data/assist_settings.dart';
import 'package:harvest/features/assist/data/providers.dart';

class _MapSecrets implements SecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null || value.isEmpty) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

/// The key lives in the keystore and nowhere else
/// ([[ADR-013-Assist-Providers]]).
void main() {
  test('the key never reaches the settings table or the outbox', () async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final secrets = _MapSecrets();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(secrets),
      ],
    );
    addTearDown(container.dispose);

    expect(
      (await container.read(assistSettingsProvider.future)).ready,
      isFalse,
    );
    await container
        .read(assistSettingsProvider.notifier)
        .save(
          kind: AssistKind.gemini,
          model: '',
          baseUrl: '',
          apiKey: 'secret-key-123',
        );

    final config = await container.read(assistSettingsProvider.future);
    expect(config.ready, isTrue);
    expect(config.provider(), isA<GeminiProvider>());
    expect(secrets.values[AssistKeys.secretKey], 'secret-key-123');

    final rows = await db.select(db.kvSettings).get();
    expect(
      rows.map((r) => r.valueJson).join(),
      isNot(contains('secret-key-123')),
    );
    final logged = await db.select(db.outbox).get();
    expect(logged.map((r) => r.rowUuid), isNot(contains(AssistKeys.secretKey)));
  });
}
