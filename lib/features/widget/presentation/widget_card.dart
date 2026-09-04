import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/widget/domain/widget_service.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Explains the home-screen widget and offers to push it fresh.
///
/// The widget updates itself on every check-in and at the 3 AM reset;
/// the button is here for the one case those do not cover — a widget
/// placed on the home screen before the app has written anything.
class WidgetCard extends ConsumerWidget {
  const WidgetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.widgets_outlined),
                const SizedBox(width: HarvestSpacing.md),
                Expanded(child: Text(l10n.widgetTitle)),
              ],
            ),
            const SizedBox(height: HarvestSpacing.xs),
            Text(l10n.widgetBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: HarvestSpacing.md),
            OutlinedButton.icon(
              onPressed: () => unawaited(
                ref.read(widgetServiceProvider).refresh(),
              ),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.widgetRefresh),
            ),
          ],
        ),
      ),
    );
  }
}
