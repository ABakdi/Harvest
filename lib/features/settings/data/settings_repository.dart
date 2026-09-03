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

  /// Every value is stored as JSON. Reads are tolerant: a number or a
  /// bool written by an older version still comes back as its text.
  static String? _asText(String valueJson) {
    try {
      final value = jsonDecode(valueJson);
      return value?.toString();
    } on FormatException {
      return valueJson;
    }
  }

  /// Watches one setting; emits `null` while unset.
  Stream<String?> watchString(String key) {
    final query = _db.select(_db.kvSettings)..where((s) => s.key.equals(key));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _asText(row.valueJson),
    );
  }

  /// One-shot read; null when the key was never set.
  Future<String?> getString(String key) async {
    final row = await (_db.select(
      _db.kvSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row == null ? null : _asText(row.valueJson);
  }

  Future<bool?> getBool(String key) async => switch (await getString(key)) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  Future<int?> getInt(String key) async =>
      int.tryParse(await getString(key) ?? '');

  /// A stored "HH:mm" as (hour, minute); null when unset or malformed.
  Future<(int, int)?> getTime(String key) async =>
      parseTime(await getString(key));

  /// "HH:mm" → (hour, minute), tolerant of a missing zero pad.
  static (int, int)? parseTime(String? raw) {
    final parts = (raw ?? '').split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour, minute);
  }

  /// The one encoding for times: zero-padded "HH:mm".
  static String formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Watches several settings at once; absent keys are simply missing.
  Stream<Map<String, String>> watchAll(List<String> keys) {
    final query = _db.select(_db.kvSettings)..where((s) => s.key.isIn(keys));
    return query.watch().map(
      (rows) => {
        for (final row in rows) row.key: ?_asText(row.valueJson),
      },
    );
  }

  Future<void> setString(String key, String value) => _db
      .into(_db.kvSettings)
      .insertOnConflictUpdate(
        KvSettingsCompanion.insert(
          key: key,
          valueJson: jsonEncode(value),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> setBool(String key, {required bool value}) =>
      setString(key, '$value');

  Future<void> setInt(String key, int value) => setString(key, '$value');

  Future<void> setTime(String key, int hour, int minute) =>
      setString(key, formatTime(hour, minute));

  /// Forgets a setting.
  Future<void> remove(String key) =>
      (_db.delete(_db.kvSettings)..where((s) => s.key.equals(key))).go();
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(databaseProvider));
