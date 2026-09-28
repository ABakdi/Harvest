import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:harvest/core/security/file_vault.dart';

/// A picture sealed on disk ([FileVault]), drawn from its bytes opened in
/// memory: [FileImage] for a file the vault keeps. Two are the same
/// picture when they name the same file, so evicting one lets a picture
/// replaced on disk be drawn again.
@immutable
class VaultFileImage extends ImageProvider<VaultFileImage> {
  const VaultFileImage(this.file, this.vault, {this.scale = 1});

  final File file;

  /// Null only where there is no Keystore (a test): the file is read as
  /// it is.
  final FileVault? vault;
  final double scale;

  @override
  Future<VaultFileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<VaultFileImage>(this);

  @override
  ImageStreamCompleter loadImage(
    VaultFileImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(key, decode),
    scale: key.scale,
    debugLabel: key.file.path,
  );

  static Future<ui.Codec> _load(
    VaultFileImage key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await (key.vault?.read(key.file) ?? key.file.readAsBytes());
    if (bytes.isEmpty) {
      // Not cached: the file may be there next time.
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError('${key.file.path} is empty and cannot be drawn');
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is VaultFileImage &&
      other.file.path == file.path &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(file.path, scale);

  @override
  String toString() => 'VaultFileImage("${file.path}", scale: $scale)';
}
