import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/domain/sync_secret.dart';
import 'package:harvest/features/sync/presentation/sync_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The words for what is wrong with a sync secret, or null when there
/// is nothing to say yet.
String? syncSecretMessage(AppLocalizations l10n, SyncSecretProblem? problem) =>
    switch (problem) {
      null || SyncSecretProblem.empty => null,
      SyncSecretProblem.pinTooShort ||
      SyncSecretProblem.pinTooLong => l10n.syncPinLength,
      SyncSecretProblem.passphraseTooShort => l10n.syncPassphraseShort,
    };

/// A PIN field's input: digits only, at most six, and an Arabic
/// keyboard's digits (٠–٩, and the Persian ۰–۹) written as the ASCII
/// ones they are — the web does the same, so the same keys give the
/// same PIN, and the same key, on both.
class PinDigitsFormatter extends TextInputFormatter {
  const PinDigitsFormatter();

  static String digitsOf(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      final digit = switch (rune) {
        >= 0x30 && <= 0x39 => rune - 0x30,
        >= 0x660 && <= 0x669 => rune - 0x660,
        >= 0x6F0 && <= 0x6F9 => rune - 0x6F0,
        _ => null,
      };
      if (digit == null) continue;
      if (out.length == syncPinMaxLength) break;
      out.write(digit);
    }
    return out.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = digitsOf(newValue.text);
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Asks for the sync PIN ([[Accounts]]): *chosen*, typed twice, on the
/// first device; *entered*, once, on a device whose account already has
/// sealed rows — and then checked against them. [asking] is the prompt
/// that follows sign-in, which can be put off with *Later*.
Future<void> showSyncPinSheet(BuildContext context, {bool asking = false}) =>
    showHarvestSheet<void>(
      context,
      builder: (_) => SyncPinSheet(asking: asking),
    );

class SyncPinSheet extends ConsumerStatefulWidget {
  const SyncPinSheet({this.asking = false, super.key});

  final bool asking;

  @override
  ConsumerState<SyncPinSheet> createState() => _SyncPinSheetState();
}

enum _Phase { typing, deriving, checking }

class _SyncPinSheetState extends ConsumerState<SyncPinSheet> {
  final _first = TextEditingController();
  final _second = TextEditingController();

  /// A passphrase rather than a PIN, for whoever wants more ([[Accounts]]:
  /// what a PIN costs).
  var _passphrase = false;
  _Phase _phase = _Phase.typing;
  var _tried = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  bool get _entering => ref.read(syncSealedSeenProvider).value ?? false;

  String? _problem(AppLocalizations l10n) {
    final rule = syncSecretMessage(l10n, syncSecretProblem(_first.text));
    if (rule != null) return rule;
    if (!_entering && _first.text != _second.text) return l10n.syncPinMismatch;
    return null;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _tried = true;
      _error = null;
    });
    if (_first.text.isEmpty || _problem(l10n) != null) return;
    final entering = _entering;
    final navigator = Navigator.of(context);
    // Read before the sheet goes: its ref dies with it.
    final sync = ref.read(syncControllerProvider.notifier);
    final secret = ref.read(syncPassphraseProvider.notifier);
    setState(() => _phase = _Phase.deriving);
    await secret.set(_first.text);
    if (!entering) {
      navigator.pop();
      // The private tier goes up now, not at the next trigger.
      unawaited(sync.syncNow());
      return;
    }
    if (mounted) setState(() => _phase = _Phase.checking);
    await sync.syncNow();
    // A key that could not open what the others sealed has already been
    // forgotten by the sync; say so here, where it was typed.
    final kept = ref.read(syncPassphraseProvider).value ?? false;
    if (!mounted) return;
    if (kept) {
      navigator.pop();
      return;
    }
    _first.clear();
    _second.clear();
    setState(() {
      _phase = _Phase.typing;
      _tried = false;
      _error = l10n.syncPinWrong;
    });
  }

  void _switchKind() {
    _first.clear();
    _second.clear();
    setState(() {
      _passphrase = !_passphrase;
      _tried = false;
      _error = null;
    });
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? helper,
    String? error,
    bool autofocus = false,
  }) => TextField(
    controller: controller,
    autofocus: autofocus,
    obscureText: true,
    autocorrect: false,
    enableSuggestions: false,
    enabled: _phase == _Phase.typing,
    keyboardType: _passphrase
        ? TextInputType.visiblePassword
        : TextInputType.number,
    inputFormatters: _passphrase ? null : const [PinDigitsFormatter()],
    onChanged: (_) => setState(() {}),
    onSubmitted: (_) => unawaited(_save()),
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      errorText: error,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entering = ref.watch(syncSealedSeenProvider).value ?? false;
    final problem = _problem(l10n);
    final rule = syncSecretMessage(l10n, syncSecretProblem(_first.text));
    final working = _phase != _Phase.typing;

    return HarvestSheet(
      title: l10n.syncPinTitle,
      actionLabel: switch (_phase) {
        _Phase.deriving => l10n.syncPinWorking,
        _Phase.checking => l10n.syncPinChecking,
        _Phase.typing => entering ? l10n.syncPinEnter : l10n.syncPinChoose,
      },
      onAction: working || _first.text.isEmpty
          ? null
          : () => unawaited(_save()),
      trailing: widget.asking && !working
          ? TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.syncPinLater),
            )
          : null,
      children: [
        Text(entering ? l10n.syncPinEnterBody : l10n.syncPinChooseBody),
        const SizedBox(height: HarvestSpacing.md),
        _field(
          controller: _first,
          autofocus: true,
          label: _passphrase ? l10n.syncPassphraseField : l10n.syncPinField,
          helper: _passphrase ? l10n.syncPassphraseRule : l10n.syncPinRule,
          error: _tried ? rule : null,
        ),
        if (!entering) ...[
          const SizedBox(height: HarvestSpacing.sm),
          _field(
            controller: _second,
            label: _passphrase ? l10n.syncPassphraseRepeat : l10n.syncPinRepeat,
            error: rule == null && (_tried || _second.text.isNotEmpty)
                ? problem
                : null,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: HarvestSpacing.sm),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: working ? null : _switchKind,
            child: Text(
              _passphrase ? l10n.syncPinUsePin : l10n.syncPinUsePassphrase,
            ),
          ),
        ),
        // Said plainly, and said twice ([[Accounts]]): once here, once
        // in what it costs.
        Text(
          l10n.syncPinLoss,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (!_passphrase) ...[
          const SizedBox(height: HarvestSpacing.sm),
          Text(
            l10n.syncPinCost,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (working) ...[
          const SizedBox(height: HarvestSpacing.md),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }
}
