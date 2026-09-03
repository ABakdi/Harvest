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

/// The raw rate settings as stored, for the card's fields.
@riverpod
Stream<Map<String, String>> rateSettings(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchAll(RateKeys.all);

/// Exchange-rate settings (checkpoint P5): manual DZD legs, fetched
/// EUR→USD from the ECB. Saves on submit or when a field loses focus
/// with a changed value, and says so.
class RatesCard extends ConsumerStatefulWidget {
  const RatesCard({super.key});

  @override
  ConsumerState<RatesCard> createState() => _RatesCardState();
}

class _RatesCardState extends ConsumerState<RatesCard> {
  final _usdController = TextEditingController();
  final _eurController = TextEditingController();
  final _usdFocus = FocusNode();
  final _eurFocus = FocusNode();
  var _fetching = false;

  @override
  void initState() {
    super.initState();
    final values = ref.read(rateSettingsProvider).value ?? const {};
    _usdController.text = values[RateKeys.dzdPerUsd] ?? '';
    _eurController.text = values[RateKeys.dzdPerEur] ?? '';
    _usdFocus.addListener(
      () => _onFocusChange(_usdFocus, RateKeys.dzdPerUsd, _usdController),
    );
    _eurFocus.addListener(
      () => _onFocusChange(_eurFocus, RateKeys.dzdPerEur, _eurController),
    );
  }

  @override
  void dispose() {
    _usdController.dispose();
    _eurController.dispose();
    _usdFocus.dispose();
    _eurFocus.dispose();
    super.dispose();
  }

  void _onFocusChange(
    FocusNode node,
    String key,
    TextEditingController controller,
  ) {
    if (node.hasFocus) return;
    final stored = ref.read(rateSettingsProvider).value?[key] ?? '';
    if (controller.text.trim() != stored) {
      unawaited(_saveManual(key, controller.text));
    }
  }

  Future<void> _saveManual(String key, String raw) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(settingsRepositoryProvider);
    final text = raw.trim();
    if (text.isEmpty) {
      await repo.remove(key);
      messenger.showSnackBar(SnackBar(content: Text(l10n.rateCleared)));
      return;
    }
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null || !isSaneRate(value)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.rateInvalid)));
      return;
    }
    await repo.setString(key, '$value');
    messenger.showSnackBar(SnackBar(content: Text(l10n.rateSaved)));
  }

  Future<void> _fetch() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _fetching = true);
    final rate = await ref.read(ratesServiceProvider).fetchEurUsd();
    if (!mounted) return;
    setState(() => _fetching = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(rate == null ? l10n.ratesFetchFailed : l10n.rateSaved),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final values = ref.watch(rateSettingsProvider).value ?? const {};

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ratesExplainer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: HarvestSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usdController,
                    focusNode: _usdFocus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onSubmitted: (raw) =>
                        unawaited(_saveManual(RateKeys.dzdPerUsd, raw)),
                    decoration: InputDecoration(
                      labelText: l10n.ratesDzdUsd,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: HarvestSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _eurController,
                    focusNode: _eurFocus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onSubmitted: (raw) =>
                        unawaited(_saveManual(RateKeys.dzdPerEur, raw)),
                    decoration: InputDecoration(
                      labelText: l10n.ratesDzdEur,
                      isDense: true,
                    ),
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
