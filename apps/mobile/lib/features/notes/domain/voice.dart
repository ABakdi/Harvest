/// Recordings in notes, and notes read aloud ([[Notes]] N7, N10).
library;

/// The extensions an embed may name and still be a recording.
const audioExtensions = {'m4a', 'aac', 'mp3', 'wav', 'ogg', 'opus'};

final _embed = RegExp(r'!\[\[([^\[\]\n]+?)\]\]');

/// Every recording a body embeds, by file name, in order.
///
/// An embed is Obsidian's own syntax, `![[Voice 2026-09-19 14-32.m4a]]`,
/// so the pair of `.md` and `.m4a` opens in Obsidian as it is. Only
/// names with an audio extension count; `![[picture.png]]` is somebody
/// else's business.
List<String> audioEmbedsIn(String body) => [
  for (final match in _embed.allMatches(body))
    if (_isAudio(match.group(1)!.trim())) match.group(1)!.trim(),
];

bool _isAudio(String name) {
  final dot = name.lastIndexOf('.');
  return dot > 0 && audioExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// The embed line for [fileName].
String audioEmbed(String fileName) => '![[$fileName]]';

/// A recording's name: the moment it started, which is what I remember
/// it by, and unique enough — a second one in the same minute gets a
/// counter.
String voiceFileName(DateTime at, {Set<String> taken = const {}}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final stem =
      'Voice ${at.year}-${two(at.month)}-${two(at.day)} '
      '${two(at.hour)}-${two(at.minute)}';
  var name = '$stem.m4a';
  for (var i = 2; taken.contains(name); i++) {
    name = '$stem ($i).m4a';
  }
  return name;
}

/// A voice note's title, from the moment it was started.
String voiceNoteTitle(DateTime at) =>
    voiceFileName(at).replaceAll(RegExp(r'\.m4a$'), '');

/// A note as it should be heard: the words, without the markdown.
///
/// Headings, emphasis, list markers, quotes, link brackets and code
/// fences are dropped; an embed is dropped whole, because "exclamation
/// bracket bracket Voice two thousand twenty-six" is nobody's idea of
/// reading. What comes back is split into paragraphs, so the player can
/// skip one at a time.
List<String> speechParagraphs(String markdown) {
  final lines = <String>[];
  var inFence = false;
  for (final raw in markdown.split('\n')) {
    final line = raw.trimRight();
    if (line.trimLeft().startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    var text = line
        .replaceAll(_embed, '')
        .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+'), '')
        .replaceAll(RegExp(r'^\s*>\s?'), '')
        .replaceAll(RegExp(r'^\s*([-*+]|\d+[.)])\s+(\[[ xX]\]\s+)?'), '')
        .replaceAllMapped(RegExp(r'\[\[([^\]|]+)(\|([^\]]+))?\]\]'), (m) => m.group(3) ?? m.group(1)!)
        .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1)!)
        .replaceAll(RegExp(r'(\*\*|__|\*|_|~~|`|==)'), '')
        .replaceAll(RegExp(r'^\s*([-*_]\s*){3,}$'), '')
        .trim();
    // A table row reads as its cells.
    if (text.startsWith('|')) {
      text = text
          .split('|')
          .map((cell) => cell.trim())
          .where((cell) => cell.isNotEmpty && !RegExp(r'^:?-+:?$').hasMatch(cell))
          .join(', ');
    }
    lines.add(text);
  }
  final paragraphs = <String>[];
  final buffer = StringBuffer();
  for (final line in lines) {
    if (line.isEmpty) {
      if (buffer.isNotEmpty) {
        paragraphs.add(buffer.toString());
        buffer.clear();
      }
      continue;
    }
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(line);
  }
  if (buffer.isNotEmpty) paragraphs.add(buffer.toString());
  return paragraphs;
}

final _arabic = RegExp('[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]');

/// Which voice should read [text]: Arabic when most of its letters are
/// Arabic, otherwise [fallback] (the app's language).
String speechLanguageOf(String text, {required String fallback}) {
  final letters = RegExp(r'\p{L}', unicode: true).allMatches(text).length;
  if (letters == 0) return fallback;
  final arabic = _arabic.allMatches(text).length;
  return arabic * 2 >= letters ? 'ar' : fallback;
}
