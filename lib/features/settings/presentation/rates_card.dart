import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/finances/data/rates_service.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rates_card.g.dart';

@riverpod
Stream<Map<String, String>> rateSettings(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchAll(const [
      RateKeys.dzdPerUsd,
      RateKeys.dzdPerEur,
      RateKeys.usdPerEur,
      RateKeys.usdPerEurAt,
    ]);

/// Exchange-rate settings (checkpoint P5): manual DZD legs, fetched
/// EUR→USD from the ECB.
class RatesCard extends ConsumerStatefulWidget {
  const RatesCard({super.key});

  @override
  ConsumerState<RatesCard> createState() => _RatesCardState();
}

class _RatesCardState extends ConsumerState<RatesCard> {
  final _usdController = TextEditingController();
  final _eurController = TextEditingController();
  var _seeded = false;
  var _fetching = false;

  @override
  void dispose() {
    _usdController.dispose();
    _eurController.dispose();
    super.dispose();
  }

  Future<void> _saveManual(String key, String raw) async {
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    await ref.read(settingsRepositoryProvider).setString(key, '$value');
  }

  Future<void> _fetch() async {
    setState(() => _fetching = true);
    final rate = await ref.read(ratesServiceProvider).fetchEurUsd();
    if (!mounted) return;
    setState(() => _fetching = false);
    if (rate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).ratesFetchFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final values = ref.watch(rateSettingsProvider).value ?? const {};

    if (!_seeded && values.isNotEmpty) {
      _seeded = true;
      _usdController.text = values[RateKeys.dzdPerUsd] ?? '';
      _eurController.text = values[RateKeys.dzdPerEur] ?? '';
    }

    final fetched = values[RateKeys.usdPerEur];
    final fetchedAtRaw = values[RateKeys.usdPerEurAt];
    String? fetchedAt;
    if (fetchedAtRaw != null) {
      final at = DateTime.tryParse(fetchedAtRaw);
      if (at != null) {
        fetchedAt = DateFormat.MMMd(
          Localizations.localeOf(context).toString(),
        ).add_Hm().format(at);
      }
    }

    InputDecoration decoration(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HarvestRadii.button),
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usdController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onSubmitted: (raw) =>
                        unawaited(_saveManual(RateKeys.dzdPerUsd, raw)),
                    onTapOutside: (_) => unawaited(
                      _saveManual(RateKeys.dzdPerUsd, _usdController.text),
                    ),
                    decoration: decoration(l10n.ratesDzdUsd),
                  ),
                ),
                const SizedBox(width: HarvestSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _eurController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onSubmitted: (raw) =>
                        unawaited(_saveManual(RateKeys.dzdPerEur, raw)),
                    onTapOutside: (_) => unawaited(
                      _saveManual(RateKeys.dzdPerEur, _eurController.text),
                    ),
                    decoration: decoration(l10n.ratesDzdEur),
                  ),
                ),
              ],
            ),
            const SizedBox(height: HarvestSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fetched == null
                            ? l10n.ratesEurUsd
                            : '${l10n.ratesEurUsd}: $fetched',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (fetchedAt != null)
                        Text(
                          l10n.ratesUpdated(fetchedAt),
                          style: theme.textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _fetching ? null : () => unawaited(_fetch()),
                  icon: _fetching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined),
                  label: Text(l10n.fetchNow),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
