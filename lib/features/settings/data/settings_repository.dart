import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_repository.g.dart';

/// Well-known settings keys.
abstract final class SettingKeys {
  static const themeMode = 'themeMode';
  static const locale = 'locale';
}

/// Reactive key-value settings on top of the local database.
class SettingsRepository {
  SettingsRepository(this._db);

  final HarvestDatabase _db;

  /// Watches one setting; emits `null` while unset.
  Stream<String?> watchString(String key) {
    final query = _db.select(_db.kvSettings)..where((s) => s.key.equals(key));
    return query
        .watchSingleOrNull()
        .map((row) => row == null ? null : jsonDecode(row.valueJson) as String);
  }

  /// One-shot read; null when the key was never set.
  Future<String?> getString(String key) async {
    final row = await (_db.select(_db.kvSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row == null ? null : jsonDecode(row.valueJson) as String?;
  }

  /// Watches several settings at once; absent keys are simply missing.
  Stream<Map<String, String>> watchAll(List<String> keys) {
    final query = _db.select(_db.kvSettings)..where((s) => s.key.isIn(keys));
    return query.watch().map(
          (rows) => {
            for (final row in rows)
              row.key: jsonDecode(row.valueJson).toString(),
          },
        );
  }

  Future<void> setString(String key, String value) =>
      _db.into(_db.kvSettings).insertOnConflictUpdate(
            KvSettingsCompanion.insert(
              key: key,
              valueJson: jsonEncode(value),
              updatedAt: Value(DateTime.now()),
            ),
          );
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(databaseProvider));
