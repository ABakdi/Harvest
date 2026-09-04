import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/features/security/domain/app_lock.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The Privacy switch: hand the front door to whatever the device
/// already trusts.
class AppLockCard extends ConsumerWidget {
  const AppLockCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lock = ref.watch(appLockProvider);

    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.lock_outline),
        title: Text(l10n.appLockTitle),
        subtitle: Text(l10n.appLockBody, style: theme.textTheme.bodySmall),
        value: lock.enabled,
        onChanged: (value) async {
          final messenger = ScaffoldMessenger.of(context);
          final took = await ref
              .read(appLockProvider.notifier)
              .setEnabled(value: value);
          // A lock that cannot lock is worse than no lock: say why
          // rather than leaving a switch that silently sprang back.
          if (!took) {
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.appLockUnavailable)),
            );
          }
        },
      ),
    );
  }
}
