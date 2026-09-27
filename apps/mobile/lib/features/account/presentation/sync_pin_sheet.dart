import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/western_digits.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/core/ui/widgets/text_prompt.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/domain/sync_secret.dart';
import 'package:harvest/features/account/presentation/account_card.dart';
import 'package:harvest/features/sync/presentation/sync_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The words for what is wrong with a sync secret, or null when there
/// is nothing to say yet.
String? syncSecretMessage(AppLocalizations l10n, SyncSecretProblem? problem) =>
    switch (problem) {
      null || SyncSecretProblem.empty => null,
      SyncSecretProblem.pinTooShort ||
      SyncSecretProblem.pinTooLong => l10n.syncPinLength,
      SyncSecretProblem.pinTooSimple => l10n.syncPinTooSimple,
      SyncSecretProblem.passphraseTooShort => l10n.syncPassphraseShort,
    };

/// A PIN field's input: digits only, at most six, and an Arabic
/// keyboard's digits (٠–٩, and the Persian ۰–۹) written as the ASCII
/// ones they are — the web does the same, so the same keys give the
/// same PIN, and the same key, on both.
class PinDigitsFormatter extends TextInputFormatter {
  const PinDigitsFormatter();

  static String digitsOf(String text) {
    final ascii = westernDigits(text).replaceAll(RegExp('[^0-9]'), '');
    return ascii.length > syncPinMaxLength
        ? ascii.substring(0, syncPinMaxLength)
        : ascii;
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

/// Asks for the sync PIN ([[Accounts]]): *chosen*, typed twice, while
/// the account has no key check on the server; *entered*, once, when it
/// has one — and a PIN that does not open the check is refused on the
/// spot. The server decides which, not what this phone has pulled.
/// [asking] is the prompt that follows sign-in, which can be put off
/// with *Later*; [changedElsewhere] says the PIN was started over on
/// another device, which is why it is asked for again.
Future<void> showSyncPinSheet(
  BuildContext context, {
  bool asking = false,
  bool changedElsewhere = false,
}) => showHarvestSheet<void>(
  context,
  builder: (_) =>
      SyncPinSheet(asking: asking, changedElsewhere: changedElsewhere),
);

/// Starts the sync PIN over ([[Accounts]]: start over): says plainly
/// what goes, asks for the account's password, and then drops the key
/// check, the key share and everything private on the server. True
/// when it was done; the next PIN is then *chosen*. [changing] is the
/// same thing asked for as *Change PIN*, by someone who still has it.
Future<bool> startSyncPinOver(
  BuildContext context,
  WidgetRef ref, {
  bool changing = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final pin = ref.read(syncPassphraseProvider.notifier);
  final ok = await confirm(
    context,
    title: changing ? l10n.syncPinChange : l10n.syncPinStartOver,
    body: l10n.syncPinStartOverBody,
    confirmLabel: l10n.syncPinStartOverConfirm,
    destructive: true,
  );
  if (!ok || !context.mounted) return false;
  final password = await promptForText(
    context,
    title: l10n.accountDeleteConfirm,
    confirmLabel: l10n.syncPinStartOverConfirm,
  );
  if (password == null || password.isEmpty) return false;
  try {
    await pin.startOver(password);
    return true;
  } on ApiException catch (error) {
    final words = error.code == 'forbidden'
        ? l10n.syncPinWrongPassword
        : accountError(l10n, error);
    messenger?.showSnackBar(SnackBar(content: Text(words)));
    return false;
  }
}

class SyncPinSheet extends ConsumerStatefulWidget {
  const SyncPinSheet({
    this.asking = false,
    this.changedElsewhere = false,
    super.key,
  });

  final bool asking;
  final bool changedElsewhere;

  @override
  ConsumerState<SyncPinSheet> createState() => _SyncPinSheetState();
}

enum _Phase { typing, deriving }

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

  /// Whether the account already has a PIN, as the server says; null
  /// while it has not answered.
  bool? get _entering {
    final share = ref.read(syncKeyShareProvider).value;
    return share == null ? null : !share.choosing;
  }

  /// The rule for what is typed. Entering, the PIN is the one already
  /// chosen, and the account's key check is its judge; choosing, a PIN
  /// too easy to guess is refused.
  SyncSecretProblem? _rule(String text, {required bool entering}) {
    final problem = syncSecretProblem(text);
    if (entering && problem == SyncSecretProblem.pinTooSimple) return null;
    return problem;
  }

  String? _problem(AppLocalizations l10n, {required bool entering}) {
    final rule = syncSecretMessage(
      l10n,
      _rule(_first.text, entering: entering),
    );
    if (rule != null) return rule;
    if (!entering && _first.text != _second.text) return l10n.syncPinMismatch;
    return null;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final entering = _entering;
    if (entering == null) return;
    setState(() {
      _tried = true;
      _error = null;
    });
    if (_first.text.isEmpty || _problem(l10n, entering: entering) != null) {
      return;
    }
    final navigator = Navigator.of(context);
    // Read before the sheet goes: its ref dies with it.
    final sync = ref.read(syncControllerProvider.notifier);
    final secret = ref.read(syncPassphraseProvider.notifier);
    setState(() => _phase = _Phase.deriving);
    String? error;
    try {
      await secret.set(_first.text);
    } on SyncPinRefused catch (refused) {
      error = refused.chosenElsewhere
          ? l10n.syncPinChosenElsewhere
          : l10n.syncPinWrong;
    } on ApiException catch (failure) {
      error = failure.offline
          ? l10n.syncPinUnreachable
          : accountError(l10n, failure);
    }
    if (error == null) {
      navigator.pop();
      // The private tier goes up now, not at the next trigger.
      unawaited(sync.syncNow());
      return;
    }
    if (!mounted) return;
    _first.clear();
    _second.clear();
    setState(() {
      _phase = _Phase.typing;
      _tried = false;
      _error = error;
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
    final share = ref.watch(syncKeyShareProvider);
    final working = _phase != _Phase.typing;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // Whether to choose or to enter is the server's answer; until it
    // comes there is nothing to type into.
    final entering = switch (share) {
      AsyncData(:final value) => !value.choosing,
      _ => null,
    };
    if (entering == null) {
      final failed = share.hasError && !share.isLoading;
      return HarvestSheet(
        title: l10n.syncPinTitle,
        actionLabel: failed ? l10n.galleryFileRetry : l10n.syncPinChecking,
        onAction: failed ? () => ref.invalidate(syncKeyShareProvider) : null,
        trailing: widget.asking
            ? TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.syncPinLater),
              )
            : null,
        children: [
          if (failed)
            Text(
              share.error is ApiException &&
                      !(share.error! as ApiException).offline
                  ? accountError(l10n, share.error!)
                  : l10n.syncPinUnreachable,
            )
          else
            const LinearProgressIndicator(),
        ],
      );
    }

    final problem = _problem(l10n, entering: entering);
    final rule = syncSecretMessage(
      l10n,
      _rule(_first.text, entering: entering),
    );

    return HarvestSheet(
      title: l10n.syncPinTitle,
      actionLabel: switch (_phase) {
        _Phase.deriving =>
          entering ? l10n.syncPinChecking : l10n.syncPinWorking,
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
        if (widget.changedElsewhere) ...[
          Text(
            l10n.syncPinChangedElsewhere,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: HarvestSpacing.sm),
        ],
        Text(entering ? l10n.syncPinEnterBody : l10n.syncPinChooseBody),
        const SizedBox(height: HarvestSpacing.md),
        _field(
          controller: _first,
          autofocus: true,
          label: _passphrase ? l10n.syncPassphraseField : l10n.syncPinField,
          // Six digits suggested when choosing; entering, the one there is.
          helper: _passphrase
              ? l10n.syncPassphraseRule
              : entering
              ? null
              : l10n.syncPinRule,
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
        if (entering)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: working
                  ? null
                  : () async {
                      if (await startSyncPinOver(context, ref) && mounted) {
                        _first.clear();
                        _second.clear();
                        setState(() {
                          _tried = false;
                          _error = null;
                        });
                      }
                    },
              child: Text(l10n.syncPinForgot),
            ),
          ),
        // Said plainly, and said twice ([[Accounts]]): once here, once
        // in what it costs.
        Text(l10n.syncPinLoss, style: muted),
        if (!_passphrase) ...[
          const SizedBox(height: HarvestSpacing.sm),
          Text(l10n.syncPinCost, style: muted),
        ],
        if (working) ...[
          const SizedBox(height: HarvestSpacing.md),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }
}
