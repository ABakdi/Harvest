import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/check_in_controller.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Logs units against a project: from the field and from the end of a
/// focus session alike. Returns the check-in result, or null when the
/// sheet was dismissed.
Future<CheckInResult?> showQuantitySheet(
  BuildContext context,
  WidgetRef ref, {
  required FieldItem item,
}) {
  final commitment = item.commitment;
  final remaining = commitment.maxUnitsPerDay - item.loggedToday;
  return showHarvestSheet<CheckInResult>(
    context,
    builder: (sheetContext) => _QuantitySheet(
      commitment: commitment,
      remaining: remaining,
      onLog: (quantity) => ref
          .read(checkInControllerProvider.notifier)
          .checkIn(
            commitment,
            quantity: quantity,
          ),
    ),
  );
}

class _QuantitySheet extends StatefulWidget {
  const _QuantitySheet({
    required this.commitment,
    required this.remaining,
    required this.onLog,
  });

  final Commitment commitment;
  final int remaining;
  final Future<CheckInResult?> Function(int quantity) onLog;

  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  late final _controller = TextEditingController(
    text: '${widget.commitment.dailyCommitment ?? 1}',
  );
  var _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _quantity {
    final value = int.tryParse(_controller.text);
    return value != null && value > 0 ? value : null;
  }

  Future<void> _submit() async {
    final quantity = _quantity;
    if (quantity == null || _busy) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      final result = await widget.onLog(quantity);
      navigator.pop(result);
    } on Object {
      if (mounted) setState(() => _busy = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HarvestSheet(
      title: l10n.logProgressTitle,
      subtitle: widget.commitment.title,
      actionLabel: l10n.log,
      onAction: _quantity == null || _busy ? null : _submit,
      scrollable: false,
      children: [
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => unawaited(_submit()),
          decoration: InputDecoration(
            labelText: l10n.logQuantityLabel,
            helperText: l10n.logRemainingToday(widget.remaining),
          ),
        ),
      ],
    );
  }
}
