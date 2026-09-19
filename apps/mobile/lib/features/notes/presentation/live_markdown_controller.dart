import 'package:flutter/material.dart';
import 'package:harvest/features/notes/domain/markdown.dart';

/// The editor's one mode: markdown, rendered, with the syntax showing
/// only on the line the caret is on.
///
/// This is the Obsidian trick, and it is worth copying for the reason
/// Obsidian is right about: a note with a Read button and an Edit
/// button is two documents that happen to share a body. Here there is
/// one document. `**bold**` is drawn bold with the asterisks folded
/// away, and the moment the caret lands on that line the asterisks
/// come back so they can be edited like the text they are.
///
/// Nothing is ever removed from the string — every marker is still a
/// character at its own offset, drawn at a hair's width and in no
/// colour when it is folded. Selection, undo and the caret therefore
/// need no translation between "what is stored" and "what is shown",
/// which is where an editor like this usually goes wrong.
class LiveMarkdownController extends TextEditingController {
  LiveMarkdownController({super.text});

  /// Turns folding off entirely, for a plain-text look.
  bool raw = false;

  /// A marker that is folded away: present, addressable, invisible.
  static const _folded = TextStyle(
    fontSize: 0.01,
    height: 0.01,
    color: Color(0x00000000),
    letterSpacing: 0,
  );

  /// The line the caret sits on shows its syntax; every other line is
  /// rendered. A selection spanning lines unfolds all of them, because
  /// selecting text you cannot see is not a feature.
  ({int start, int end}) _activeLines(String source) {
    final selection = this.selection;
    if (!selection.isValid) return (start: -1, end: -1);
    final from = selection.start.clamp(0, source.length);
    final to = selection.end.clamp(0, source.length);
    return (
      start: source.lastIndexOf('\n', from == 0 ? 0 : from - 1) + 1,
      end: () {
        final next = source.indexOf('\n', to);
        return next < 0 ? source.length : next;
      }(),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final source = text;
    final scheme = Theme.of(context).colorScheme;
    final base = style ?? const TextStyle();
    if (raw || source.isEmpty) {
      return TextSpan(style: base, text: source);
    }

    final active = _activeLines(source);
    final spans = <InlineSpan>[];
    final lines = source.split('\n');
    var offset = 0;
    var inFence = false;

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final end = offset + line.length;
      final editing = active.start <= end && active.end >= offset;

      if (line.trimLeft().startsWith('```')) {
        inFence = !inFence;
        spans.add(
          TextSpan(
            text: line,
            style: base.copyWith(
              fontFamily: 'monospace',
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
      } else if (inFence) {
        spans.add(
          TextSpan(
            text: line,
            style: base.copyWith(fontFamily: 'monospace'),
          ),
        );
      } else {
        spans.addAll(
          _line(line: line, base: base, scheme: scheme, editing: editing),
        );
      }

      offset = end + 1;
      // Between lines only: the spans have to add back up to exactly
      // the source, or the field renders one string and edits another.
      if (index < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: base));
      }
    }
    return TextSpan(style: base, children: spans);
  }

  /// One line: its block marker, then its inline spans.
  List<InlineSpan> _line({
    required String line,
    required TextStyle base,
    required ColorScheme scheme,
    required bool editing,
  }) {
    TextStyle marker(TextStyle shown) => editing
        ? shown.copyWith(color: scheme.onSurfaceVariant)
        : shown.merge(_folded);

    // Headings: the hashes fold away and the line takes the size they
    // asked for.
    final heading = RegExp(r'^(#{1,6})\s+').firstMatch(line);
    if (heading != null) {
      final level = heading.group(1)!.length;
      final style = base.copyWith(
        fontSize: (base.fontSize ?? 16) * switch (level) {
          1 => 1.6,
          2 => 1.35,
          3 => 1.18,
          _ => 1.06,
        },
        fontWeight: FontWeight.w800,
        height: 1.4,
      );
      return [
        TextSpan(text: heading.group(0), style: marker(style)),
        ..._inline(line.substring(heading.end), style, scheme, editing),
      ];
    }

    // A quote keeps its bar visible even when folded — the marker is
    // the only thing that says it is a quote.
    final quote = RegExp(r'^\s*>\s?').firstMatch(line);
    if (quote != null) {
      final style = base.copyWith(
        color: scheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      );
      return [
        TextSpan(
          text: quote.group(0),
          style: style.copyWith(
            color: scheme.secondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        ..._inline(line.substring(quote.end), style, scheme, editing),
      ];
    }

    // Task lists. The marker is tinted rather than swapped for a drawn
    // checkbox: a widget span costs one placeholder character, the
    // rendered text stops matching the stored text, and every caret
    // offset past it is wrong by one. A green `[x]` and a struck-out
    // line say the same thing and cost nothing.
    final task = RegExp(r'^(\s*)([-*+]\s+)(\[([ xX])\]\s*)').firstMatch(line);
    if (task != null) {
      final done = task.group(4)!.toLowerCase() == 'x';
      final style = base.copyWith(
        color: done ? scheme.onSurfaceVariant : null,
        decoration: done ? TextDecoration.lineThrough : null,
      );
      return [
        TextSpan(text: task.group(1), style: base),
        TextSpan(
          text: task.group(2),
          style: marker(base.copyWith(color: scheme.secondary)),
        ),
        TextSpan(
          text: task.group(3),
          style: base.copyWith(
            color: done ? scheme.secondary : scheme.outline,
            fontWeight: FontWeight.w800,
          ),
        ),
        ..._inline(line.substring(task.end), style, scheme, editing),
      ];
    }

    // Bullets and numbers: the marker stays, tinted, because a list
    // without one reads as a paragraph.
    final bullet = RegExp(r'^(\s*)([-*+]|\d+[.)])(\s+)').firstMatch(line);
    if (bullet != null) {
      return [
        TextSpan(text: bullet.group(1), style: base),
        TextSpan(
          text: bullet.group(2),
          style: base.copyWith(
            color: scheme.secondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        TextSpan(text: bullet.group(3), style: base),
        ..._inline(line.substring(bullet.end), base, scheme, editing),
      ];
    }

    // A table row is monospaced so its columns line up while typing.
    if (line.trimLeft().startsWith('|')) {
      // A dash is what makes it a divider; an empty row is just a row.
      final divider = RegExp(r'^\s*\|[\s:|-]*-[\s:|-]*\|\s*$').hasMatch(line);
      return [
        TextSpan(
          text: line,
          style: base.copyWith(
            fontFamily: 'monospace',
            fontSize: (base.fontSize ?? 16) * 0.92,
            color: divider ? scheme.outline : null,
          ),
        ),
      ];
    }

    if (RegExp(r'^\s*(-{3,}|\*{3,}|_{3,})\s*$').hasMatch(line)) {
      return [
        TextSpan(
          text: line,
          style: base.copyWith(
            color: scheme.outline,
            letterSpacing: 2,
          ),
        ),
      ];
    }

    return _inline(line, base, scheme, editing);
  }

  /// Inline markers, folded unless the caret is on this line.
  List<InlineSpan> _inline(
    String text,
    TextStyle base,
    ColorScheme scheme,
    bool editing,
  ) {
    if (text.isEmpty) return [TextSpan(text: text, style: base)];

    TextStyle fold(TextStyle shown) =>
        editing ? shown.copyWith(color: scheme.outline) : shown.merge(_folded);

    final spans = <InlineSpan>[];
    for (final part in scanInline(text)) {
      switch (part.kind) {
        case InlineKind.text:
          spans.add(TextSpan(text: part.text, style: base));
        case InlineKind.bold:
          spans
            ..add(TextSpan(text: part.open, style: fold(base)))
            ..add(
              TextSpan(
                text: part.text,
                style: base.copyWith(fontWeight: FontWeight.w800),
              ),
            )
            ..add(TextSpan(text: part.close, style: fold(base)));
        case InlineKind.italic:
          spans
            ..add(TextSpan(text: part.open, style: fold(base)))
            ..add(
              TextSpan(
                text: part.text,
                style: base.copyWith(fontStyle: FontStyle.italic),
              ),
            )
            ..add(TextSpan(text: part.close, style: fold(base)));
        case InlineKind.code:
          final style = base.copyWith(
            fontFamily: 'monospace',
            backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
          );
          spans
            ..add(TextSpan(text: part.open, style: fold(style)))
            ..add(TextSpan(text: part.text, style: style))
            ..add(TextSpan(text: part.close, style: fold(style)));
        case InlineKind.wikiLink:
          final style = base.copyWith(
            color: scheme.secondary,
            fontWeight: FontWeight.w700,
          );
          spans
            ..add(TextSpan(text: part.open, style: fold(style)))
            ..add(TextSpan(text: part.text, style: style))
            ..add(TextSpan(text: part.close, style: fold(style)));
        case InlineKind.link:
          final style = base.copyWith(
            color: scheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: scheme.primary,
          );
          spans
            ..add(TextSpan(text: part.open, style: fold(style)))
            ..add(TextSpan(text: part.text, style: style))
            ..add(
              TextSpan(
                text: part.close,
                style: fold(base.copyWith(color: scheme.outline)),
              ),
            );
      }
    }
    return spans;
  }
}
