import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/domain/secure_address.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/core/ui/widgets/text_prompt.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/presentation/sync_pin_sheet.dart';
import 'package:harvest/features/sync/presentation/sync_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Settings → Account ([[Accounts]]): signed out, a way in; signed in,
/// what sync is doing and the way out.
class AccountCard extends ConsumerWidget {
  const AccountCard({this.creating = false, super.key});

  /// Signed out, open on *Create account* rather than *Sign in*.
  final bool creating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountControllerProvider).value;
    if (account == null) return const SizedBox.shrink();
    return account.signedIn
        ? _SignedIn(state: account)
        : _SignedOut(serverUrl: account.serverUrl, creating: creating);
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
  ApiException(code: 'pinChanged') => l10n.syncPinChangedElsewhere,
  ApiException(:final code) => l10n.accountErrorOther(code),
  _ => l10n.accountErrorOther(error.runtimeType.toString()),
};

/// What is wrong with the sign-in form before it is sent, in words, or
/// null when it may go: the same checks the server's contract makes —
/// an https server (plain http only to this device or the emulator,
/// S6-12), an address with an @ and a dot after it, a
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
  if (!isSecureAddress(server)) return l10n.accountServerNotSecure;
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
  const _SignedOut({required this.serverUrl, this.creating = false});

  final String serverUrl;
  final bool creating;

  @override
  ConsumerState<_SignedOut> createState() => _SignedOutState();
}

class _SignedOutState extends ConsumerState<_SignedOut> {
  late final _server = TextEditingController(text: widget.serverUrl);
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  late bool _creating = widget.creating;
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
              // A label, not something to tap (U6-20).
              trailing: me.verified
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: HarvestSpacing.xs),
                        Text(
                          l10n.accountVerified,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    )
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
              // The same lines the account sheet shows (U6-20).
              ...syncStatusLines(context, l10n, sync),
              if ((last?.invalid ?? 0) > 0)
                Text(
                  l10n.accountRefused(last!.invalid),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              if (last?.refusedFor.contains('quota_exceeded') ?? false)
                Text(
                  l10n.syncRefusedQuota,
                  style: theme.textTheme.bodySmall,
                ),
              if (last?.refusedFor.any(
                    (code) => code == 'clock_ahead' || code == 'clock_too_far',
                  ) ??
                  false)
                Text(
                  l10n.syncRefusedClock,
                  style: theme.textTheme.bodySmall,
                ),
              if ((last?.locked ?? 0) > 0)
                Text(
                  l10n.accountLocked(last!.locked),
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
            const SyncPinTile(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.devices_outlined),
              title: Text(l10n.accountDevices),
              onTap: () => unawaited(
                showHarvestSheet<void>(
                  context,
                  builder: (_) => const AccountDevices(),
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
                final password = await promptForPassword(
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

/// How sync stands, in the words the account sheet and the Account page
/// both use (U6-20): online or offline, the last sync, whether anything
/// waits, and an error when there is one.
List<Widget> syncStatusLines(
  BuildContext context,
  AppLocalizations l10n,
  SyncStatus sync,
) {
  final theme = Theme.of(context);
  final last = sync.last;
  final muted = theme.textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );
  return [
    if (sync.offline)
      Text(l10n.accountOffline, style: theme.textTheme.bodyMedium)
    else if (last != null && sync.error == null)
      Text(l10n.accountOnline, style: theme.textTheme.bodyMedium),
    Text(
      last == null
          ? l10n.accountNeverSynced
          : l10n.accountLastSynced(
              TimeOfDay.fromDateTime(last.at).format(context),
            ),
      style: muted,
    ),
    Text(
      sync.pending > 0 ? l10n.accountChangesWaiting : l10n.accountAllSent,
      style: muted,
    ),
    if (sync.error != null && !sync.offline)
      Text(
        accountError(l10n, ApiException(sync.error!, 0)),
        style: TextStyle(color: theme.colorScheme.error),
      ),
  ];
}

/// What kind of client a session is, in words.
String sessionClient(AppLocalizations l10n, Object? client) =>
    client == 'web' ? l10n.accountClientWeb : l10n.accountClientPhone;

/// "Web · last seen Sep 3, 8:43 PM", on this phone's clock (Q5-27).
@visibleForTesting
String sessionSeen(
  BuildContext context,
  AppLocalizations l10n,
  Map<String, Object?> session,
) {
  final client = sessionClient(l10n, session['client']);
  final seen = DateTime.tryParse('${session['lastSeenAt']}');
  if (seen == null) return client;
  return '$client · ${l10n.accountLastSeen(formatMoment(context, seen))}';
}

/// The signed-in sessions, each with a way to end it ([[Accounts]]).
///
/// Ending one asks first, says it is done, and keeps the sheet open on
/// the rest; a list that could not be read offers to try again; and
/// each row carries the day it signed in, so seven "Chrome on Linux"
/// can be told apart (U6-18).
class AccountDevices extends ConsumerStatefulWidget {
  const AccountDevices({super.key});

  @override
  ConsumerState<AccountDevices> createState() => _AccountDevicesState();
}

class _AccountDevicesState extends ConsumerState<AccountDevices> {
  late Future<List<Map<String, Object?>>> _sessions = _read();

  /// The one being ended: its button waits, and a second tap on it
  /// ends nothing more.
  String? _ending;

  Future<List<Map<String, Object?>>> _read() =>
      ref.read(accountControllerProvider.notifier).sessions();

  Future<void> _end(Map<String, Object?> session, String name) async {
    if (_ending != null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirm(
      context,
      title: l10n.accountEndSessionTitle(name),
      body: l10n.accountEndSessionBody,
      confirmLabel: l10n.accountEndSession,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _ending = session['id']! as String);
    try {
      await ref
          .read(accountControllerProvider.notifier)
          .endSession(session['id']! as String);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.accountSessionEnded(name))),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(accountError(l10n, error))),
      );
    }
    if (!mounted) return;
    setState(() {
      _ending = null;
      _sessions = _read();
    });
  }

  /// Ends every session but this one, after asking (U6-18).
  Future<void> _endOthers(List<Map<String, Object?>> sessions) async {
    if (_ending != null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final others = [
      for (final session in sessions)
        if (session['current'] != true) session['id']! as String,
    ];
    final ok = await confirm(
      context,
      title: l10n.accountEndOthersTitle,
      body: l10n.accountEndOthersBody,
      confirmLabel: l10n.accountEndOthers,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _ending = _all);
    final controller = ref.read(accountControllerProvider.notifier);
    var ended = 0;
    Object? failure;
    for (final id in others) {
      try {
        await controller.endSession(id);
        ended++;
      } on Object catch (error) {
        failure = error;
      }
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? l10n.accountOthersEnded(ended)
              : accountError(l10n, failure),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _ending = null;
      _sessions = _read();
    });
  }

  /// [_ending] while every other session is being ended.
  static const _all = '*';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HarvestSheet(
      title: l10n.accountDevices,
      children: [
        FutureBuilder<List<Map<String, Object?>>>(
          future: _sessions,
          builder: (context, snapshot) {
            final sessions = snapshot.data;
            if (snapshot.hasError &&
                snapshot.connectionState == ConnectionState.done) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(accountError(l10n, snapshot.error!)),
                  const SizedBox(height: HarvestSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _sessions = _read()),
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.accountDevicesRetry),
                  ),
                ],
              );
            }
            if (sessions == null) return const LinearProgressIndicator();
            final others = sessions.where((s) => s['current'] != true).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final session in sessions)
                  _deviceRow(context, l10n, session),
                if (others > 1) ...[
                  const SizedBox(height: HarvestSpacing.sm),
                  OutlinedButton.icon(
                    key: const ValueKey('end-other-sessions'),
                    onPressed: _ending == null
                        ? () => unawaited(_endOthers(sessions))
                        : null,
                    icon: const Icon(Icons.logout),
                    label: Text(l10n.accountEndOthers),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _deviceRow(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, Object?> session,
  ) {
    final current = session['current'] == true;
    final name =
        (session['deviceName'] as String?) ??
        sessionClient(l10n, session['client']);
    final since = DateTime.tryParse('${session['createdAt']}');
    final ending = _ending == session['id'];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        session['client'] == 'web' ? Icons.language : Icons.phone_android,
      ),
      title: Text(current ? l10n.accountThisDevice : name),
      subtitle: Text(
        [
          sessionSeen(context, l10n, session),
          if (since != null)
            l10n.accountSignedInOn(formatDay(context, HarvestDay.of(since))),
        ].join(' · '),
      ),
      trailing: current
          ? null
          : ending
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: _ending == null
                  ? () => unawaited(_end(session, name))
                  : null,
              child: Text(l10n.accountEndSession),
            ),
    );
  }
}

/// The sync PIN ([[Accounts]]): set once per device, never sent.
///
/// *Change PIN* is starting over while I still have everything: a file
/// on the server is named by its contents and cannot be re-sealed in
/// place, so the server's private rows and files go, and this phone
/// sends its own again under the new PIN. The other devices are asked
/// for the new one at their next sync.
class SyncPinTile extends ConsumerWidget {
  const SyncPinTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final set = ref.watch(syncPassphraseProvider).value ?? false;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(set ? Icons.lock_outline : Icons.lock_open_outlined),
      title: Text(l10n.syncPinTitle),
      subtitle: Text(set ? l10n.syncPinIsSet : l10n.syncPinWaiting),
      trailing: set
          ? PopupMenuButton<bool>(
              key: const ValueKey('sync-pin-menu'),
              tooltip: l10n.syncPinMenu,
              onSelected: (change) async {
                if (!change) {
                  // Asked first (U6-19): money, places and pictures stay
                  // locked here until the PIN is entered again.
                  final pin = ref.read(syncPassphraseProvider.notifier);
                  final ok = await confirm(
                    context,
                    title: l10n.syncPinForgetTitle,
                    body: l10n.syncPinForgetBody,
                    confirmLabel: l10n.syncPinForget,
                  );
                  if (ok) await pin.forget();
                  return;
                }
                // Changing is starting over while I still have it all:
                // what this phone holds goes up under the new one.
                if (await startSyncPinOver(context, ref, changing: true) &&
                    context.mounted) {
                  await showSyncPinSheet(context);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: true, child: Text(l10n.syncPinChange)),
                PopupMenuItem(value: false, child: Text(l10n.syncPinForget)),
              ],
            )
          : const Icon(Icons.chevron_right),
      onTap: set ? null : () => unawaited(showSyncPinSheet(context)),
    );
  }
}
