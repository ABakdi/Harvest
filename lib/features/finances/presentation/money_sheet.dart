import 'dart:async';

import 'package:flutter/material.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// What a money sheet hands back: minor units, currency, an optional
/// note, and whether the money comes from (or goes to) the wallet.
typedef MoneyEntry = ({
  int minor,
  Currency currency,
  String? note,
  bool fromWallet,
});

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

  /// Shows a "from the wallet" switch with the balance per currency;
  /// the switch starts on when the wallet can cover the amount.
  Map<Currency, int>? walletBalances,
  String? walletLabel,
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
    walletBalances: walletBalances,
    walletLabel: walletLabel,
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
    this.walletBalances,
    this.walletLabel,
  });

  final String title;
  final String? subtitle;
  final Currency initialCurrency;
  final bool lockCurrency;
  final int? initialAmountMinor;
  final Map<Currency, int>? maxMinor;
  final Color? accent;
  final Map<Currency, int>? walletBalances;
  final String? walletLabel;

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

  /// null until the user overrides it: the toggle follows the balance
  /// while it is untouched, so the common case needs no thought.
  bool? _fromWallet;

  int? get _minor => parseToMinor(_amountController.text);
  int? get _cap => widget.maxMinor?[_currency];
  bool get _overCap => _minor != null && _cap != null && _minor! > _cap!;
  bool get _valid => _minor != null && !_overCap;

  bool get _hasWalletOption => widget.walletBalances != null;
  int get _walletBalance => widget.walletBalances?[_currency] ?? 0;

  /// The wallet can pay when it holds at least the amount asked for.
  bool get _walletCanCover =>
      _minor != null && _walletBalance >= _minor! && _minor! > 0;

  bool get _useWallet =>
      _hasWalletOption && (_fromWallet ?? _walletCanCover) && _walletCanCover;

  void _submit() {
    if (!_valid) return;
    unawaited(HarvestHaptics.tick());
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      (
        minor: _minor!,
        currency: _currency,
        note: note.isEmpty ? null : note,
        fromWallet: _useWallet,
      ),
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
                  color: theme.colorScheme.onSurfaceVariant,
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
                color: theme.colorScheme.onSurfaceVariant,
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
          if (_hasWalletOption) ...[
            const SizedBox(height: HarvestSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.walletLabel ?? l10n.fromWalletToggle),
              subtitle: Text(
                _minor != null && !_walletCanCover
                    ? l10n.walletShort
                    : l10n.walletHas(formatAmount(_walletBalance, _currency)),
              ),
              value: _useWallet,
              onChanged: _walletCanCover
                  ? (value) => setState(() => _fromWallet = value)
                  : null,
            ),
          ],
          const SizedBox(height: HarvestSpacing.md),
          TextField(
            controller: _noteController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            maxLength: noteMaxLength,
            decoration: InputDecoration(
              labelText: l10n.noteLabel,
              counterText: '',
            ),
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
