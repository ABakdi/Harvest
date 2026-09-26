import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/security/domain/app_lock.dart';
import 'package:harvest/features/security/domain/auth_gateway.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The shield over the whole app.
///
/// It lives in `MaterialApp.router`'s builder, above the navigator, so
/// it covers every route, sheet and dialog at once — there is no screen
/// the lock can be behind.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> {
  @override
  void initState() {
    super.initState();
    // A cold start into a locked app asks straight away, without
    // waiting for a tap (rule L3).
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptIfOwed());
  }

  void _promptIfOwed() {
    if (!mounted) return;
    final lock = ref.read(appLockProvider);
    if (lock.phase == AppLockPhase.locked && !lock.prompting) {
      unawaited(
        ref
            .read(appLockProvider.notifier)
            .unlock(reason: AppLocalizations.of(context).lockReason),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    // Coming back past the grace window flips covered → locked without
    // a tap, so the prompt has to follow the state, not the gesture.
    ref.listen(appLockProvider, (previous, next) {
      if (previous?.phase != AppLockPhase.locked &&
          next.phase == AppLockPhase.locked) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _promptIfOwed());
      }
    });

    return Stack(
      children: [
        widget.child,
        if (lock.phase != AppLockPhase.unlocked)
          _LockScreen(
            // The app switcher's snapshot only needs the cover; the
            // retry button belongs to the phase that actually asks.
            onRetry: lock.phase == AppLockPhase.locked && !lock.prompting
                ? _promptIfOwed
                : null,
            outcome: lock.lastOutcome,
          ),
      ],
    );
  }
}

/// The cover itself: the app's mark, why it is here, and a way back in.
class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.onRetry, this.outcome});

  final VoidCallback? onRetry;
  final AuthOutcome? outcome;

  String? _message(AppLocalizations l10n) => switch (outcome) {
    AuthOutcome.lockedOut => l10n.lockTooManyTries,
    AuthOutcome.unavailable => l10n.lockUnavailable,
    AuthOutcome.refused => l10n.lockRefused,
    // noCredentials disarms the lock instead of stranding the app, so
    // it never reaches the shield.
    AuthOutcome.noCredentials || AuthOutcome.unlocked || null => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final message = _message(l10n);

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(HarvestSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(HarvestSpacing.lg),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: theme.primaryGradient,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: HarvestSpacing.lg),
                Text(
                  l10n.lockTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: HarvestSpacing.xs),
                Text(
                  message ?? l10n.lockBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: message == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: HarvestSpacing.lg),
                if (onRetry != null)
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(l10n.lockUnlockAction),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
