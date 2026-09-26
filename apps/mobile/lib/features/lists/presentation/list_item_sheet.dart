import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/lists/data/lists_repository.dart';
import 'package:harvest/features/lists/domain/lists.dart';
import 'package:harvest/features/lists/domain/share_links.dart';
import 'package:harvest/features/lists/presentation/list_labels.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Writes an item down in [list], or edits [existing] where it is. The
/// fields are the list's kind's ([[Lists]] L2): a note on a plain list,
/// an estimate and a planned day on a shopping list, a type, a link and
/// a creator on a media list.
Future<ListItem?> showListItemSheet(
  BuildContext context, {
  required ItemList list,
  ListItem? existing,
}) => showHarvestSheet<ListItem>(
  context,
  builder: (_) => _ItemSheet(lists: [list], list: list, existing: existing),
);

/// *Save to a list*: what another app shared, before it is saved
/// ([[Lists]]: Saving from anywhere). The title, the link and the list
/// are all mine to change; [initial] is where the link would land, or
/// null to make me choose. Nothing is fetched (L9).
Future<ListItem?> showShareSheet(
  BuildContext context, {
  required SharedDraft draft,
  required List<ItemList> lists,
  ItemList? initial,
}) => showHarvestSheet<ListItem>(
  context,
  builder: (_) =>
      _ItemSheet(lists: lists, list: initial, shared: draft, chooseList: true),
);

class _ItemSheet extends ConsumerStatefulWidget {
  const _ItemSheet({
    required this.lists,
    required this.list,
    this.existing,
    this.shared,
    this.chooseList = false,
  });

  /// The lists that can be chosen; just the one unless [chooseList].
  final List<ItemList> lists;
  final ItemList? list;
  final ListItem? existing;
  final SharedDraft? shared;
  final bool chooseList;

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  late final ListItem? _existing = widget.existing;
  late final SharedDraft? _shared = widget.shared;

  /// A bare shared link stands in as the title only until I type one:
  /// the field starts empty and shows the link as its hint.
  late final _title = TextEditingController(
    text:
        _existing?.title ??
        (_shared == null || _shared.title == _shared.link
            ? ''
            : _shared.title),
  );
  late final _note = TextEditingController(text: _existing?.note);
  late final _link = TextEditingController(
    text: _existing?.link ?? _shared?.link,
  );
  late final _creator = TextEditingController(text: _existing?.creator);
  late final _amount = TextEditingController(
    text: _existing?.priceMinor == null
        ? ''
        : formatMinor(_existing!.priceMinor!),
  );
  late ItemList? _list = widget.list;
  late Currency _currency = _existing?.currency ?? Currency.dzd;
  late HarvestDay? _targetDay = _existing?.targetDay;
  late MediaType? _mediaType =
      _existing?.mediaType ?? _shared?.target?.mediaType;
  var _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _link.dispose();
    _creator.dispose();
    _amount.dispose();
    super.dispose();
  }

  ListKind? get _kind => _list?.kind;

  /// Empty means "no estimate yet"; a filled field must be a number.
  int? get _minor {
    final text = _amount.text.trim();
    return text.isEmpty ? null : parseToMinor(text);
  }

  bool get _amountInvalid =>
      _kind == ListKind.shopping &&
      _amount.text.trim().isNotEmpty &&
      _minor == null;

  /// What is saved as the title: what I typed, or the shared link.
  String get _titleText {
    final typed = _title.text.trim();
    if (typed.isNotEmpty) return typed;
    return _shared?.link ?? '';
  }

  String? _blankToNull(String text) =>
      text.trim().isEmpty ? null : text.trim();

  Future<void> _pickDay() async {
    final today = HarvestDay.today();
    final last = today.addDays(365 * 10);
    // The picker only offers today onward, so a plan whose day has
    // already passed opens on the nearest day it can show.
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
    final list = _list;
    if (list == null) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final repository = ref.read(listsRepositoryProvider);
    var note = _blankToNull(_note.text);
    final link = _blankToNull(_link.text);
    // A shared link saved to a list that keeps no link is kept in the
    // note rather than dropped.
    if (_shared != null && link != null && list.kind != ListKind.media) {
      note = note == null ? link : '$note\n$link';
    }
    final existing = _existing;
    if (existing == null) {
      final item = await repository.addItem(
        list.uuid,
        title: _titleText,
        note: note,
        priceMinor: _minor,
        currency: _currency,
        targetDay: _targetDay,
        mediaType: _mediaType,
        link: link,
        creator: _blankToNull(_creator.text),
      );
      navigator.pop(item);
      return;
    }
    await repository.editItem(
      existing.uuid,
      title: _titleText,
      note: note,
      priceMinor: _minor,
      currency: _currency,
      targetDay: _targetDay,
      mediaType: _mediaType,
      link: link,
      creator: _blankToNull(_creator.text),
    );
    navigator.pop(await repository.item(existing.uuid));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final existing = _existing;
    final kind = _kind;
    final canSave =
        _titleText.isNotEmpty && !_saving && !_amountInvalid && _list != null;

    return HarvestSheet(
      title: widget.chooseList
          ? l10n.listsShareTitle
          : existing == null
          ? l10n.listsNewItem
          : l10n.wishlistEditItem,
      subtitle: widget.chooseList || _list == null
          ? null
          : listName(l10n, _list!),
      actionLabel: l10n.save,
      onAction: canSave ? () => unawaited(_save()) : null,
      children: [
        TextField(
          controller: _title,
          autofocus: existing == null && _shared == null,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.titleLabel,
            hintText: _shared?.link ?? _titleHint(l10n, kind),
            counterText: '',
          ),
        ),
        if (widget.chooseList) ...[
          const SizedBox(height: HarvestSpacing.md),
          Text(
            l10n.listsListLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: HarvestSpacing.xs),
          Wrap(
            spacing: HarvestSpacing.xs,
            runSpacing: HarvestSpacing.xs,
            children: [
              for (final list in widget.lists)
                ChoiceChip(
                  avatar: Icon(listIcon(list), size: 18),
                  label: Text(listName(l10n, list)),
                  selected: list.uuid == _list?.uuid,
                  onSelected: (_) => setState(() {
                    _list = list;
                    if (list.kind == ListKind.media) {
                      _mediaType ??= MediaType.article;
                    }
                  }),
                ),
            ],
          ),
          if (_list == null)
            Padding(
              padding: const EdgeInsets.only(top: HarvestSpacing.xs),
              child: Text(
                l10n.listsSharePickList,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
        if (kind == ListKind.shopping) ..._shoppingFields(context, l10n),
        if (kind == ListKind.media) ..._mediaFields(context, l10n),
        if (kind != ListKind.media &&
            widget.chooseList &&
            (_shared?.link != null)) ...[
          const SizedBox(height: HarvestSpacing.sm),
          TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l10n.listsLinkLabel,
              helperText: l10n.listsLinkInNote,
            ),
          ),
        ],
        const SizedBox(height: HarvestSpacing.sm),
        TextField(
          controller: _note,
          maxLength: 500,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.wishlistNoteLabel,
            hintText: kind == ListKind.shopping
                ? l10n.wishlistNoteHint
                : l10n.listsNoteHint,
            counterText: '',
          ),
        ),
      ],
    );
  }

  String _titleHint(AppLocalizations l10n, ListKind? kind) => switch (kind) {
    ListKind.shopping => l10n.wishlistTitleHint,
    ListKind.media => l10n.listsTitleHintMedia,
    ListKind.plain || null => l10n.listsTitleHintPlain,
  };

  List<Widget> _shoppingFields(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final day = _targetDay;
    return [
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
          prefixText: _currency.symbol,
          errorText: _amountInvalid ? l10n.wishlistEstimateInvalid : null,
        ),
      ),
      const SizedBox(height: HarvestSpacing.sm),
      SegmentedButton<Currency>(
        segments: [
          for (final currency in Currency.values)
            // The same pills as the expense sheet: DA, $, €.
            ButtonSegment(value: currency, label: Text(currency.symbol)),
        ],
        selected: {_currency},
        onSelectionChanged: (selection) =>
            setState(() => _currency = selection.first),
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
    ];
  }

  List<Widget> _mediaFields(BuildContext context, AppLocalizations l10n) => [
    const SizedBox(height: HarvestSpacing.md),
    Text(l10n.listsTypeLabel, style: Theme.of(context).textTheme.labelLarge),
    const SizedBox(height: HarvestSpacing.xs),
    Wrap(
      spacing: HarvestSpacing.xs,
      runSpacing: HarvestSpacing.xs,
      children: [
        for (final type in MediaType.values)
          ChoiceChip(
            avatar: Icon(mediaTypeIcon(type), size: 18),
            label: Text(mediaTypeLabel(l10n, type)),
            selected: _mediaType == type,
            onSelected: (on) => setState(() => _mediaType = on ? type : null),
          ),
      ],
    ),
    const SizedBox(height: HarvestSpacing.sm),
    TextField(
      controller: _creator,
      maxLength: 120,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: l10n.listsCreatorLabel,
        counterText: '',
      ),
    ),
    const SizedBox(height: HarvestSpacing.sm),
    TextField(
      controller: _link,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(
        labelText: l10n.listsLinkLabel,
        hintText: 'https://',
      ),
    ),
  ];
}

/// A new list: a name and a kind, which decides its items' fields
/// ([[Lists]] L1, L2). Hands back the list made.
Future<ItemList?> showNewListSheet(BuildContext context) =>
    showHarvestSheet<ItemList>(context, builder: (_) => const _NewListSheet());

class _NewListSheet extends ConsumerStatefulWidget {
  const _NewListSheet();

  @override
  ConsumerState<_NewListSheet> createState() => _NewListSheetState();
}

class _NewListSheetState extends ConsumerState<_NewListSheet> {
  final _name = TextEditingController();
  ListKind _kind = ListKind.plain;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final list = await ref
        .read(listsRepositoryProvider)
        .createList(name: _name.text, kind: _kind);
    navigator.pop(list);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return HarvestSheet(
      title: l10n.listsNew,
      actionLabel: l10n.save,
      onAction: _name.text.trim().isEmpty || _saving
          ? null
          : () => unawaited(_save()),
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.listsNameLabel,
            hintText: l10n.listsNameHint,
            counterText: '',
          ),
        ),
        const SizedBox(height: HarvestSpacing.md),
        SegmentedButton<ListKind>(
          segments: [
            for (final kind in ListKind.values)
              ButtonSegment(
                value: kind,
                icon: Icon(kindIcon(kind), size: 18),
                label: Text(kindLabel(l10n, kind)),
              ),
          ],
          selected: {_kind},
          onSelectionChanged: (selection) =>
              setState(() => _kind = selection.first),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        Text(
          switch (_kind) {
            ListKind.plain => l10n.listsKindPlainHint,
            ListKind.shopping => l10n.listsKindShoppingHint,
            ListKind.media => l10n.listsKindMediaHint,
          },
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
