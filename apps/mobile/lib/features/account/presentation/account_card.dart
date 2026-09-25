import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/core/ui/widgets/text_prompt.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/sync/presentation/sync_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Settings → Account ([[Accounts]]): signed out, a way in; signed in,
/// what sync is doing and the way out.
class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountControllerProvider).value;
    if (account == null) return const SizedBox.shrink();
    return account.signedIn
        ? _SignedIn(state: account)
        : _SignedOut(serverUrl: account.serverUrl);
  }
}

/// The words for a server's answer, never its stack.
String accountError(AppLocalizations l10n, Object error) => switch (error) {
  ApiException(offline: true) => l10n.accountErrorOffline,
  ApiException(code: 'unauthorized') => l10n.accountErrorWrong,
  ApiException(code: 'conflict') => l10n.accountErrorTaken,
  ApiException(code: 'rate_limited') => l10n.accountErrorRateLimited,
  ApiException(code: 'validation_failed', :final message) =>
    l10n.accountErrorInvalid(message ?? ''),
  ApiException(code: 'passphrase') => l10n.passphraseWrong,
  ApiException(:final code) => l10n.accountErrorOther(code),
  _ => l10n.accountErrorOther(error.runtimeType.toString()),
};

/// What is wrong with the sign-in form before it is sent, in words, or
/// null when it may go: the same checks the server's contract makes —
/// an http(s) server, an address with an @ and a dot after it, a
/// password (ten characters or more for a new account).
@visibleForTesting
String? signInProblem(
  AppLocalizations l10n, {
  required String server,
  required String email,
  required String password,
  required bool creating,
}) {
  final url = Uri.tryParse(server.trim());
  if (url == null ||
      !(url.isScheme('http') || url.isScheme('https')) ||
      url.host.isEmpty) {
    return l10n.accountServerInvalid;
  }
  final address = email.trim();
  if (address.isEmpty) return l10n.accountEmailMissing;
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address) ||
      address.length > 254) {
    return l10n.accountEmailInvalid;
  }
  if (password.isEmpty) return l10n.accountPasswordMissing;
  if (creating && password.length < 10) return l10n.accountPasswordShort;
  if (password.length > 256) return l10n.accountPasswordLong;
  return null;
}

class _SignedOut extends ConsumerStatefulWidget {
  const _SignedOut({required this.serverUrl});

  final String serverUrl;

  @override
  ConsumerState<_SignedOut> createState() => _SignedOutState();
}

class _SignedOutState extends ConsumerState<_SignedOut> {
  late final _server = TextEditingController(text: widget.serverUrl);
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  var _creating = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    // The server's own checks, asked first: an empty form is a thing
    // to say, not a request to send ([[Accounts]]).
    final problem = signInProblem(
      l10n,
      server: _server.text,
      email: _email.text,
      password: _password.text,
      creating: _creating,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final controller = ref.read(accountControllerProvider.notifier);
    try {
      if (_server.text.trim() != widget.serverUrl) {
        await controller.setServerUrl(_server.text);
      }
      if (_creating) {
        await controller.register(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
      } else {
        await controller.login(email: _email.text, password: _password.text);
      }
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    } on Object catch (error) {
      if (mounted) setState(() => _error = accountError(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.accountWhy,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: HarvestSpacing.md),
              TextField(
                controller: _server,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.accountServer,
                  hintText: l10n.accountServerHint,
                  // The hint only shows on an empty, focused field; the
                  // example stays in view underneath.
                  helperText: l10n.accountServerExample,
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: HarvestSpacing.sm),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: l10n.accountEmail),
              ),
              const SizedBox(height: HarvestSpacing.sm),
              TextField(
                controller: _password,
                obscureText: true,
                autofillHints: [
                  if (_creating)
                    AutofillHints.newPassword
                  else
                    AutofillHints.password,
                ],
                decoration: InputDecoration(
                  labelText: l10n.accountPassword,
                  helperText: _creating ? l10n.accountPasswordRule : null,
                ),
              ),
              if (_creating) ...[
                const SizedBox(height: HarvestSpacing.sm),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: l10n.accountDisplayName,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: HarvestSpacing.sm),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: HarvestSpacing.md),
              FilledButton(
                onPressed: _busy ? null : () => unawaited(_submit()),
                child: Text(
                  _creating ? l10n.accountCreate : l10n.accountSignIn,
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    // One form's complaint is not the other's.
                    : () => setState(() {
                        _creating = !_creating;
                        _error = null;
                      }),
                child: Text(
                  _creating ? l10n.accountHaveOne : l10n.accountNeedOne,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.state});

  final AccountState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = state.me!;
    final sync = ref.watch(syncControllerProvider);
    final controller = ref.read(accountControllerProvider.notifier);
    final last = sync.last;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(me.displayName ?? me.email),
              subtitle: Text(
                me.displayName == null
                    ? state.serverUrl
                    : '${me.email} · ${state.serverUrl}',
              ),
              trailing: me.verified
                  ? Chip(label: Text(l10n.accountVerified))
                  : null,
            ),
            if (!me.verified) ...[
              Text(l10n.accountUnverified),
              Wrap(
                spacing: HarvestSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await controller.resendVerification();
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.accountResent)),
                      );
                    },
                    child: Text(l10n.accountResend),
                  ),
                  TextButton(
                    onPressed: () => unawaited(controller.refreshMe()),
                    child: Text(l10n.accountVerified),
                  ),
                ],
              ),
            ] else ...[
              Text(
                last == null
                    ? l10n.accountNeverSynced
                    : l10n.accountLastSynced(
                        TimeOfDay.fromDateTime(last.at).format(context),
                      ),
                style: theme.textTheme.bodyMedium,
              ),
              if (sync.pending > 0)
                Text(
                  l10n.accountPending(sync.pending),
                  style: theme.textTheme.bodySmall,
                ),
              if ((last?.invalid ?? 0) > 0)
                Text(
                  l10n.accountRefused(last!.invalid),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              if ((last?.heldBack ?? 0) > 0)
                Text(
                  l10n.accountHeldBack,
                  style: theme.textTheme.bodySmall,
                ),
              if (sync.error != null)
                Text(
                  accountError(l10n, ApiException(sync.error!, 0)),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              const SizedBox(height: HarvestSpacing.sm),
              FilledButton.tonalIcon(
                onPressed: sync.running
                    ? null
                    : () => unawaited(
                        ref.read(syncControllerProvider.notifier).syncNow(),
                      ),
                icon: const Icon(Icons.sync),
                label: Text(
                  sync.running ? l10n.accountSyncing : l10n.accountSyncNow,
                ),
              ),
            ],
            const Divider(height: HarvestSpacing.lg),
            const _Passphrase(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.devices_outlined),
              title: Text(l10n.accountDevices),
              onTap: () => unawaited(
                showHarvestSheet<void>(
                  context,
                  builder: (_) => const _Devices(),
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout),
              title: Text(l10n.accountSignOut),
              onTap: () async {
                final ok = await confirm(
                  context,
                  title: l10n.accountSignOut,
                  body: l10n.accountSignOutBody,
                  confirmLabel: l10n.accountSignOut,
                );
                if (ok) await controller.logout();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_forever_outlined,
                color: theme.colorScheme.error,
              ),
              title: Text(
                l10n.accountDelete,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await confirm(
                  context,
                  title: l10n.accountDelete,
                  body: l10n.accountDeleteBody,
                  confirmLabel: l10n.accountDelete,
                );
                if (!ok || !context.mounted) return;
                final password = await promptForText(
                  context,
                  title: l10n.accountDeleteConfirm,
                  confirmLabel: l10n.accountDelete,
                );
                if (password == null || password.isEmpty) return;
                try {
                  await controller.deleteAccount(password);
                } on Object catch (error) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(accountError(l10n, error))),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Devices extends ConsumerWidget {
  const _Devices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(accountControllerProvider.notifier);
    return HarvestSheet(
      title: l10n.accountDevices,
      children: [
        FutureBuilder<List<Map<String, Object?>>>(
          future: controller.sessions(),
          builder: (context, snapshot) {
            final sessions = snapshot.data;
            if (snapshot.hasError) {
              return Text(accountError(l10n, snapshot.error!));
            }
            if (sessions == null) return const LinearProgressIndicator();
            return Column(
              children: [
                for (final session in sessions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      session['client'] == 'web'
                          ? Icons.language
                          : Icons.phone_android,
                    ),
                    title: Text(
                      session['current'] == true
                          ? l10n.accountThisDevice
                          : (session['deviceName'] as String?) ??
                                '${session['client']}',
                    ),
                    subtitle: Text('${session['lastSeenAt']}'),
                    trailing: session['current'] == true
                        ? null
                        : TextButton(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              await controller.endSession(
                                session['id']! as String,
                              );
                              navigator.pop();
                            },
                            child: Text(l10n.accountEndSession),
                          ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The private tier's passphrase: set once per device, never sent.
class _Passphrase extends ConsumerWidget {
  const _Passphrase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final set = ref.watch(syncPassphraseProvider).value ?? false;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(set ? Icons.lock_outline : Icons.lock_open_outlined),
      title: Text(l10n.passphraseTitle),
      subtitle: Text(set ? l10n.passphraseSet : l10n.passphraseUnset),
      trailing: set
          ? TextButton(
              onPressed: () => unawaited(
                ref.read(syncPassphraseProvider.notifier).forget(),
              ),
              child: Text(l10n.passphraseForget),
            )
          : null,
      onTap: set
          ? null
          : () => unawaited(
              showHarvestSheet<void>(
                context,
                builder: (_) => const _PassphraseSheet(),
              ),
            ),
    );
  }
}

class _PassphraseSheet extends ConsumerStatefulWidget {
  const _PassphraseSheet();

  @override
  ConsumerState<_PassphraseSheet> createState() => _PassphraseSheetState();
}

class _PassphraseSheetState extends ConsumerState<_PassphraseSheet> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  var _working = false;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  String? _problem(AppLocalizations l10n) {
    if (_first.text.length < 12) return l10n.passphraseShort;
    if (_first.text != _second.text) return l10n.passphraseMismatch;
    return null;
  }

  Future<void> _save() async {
    setState(() => _working = true);
    final navigator = Navigator.of(context);
    // Read before the sheet goes: its ref dies with it.
    final sync = ref.read(syncControllerProvider.notifier);
    await ref.read(syncPassphraseProvider.notifier).set(_first.text);
    navigator.pop();
    unawaited(sync.syncNow());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final problem = _problem(l10n);
    return HarvestSheet(
      title: l10n.passphraseTitle,
      actionLabel: _working ? l10n.passphraseWorking : l10n.passphraseSetAction,
      onAction: problem != null || _working ? null : () => unawaited(_save()),
      children: [
        Text(l10n.passphraseBody),
        const SizedBox(height: HarvestSpacing.md),
        TextField(
          controller: _first,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: l10n.passphraseField),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        TextField(
          controller: _second,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.passphraseRepeat,
            errorText: _second.text.isEmpty ? null : problem,
          ),
        ),
        if (_working) ...[
          const SizedBox(height: HarvestSpacing.md),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }
}
