import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The currencies a search finds: by name in [language], by code, or by
/// symbol, ignoring case; every currency, by name, for an empty search.
List<Currency> searchCurrencies(String query, String language) {
  final needle = query.trim().toLowerCase();
  return [
    for (final currency in Currency.values)
      if (needle.isEmpty ||
          currency.nameIn(language).toLowerCase().contains(needle) ||
          currency.en.toLowerCase().contains(needle) ||
          currency.code.toLowerCase().contains(needle) ||
          currency.symbol.toLowerCase() == needle)
        currency,
  ]..sort((a, b) {
    // A code typed in full comes first, then names in the language's order.
    final exactA = a.code.toLowerCase() == needle;
    final exactB = b.code.toLowerCase() == needle;
    if (exactA != exactB) return exactA ? -1 : 1;
    return a.nameIn(language).compareTo(b.nameIn(language));
  });
}

/// Opens the currency list, searchable, and answers the one chosen, or
/// null when the sheet is closed.
Future<Currency?> pickCurrency(BuildContext context, {Currency? selected}) =>
    showHarvestSheet<Currency>(
      context,
      builder: (_) => _CurrencySheet(selected: selected),
    );

class _CurrencySheet extends StatefulWidget {
  const _CurrencySheet({this.selected});

  final Currency? selected;

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final found = searchCurrencies(_query, language);
    return HarvestSheet(
      title: l10n.currencyPickerTitle,
      children: [
        TextField(
          autofocus: true,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l10n.currencySearchHint,
          ),
        ),
        if (found.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.currencyNoMatch),
          ),
        for (final currency in found)
          ListTile(
            key: ValueKey('currency-${currency.code}'),
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 48,
              child: Text(
                currency.symbol,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            title: Text(currency.nameIn(language)),
            subtitle: Text(currency.code),
            selected: currency == widget.selected,
            onTap: () => Navigator.of(context).pop(currency),
          ),
      ],
    );
  }
}

/// A currency to pick for one amount: the few I use as pills — the
/// default currency, the dollar and the euro, and whatever is chosen —
/// and every other one a tap away, searchable ([[Finances]], M7.8).
class CurrencyChoice extends ConsumerWidget {
  const CurrencyChoice({
    required this.selected,
    required this.onChanged,
    this.showSelectedIcon = true,
    super.key,
  });

  final Currency selected;
  final ValueChanged<Currency> onChanged;
  final bool showSelectedIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final quick = {
      ref.watch(defaultCurrencyProvider),
      Currency.usd,
      Currency.eur,
      selected,
    };
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<Currency>(
            showSelectedIcon: showSelectedIcon,
            segments: [
              for (final option in quick)
                ButtonSegment(
                  value: option,
                  label: Text(option.symbol),
                  tooltip: option.code,
                ),
            ],
            selected: {selected},
            onSelectionChanged: (selection) {
              unawaited(HarvestHaptics.tick());
              onChanged(selection.first);
            },
          ),
        ),
        IconButton(
          tooltip: l10n.currencyMore,
          icon: const Icon(Icons.more_horiz),
          onPressed: () async {
            final chosen = await pickCurrency(context, selected: selected);
            if (chosen != null) onChanged(chosen);
          },
        ),
      ],
    );
  }
}
