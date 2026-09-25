import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/wishlist/data/wishlist_repository.dart';
import 'package:harvest/features/wishlist/domain/wishlist.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// What the sheet hands back: title, list, optional estimate, currency,
/// optional note and optional planned day.
typedef WishlistDraft = ({
  String title,
  WishlistList list,
  int? priceMinor,
  Currency currency,
  String? note,
  HarvestDay? targetDay,
});

/// Writes an item down, or edits [existing]. The tab you add from is
/// preselected; editing carries the item's own list.
Future<WishlistDraft?> showWishlistEditor(
  BuildContext context, {
  WishlistItem? existing,
  WishlistList? initialList,
}) => showHarvestSheet<WishlistDraft>(
  context,
  builder: (_) => _WishlistEditorSheet(existing: existing, initialList: initialList),
);

class _WishlistEditorSheet extends ConsumerStatefulWidget {
  const _WishlistEditorSheet({this.existing, this.initialList});

  final WishlistItem? existing;

  /// The list the sheet opens on for a new item (the tab it was added from).
  final WishlistList? initialList;

  @override
  ConsumerState<_WishlistEditorSheet> createState() =>
      _WishlistEditorSheetState();
}

class _WishlistEditorSheetState extends ConsumerState<_WishlistEditorSheet> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _note = TextEditingController(text: widget.existing?.note);
  late final _amount = TextEditingController(
    text: widget.existing == null || widget.existing!.priceMinor == null
        ? ''
        : formatMinor(widget.existing!.priceMinor!),
  );
  late WishlistList _list =
      widget.existing?.list ?? widget.initialList ?? WishlistList.buy;
  late Currency _currency = widget.existing?.currency ?? Currency.dzd;
  late HarvestDay? _targetDay = widget.existing?.targetDay;
  var _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// Empty means "no estimate yet"; a filled field must be a number.
  int? get _minor {
    final text = _amount.text.trim();
    return text.isEmpty ? null : parseToMinor(text);
  }

  bool get _amountInvalid =>
      _amount.text.trim().isNotEmpty && _minor == null;

  Future<void> _pickDay() async {
    final today = HarvestDay.today();
    final last = today.addDays(365 * 10);
    // The picker only offers today onward, so a plan whose day has
    // already passed (or one typed far out on another device) opens on
    // the nearest day it can show instead of tripping its range check.
    var initial = _targetDay ?? today.addDays(7);
    if (initial.compareTo(today) < 0) initial = today;
    if (initial.compareTo(last) > 0) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.toDateTime(),
      firstDate: today.toDateTime(),
      lastDate: last.toDateTime(),
    );
    if (picked == null) return;
    setState(() => _targetDay = HarvestDay.fromDate(picked));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final repository = ref.read(wishlistRepositoryProvider);
    final title = _title.text.trim();
    final existing = widget.existing;
    if (existing == null) {
      final item = await repository.add(
        list: _list,
        title: title,
        priceMinor: _minor,
        currency: _currency,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        targetDay: _targetDay,
      );
      final draft = (
        title: item.title,
        list: item.list,
        priceMinor: item.priceMinor,
        currency: item.currency,
        note: item.note,
        targetDay: item.targetDay,
      );
      navigator.pop(draft);
      return;
    }
    await repository.edit(
      existing.uuid,
      title: title,
      priceMinor: _minor,
      currency: _currency,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      targetDay: _targetDay,
    );
    if (_list != existing.list) {
      await repository.move(existing.uuid, _list);
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final existing = widget.existing;
    final day = _targetDay;

    return HarvestSheet(
      title: existing == null ? l10n.wishlistNew : l10n.wishlistEditItem,
      actionLabel: l10n.save,
      onAction:
          _title.text.trim().isEmpty || _saving || _amountInvalid
          ? null
          : () => unawaited(_save()),
      children: [
        TextField(
          controller: _title,
          autofocus: existing == null,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.titleLabel,
            hintText: l10n.wishlistTitleHint,
            counterText: '',
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        SegmentedButton<WishlistList>(
          segments: [
            ButtonSegment(
              value: WishlistList.buy,
              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
              label: Text(l10n.wishlistBuyList),
            ),
            ButtonSegment(
              value: WishlistList.wish,
              icon: const Icon(Icons.star_outline, size: 18),
              label: Text(l10n.wishlistWishlist),
            ),
          ],
          selected: {_list},
          onSelectionChanged: (selection) =>
              setState(() => _list = selection.first),
        ),
        const SizedBox(height: HarvestSpacing.md),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            labelText: l10n.wishlistEstimateLabel,
            hintText: l10n.wishlistEstimateHint,
            prefixText: '${_currency.symbol} ',
            errorText: _amountInvalid ? l10n.wishlistEstimateInvalid : null,
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        SegmentedButton<Currency>(
          segments: [
            for (final currency in Currency.values)
              ButtonSegment(
                value: currency,
                label: Text(currency.code),
              ),
          ],
          selected: {_currency},
          onSelectionChanged: (selection) =>
              setState(() => _currency = selection.first),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        TextField(
          controller: _note,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.wishlistNoteLabel,
            hintText: l10n.wishlistNoteHint,
            counterText: '',
          ),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(l10n.wishlistTargetDay),
          subtitle: Text(
            day == null
                ? l10n.wishlistNoTargetDay
                : formatDay(context, day, weekday: true),
          ),
          trailing: day == null
              ? null
              : IconButton(
                  tooltip: l10n.wishlistNoTargetDay,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _targetDay = null),
                ),
          onTap: () => unawaited(_pickDay()),
        ),
      ],
    );
  }
}
