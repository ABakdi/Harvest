import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'exercise_media.g.dart';

/// The commit the media is fetched from — the same one the bundled
/// catalogue was trimmed at, so a filename always resolves.
const datasetCommit = '7455efae41b330c265e7cd4b78dfa848e7ce5ebd';
const datasetRepo = 'hasaneyldrm/exercises-dataset';

/// What the licence requires wherever the media appears.
const mediaAttribution = '© Gym Visual';
const mediaAttributionUrl = 'https://gymvisual.com/';

/// Settings keys the gym's media uses.
abstract final class MediaKeys {
  /// When on, nothing is ever fetched and the gym works on words alone.
  static const neverFetch = 'gym.neverFetchMedia';
}

/// Which picture of an exercise.
enum MediaKind {
  thumbnail,
  animation;

  String get folder => this == MediaKind.thumbnail ? 'images' : 'videos';
  String get extension => this == MediaKind.thumbnail ? '.jpg' : '.gif';
}

/// The thumbnails and animations, fetched when asked for and kept.
///
/// Harvest does not re-host this media. The images are © Gym Visual,
/// redistributed to *that repository* rather than to us, so the app is
/// a client of their hosting and never a fourth-hand distributor
/// ([[ADR-008-Exercise-Catalogue]]).
///
/// It is also the only outbound request the app makes that is not an
/// export I tapped ([[Business-Rules]] #13): a GET for a static file,
/// carrying no account, no device id and no history. It reveals which
/// file, and that is all it can reveal.
class ExerciseMedia {
  ExerciseMedia(this._settings, {http.Client? client})
    : _client = client ?? http.Client();

  final SettingsRepository _settings;
  final http.Client _client;
  Directory? _root;

  static const folder = 'exercise-media';

  Future<Directory> root() async {
    if (_root != null) return _root!;
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, folder));
    if (!directory.existsSync()) await directory.create(recursive: true);
    return _root = directory;
  }

  Uri urlFor(String stem, MediaKind kind) => Uri.https(
    'raw.githubusercontent.com',
    '/$datasetRepo/$datasetCommit/${kind.folder}/$stem${kind.extension}',
  );

  Future<File> fileFor(String stem, MediaKind kind) async =>
      File(p.join((await root()).path, '${kind.folder}-$stem${kind.extension}'));

  Future<bool> get neverFetch async =>
      await _settings.getBool(MediaKeys.neverFetch) ?? false;

  Future<void> setNeverFetch({required bool value}) =>
      _settings.setBool(MediaKeys.neverFetch, value: value);

  /// The file if it is cached, fetched if it is not, and null when it
  /// cannot be had — no network, or fetching is switched off.
  ///
  /// Null is an ordinary answer, not an error: the gym shows names and
  /// instructions and works completely without a single picture.
  Future<File?> get(String stem, MediaKind kind) async {
    final file = await fileFor(stem, kind);
    if (file.existsSync() && await file.length() > 0) return file;
    if (await neverFetch) return null;

    try {
      final response = await _client
          .get(urlFor(stem, kind))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } on Object catch (error) {
      // A picture that did not arrive is a picture, not a crash.
      debugPrint('[gym] media unavailable: ${error.runtimeType}');
      return null;
    }
  }

  /// Already on disk? Answers without touching the network, so a list
  /// can show what it has without fetching a screenful.
  Future<File?> cached(String stem, MediaKind kind) async {
    final file = await fileFor(stem, kind);
    return file.existsSync() && await file.length() > 0 ? file : null;
  }

  /// Everything at once, for someone who knows they are getting on a
  /// train. Reports progress and stops when asked.
  Future<int> fetchAll(
    List<String> stems, {
    MediaKind kind = MediaKind.animation,
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    var done = 0;
    for (final stem in stems) {
      if (cancelled?.call() ?? false) break;
      await get(stem, kind);
      onProgress?.call(++done, stems.length);
    }
    return done;
  }

  Future<int> cacheBytes() async {
    final directory = await root();
    if (!directory.existsSync()) return 0;
    var total = 0;
    await for (final entity in directory.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> clearCache() async {
    final directory = await root();
    if (!directory.existsSync()) return;
    await for (final entity in directory.list()) {
      if (entity is File) await entity.delete();
    }
  }
}

@Riverpod(keepAlive: true)
ExerciseMedia exerciseMedia(Ref ref) =>
    ExerciseMedia(ref.watch(settingsRepositoryProvider));
