import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/gallery/presentation/gallery_screen.dart';
import 'package:harvest/features/notes/presentation/editing_focus.dart';
import 'package:harvest/features/notes/presentation/notes_screen.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Which half of the record I am looking at.
enum RecordsTab { notes, gallery }

/// Notes and the Gallery, in one place.
///
/// They were two tabs and that was one too many: both are the same
/// instinct — keeping a record of a day that a number cannot hold —
/// and one keeps it in words while the other keeps it in pictures.
/// Sitting them side by side under one tab says that, and hands the
/// bottom bar back its breathing room.
///
/// When only one of the two is switched on there is nothing to switch
/// between, so the switch does not appear at all.
class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({this.initial, this.noteUuid, super.key});

  final RecordsTab? initial;

  /// Opens straight onto a note, for a link followed from elsewhere.
  final String? noteUuid;

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  RecordsTab? _tab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notes = ref.watch(notesEnabledProvider);
    final gallery = ref.watch(galleryEnabledProvider);

    // The switch follows what is on: turning notes off while looking at
    // them should land on the gallery, not on a blank screen.
    final current = switch ((notes, gallery)) {
      (true, false) => RecordsTab.notes,
      (false, true) => RecordsTab.gallery,
      _ => _tab ?? widget.initial ?? RecordsTab.notes,
    };

    final body = current == RecordsTab.notes
        ? NotesScreen(initialUuid: widget.noteUuid)
        : const GalleryScreen();

    // While a note is being written the switch goes, the way the
    // navigation bar does: the toolbar wants that strip, and the
    // keyboard is over it anyway.
    final writing = ref.watch(writingNoteProvider);
    final showSwitch = notes && gallery && !writing;

    // The Column is here whether or not the switch is, so the screen
    // above it keeps its place in the tree. Move it and every element
    // under it is rebuilt from scratch — which, in an editor, means the
    // text field loses focus and the keyboard shuts the moment it opens.
    return Column(
      children: [
        Expanded(child: body),
        if (showSwitch)
          _Switcher(
            current: current,
            notesLabel: l10n.navNotes,
            galleryLabel: l10n.navGallery,
            onChanged: (tab) {
              HarvestHaptics.tick().ignore();
              setState(() => _tab = tab);
            },
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}

/// A two-way switch under the screen, above the app's own bar.
///
/// It is the app's own segmented button rather than something new:
/// this is a choice between two things, the app already has a control
/// for that, and a bespoke one here would read as a different app.
class _Switcher extends StatelessWidget {
  const _Switcher({
    required this.current,
    required this.notesLabel,
    required this.galleryLabel,
    required this.onChanged,
  });

  final RecordsTab current;
  final String notesLabel;
  final String galleryLabel;
  final ValueChanged<RecordsTab> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        HarvestSpacing.md,
        HarvestSpacing.xs,
        HarvestSpacing.md,
        HarvestSpacing.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<RecordsTab>(
          segments: [
            ButtonSegment(
              value: RecordsTab.notes,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(notesLabel),
            ),
            ButtonSegment(
              value: RecordsTab.gallery,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(galleryLabel),
            ),
          ],
          selected: {current},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ),
    ),
  );
}
