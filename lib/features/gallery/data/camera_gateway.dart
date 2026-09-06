import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'camera_gateway.g.dart';

/// What was captured, before it is filed.
typedef Capture = ({File file, bool isVideo});

/// The camera and the photo picker, behind an interface like every
/// other platform edge in this app — so the gallery's rules can be
/// tested without a lens.
abstract interface class CameraGateway {
  /// Takes a photo. Null when the user backed out.
  Future<Capture?> takePhoto();

  /// Picks a photo from the phone's own gallery.
  Future<Capture?> pickPhoto();

  Future<Capture?> takeVideo();

  Future<Capture?> pickVideo();
}

/// `image_picker`, with the downscale applied on the way in.
///
/// The plugin resizes and re-encodes before it hands the file over,
/// which is exactly rule G4: a daily selfie for five years should cost
/// megabytes, not gigabytes, and the original is not kept because it
/// never reaches us.
class ImagePickerCamera implements CameraGateway {
  ImagePickerCamera([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Long edge after downscaling, and the JPEG quality it lands at.
  static const maxEdge = 1600.0;
  static const quality = 82;

  /// Long enough for a progress clip, short enough not to fill a phone.
  static const maxVideo = Duration(minutes: 2);

  @override
  Future<Capture?> takePhoto() => _photo(ImageSource.camera);

  @override
  Future<Capture?> pickPhoto() => _photo(ImageSource.gallery);

  @override
  Future<Capture?> takeVideo() => _video(ImageSource.camera);

  @override
  Future<Capture?> pickVideo() => _video(ImageSource.gallery);

  Future<Capture?> _photo(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: maxEdge,
        maxHeight: maxEdge,
        imageQuality: quality,
      );
      if (picked == null) return null;
      return (file: File(picked.path), isVideo: false);
    } on PlatformException catch (error) {
      _log(error);
      return null;
    } on MissingPluginException catch (error) {
      _log(error);
      return null;
    }
  }

  Future<Capture?> _video(ImageSource source) async {
    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: maxVideo,
      );
      if (picked == null) return null;
      return (file: File(picked.path), isVideo: true);
    } on PlatformException catch (error) {
      _log(error);
      return null;
    } on MissingPluginException catch (error) {
      _log(error);
      return null;
    }
  }

  /// A refused permission or a missing plugin is a capture that did not
  /// happen, not a crash.
  void _log(Object error) =>
      debugPrint('[gallery] capture unavailable: ${error.runtimeType}');
}

@Riverpod(keepAlive: true)
CameraGateway cameraGateway(Ref ref) => ImagePickerCamera();
