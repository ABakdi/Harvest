import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/widgets/text_prompt.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/presentation/account_card.dart';
import 'package:harvest/features/security/domain/auth_gateway.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Proves the account's password to the server (`POST /v1/me/reauth`):
/// done when it answers 204; a wrong one is 403 `forbidden`, and too many
/// 429 with how long to wait. Its own provider so a test needs no server.
final reauthProvider = Provider<Future<void> Function(String password)>(
  (ref) =>
      (password) => ref.read(apiClientProvider).post('/v1/me/reauth', {
        'password': password,
      }),
);

/// Asks who is holding the phone before anything of mine is written out
/// ([[Phase-7-Privacy-and-Currencies]], M7.6). Signed in, the account's
/// password, checked by the server, so a phone left open is not an
/// archive for whoever picks it up; signed out, the phone's own lock. A
/// phone with no lock at all has nothing to ask with, and lets it go:
/// whoever holds it can read everything anyway. True when it passed.
Future<bool> confirmItsMe(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  void say(String words) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(words)));

  final account = ref.read(accountControllerProvider).value;
  if (account?.signedIn ?? false) {
    final password = await promptForPassword(
      context,
      title: l10n.exportConfirmPassword,
      confirmLabel: l10n.exportAction,
    );
    if (password == null || password.isEmpty) return false;
    try {
      await ref.read(reauthProvider)(password);
      return true;
    } on ApiException catch (error) {
      if (error.code == 'forbidden') {
        say(l10n.syncPinWrongPassword);
      } else if (error.status == 429) {
        final minutes = ((error.retryAfter?.inSeconds ?? 60) / 60).ceil();
        say(l10n.exportConfirmLimited(minutes < 1 ? 1 : minutes));
      } else if (error.offline) {
        say(l10n.exportConfirmOffline);
      } else {
        say(accountError(l10n, error));
      }
      return false;
    }
  }

  final lock = ref.read(authGatewayProvider);
  if (!await lock.canAuthenticate()) return true;
  final outcome = await lock.authenticate(reason: l10n.exportConfirmReason);
  if (outcome == AuthOutcome.unlocked || outcome == AuthOutcome.noCredentials) {
    return true;
  }
  say(l10n.exportConfirmRefused);
  return false;
}
