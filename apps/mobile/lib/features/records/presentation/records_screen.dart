import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/widgets/paired_screen.dart';
import 'package:harvest/features/gallery/presentation/gallery_screen.dart';
import 'package:harvest/features/lists/presentation/lists_screen.dart';
import 'package:harvest/features/notes/presentation/notes_screen.dart';
import 'package:harvest/features/places/presentation/places_screen.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Which half of the record I am looking at.
///
/// In the order the tabs are drawn: *Notes · Lists · Gallery · Places*
/// (M6.13). The one I was on last is remembered by name, so the order
/// can change under it.
enum RecordsTab { notes, lists, gallery, places }

/// Notes, Lists, the Gallery and Places, in one place.
///
/// They were two tabs and that was one too many: both are the same
/// instinct — keeping a record of a day that a number cannot hold —
/// and one keeps it in words while the other keeps it in pictures.
/// Sitting them side by side under one tab says that, and hands the
/// bottom bar back its breathing room. The switching is
/// [PairedScreen]'s ([[Checkpoint-6]]). Lists joined them, second
/// to Notes: what I have not got to yet is a record too ([[Lists]]).
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({
    this.initial,
    this.noteUuid,
    this.listUuid,
    super.key,
  });

  final RecordsTab? initial;

  /// Opens straight onto a note, for a link followed from elsewhere.
  final String? noteUuid;

  /// Opens Lists on one list — *To buy*, from the Granary.
  final String? listUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PairedScreen<RecordsTab>(
      title: l10n.navRecords,
      initial: initial,
      // Where I was last — a note or the albums — is the more useful
      // place to land than the notes list, always ([[Checkpoint-7]]).
      rememberKey: SettingKeys.recordsTab,
      // The map is only landed on once it has been seen to work here: a
      // map that took the app down must not do it again on every visit
      // to Records. Notes opens instead; Places is still a tap away.
      recallable: (tab) async =>
          tab != RecordsTab.places ||
          await ref
                  .read(settingsRepositoryProvider)
                  .getString(PlacesMapHealth.key) ==
              PlacesMapHealth.shown,
      halves: [
        (
          value: RecordsTab.notes,
          icon: Icons.description_outlined,
          label: l10n.navNotes,
          on: ref.watch(notesEnabledProvider),
        ),
        (
          value: RecordsTab.lists,
          icon: Icons.checklist,
          label: l10n.navLists,
          on: ref.watch(listsEnabledProvider),
        ),
        (
          value: RecordsTab.gallery,
          icon: Icons.photo_library_outlined,
          label: l10n.navGallery,
          on: ref.watch(galleryEnabledProvider),
        ),
        (
          value: RecordsTab.places,
          icon: Icons.map_outlined,
          label: l10n.navPlaces,
          on: ref.watch(placesEnabledProvider),
        ),
      ],
      builder: (current, title, tabs) => switch (current) {
        RecordsTab.notes => NotesScreen(
          initialUuid: noteUuid,
          title: title,
          tabs: tabs,
        ),
        RecordsTab.gallery => GalleryScreen(title: title, tabs: tabs),
        RecordsTab.places => PlacesScreen(title: title, tabs: tabs),
        RecordsTab.lists => ListsScreen(
          title: title,
          tabs: tabs,
          initialList: listUuid,
        ),
      },
    );
  }
}
