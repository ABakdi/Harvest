import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Bottom sheet to log a new debt with its advanced options.
Future<void> showDebtSheet(BuildContext context) => showHarvestSheet<void>(
  context,
  builder: (_) => const _DebtSheet(),
);

class _DebtSheet extends ConsumerStatefulWidget {
  const _DebtSheet();

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
    _currency =
        ref.read(financeSettingsProvider).value?.defaultCurrency ??
        Currency.dzd;
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _valid =>
      _personController.text.trim().isNotEmpty &&
      parseToMinor(_amountController.text) != null;

  Future<void> _save() async {
    final minor = parseToMinor(_amountController.text)!;
    final person = _personController.text.trim();
    final note = _noteController.text.trim();
    Navigator.of(context).pop();
    await ref
        .read(vaultRepositoryProvider)
        .createDebt(
          person: person,
          amountMinor: minor,
          currency: _currency,
          payOffBy: _payOffBy,
          remindAt: _remindAt == null
              ? null
              : '${_remindAt!.hour}:'
                    '${_remindAt!.minute.toString().padLeft(2, '0')}',
          note: note.isEmpty ? null : note,
        );
    await ref.read(notificationServiceProvider).requestPermission();
    await ref.read(notificationPlannerProvider).planToday();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();

    return HarvestSheet(
      title: l10n.addDebt,
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
          onChanged: (_) => setState(() {}),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            labelText: l10n.amountLabel,
            prefixText: '${_currency.symbol} ',
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
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
