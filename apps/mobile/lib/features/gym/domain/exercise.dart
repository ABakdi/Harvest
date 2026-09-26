import 'package:meta/meta.dart';

/// One exercise, from the bundled catalogue or added by me.
///
/// The catalogue's 1,324 are reference data — read-only, never synced,
/// never exported, referred to by id and nothing else
/// ([[ADR-008-Exercise-Catalogue]]). Mine live in the database and
/// travel with my data. Everything downstream treats them identically,
/// which is the point of them being one type.
@immutable
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.bodyPart,
    this.equipment,
    this.target,
    this.secondary = const [],
    this.steps = const [],
    this.mediaId,
    this.mine = false,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    name: json['name'] as String,
    bodyPart: json['bodyPart'] as String?,
    equipment: json['equipment'] as String?,
    target: json['target'] as String?,
    secondary: [
      for (final muscle in (json['secondary'] as List<dynamic>?) ?? const [])
        muscle as String,
    ],
    steps: [
      for (final step in (json['steps'] as List<dynamic>?) ?? const [])
        step as String,
    ],
    mediaId: json['media'] as String?,
  );

  /// A catalogue id is four digits ("0001"); mine is a uuid. Which it
  /// is decides where the row lives and nothing else.
  final String id;
  final String name;
  final String? bodyPart;
  final String? equipment;

  /// The muscle it is for.
  final String? target;
  final List<String> secondary;
  final List<String> steps;

  /// The other half of the upstream filename. Null for mine, which
  /// have no picture.
  final String? mediaId;
  final bool mine;

  /// The name as it is read: the catalogue writes every name in lower
  /// case (`barbell full squat`), which is a database's idea of a title.
  /// Only the display changes — the stored name, the id and the search
  /// all keep what is there. Mine are shown as I typed them.
  String get displayName => mine ? name : titleCase(name);

  /// `0001-2gPfomN` — the stem the thumbnail and the animation share.
  String? get mediaStem => mediaId == null ? null : '$id-$mediaId';

  /// Whether there is a bar to load — and therefore a bar weight to
  /// know and plates to work out. A dumbbell row has neither, and a
  /// bar weight beside it was a question with no answer
  /// ([[Checkpoint-6]]).
  ///
  /// Five of the catalogue's equipment names are bars; my own
  /// exercises say so in their equipment or their name.
  bool get usesBar {
    final gear = (equipment ?? '').toLowerCase();
    if (barEquipment.contains(gear)) return true;
    final words = '$gear ${name.toLowerCase()}';
    return words.contains('barbell') || words.contains('smith machine');
  }

  /// Everything a search should look at, lowercased once.
  String get haystack => [
    name,
    bodyPart,
    equipment,
    target,
    ...secondary,
  ].whereType<String>().join(' ').toLowerCase();
}

/// The catalogue's equipment names that mean "a bar with plates".
const barEquipment = {
  'barbell',
  'ez barbell',
  'olympic barbell',
  'smith machine',
  'trap bar',
};

/// What a catalogue search is narrowed by.
typedef ExerciseFilter = ({String search, String? bodyPart, String? equipment});

const ExerciseFilter emptyExerciseFilter = (
  search: '',
  bodyPart: null,
  equipment: null,
);

/// The exercises matching a filter.
///
/// Search reads the name, the body part, the equipment and every
/// muscle, because mid-session the question is rarely "what is it
/// called" — it is "what else hits triceps that is not this bench".
///
/// Every word has to match somewhere, so "cable row" finds the cable
/// rows rather than everything with a cable and everything with a row.
List<Exercise> filterExercises(List<Exercise> all, ExerciseFilter filter) {
  final words = filter.search
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  final matched = all.where((exercise) {
    if (filter.bodyPart != null && exercise.bodyPart != filter.bodyPart) {
      return false;
    }
    if (filter.equipment != null && exercise.equipment != filter.equipment) {
      return false;
    }
    if (words.isEmpty) return true;
    final haystack = exercise.haystack;
    return words.every(haystack.contains);
  }).toList();

  // Mine first — I added them because the catalogue was missing
  // something, so burying them under 1,324 borrowed rows would defeat
  // the point. Then a name that starts with the search, then the rest.
  final needle = filter.search.trim().toLowerCase();
  matched.sort((a, b) {
    if (a.mine != b.mine) return a.mine ? -1 : 1;
    if (needle.isNotEmpty) {
      final aStarts = a.name.toLowerCase().startsWith(needle);
      final bStarts = b.name.toLowerCase().startsWith(needle);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return matched;
}

/// Small words that stay small inside a title.
const _smallWords = {
  'a',
  'an',
  'and',
  'at',
  'by',
  'for',
  'in',
  'of',
  'on',
  'or',
  'the',
  'to',
  'with',
  'vs',
  'v.',
};

/// Initialisms in the catalogue's names, written in capitals whole:
/// `jm` (the JM press), `ez` and `sz` (the curl bars), `pov` (the
/// camera's point of view). Words as short as these (`up`, `on`, `ab`)
/// are words, and stay out. One list with the web's `titleCase`.
const titleInitialisms = {'ez', 'jm', 'pov', 'sz'};

/// `barbell full squat (side pov)` → `Barbell Full Squat (Side POV)`:
/// each word's first letter raised — after a space, a hyphen, a slash
/// or a bracket — the small words left small unless they lead, and the
/// [titleInitialisms] in capitals.
String titleCase(String text) {
  final words = text.split(' ');
  return [
    for (final (index, word) in words.indexed)
      if (index > 0 && _smallWords.contains(word)) word else _raise(word),
  ].join(' ');
}

String _raise(String word) {
  final out = StringBuffer();
  // Each piece between a hyphen, a slash or a bracket, with its
  // separator: `(sz-bar)` is `(`, `sz-`, `bar)`.
  for (final piece in RegExp('[^-/(]*[-/(]?').allMatches(word)) {
    final text = piece.group(0)!;
    if (text.isEmpty) continue;
    final core = text.replaceAll(RegExp('[^a-z]'), '');
    if (titleInitialisms.contains(core)) {
      out.write(text.toUpperCase());
    } else {
      out
        ..write(text[0].toUpperCase())
        ..write(text.substring(1));
    }
  }
  return out.toString();
}
