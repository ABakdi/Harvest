import 'package:flutter/material.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/l10n/app_localizations.dart';

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
  const AmountKeypad({required this.controller, super.key});

  final TextEditingController controller;

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
    this.tooltip,
    this.onLongPress,
  });

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
          height: 46,
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
