import 'dart:async';

import 'package:flutter/material.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/finances/domain/amount_expression.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/amount_keypad.dart';
import 'package:harvest/features/finances/presentation/currency_picker.dart';
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

/// Asks before an implausibly large amount is saved: above
/// [plausibleMaxMinor] it is far likelier a slipped finger than a
/// purchase, and it would dominate every total (W6-15). True when the
/// amount is ordinary or I said yes.
Future<bool> confirmLargeAmount(
  BuildContext context,
  int minor,
  Currency currency,
) async {
  if (isPlausibleAmount(minor)) return true;
  final l10n = AppLocalizations.of(context);
  return confirm(
    context,
    title: l10n.amountLargeTitle(formatMoney(minor, currency)),
    body: l10n.amountLargeBody,
    confirmLabel: l10n.amountLargeConfirm,
  );
}

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
}) => showHarvestSheet<MoneyEntry>(
  context,
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

  // A sum counts here as it does in the expense sheet ([[Audit-v3]] G5-06).
  int? get _minor => evaluateAmountToMinor(_amountController.text);
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

  Future<void> _submit() async {
    if (!_valid) return;
    if (!await confirmLargeAmount(context, _minor!, _currency)) return;
    if (!mounted) return;
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

    return HarvestSheet(
      title: widget.title,
      subtitle: widget.subtitle,
      actionLabel: l10n.save,
      onAction: _valid ? () => unawaited(_submit()) : null,
      children: [
        // The app's keypad, with `+`, as in the expense sheet (U6-10).
        AmountField(
          controller: _amountController,
          currency: _currency,
          label: l10n.amountLabel,
          onChanged: () => setState(() {}),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: _overCap ? theme.colorScheme.error : accent,
          ),
          errorText: _overCap
              ? '${l10n.amountLabel} ≤ ${formatMoney(_cap!, _currency)}'
              : null,
        ),
        const SizedBox(height: HarvestSpacing.sm),
        if (!widget.lockCurrency)
          CurrencyChoice(
            selected: _currency,
            onChanged: (currency) => setState(() => _currency = currency),
          ),
        if (_cap != null && !_overCap)
          Padding(
            padding: const EdgeInsets.only(top: HarvestSpacing.sm),
            child: Text(
              formatMoney(_cap!, _currency),
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
                  : l10n.walletHas(formatMoney(_walletBalance, _currency)),
            ),
            // Before an amount is typed the row already answers: the
            // choice is made up front and applied once the wallet is
            // known to cover it. A row that ignored taps until then read
            // as a label that does nothing.
            value: _minor == null
                ? (_fromWallet ?? true) && _walletBalance > 0
                : _useWallet,
            onChanged: (_minor == null ? _walletBalance > 0 : _walletCanCover)
                ? (value) => setState(() => _fromWallet = value)
                : null,
          ),
        ],
        const SizedBox(height: HarvestSpacing.md),
        TextField(
          textCapitalization: TextCapitalization.sentences,
          controller: _noteController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          maxLength: noteMaxLength,
          decoration: InputDecoration(
            labelText: l10n.noteLabel,
            counterText: '',
          ),
        ),
      ],
    );
  }
}
