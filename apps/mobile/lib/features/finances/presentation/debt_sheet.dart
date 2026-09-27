import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/confirm_dialog.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/amount_expression.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/guarded.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/finances/presentation/money_sheet.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Bottom sheet to log a new debt with its advanced options, or, with
/// [existing], to correct one or remove it ([[Finances]] The Vault).
Future<void> showDebtSheet(BuildContext context, {Debt? existing}) =>
    showHarvestSheet<void>(
      context,
      builder: (_) => _DebtSheet(existing: existing),
    );

class _DebtSheet extends ConsumerStatefulWidget {
  const _DebtSheet({this.existing});

  final Debt? existing;

  @override
  ConsumerState<_DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends ConsumerState<_DebtSheet> {
  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  Currency _currency = Currency.dzd;
  HarvestDay? _payOffBy;
  TimeOfDay? _remindAt;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      _currency =
          ref.read(financeSettingsProvider).value?.defaultCurrency ??
          Currency.dzd;
      return;
    }
    _personController.text = existing.person;
    _amountController.text = formatMinor(existing.amountMinor);
    _noteController.text = existing.note ?? '';
    _currency = existing.currency;
    _payOffBy = existing.payOffBy;
    final remind = SettingsRepository.parseTime(existing.remindAt);
    if (remind != null) {
      _remindAt = TimeOfDay(hour: remind.$1, minute: remind.$2);
    }
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // A sum counts here as it does in the expense sheet ([[Audit-v3]] G5-06).
  int? get _minor => evaluateAmountToMinor(_amountController.text);

  /// What has been paid already: an edit cannot owe less than that.
  int get _paid => widget.existing?.paidMinor ?? 0;

  bool get _belowPaid => _minor != null && _minor! < _paid;

  bool get _valid =>
      _personController.text.trim().isNotEmpty && _minor != null && !_belowPaid;

  Future<void> _save() async {
    final minor = _minor!;
    final person = _personController.text.trim();
    final note = _noteController.text.trim();
    final remindAt = _remindAt;
    // Everything the save needs is read before the sheet closes: once it
    // is popped its ref is gone, and reaching for it after the awaits
    // below threw "Using ref when a widget is unmounted".
    final vault = ref.read(vaultRepositoryProvider);
    final notifications = ref.read(notificationServiceProvider);
    final planner = ref.read(notificationPlannerProvider);
    final remindText = remindAt == null
        ? null
        : '${remindAt.hour}:${remindAt.minute.toString().padLeft(2, '0')}';
    final existing = widget.existing;
    final saved = runGuarded(
      context,
      existing == null
          ? vault.createDebt(
              person: person,
              amountMinor: minor,
              currency: _currency,
              payOffBy: _payOffBy,
              remindAt: remindText,
              note: note.isEmpty ? null : note,
            )
          : vault.updateDebt(
              uuid: existing.uuid,
              person: person,
              amountMinor: minor,
              currency: _currency,
              payOffBy: _payOffBy,
              remindAt: remindText,
              note: note.isEmpty ? null : note,
            ),
      haptic: false,
    );
    Navigator.of(context).pop();
    if (!await saved) return;
    // Only a debt with a reminder has anything to ring for; asking to
    // notify about one without is a question with no reason behind it.
    if (remindAt != null) await notifications.requestPermission();
    await planner.planToday();
  }

  /// A debt logged by mistake goes the way an expense does: ask,
  /// remove, offer Undo. Its payments go with it; the wallet keeps
  /// what they took, because that money did leave.
  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final l10n = AppLocalizations.of(context);
    final vault = ref.read(vaultRepositoryProvider);
    final planner = ref.read(notificationPlannerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await confirm(
      context,
      title: l10n.debtDeleteTitle,
      body: l10n.debtDeleteBody(existing.person),
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final removed = runGuarded(
      context,
      vault.deleteDebt(existing.uuid),
      haptic: false,
    );
    navigator.pop();
    if (!await removed) return;
    // Its reminder stops with it.
    unawaited(planner.planToday());
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // An action is an offer for a few seconds, not a fixture.
          persist: false,
          content: Text(l10n.deleted),
          action: SnackBarAction(
            label: l10n.undoAction,
            onPressed: () async {
              await vault.restoreDebt(existing.uuid);
              await planner.planToday();
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final existing = widget.existing;
    // Payments were made in the debt's currency; it stays that one.
    final currencyLocked = _paid > 0;

    return HarvestSheet(
      title: existing == null ? l10n.addDebt : l10n.debtEditTitle,
      trailing: existing == null
          ? null
          : IconButton(
              tooltip: l10n.deleteAction,
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: () => unawaited(_delete()),
            ),
      actionLabel: l10n.save,
      onAction: _valid ? () => unawaited(_save()) : null,
      children: [
        TextField(
          controller: _personController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: l10n.debtPerson),
        ),
        const SizedBox(height: HarvestSpacing.md),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(amountCharacters),
          ],
          onChanged: (_) => setState(() {}),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            labelText: l10n.amountLabel,
            prefixText: _currency.symbol,
            errorText: _belowPaid
                ? l10n.debtAmountBelowPaid(formatMoney(_paid, _currency))
                : null,
            helperText: amountSumHelper(
              l10n,
              _amountController.text,
              _currency,
            ),
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        if (!currencyLocked)
          SegmentedButton<Currency>(
            segments: [
              for (final option in Currency.values)
                ButtonSegment(value: option, label: Text(option.symbol)),
            ],
            selected: {_currency},
            onSelectionChanged: (selection) =>
                setState(() => _currency = selection.first),
          ),
        const SizedBox(height: HarvestSpacing.md),
        _OptionRow(
          icon: Icons.event,
          label: l10n.debtPayOffBy,
          value: _payOffBy == null
              ? l10n.notSet
              : DateFormat.MMMd(locale).format(
                  DateTime(
                    _payOffBy!.year,
                    _payOffBy!.month,
                    _payOffBy!.day,
                  ),
                ),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: now,
              lastDate: now.add(const Duration(days: 365 * 5)),
            );
            if (picked != null) {
              setState(() => _payOffBy = HarvestDay.fromDate(picked));
            }
          },
        ),
        _OptionRow(
          icon: Icons.alarm,
          label: l10n.debtRemindAt,
          value: _remindAt == null ? l10n.notSet : _remindAt!.format(context),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _remindAt ?? const TimeOfDay(hour: 19, minute: 0),
            );
            if (picked != null) setState(() => _remindAt = picked);
          },
        ),
        const SizedBox(height: HarvestSpacing.sm),
        TextField(
          controller: _noteController,
          decoration: InputDecoration(labelText: l10n.noteLabel),
        ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconBadge(icon, color: theme.colorScheme.tertiary, size: 40),
      title: Text(label),
      trailing: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.primary,
        ),
      ),
      onTap: onTap,
    );
  }
}
