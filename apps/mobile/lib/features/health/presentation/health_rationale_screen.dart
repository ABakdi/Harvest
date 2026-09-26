import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The answer to *Why does Harvest need this?*
///
/// Health Connect puts that question on its own permission screen and
/// sends whoever taps it back into the app. The app declared the intent
/// filters and then dropped the question on the field
/// ([[Audit-v2]] S3-02). This is the page it meant to show: what is
/// read, what it is used for, where it stays, and how to take it back
/// ([[Health]] H2, H3).
class HealthRationaleScreen extends StatelessWidget {
  const HealthRationaleScreen({super.key});

  /// Asks the activity whether it was opened by that question, and
  /// clears the flag so it is answered once.
  static Future<bool> wasAsked() async {
    try {
      final asked = await const MethodChannel(
        'harvest/health',
      ).invokeMethod<bool>('takeRationaleRequest');
      return asked ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthWhyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        children: [
          Text(
            l10n.healthWhyLead,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: HarvestSpacing.md),
          Text(l10n.healthWhyUse, style: body),
          const SizedBox(height: HarvestSpacing.md),
          Text(l10n.healthWhyStays, style: body),
          const SizedBox(height: HarvestSpacing.md),
          Text(l10n.healthWhyOff, style: body),
        ],
      ),
    );
  }
}
