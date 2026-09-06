import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'archive_picker.g.dart';

/// A zip the user chose, with the name they will recognise it by.
typedef PickedArchive = ({String name, Uint8List bytes});

/// Choosing a file, behind an interface like every other platform edge
/// — so the merge can be tested without a file browser.
// ignore: one_member_abstracts — an interface for a fake, not a callback.
abstract interface class ArchivePicker {
  /// Null when the user backed out or the platform refused.
  Future<PickedArchive?> pickZip();
}

class FilePickerArchive implements ArchivePicker {
  const FilePickerArchive();

  @override
  Future<PickedArchive?> pickZip() async {
    try {
      // Any file rather than a zip filter: Android's document picker
      // greys out perfectly good archives when the provider reports a
      // vague MIME type, and a file that is not ours is caught by the
      // reader a moment later anyway.
      final picked = await FilePicker.pickFile();
      if (picked == null) return null;
      return (name: picked.name, bytes: await picked.readAsBytes());
    } on PlatformException catch (error) {
      debugPrint('[import] picker unavailable: ${error.code}');
      return null;
    } on MissingPluginException catch (error) {
      debugPrint('[import] picker unavailable: ${error.runtimeType}');
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
ArchivePicker archivePicker(Ref ref) => const FilePickerArchive();
