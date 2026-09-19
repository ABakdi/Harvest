import 'dart:io';

import 'package:harvest/features/gallery/data/camera_gateway.dart';

/// A camera that hands back whatever file the test gives it, or backs
/// out entirely when given nothing.
class FakeCamera implements CameraGateway {
  const FakeCamera({this.photo, this.video});

  final File? photo;
  final File? video;

  @override
  Future<Capture?> takePhoto() async => _photo();

  @override
  Future<Capture?> pickPhoto() async => _photo();

  @override
  Future<Capture?> takeVideo() async => _video();

  @override
  Future<Capture?> pickVideo() async => _video();

  Capture? _photo() => photo == null ? null : (file: photo!, isVideo: false);

  Capture? _video() => video == null ? null : (file: video!, isVideo: true);
}
