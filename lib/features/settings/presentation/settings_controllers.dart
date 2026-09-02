import 'package:flutter/material.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_controllers.g.dart';

/// The persisted theme mode; defaults to following the system.
@Riverpod(keepAlive: true)
class ThemeModeSetting extends _$ThemeModeSetting {
  @override
  Stream<ThemeMode> build() =>
      ref.watch(settingsRepositoryProvider).watchString(SettingKeys.themeMode).map(
            (value) => ThemeMode.values.firstWhere(
              (m) => m.name == value,
              orElse: () => ThemeMode.system,
            ),
          );

  Future<void> set(ThemeMode mode) => ref
      .read(settingsRepositoryProvider)
      .setString(SettingKeys.themeMode, mode.name);
}

/// The persisted locale override; `null` means follow the system.
@Riverpod(keepAlive: true)
class LocaleSetting extends _$LocaleSetting {
  static const system = 'system';

  @override
  Stream<Locale?> build() =>
      ref.watch(settingsRepositoryProvider).watchString(SettingKeys.locale).map(
            (value) => value == null || value == system ? null : Locale(value),
          );

  Future<void> set(String languageCodeOrSystem) => ref
      .read(settingsRepositoryProvider)
      .setString(SettingKeys.locale, languageCodeOrSystem);
}
