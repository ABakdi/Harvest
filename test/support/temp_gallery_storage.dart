import 'dart:io';

import 'package:harvest/features/gallery/data/gallery_storage.dart';

/// Gallery storage rooted in a temp directory, so a test never needs a
/// documents directory and never leaves a picture behind.
class TempGalleryStorage extends GalleryStorage {
  TempGalleryStorage(this._root);

  final Directory _root;

  @override
  Future<Directory> root() async {
    if (!_root.existsSync()) await _root.create(recursive: true);
    return _root;
  }
}
