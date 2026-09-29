import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/celebration.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/hero_card.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/core/ui/widgets/ledger_row.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/core/ui/widgets/stat_tile.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/finance_actions.dart';
import 'package:harvest/features/finances/domain/move_filter.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:harvest/features/finances/presentation/debt_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/guarded.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/finances/presentation/money_sheet.dart';
import 'package:harvest/features/finances/presentation/move_filter_bar.dart';
import 'package:harvest/features/finances/presentation/moves_ledger.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

export 'package:harvest/features/finances/presentation/debt_sheet.dart'
    show showDebtSheet;

// Split along its three pots (Q6-27): each section in its own file.
part 'vault_debts.dart';
part 'vault_savings.dart';
part 'vault_wallet.dart';

/// The three pots of the vault (round 4: one clear section each).
enum VaultSection { wallet, savings, debts }

/// The vault: wallet (meant to be spent), savings (meant to be saved),
/// and debts — each section with its total and its own atomic moves.
class VaultTab extends ConsumerStatefulWidget {
  const VaultTab({super.key});

  @override
  ConsumerState<VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends ConsumerState<VaultTab> {
  VaultSection _section = VaultSection.wallet;

  /// One filter for the whole tab: narrowing to "food" and then
  /// switching pot should still be narrowed to food.
  MoveFilter _filter = MoveFilter.empty;

  void _select(VaultSection section) {
    if (section == _section) return;
    unawaited(HarvestHaptics.tick());
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final totals = ref.watch(vaultTotalsProvider);
    final health = ref.watch(savingsHealthProvider);
    final defaultCurrency = ref.watch(defaultCurrencyProvider);
    final savingsColor = health == SavingsHealth.low
        ? scheme.error
        : scheme.secondary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HarvestSpacing.md,
        HarvestSpacing.sm,
        HarvestSpacing.md,
        HarvestSpacing.xl,
      ),
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.account_balance_wallet,
                  color: scheme.primary,
                  label: l10n.walletTitle,
                  value: formatMoney(totals.wallet, defaultCurrency),
                  selected: _section == VaultSection.wallet,
                  onTap: () => _select(VaultSection.wallet),
                ),
              ),
              const SizedBox(width: HarvestSpacing.sm),
              Expanded(
                child: StatTile(
                  icon: Icons.savings,
                  color: savingsColor,
                  label: l10n.savingsSectionTitle,
                  value: formatMoney(totals.savings, defaultCurrency),
                  selected: _section == VaultSection.savings,
                  onTap: () => _select(VaultSection.savings),
                ),
              ),
              const SizedBox(width: HarvestSpacing.sm),
              Expanded(
                child: StatTile(
                  icon: Icons.handshake,
                  color: scheme.tertiary,
                  label: l10n.vaultOwed,
                  value: formatMoney(totals.owed, defaultCurrency),
                  selected: _section == VaultSection.debts,
                  onTap: () => _select(VaultSection.debts),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: HarvestSpacing.md),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: KeyedSubtree(
            key: ValueKey(_section),
            child: switch (_section) {
              VaultSection.wallet => _WalletSection(
                filter: _filter,
                onFilter: (filter) => setState(() => _filter = filter),
              ),
              VaultSection.savings => _SavingsSection(
                filter: _filter,
                onFilter: (filter) => setState(() => _filter = filter),
              ),
              VaultSection.debts => const _DebtsSection(),
            },
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------- shared bits

/// Per-currency balances inside a hero card: the default currency big,
/// the rest with their converted caption.
class _Balances extends StatelessWidget {
  const _Balances({
    required this.balances,
    required this.rates,
    required this.defaultCurrency,
  });

  final Map<Currency, int> balances;
  final Rates rates;
  final Currency defaultCurrency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = balances.entries.toList()
      ..sort((a, b) {
        if (a.key == defaultCurrency) return -1;
        if (b.key == defaultCurrency) return 1;
        return a.key.code.compareTo(b.key.code);
      });
    if (entries.isEmpty) {
      return Text(
        formatMoney(0, defaultCurrency),
        style: theme.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : HarvestSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatMoney(entries[i].value, entries[i].key),
                  style:
                      (i == 0
                              ? theme.textTheme.displaySmall
                              : theme.textTheme.titleLarge)
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                ),
                if (conversionCaption(
                      minor: entries[i].value,
                      currency: entries[i].key,
                      rates: rates,
                    )
                    case final caption?) ...[
                  const SizedBox(width: HarvestSpacing.sm),
                  Opacity(
                    opacity: 0.8,
                    child: Text(
                      caption,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// A translucent pill button living on a hero card.
class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Foreground on tinted cards; white on gradients when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? Colors.white;
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: foreground.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(HarvestRadii.button),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  unawaited(HarvestHaptics.tick());
                  onTap!();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HarvestSpacing.md,
              vertical: HarvestSpacing.sm + 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: HarvestSpacing.xs + 2),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One pot's ledger, grouped by day, inside a card.
