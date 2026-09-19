import 'dart:typed_data';

import 'package:harvest/features/export/data/downloads_gateway.dart';

/// Downloads, faked: it keeps the bytes instead of writing them, so the
/// export flow can be run end to end without a device.
class FakeDownloadsGateway implements DownloadsGateway {
  String? fileName;
  String? mimeType;
  Uint8List? bytes;

  /// When set, the save fails with this reason instead of succeeding.
  String? failWith;

  @override
  Future<String> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (failWith case final reason?) throw DownloadFailure(reason);
    this.fileName = fileName;
    this.bytes = bytes;
    this.mimeType = mimeType;
    return 'Download/$fileName';
  }
}
