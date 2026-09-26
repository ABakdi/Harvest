import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/presentation/account_card.dart';
import 'package:harvest/features/account/presentation/sync_pin_sheet.dart';
import 'package:harvest/features/sync/presentation/sync_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The small mark on the account circle: how sync stands ([[Accounts]]).
enum SyncMark {
  /// Signed out: no mark at all.
  none,

  /// Everything has gone up.
  sent,

  /// Something waits — changes, a first sync, a verification.
  pending,

  /// The server was not reached.
  offline,

  /// The last sync failed.
  error,
}

/// Which mark the circle wears.
SyncMark syncMarkOf({required Me? me, required SyncStatus sync}) {
  if (me == null) return SyncMark.none;
  if (sync.offline) return SyncMark.offline;
  if (sync.error != null) return SyncMark.error;
  if (!me.verified || sync.running || sync.pending > 0 || sync.last == null) {
    return SyncMark.pending;
  }
  return SyncMark.sent;
}

/// The account at a glance, top-left on every tab ([[Accounts]]): my
/// initial when signed in, a plain person when not, a mark for how sync
/// stands and a dot while the sync PIN is still to set. A tap opens
/// [AccountSheet].
class AccountCircle extends ConsumerWidget {
  const AccountCircle({super.key});

  static Color markColor(SyncMark mark, ColorScheme scheme) => switch (mark) {
    SyncMark.none => Colors.transparent,
    SyncMark.sent => HarvestBrand.mid,
    SyncMark.pending => Colors.amber.shade700,
    SyncMark.offline => Colors.grey,
    SyncMark.error => scheme.error,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(accountControllerProvider).value?.me;
    final sync = ref.watch(syncControllerProvider);
    // Unknown counts as set: a dot that flickers on at every start is
    // worse than one that arrives a moment late.
    final pinMissing =
        me != null && !(ref.watch(syncPassphraseProvider).value ?? true);
    final mark = syncMarkOf(me: me, sync: sync);

    final words = [
      switch (mark) {
        SyncMark.none => null,
        SyncMark.sent => l10n.accountAllSent,
        SyncMark.pending =>
          sync.pending > 0 ? l10n.accountPending(sync.pending) : null,
        SyncMark.offline => l10n.accountOffline,
        SyncMark.error => accountError(l10n, ApiException(sync.error!, 0)),
      },
      if (pinMissing) l10n.syncPinWaiting,
    ].nonNulls.join(' · ');

    final initial = me == null
        ? null
        : String.fromCharCodes(
            (me.displayName ?? me.email).trim().runes.take(1),
          ).toUpperCase();

    return Semantics(
      value: words,
      child: IconButton(
        key: const ValueKey('account-circle'),
        tooltip: l10n.accountCircleLabel,
        constraints: const BoxConstraints(
          minWidth: HarvestSpacing.tap,
          minHeight: HarvestSpacing.tap,
        ),
        onPressed: () => unawaited(showAccountSheet(context)),
        icon: SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: me == null
                    ? scheme.surfaceContainerHighest
                    : scheme.primaryContainer,
                foregroundColor: me == null
                    ? scheme.onSurfaceVariant
                    : scheme.onPrimaryContainer,
                child: initial == null || initial.isEmpty
                    ? const Icon(Icons.person_outline, size: 20)
                    : Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              if (mark != SyncMark.none)
                PositionedDirectional(
                  end: -1,
                  bottom: -1,
                  child: _Dot(
                    key: ValueKey('account-mark-${mark.name}'),
                    size: 11,
                    color: markColor(mark, scheme),
                    ring: scheme.surface,
                  ),
                ),
              if (pinMissing)
                PositionedDirectional(
                  end: -1,
                  top: -1,
                  child: _Dot(
                    key: const ValueKey('account-pin-dot'),
                    size: 9,
                    color: scheme.tertiary,
                    ring: scheme.surface,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.size,
    required this.color,
    required this.ring,
    super.key,
  });

  final double size;
  final Color color;
  final Color ring;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: ring, width: 1.5),
    ),
  );
}

/// The circle as an app bar's leading, on a tab's own screen. A screen
/// pushed on top keeps its back arrow instead; one with a drawer keeps
/// its menu button beside the circle.
Widget? accountLeading(BuildContext context, {bool drawer = false}) {
  if (ModalRoute.of(context)?.impliesAppBarDismissal ?? false) return null;
  if (!drawer) return const AccountCircle();
  return const Row(
    mainAxisSize: MainAxisSize.min,
    children: [AccountCircle(), DrawerButton()],
  );
}

/// The width [accountLeading] needs, or null for the app bar's own.
double? accountLeadingWidth(BuildContext context, {bool drawer = false}) {
  if (!drawer) return null;
  if (ModalRoute.of(context)?.impliesAppBarDismissal ?? false) return null;
  return HarvestSpacing.tap * 2 + HarvestSpacing.sm;
}

Future<void> showAccountSheet(BuildContext context) => showHarvestSheet<void>(
  context,
  builder: (_) => const AccountSheet(),
);

/// What the circle opens: the account, how sync stands, and the few
/// things worth doing from anywhere. The full page stays in Settings.
class AccountSheet extends ConsumerWidget {
  const AccountSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(accountControllerProvider).value;
    final me = account?.me;
    return HarvestSheet(
      title: l10n.accountCircleLabel,
      children: me == null
          ? _signedOut(context, l10n)
          : _signedIn(context, ref, l10n, me),
    );
  }

  static void _openPage(BuildContext context, {bool creating = false}) {
    Navigator.of(context)
      ..pop()
      ..push(
        MaterialPageRoute<void>(
          builder: (_) => AccountPage(creating: creating),
        ),
      );
  }

  List<Widget> _signedOut(BuildContext context, AppLocalizations l10n) => [
    Text(l10n.accountWhy),
    const SizedBox(height: HarvestSpacing.md),
    FilledButton(
      onPressed: () => _openPage(context),
      child: Text(l10n.accountSignIn),
    ),
    const SizedBox(height: HarvestSpacing.sm),
    OutlinedButton(
      onPressed: () => _openPage(context, creating: true),
      child: Text(l10n.accountCreate),
    ),
  ];

  List<Widget> _signedIn(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Me me,
  ) {
    final theme = Theme.of(context);
    final sync = ref.watch(syncControllerProvider);
    final last = sync.last;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.account_circle_outlined),
        title: Text(me.email),
        subtitle: Text(
          me.verified ? l10n.accountVerified : l10n.accountUnverified,
        ),
      ),
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
        sync.pending > 0
            ? l10n.accountPending(sync.pending)
            : l10n.accountAllSent,
        style: muted,
      ),
      if (sync.error != null && !sync.offline)
        Text(
          accountError(l10n, ApiException(sync.error!, 0)),
          style: TextStyle(color: theme.colorScheme.error),
        ),
      const SizedBox(height: HarvestSpacing.sm),
      FilledButton.tonalIcon(
        // Unverified too: the sync asks the server again first.
        onPressed: sync.running
            ? null
            : () => unawaited(
                ref.read(syncControllerProvider.notifier).syncNow(),
              ),
        icon: const Icon(Icons.sync),
        label: Text(sync.running ? l10n.accountSyncing : l10n.accountSyncNow),
      ),
      const Divider(height: HarvestSpacing.lg),
      const SyncPinTile(),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.devices_outlined),
        title: Text(l10n.accountDevices),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => unawaited(
          showHarvestSheet<void>(
            context,
            builder: (_) => const AccountDevices(),
          ),
        ),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.manage_accounts_outlined),
        title: Text(l10n.accountPage),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openPage(context),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.logout),
        title: Text(l10n.accountSignOut),
        onTap: () async {
          final controller = ref.read(accountControllerProvider.notifier);
          final ok = await confirm(
            context,
            title: l10n.accountSignOut,
            body: l10n.accountSignOutBody,
            confirmLabel: l10n.accountSignOut,
          );
          if (ok) await controller.logout();
        },
      ),
    ];
  }
}

/// Settings → Account, reached from the circle: the full page.
class AccountPage extends StatelessWidget {
  const AccountPage({this.creating = false, super.key});

  final bool creating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAccount)),
      body: ListView(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        children: [AccountCard(creating: creating)],
      ),
    );
  }
}

/// Keeps "asked this start" for the sync PIN prompt: once per start,
/// and again after each sign-in ([[Accounts]]: asked for, not hidden).
class SyncPinAsked extends Notifier<bool> {
  @override
  bool build() => false;

  bool get asked => state;
  set asked(bool value) => state = value;
}

final syncPinAskedProvider = NotifierProvider<SyncPinAsked, bool>(
  SyncPinAsked.new,
);

/// Asks for the sync PIN when a signed-in device has none: straight
/// after signing in, and at a start while signed in. *Later* puts it off
/// until the next start; the circle keeps its dot meanwhile.
class SyncPinPrompt extends ConsumerStatefulWidget {
  const SyncPinPrompt({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncPinPrompt> createState() => _SyncPinPromptState();
}

class _SyncPinPromptState extends ConsumerState<SyncPinPrompt> {
  var _showing = false;

  @override
  void initState() {
    super.initState();
    ref
      ..listenManual(accountControllerProvider, (previous, next) {
        final before = previous?.value?.me;
        final now = next.value?.me;
        // Signed out, or into another account: the next sign-in asks.
        _consider(
          forgetAsked: now == null || (before != null && before.id != now.id),
        );
      }, fireImmediately: true)
      ..listenManual(
        syncPassphraseProvider,
        (_, _) => _consider(),
        fireImmediately: true,
      );
  }

  /// After the frame: the listeners fire while the tree is building,
  /// and nothing may change then.
  void _consider({bool forgetAsked = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final asked = ref.read(syncPinAskedProvider.notifier);
      if (forgetAsked) asked.asked = false;
      if (_showing) return;
      final me = ref.read(accountControllerProvider).value?.me;
      final set = ref.read(syncPassphraseProvider);
      if (me == null || !set.hasValue || set.value!) return;
      if (asked.asked) return;
      asked.asked = true;
      _showing = true;
      unawaited(
        showSyncPinSheet(
          context,
          asking: true,
        ).whenComplete(() => _showing = false),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
