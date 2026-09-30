import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';

/// A switch bound to one of this phone's own settings, on or off, with
/// [fallback] until it has been set. [onChanged] runs after the value is
/// kept: what turning it on should also do.
class SettingSwitchTile extends ConsumerWidget {
  const SettingSwitchTile({
    required this.settingKey,
    required this.title,
    this.subtitle,
    this.fallback = true,
    this.onChanged,
    super.key,
  });

  final String settingKey;
  final String title;
  final String? subtitle;
  final bool fallback;
  final Future<void> Function({required bool on})? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsRepositoryProvider);
    return StreamBuilder<String?>(
      stream: settings.watchString(settingKey),
      builder: (context, snapshot) {
        final raw = snapshot.data;
        final value = raw == null ? fallback : raw == 'true';
        return SwitchListTile(
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          value: value,
          onChanged: (next) => unawaited(() async {
            await settings.setBool(settingKey, value: next);
            await onChanged?.call(on: next);
          }()),
        );
      },
    );
  }
}
