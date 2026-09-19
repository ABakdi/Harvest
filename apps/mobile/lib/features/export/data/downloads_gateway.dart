import 'dart:io';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'downloads_gateway.g.dart';

/// The file could not be written, with a reason worth showing.
class DownloadFailure implements Exception {
  const DownloadFailure(this.reason);

  /// One of `permission`, `unsupported`, or a platform message.
  final String reason;

  @override
  String toString() => 'DownloadFailure($reason)';
}

/// Puts a file in the device's Downloads folder.
///
/// Behind an interface so the export flow can be driven in a test
/// without a device, the same way the reminders and the lock are.
// ignore: one_member_abstracts — an interface for a fake, not a callback.
abstract interface class DownloadsGateway {
  /// Writes [bytes] as [fileName] and returns the path to show the
  /// user. Throws [DownloadFailure] when the platform refuses.
  Future<String> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });
}

/// Saves through `MainActivity`.
///
/// On Android 10+ that is MediaStore, which needs no permission at all;
/// 8.0–9.0 falls back to a plain file write under the legacy storage
/// permission, which the manifest caps at API 28 (rule X6).
class PlatformDownloadsGateway implements DownloadsGateway {
  const PlatformDownloadsGateway();

  static const _channel = MethodChannel('harvest/downloads');

  @override
  Future<String> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (!Platform.isAndroid) {
      throw const DownloadFailure('unsupported');
    }
    try {
      final path = await _channel.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'bytes': bytes,
        'mimeType': mimeType,
      });
      if (path == null) throw const DownloadFailure('unknown');
      return path;
    } on PlatformException catch (error) {
      throw DownloadFailure(error.code);
    } on MissingPluginException {
      throw const DownloadFailure('unsupported');
    }
  }
}

@Riverpod(keepAlive: true)
DownloadsGateway downloadsGateway(Ref ref) => const PlatformDownloadsGateway();
