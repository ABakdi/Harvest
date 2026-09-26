import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// What the place form asks for: a name, how far it reaches and,
/// optionally, a note.
typedef PlaceDraft = ({String name, String? notes, double radiusM});

/// Name, note and reach behind saving, and editing, a place on the map.
class PlaceFormDialog extends StatefulWidget {
  const PlaceFormDialog({
    required this.title,
    required this.nameHint,
    super.key,
    this.initialName = '',
    this.initialNotes = '',
    this.initialRadiusM = stayRadiusM,
  });

  final String title;
  final String nameHint;
  final String initialName;
  final String initialNotes;
  final double initialRadiusM;

  @override
  State<PlaceFormDialog> createState() => _PlaceFormDialogState();
}

class _PlaceFormDialogState extends State<PlaceFormDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _notes =
      TextEditingController(text: widget.initialNotes);
  late final TextEditingController _radius =
      TextEditingController(text: '${widget.initialRadiusM.round()}');
  var _nameError = false;
  var _radiusError = false;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _radius.dispose();
    super.dispose();
  }

  /// The reach typed, when it is a whole number of metres in range.
  double? get _radiusM {
    final value = int.tryParse(_radius.text.trim());
    if (value == null || value < minPlaceRadiusM || value > maxPlaceRadiusM) {
      return null;
    }
    return value.toDouble();
  }

  void _save() {
    final name = _name.text.trim();
    final radiusM = _radiusM;
    if (name.isEmpty || radiusM == null) {
      setState(() {
        _nameError = name.isEmpty;
        _radiusError = radiusM == null;
      });
      return;
    }
    final notes = _notes.text.trim();
    Navigator.pop(context, (
      name: name,
      notes: notes.isEmpty ? null : notes,
      radiusM: radiusM,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.placesPlaceName,
              hintText: widget.nameHint,
              errorText: _nameError ? l10n.placesPlaceName : null,
            ),
            onChanged: (_) {
              if (_nameError) setState(() => _nameError = false);
            },
          ),
          const SizedBox(height: HarvestSpacing.md),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: l10n.placesPlaceNotes,
              hintText: l10n.placesPlaceNotesHint,
            ),
          ),
          const SizedBox(height: HarvestSpacing.md),
          TextField(
            controller: _radius,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.placesRadius,
              helperText: _radiusError
                  ? null
                  : l10n.placesRadiusRange(minPlaceRadiusM, maxPlaceRadiusM),
              errorText: _radiusError
                  ? l10n.placesRadiusRange(minPlaceRadiusM, maxPlaceRadiusM)
                  : null,
            ),
            onChanged: (_) {
              if (_radiusError) setState(() => _radiusError = false);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(switch (widget.initialName.isEmpty) {
            true => l10n.placesSavePlace,
            false => l10n.save,
          }),
        ),
      ],
    );
  }
}
