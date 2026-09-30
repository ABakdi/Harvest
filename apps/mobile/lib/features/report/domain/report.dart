import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/features/account/data/api_client.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/account/domain/heartbeat.dart';
import 'package:image/image.dart' as img;

/// *Report a problem* ([[Admin]], F12-5): what the phone may send, the
/// same limits the server holds (`packages/contracts/src/admin.ts`).
abstract final class ReportLimits {
  static const textMax = 5000;
  static const images = 4;
  static const int imageBytes = 5 * 1024 * 1024;
  static const int audioBytes = 10 * 1024 * 1024;
  static const int totalBytes = 21 * 1024 * 1024;

  /// Long enough for someone to say what went wrong, and no longer.
  static const recording = Duration(minutes: 5);

  /// A picture's long edge after re-encoding, and its JPEG quality.
  static const maxEdge = 2048;
  static const quality = 85;
}

/// What is wrong with a report before it goes, or null when nothing is.
enum ReportProblem {
  empty,
  tooLong,
  tooManyImages,
  imageTooLarge,
  audioTooLarge,
  tooLarge,
}

ReportProblem? reportProblem({
  required String text,
  required List<Uint8List> images,
  required int? audioBytes,
}) {
  final words = text.trim();
  if (words.isEmpty) return ReportProblem.empty;
  if (words.length > ReportLimits.textMax) return ReportProblem.tooLong;
  if (images.length > ReportLimits.images) return ReportProblem.tooManyImages;
  if (images.any((image) => image.length > ReportLimits.imageBytes)) {
    return ReportProblem.imageTooLarge;
  }
  if ((audioBytes ?? 0) > ReportLimits.audioBytes) {
    return ReportProblem.audioTooLarge;
  }
  final total =
      images.fold<int>(0, (sum, image) => sum + image.length) +
      (audioBytes ?? 0);
  if (total > ReportLimits.totalBytes) return ReportProblem.tooLarge;
  return null;
}

/// A picture made fit to leave the phone: decoded, turned the way its
/// camera meant, shrunk to [ReportLimits.maxEdge], and encoded again as
/// JPEG with **none** of its metadata — no GPS position, camera or time
/// goes with it (AD7). Null when the bytes are not a picture.
Uint8List? reencodeForReport(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object {
    // A decoder that trips over bytes that are not its format.
    return null;
  }
  if (decoded == null) return null;
  // The EXIF orientation is applied to the pixels, then every tag goes.
  var picture = img.bakeOrientation(decoded)..exif = img.ExifData();
  final longest = picture.width > picture.height
      ? picture.width
      : picture.height;
  if (longest > ReportLimits.maxEdge) {
    picture = picture.width >= picture.height
        ? img.copyResize(picture, width: ReportLimits.maxEdge)
        : img.copyResize(picture, height: ReportLimits.maxEdge);
    picture.exif = img.ExifData();
  }
  return img.encodeJpg(picture, quality: ReportLimits.quality);
}

/// Re-encodes [file] off the UI isolate ([reencodeForReport]).
Future<Uint8List?> reencodeFileForReport(File file) async {
  final bytes = await file.readAsBytes();
  return compute(reencodeForReport, bytes);
}

/// Sends a report to `POST /v1/reports`, **without** the session, even
/// when there is one: a report belongs to no account (AD7).
class ReportSender {
  ReportSender({required this.api, required this.version});

  final ApiClient api;
  final Future<String> Function() version;

  /// A report's body can be twenty megabytes on a slow line.
  static const timeout = Duration(minutes: 3);

  /// Answers the report's id.
  Future<String?> send({
    required String text,
    required List<Uint8List> images,
    File? recording,
  }) async {
    final audio = recording == null ? null : await recording.readAsBytes();
    final answer = await api.postAnonymous('/v1/reports', {
      'text': text.trim(),
      'platform': 'android',
      'appVersion': await version(),
      'attachments': [
        for (final image in images)
          {'kind': 'image', 'type': 'image/jpeg', 'data': base64Encode(image)},
        if (audio != null)
          // The recorder writes AAC in an MPEG-4 box (.m4a).
          {'kind': 'audio', 'type': 'audio/mp4', 'data': base64Encode(audio)},
      ],
    }, timeout: timeout);
    return answer['id'] as String?;
  }
}

final reportSenderProvider = Provider<ReportSender>(
  (ref) => ReportSender(
    api: ref.watch(apiClientProvider),
    version: () => ref.read(appVersionProvider.future),
  ),
);
