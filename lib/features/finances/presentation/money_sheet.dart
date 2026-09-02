import 'dart:async';

import 'package:flutter/material.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// What a money sheet hands back: minor units, currency, optional note.
typedef MoneyEntry = ({int minor, Currency currency, String? note});

/// The one way an amount is asked for in the vault: a big number, the
/// currency pills, an optional note, and the bouncy confirm.
Future<MoneyEntry?> showMoneySheet(
  BuildContext context, {
  required String title,
  required Currency initialCurrency,
  String? subtitle,
  bool lockCurrency = false,
  int? initialAmountMinor,

  /// Caps the amount per currency (savings can't go negative).
  Map<Currency, int>? maxMinor,
  Color? accent,
}) => showModalBottomSheet<MoneyEntry>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _MoneySheet(
    title: title,
    subtitle: subtitle,
    initialCurrency: initialCurrency,
    lockCurrency: lockCurrency,
    initialAmountMinor: initialAmountMinor,
    maxMinor: maxMinor,
    accent: accent,
  ),
);

class _MoneySheet extends StatefulWidget {
  const _MoneySheet({
    required this.title,
    required this.initialCurrency,
    required this.lockCurrency,
    this.subtitle,
    this.initialAmountMinor,
    this.maxMinor,
    this.accent,
  });

  final String title;
  final String? subtitle;
  final Currency initialCurrency;
  final bool lockCurrency;
  final int? initialAmountMinor;
  final Map<Currency, int>? maxMinor;
  final Color? accent;

  @override
  State<_MoneySheet> createState() => _MoneySheetState();
}

class _MoneySheetState extends State<_MoneySheet> {
  late final _amountController = TextEditingController(
    text: widget.initialAmountMinor == null
        ? ''
        : formatMinor(widget.initialAmountMinor!),
  );
  final _noteController = TextEditingController();
  late Currency _currency = widget.initialCurrency;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int? get _minor => parseToMinor(_amountController.text);
  int? get _cap => widget.maxMinor?[_currency];
  bool get _overCap => _minor != null && _cap != null && _minor! > _cap!;
  bool get _valid => _minor != null && !_overCap;

  void _submit() {
    if (!_valid) return;
    unawaited(HarvestHaptics.tick());
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      (minor: _minor!, currency: _currency, note: note.isEmpty ? null : note),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = widget.accent ?? theme.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(
        left: HarvestSpacing.lg,
        right: HarvestSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + HarvestSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (widget.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                widget.subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          const SizedBox(height: HarvestSpacing.md),
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: _overCap ? theme.colorScheme.error : accent,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
              prefixText: '${_currency.symbol} ',
              prefixStyle: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              errorText: _overCap
                  ? '${l10n.amountLabel} ≤ ${_currency.symbol}${formatMinor(_cap!)}'
                  : null,
            ),
          ),
          const SizedBox(height: HarvestSpacing.sm),
          if (!widget.lockCurrency)
            SegmentedButton<Currency>(
              segments: [
                for (final option in Currency.values)
                  ButtonSegment(value: option, label: Text(option.symbol)),
              ],
              selected: {_currency},
              onSelectionChanged: (selection) {
                unawaited(HarvestHaptics.tick());
                setState(() => _currency = selection.first);
              },
            ),
          if (_cap != null && !_overCap)
            Padding(
              padding: const EdgeInsets.only(top: HarvestSpacing.sm),
              child: Text(
                '${_currency.symbol}${formatMinor(_cap!)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: HarvestSpacing.md),
          TextField(
            controller: _noteController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: l10n.noteLabel),
          ),
          const SizedBox(height: HarvestSpacing.lg),
          BigBouncySheetButton(
            onPressed: _valid ? _submit : null,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
