import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/widgets/paired_screen.dart';
import 'package:harvest/features/gallery/presentation/gallery_screen.dart';
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
/// bottom bar back its breathing room. The switching is
/// [PairedScreen]'s ([[Checkpoint-6]]).
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({this.initial, this.noteUuid, super.key});

  final RecordsTab? initial;

  /// Opens straight onto a note, for a link followed from elsewhere.
  final String? noteUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PairedScreen<RecordsTab>(
      title: l10n.navRecords,
      initial: initial,
      halves: [
        (
          value: RecordsTab.notes,
          icon: Icons.description_outlined,
          label: l10n.navNotes,
          on: ref.watch(notesEnabledProvider),
        ),
        (
          value: RecordsTab.gallery,
          icon: Icons.photo_library_outlined,
          label: l10n.navGallery,
          on: ref.watch(galleryEnabledProvider),
        ),
      ],
      builder: (current, title, tabs) => switch (current) {
        RecordsTab.notes => NotesScreen(
          initialUuid: noteUuid,
          title: title,
          tabs: tabs,
        ),
        RecordsTab.gallery => GalleryScreen(title: title, tabs: tabs),
      },
    );
  }
}
