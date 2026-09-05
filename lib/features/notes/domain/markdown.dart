import 'package:meta/meta.dart';

/// What a line of markdown turned out to be.
enum BlockKind { paragraph, heading, bullet, numbered, task, quote, code, rule }

/// One rendered block. A line-based parse, deliberately: the spec asks
/// for headings, emphasis, lists, task lists, quotes, code, links and
/// wiki links, and nothing that needs a real parser is on that list.
@immutable
class MarkdownBlock {
  const MarkdownBlock({
    required this.kind,
    required this.spans,
    this.level = 0,
    this.checked = false,
    this.text = '',
  });

  final BlockKind kind;
  final List<InlineSpanPart> spans;

  /// Heading depth (1..6), or the list's indent level.
  final int level;

  /// Task lists only.
  final bool checked;

  /// Code blocks keep their text verbatim rather than as spans.
  final String text;
}

/// What a run of inline text is.
enum InlineKind { text, bold, italic, code, link, wikiLink }

@immutable
class InlineSpanPart {
  const InlineSpanPart(this.kind, this.text, {this.target});

  final InlineKind kind;
  final String text;

  /// Link destination, or the wiki link's note title.
  final String? target;

  @override
  bool operator ==(Object other) =>
      other is InlineSpanPart &&
      other.kind == kind &&
      other.text == text &&
      other.target == target;

  @override
  int get hashCode => Object.hash(kind, text, target);

  @override
  String toString() => '${kind.name}("$text"${target == null ? '' : ' → $target'})';
}

/// Splits markdown into blocks. Anything unrecognised stays a paragraph
/// rather than being eaten (rule: unknown syntax passes through).
List<MarkdownBlock> parseMarkdown(String source) {
  final blocks = <MarkdownBlock>[];
  final lines = source.split('\n');
  var i = 0;

  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trimLeft();

    if (trimmed.startsWith('```')) {
      final buffer = <String>[];
      i++;
      while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
        buffer.add(lines[i]);
        i++;
      }
      if (i < lines.length) i++;
      blocks.add(
        MarkdownBlock(
          kind: BlockKind.code,
          spans: const [],
          text: buffer.join('\n'),
        ),
      );
      continue;
    }

    if (trimmed.trim().isEmpty) {
      i++;
      continue;
    }

    if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed.trim())) {
      blocks.add(const MarkdownBlock(kind: BlockKind.rule, spans: []));
      i++;
      continue;
    }

    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      blocks.add(
        MarkdownBlock(
          kind: BlockKind.heading,
          level: heading.group(1)!.length,
          spans: parseInline(heading.group(2)!),
        ),
      );
      i++;
      continue;
    }

    final indent = line.length - trimmed.length;
    final task = RegExp(r'^[-*+]\s+\[([ xX])\]\s+(.*)$').firstMatch(trimmed);
    if (task != null) {
      blocks.add(
        MarkdownBlock(
          kind: BlockKind.task,
          level: indent ~/ 2,
          checked: task.group(1)!.toLowerCase() == 'x',
          spans: parseInline(task.group(2)!),
        ),
      );
      i++;
      continue;
    }

    final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
    if (bullet != null) {
      blocks.add(
        MarkdownBlock(
          kind: BlockKind.bullet,
          level: indent ~/ 2,
          spans: parseInline(bullet.group(1)!),
        ),
      );
      i++;
      continue;
    }

    final numbered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
    if (numbered != null) {
      blocks.add(
        MarkdownBlock(
          kind: BlockKind.numbered,
          level: int.parse(numbered.group(1)!),
          spans: parseInline(numbered.group(2)!),
        ),
      );
      i++;
      continue;
    }

    if (trimmed.startsWith('>')) {
      blocks.add(
        MarkdownBlock(
          kind: BlockKind.quote,
          spans: parseInline(trimmed.replaceFirst(RegExp(r'^>\s?'), '')),
        ),
      );
      i++;
      continue;
    }

    // A paragraph runs until a blank line or a line that starts a block.
    final buffer = <String>[line.trim()];
    i++;
    while (i < lines.length) {
      final next = lines[i];
      final nextTrimmed = next.trimLeft();
      if (nextTrimmed.trim().isEmpty || _startsBlock(nextTrimmed)) break;
      buffer.add(next.trim());
      i++;
    }
    blocks.add(
      MarkdownBlock(
        kind: BlockKind.paragraph,
        spans: parseInline(buffer.join(' ')),
      ),
    );
  }

  return blocks;
}

bool _startsBlock(String trimmed) =>
    trimmed.startsWith('```') ||
    trimmed.startsWith('>') ||
    RegExp(r'^#{1,6}\s').hasMatch(trimmed) ||
    RegExp(r'^[-*+]\s').hasMatch(trimmed) ||
    RegExp(r'^\d+[.)]\s').hasMatch(trimmed);

/// Splits one line into runs of plain text, emphasis, code and links.
///
/// Wiki links are matched before ordinary links so `[[Reading]]` is
/// never read as a link whose text is `[Reading`.
List<InlineSpanPart> parseInline(String source) {
  final spans = <InlineSpanPart>[];
  final pattern = RegExp(
    r'\[\[([^\[\]\n]+)\]\]'          // wiki link
    r'|\[([^\]\n]*)\]\(([^)\s]+)\)'  // [text](target)
    r'|`([^`\n]+)`'                  // code
    // Emphasis markers must sit against the word they wrap, so
    // `2 * 3 * 4` stays arithmetic instead of turning into italics.
    r'|\*\*(\S|\S[^*\n]*\S)\*\*'     // bold
    r'|__(\S|\S[^_\n]*\S)__'         // bold
    r'|\*(\S|\S[^*\n]*\S)\*'         // italic
    r'|_(\S|\S[^_\n]*\S)_',          // italic
  );

  var cursor = 0;
  for (final match in pattern.allMatches(source)) {
    if (match.start > cursor) {
      spans.add(
        InlineSpanPart(InlineKind.text, source.substring(cursor, match.start)),
      );
    }
    if (match.group(1) != null) {
      final title = match.group(1)!.trim();
      spans.add(InlineSpanPart(InlineKind.wikiLink, title, target: title));
    } else if (match.group(3) != null) {
      final text = match.group(2)!;
      spans.add(
        InlineSpanPart(
          InlineKind.link,
          text.isEmpty ? match.group(3)! : text,
          target: match.group(3),
        ),
      );
    } else if (match.group(4) != null) {
      spans.add(InlineSpanPart(InlineKind.code, match.group(4)!));
    } else if (match.group(5) != null) {
      spans.add(InlineSpanPart(InlineKind.bold, match.group(5)!));
    } else if (match.group(6) != null) {
      spans.add(InlineSpanPart(InlineKind.bold, match.group(6)!));
    } else if (match.group(7) != null) {
      spans.add(InlineSpanPart(InlineKind.italic, match.group(7)!));
    } else if (match.group(8) != null) {
      spans.add(InlineSpanPart(InlineKind.italic, match.group(8)!));
    }
    cursor = match.end;
  }
  if (cursor < source.length) {
    spans.add(InlineSpanPart(InlineKind.text, source.substring(cursor)));
  }
  return spans;
}
