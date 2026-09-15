// Trims the upstream exercise catalogue down to what Harvest ships.
//
// Run: dart run tool/trim_exercises.dart
//
// The upstream file is 17.4 MB because it carries ten languages, and
// Arabic — the one Harvest actually needs besides English — is not one
// of them ([[ADR-008-Exercise-Catalogue]]). Carrying nine languages we
// never show, to miss the one we do, would be fifteen megabytes of
// nothing. So English only, and only the fields the app reads.
//
// The media is deliberately **not** downloaded: the images and GIFs are
// © Gym Visual, redistributed to that repository rather than to us, so
// Harvest fetches them at runtime and never re-hosts them.
import 'dart:convert';
import 'dart:io';

/// The commit the catalogue is pinned to.
///
/// Updating this is a deliberate act with a release note, not a moving
/// target: the app's exercise ids are stable references into it.
const datasetCommit = '7455efae41b330c265e7cd4b78dfa848e7ce5ebd';

const datasetRepo = 'hasaneyldrm/exercises-dataset';

const _source =
    'https://raw.githubusercontent.com/$datasetRepo/$datasetCommit'
    '/data/exercises.json';

const _output = 'assets/exercises/exercises.json';

Future<void> main() async {
  stdout.writeln('Fetching $_source');
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(_source));
  final response = await request.close();
  if (response.statusCode != 200) {
    stderr.writeln('HTTP ${response.statusCode}');
    exit(1);
  }
  final body = await response.transform(utf8.decoder).join();
  client.close();

  final raw = jsonDecode(body) as List<dynamic>;
  stdout.writeln('${raw.length} exercises, ${_mb(body.length)} MB raw');

  final trimmed = <Map<String, dynamic>>[];
  for (final entry in raw) {
    final exercise = entry as Map<String, dynamic>;
    final steps = (exercise['instruction_steps'] as Map<String, dynamic>?)?['en'];

    trimmed.add({
      'id': exercise['id'],
      'name': exercise['name'],
      'bodyPart': exercise['body_part'] ?? exercise['category'],
      'equipment': exercise['equipment'],
      'target': exercise['target'],
      if (exercise['secondary_muscles'] case final List<dynamic> muscles
          when muscles.isNotEmpty)
        'secondary': muscles,
      if (steps case final List<dynamic> lines when lines.isNotEmpty)
        'steps': lines,
      // The media lives upstream; this is the half of the filename that
      // is not the id.
      'media': exercise['media_id'],
    });
  }

  // Sorted by id so the asset is byte-stable between runs and a diff
  // of it is readable.
  trimmed.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

  final file = File(_output);
  await file.parent.create(recursive: true);
  final json = jsonEncode(trimmed);
  await file.writeAsString(json);

  stdout
    ..writeln('Wrote $_output')
    ..writeln('${trimmed.length} exercises, ${_mb(json.length)} MB')
    ..writeln('Pinned to $datasetCommit');
}

String _mb(int bytes) => (bytes / 1048576).toStringAsFixed(1);
