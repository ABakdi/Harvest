import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/finances/domain/amount_expression.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The amount box every money sheet asks with: read-only to the system,
/// the app's own keypad under it, and what a sum comes to as it is
/// typed. The expense sheet had it alone; the wallet, savings, debt and
/// budget sheets took the phone's number pad, which has no `+`, so a
/// sum could only be pasted (U6-10).
///
/// It listens to [controller] itself, so a key on the keypad redraws
/// the caption; [onChanged] tells the sheet.
class AmountField extends StatefulWidget {
  const AmountField({
    required this.controller,
    required this.currency,
    required this.label,
    this.onChanged,
    this.errorText,
    this.style,
    this.autofocus = true,
    this.compact = false,
    super.key,
  });

  final TextEditingController controller;
  final Currency currency;
  final String label;
  final VoidCallback? onChanged;
  final String? errorText;
  final TextStyle? style;
  final bool autofocus;

  /// Shorter keys, for a sheet with a lot under the keypad.
  final bool compact;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(AmountField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = widget.controller.text;
    final isSum = isAmountExpression(text);
    final minor = evaluateAmountToMinor(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Read-only to the system: the keypad below is the keyboard,
        // and the phone's own must not slide up over it. The caret
        // still shows and still moves, so a wrong digit mid-sum is a
        // tap away.
        TextField(
          controller: widget.controller,
          autofocus: widget.autofocus,
          readOnly: true,
          showCursor: true,
          inputFormatters: [
            FilteringTextInputFormatter.allow(amountCharacters),
          ],
          style:
              widget.style ??
              theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
          decoration: InputDecoration(
            labelText: widget.label,
            prefixText: widget.currency.symbol,
            errorText: widget.errorText,
            // What the sum comes to, live, so Save never saves a surprise.
            helperText: !isSum
                ? null
                : minor == null
                ? l10n.amountSumIncomplete
                : l10n.amountSum(formatMoney(minor, widget.currency)),
            helperStyle: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: minor == null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        AmountKeypad(controller: widget.controller, compact: widget.compact),
      ],
    );
  }
}

/// The keypad under the amount box: digits, the four operations and
/// brackets.
///
/// No system keyboard has `× ÷ ( )` on the number layout, and the one
/// that does is a full keyboard with the digits three taps away. So
/// the expense sheet keeps its own — a calculator's keys, in the
/// app's own chips — and the amount field is read-only to the system,
/// which is what stops the phone's keyboard sliding up over it
/// ([[Checkpoint-6]]).
///
/// It edits a controller rather than a string so the caret is
/// honoured: a wrong digit in the middle of a sum is fixed by tapping
/// there, not by deleting to it.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    required this.controller,
    this.compact = false,
    super.key,
  });

  final TextEditingController controller;

  /// 42 dp keys instead of 46: still a thumb's width, and five rows
  /// give back 20 dp to a crowded sheet.
  final bool compact;

  static const _rows = [
    ['(', ')', '⌫', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '-'],
    ['1', '2', '3', '+'],
    ['.', '0', '00', 'C'],
  ];

  void _tap(String key) {
    HarvestHaptics.tick().ignore();
    switch (key) {
      case '⌫':
        _backspace();
      case 'C':
        controller.clear();
      default:
        _insert(key);
    }
  }

  void _insert(String symbol) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, symbol),
      selection: TextSelection.collapsed(offset: start + symbol.length),
    );
  }

  void _backspace() {
    final text = controller.text;
    final selection = controller.selection;
    if (selection.isValid && !selection.isCollapsed) {
      controller.value = TextEditingValue(
        text: text.replaceRange(selection.start, selection.end, ''),
        selection: TextSelection.collapsed(offset: selection.start),
      );
      return;
    }
    final at = selection.isValid ? selection.start : text.length;
    if (at <= 0) return;
    controller.value = TextEditingValue(
      text: text.replaceRange(at - 1, at, ''),
      selection: TextSelection.collapsed(offset: at - 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: HarvestSpacing.xs),
            child: Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _Key(
                        label: key,
                        tooltip: switch (key) {
                          '⌫' => l10n.amountKeyBackspace,
                          'C' => l10n.amountKeyClear,
                          _ => null,
                        },
                        // Operators and brackets in the accent, digits
                        // plain: the eye finds the `+` between numbers.
                        accent: !RegExp(r'^[\d.]+$').hasMatch(key),
                        onTap: () => _tap(key),
                        onLongPress: key == '⌫' ? controller.clear : null,
                        height: compact ? 42 : 46,
                        scheme: scheme,
                        theme: theme,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.accent,
    required this.onTap,
    required this.scheme,
    required this.theme,
    required this.height,
    this.tooltip,
    this.onLongPress,
  });

  final double height;
  final String label;
  final bool accent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final key = Material(
      color: accent
          ? scheme.secondary.withValues(alpha: 0.16)
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(HarvestRadii.chip),
      child: InkWell(
        borderRadius: BorderRadius.circular(HarvestRadii.chip),
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: height,
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: accent ? scheme.secondary : scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
    final hint = tooltip;
    return hint == null ? key : Tooltip(message: hint, child: key);
  }
}
