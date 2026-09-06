import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/widgets/feature_switcher.dart';
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
          FeatureSwitcher<RecordsTab>(
            current: current,
            halves: [
              (
                value: RecordsTab.notes,
                icon: Icons.description_outlined,
                label: l10n.navNotes,
              ),
              (
                value: RecordsTab.gallery,
                icon: Icons.photo_library_outlined,
                label: l10n.navGallery,
              ),
            ],
            onChanged: (tab) => setState(() => _tab = tab),
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
