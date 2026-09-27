import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/db/portable_settings.dart';
import 'package:harvest/core/platform/secret_store.dart';
import 'package:harvest/features/assist/data/assist_settings.dart';
import 'package:harvest/features/assist/data/providers.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';

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

  test('the key goes only where it was saved for (S5-01)', () async {
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
    await container
        .read(assistSettingsProvider.notifier)
        .save(
          kind: AssistKind.openAiCompatible,
          model: 'llama',
          baseUrl: 'https://llm.example.org/v1',
          apiKey: 'secret-key-123',
        );
    expect(
      (await container.read(assistSettingsProvider.future)).apiKey,
      'secret-key-123',
    );

    // The base URL changed behind the sheet's back, as a synced or
    // imported row would have done it.
    await SettingsRepository(
      db,
    ).setString(AssistKeys.baseUrl, 'https://attacker.example/v1');
    container.invalidate(assistSettingsProvider);
    final moved = await container.read(assistSettingsProvider.future);
    expect(moved.apiKey, isNull);
    final provider = moved.provider();
    expect(
      provider is OpenAiCompatibleProvider ? provider.apiKey : null,
      anyOf(isNull, isEmpty),
    );

    // And the setting itself neither syncs nor imports.
    expect(isImportableSetting(AssistKeys.baseUrl), isFalse);
    expect(isImportableSetting(AssistKeys.provider), isFalse);
  });

  test('a key saved before keys were bound stays where it was', () async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final secrets = _MapSecrets()..values[AssistKeys.secretKey] = 'older-key';
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(secrets),
      ],
    );
    addTearDown(container.dispose);
    expect(
      (await container.read(assistSettingsProvider.future)).apiKey,
      'older-key',
    );
    expect(secrets.values[AssistKeys.secretKeyFor], 'gemini');
  });
}
