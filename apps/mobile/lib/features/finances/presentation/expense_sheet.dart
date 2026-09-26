import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/celebration.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/amount_expression.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/domain/finance_actions.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:harvest/features/finances/presentation/amount_keypad.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/places/presentation/geotag_chip.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Icons a custom category can pick from (and the preset icons).
const categoryIconRegistry = <String, IconData>{
  'restaurant': Icons.restaurant,
  'bus': Icons.directions_bus,
  'receipt': Icons.receipt_long,
  'bag': Icons.shopping_bag,
  'heart': Icons.favorite,
  'movie': Icons.movie,
  'category': Icons.category,
  'coffee': Icons.local_cafe,
  'home': Icons.home,
  'car': Icons.directions_car,
  'gift': Icons.card_giftcard,
  'pets': Icons.pets,
  'school': Icons.school,
  'fitness': Icons.fitness_center,
  'phone': Icons.smartphone,
  'games': Icons.sports_esports,
  'travel': Icons.flight,
  'baby': Icons.child_friendly,
  'tools': Icons.handyman,
  'music': Icons.music_note,
};

/// Resolves any category key (preset or custom) to an icon.
IconData categoryIcon(String key, {List<CustomCategory> customs = const []}) {
  final preset = ExpenseCategory.values
      .where((category) => category.name == key)
      .firstOrNull;
  if (preset != null) {
    return switch (preset) {
      ExpenseCategory.food => Icons.restaurant,
      ExpenseCategory.transport => Icons.directions_bus,
      ExpenseCategory.bills => Icons.receipt_long,
      ExpenseCategory.shopping => Icons.shopping_bag,
      ExpenseCategory.health => Icons.favorite,
      ExpenseCategory.entertainment => Icons.movie,
      ExpenseCategory.other => Icons.category,
    };
  }
  final custom = customs.where((category) => category.name == key).firstOrNull;
  return categoryIconRegistry[custom?.icon] ?? Icons.category;
}

/// Resolves any category key to a display label.
String categoryLabel(AppLocalizations l10n, String key) {
  final preset = ExpenseCategory.values
      .where((category) => category.name == key)
      .firstOrNull;
  if (preset == null) return key; // customs display their own name
  return switch (preset) {
    ExpenseCategory.food => l10n.catFood,
    ExpenseCategory.transport => l10n.catTransport,
    ExpenseCategory.bills => l10n.catBills,
    ExpenseCategory.shopping => l10n.catShopping,
    ExpenseCategory.health => l10n.catHealth,
    ExpenseCategory.entertainment => l10n.catEntertainment,
    ExpenseCategory.other => l10n.catOther,
  };
}

/// What a new expense starts from when something else suggests it: a
/// list item just bought offers its title and estimate ([[Lists]] L4).
/// Only a suggestion — typed over, or the sheet dismissed, and nothing
/// is logged.
typedef ExpensePrefill = ({
  int? amountMinor,
  Currency? currency,
  String? note,
  String? category,
});

/// The sub-5-second quick-log: amount, category chip, optional note.
/// Pass [existing] to edit a same-day entry in place, or [prefill] to
/// start a new one from a suggestion.
Future<void> showExpenseSheet(
  BuildContext context, {
  Expense? existing,
  ExpensePrefill? prefill,
}) => showHarvestSheet<void>(
  context,
  builder: (_) => _ExpenseSheet(existing: existing, prefill: prefill),
);

/// What the wallet would hold in [currency] without the expense being
/// edited: its own movement ([linked]) is given back before comparing —
/// unless it is still upcoming on [today], when the balance never took
/// it ([[Finances]]).
@visibleForTesting
int walletBalanceFor(
  Map<Currency, int> balances,
  Currency currency, {
  MoneyTxn? linked,
  HarvestDay? today,
}) {
  final balance = balances[currency] ?? 0;
  return linked != null &&
          linked.currency == currency &&
          !linked.isUpcoming(today ?? HarvestDay.today())
      ? balance - linked.deltaMinor
      : balance;
}

/// Paying from the wallet is the default whenever the wallet can cover
/// [amountMinor], and never happens when it cannot — whatever [choice]
/// was made, the wallet does not go below zero.
@visibleForTesting
bool paysFromWallet({
  required int? amountMinor,
  required int walletBalance,
  bool? choice,
}) =>
    amountMinor != null && walletBalance >= amountMinor && (choice ?? true);

class _ExpenseSheet extends ConsumerStatefulWidget {
  const _ExpenseSheet({this.existing, this.prefill});

  final Expense? existing;
  final ExpensePrefill? prefill;

  @override
  ConsumerState<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<_ExpenseSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _category = ExpenseCategory.food.name;
  Currency? _currency;

  /// The Harvest Day the expense belongs to: today unless I say
  /// otherwise — a receipt found in a pocket is still Tuesday's
  /// ([[Checkpoint-8]]).
  /// Null until I pick a day or edit an existing expense: the day is
  /// then decided when it is saved, so a sheet opened at 2:58 and saved
  /// at 3:02 files under the new day ([[Audit-v2]] B3-07).
  HarvestDay? _day;

  /// null until the user decides: the toggle follows the wallet balance
  /// on a new expense, and the existing movement when editing one.
  bool? _walletChoice;

  /// The movement this expense already took from the wallet, if any.
  MoneyTxn? _linked;

  @override
  void initState() {
    super.initState();
    // The keypad writes to the controller, and a controller set
    // programmatically never calls the field's onChanged — the same
    // lesson the note editor's toolbar taught ([[Checkpoint-5]]).
    _amountController.addListener(_onAmountChanged);
    final existing = widget.existing;
    final prefill = widget.prefill;
    if (existing == null && prefill != null) {
      if (prefill.amountMinor case final minor?) {
        _amountController.text = formatMinor(minor);
      }
      _noteController.text = prefill.note ?? '';
      _category = prefill.category ?? _category;
      _currency = prefill.currency;
    }
    if (existing != null) {
      _amountController.text = formatMinor(existing.amountMinor);
      _noteController.text = existing.note ?? '';
      _category = existing.category;
      _currency = existing.currency;
      _day = existing.day;
      // Whether this expense already came out of the wallet.
      unawaited(
        ref.read(vaultRepositoryProvider).linkedTxn(existing.uuid).then((txn) {
          if (mounted) {
            setState(() {
              _walletChoice = txn != null;
              _linked = txn;
            });
          }
        }),
      );
    }
  }

  /// This expense's currency: the one it was logged in, or [fallback]
  /// (the app default). Taking the fallback as a parameter keeps the
  /// provider's type in view, which bare inference loses.
  Currency _currencyOr(Currency fallback) => _currency ?? fallback;

  Currency get _effectiveCurrency =>
      _currencyOr(ref.read(defaultCurrencyProvider));

  int get _walletBalance => walletBalanceFor(
    ref.watch(accountBalancesProvider(MoneyAccount.wallet)),
    _effectiveCurrency,
    linked: _linked,
    today: ref.watch(currentHarvestDayProvider),
  );

  bool get _walletCanCover =>
      _amountMinor != null && _walletBalance >= _amountMinor!;

  bool get _fromWallet => paysFromWallet(
    amountMinor: _amountMinor,
    walletBalance: _walletBalance,
    choice: _walletChoice,
  );

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController
      ..removeListener(_onAmountChanged)
      ..dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// The amount, or what the sum in the box comes to — a receipt is
  /// three things and a coffee, and adding it up is the app's job
  /// ([[Checkpoint-6]]).
  int? get _amountMinor => evaluateAmountToMinor(_amountController.text);

  bool get _isSum => isAmountExpression(_amountController.text);

  /// Logs (or edits) the expense in one transaction, wallet movement
  /// included, and reports a failure instead of pretending it saved.
  Future<void> _log() async {
    final amount = _amountMinor;
    if (amount == null) return;
    final note = _noteController.text.trim();
    final existing = widget.existing;
    final currency = _effectiveCurrency;
    final actions = ref.read(financeActionsProvider);
    final planner = ref.read(notificationPlannerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);

    // The reward burst rides above the sheet before it closes.
    final box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      showCheckInBurst(
        context,
        box.localToGlobal(box.size.topCenter(Offset.zero)),
        color: Theme.of(context).colorScheme.secondary,
      );
    }
    navigator.pop();

    try {
      if (existing != null) {
        await actions.updateExpense(
          uuid: existing.uuid,
          amountMinor: amount,
          category: _category,
          currency: currency,
          fromWallet: _fromWallet,
          note: note.isEmpty ? null : note,
          day: _day,
        );
      } else {
        await actions.logExpense(
          amountMinor: amount,
          category: _category,
          currency: currency,
          fromWallet: _fromWallet,
          note: note.isEmpty ? null : note,
          day: _day,
        );
      }
      await HarvestHaptics.thud();
      await planner.reevaluate();
    } on Exception catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    }
  }

  /// Removing an expense from the sheet I opened it in. The swipe on
  /// the day's list does the same thing, but a mis-log is noticed after
  /// tapping the row, not before — and there was no way out of here.
  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final l10n = AppLocalizations.of(context);
    final actions = ref.read(financeActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await confirm(
      context,
      title: l10n.deleteExpenseTitle,
      body: l10n.deleteExpenseBody(
        formatMoney(existing.amountMinor, existing.currency),
      ),
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!ok) return;
    navigator.pop();
    await actions.removeExpense(existing.uuid);
    messenger.showSnackBar(
      SnackBar(
        // An action is an offer for a few seconds, not a fixture.
        persist: false,
        content: Text(l10n.deleted),
        action: SnackBarAction(
          label: l10n.undoAction,
          onPressed: () => unawaited(actions.restoreExpense(existing.uuid)),
        ),
      ),
    );
  }

  /// Any day within a year either side: forgotten receipts look back,
  /// a bill I know is coming looks forward.
  Future<void> _pickDay() async {
    final today = HarvestDay.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: (_day ?? HarvestDay.today()).toDateTime(),
      firstDate: today.addDays(-365).toDateTime(),
      lastDate: today.addDays(365).toDateTime(),
    );
    if (picked == null || !mounted) return;
    unawaited(HarvestHaptics.tick());
    setState(() => _day = HarvestDay.fromDate(picked));
  }

  Future<void> _createCategory(BuildContext context) async {
    final created = await showCategoryCreator(context, ref);
    if (created != null) setState(() => _category = created);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final customs = ref.watch(customCategoriesProvider).value ?? const [];
    final currency = _currencyOr(ref.watch(defaultCurrencyProvider));

    return HarvestSheet(
      title: widget.existing == null ? l10n.logExpense : l10n.editExpense,
      trailing: widget.existing == null
          ? null
          : IconButton(
              tooltip: l10n.deleteAction,
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: () => unawaited(_delete()),
            ),
      // Editing saves what is already logged; only a new one is logged.
      actionLabel: widget.existing == null ? l10n.log : l10n.save,
      onAction: _amountMinor == null ? null : () => unawaited(_log()),
      children: [
        // Read-only to the system: the keypad below is the keyboard,
        // and the phone's own must not slide up over it. The caret
        // still shows and still moves, so a wrong digit mid-sum is a
        // tap away.
        TextField(
          controller: _amountController,
          autofocus: true,
          readOnly: true,
          showCursor: true,
          inputFormatters: [
            FilteringTextInputFormatter.allow(amountCharacters),
          ],
          onChanged: (_) => setState(() {}),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            labelText: l10n.amountLabel,
            prefixText: currency.symbol,
            // What the sum comes to, live, so Log never logs a surprise.
            helperText: !_isSum
                ? null
                : _amountMinor == null
                ? l10n.amountSumIncomplete
                : l10n.amountSum(formatMoney(_amountMinor!, currency)),
            helperStyle: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: _amountMinor == null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        AmountKeypad(controller: _amountController),
        const SizedBox(height: HarvestSpacing.xs),
        // Per-expense currency (checkpoint P4).
        SegmentedButton<Currency>(
          segments: [
            for (final option in Currency.values)
              ButtonSegment(
                value: option,
                label: Text(option.symbol),
              ),
          ],
          selected: {currency},
          onSelectionChanged: (selection) {
            unawaited(HarvestHaptics.tick());
            setState(() => _currency = selection.first);
          },
        ),
        const SizedBox(height: HarvestSpacing.md),
        Wrap(
          spacing: HarvestSpacing.xs,
          runSpacing: HarvestSpacing.xs,
          children: [
            for (final key in [
              ...presetCategoryKeys,
              ...customs.map((c) => c.name),
            ])
              ChoiceChip(
                avatar: Icon(
                  categoryIcon(key, customs: customs),
                  size: 18,
                ),
                label: Text(categoryLabel(l10n, key)),
                selected: _category == key,
                onSelected: (_) {
                  unawaited(HarvestHaptics.tick());
                  setState(() => _category = key);
                },
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(l10n.newCategory),
              onPressed: () => unawaited(_createCategory(context)),
            ),
          ],
        ),
        const SizedBox(height: HarvestSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.expenseDayLabel,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                _day == null || _day == HarvestDay.today()
                    ? l10n.dueToday
                    : formatDay(context, _day!, weekday: true),
              ),
              onPressed: () => unawaited(_pickDay()),
            ),
          ],
        ),
        const SizedBox(height: HarvestSpacing.xs),
        // Where the money comes from, answered here instead of in a
        // second sheet after the fact.
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.fromWalletToggle),
          subtitle: Text(
            _amountMinor != null && !_walletCanCover
                ? l10n.walletShort
                : l10n.walletHas(
                    formatMoney(_walletBalance, _effectiveCurrency),
                  ),
          ),
          // Choosable before the amount is in, like the vault's sheets.
          value: _amountMinor == null
              ? (_walletChoice ?? true) && _walletBalance > 0
              : _fromWallet,
          onChanged:
              (_amountMinor == null ? _walletBalance > 0 : _walletCanCover)
              ? (value) => setState(() => _walletChoice = value)
              : null,
        ),
        const SizedBox(height: HarvestSpacing.sm),
        TextField(
          controller: _noteController,
          textInputAction: TextInputAction.done,
          maxLength: noteMaxLength,
          decoration: InputDecoration(
            labelText: l10n.noteLabel,
            counterText: '',
          ),
        ),
        // Where the money was spent, if Places was there to say.
        if (widget.existing != null) ...[
          const SizedBox(height: HarvestSpacing.xs),
          GeotagChip(
            targetTable: 'expenses',
            targetUuid: widget.existing!.uuid,
          ),
        ],
      ],
    );
  }
}

/// Name + icon picker for a new category; returns the created key.
Future<String?> showCategoryCreator(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController();
  var icon = 'coffee';

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(l10n.newCategory),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.categoryName),
              ),
              const SizedBox(height: HarvestSpacing.md),
              SizedBox(
                width: 280,
                child: Wrap(
                  spacing: HarvestSpacing.xs,
                  runSpacing: HarvestSpacing.xs,
                  children: [
                    for (final entry in categoryIconRegistry.entries)
                      InkWell(
                        borderRadius: BorderRadius.circular(HarvestRadii.chip),
                        onTap: () => setState(() => icon = entry.key),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              HarvestRadii.chip,
                            ),
                            color: icon == entry.key
                                ? Theme.of(dialogContext).colorScheme.secondary
                                      .withValues(alpha: 0.3)
                                : null,
                          ),
                          child: Icon(entry.value, size: 22),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await ref
                  .read(financesRepositoryProvider)
                  .createCategory(name: name, icon: icon);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(name);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    ),
  );
}
