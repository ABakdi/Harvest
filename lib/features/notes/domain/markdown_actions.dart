/// The edits the toolbar above the keyboard performs.
///
/// Pure string work, deliberately: what a "make this bold" button does
/// to a body and a caret is exactly the kind of thing that is fiddly,
/// easy to get subtly wrong, and impossible to test through a widget.
/// So it is a function from (text, selection) to (text, selection) and
/// the button is three lines.
library;

import 'package:meta/meta.dart';

/// A body and where the caret is in it.
@immutable
class Edit {
  const Edit(this.text, this.start, [int? end]) : end = end ?? start;

  final String text;
  final int start;
  final int end;

  bool get collapsed => start == end;
  String get selected => text.substring(start, end);

  /// The offsets of the line the caret sits on, newline excluded.
  (int, int) get line {
    final from = text.lastIndexOf('\n', start == 0 ? 0 : start - 1) + 1;
    final next = text.indexOf('\n', end);
    return (from, next < 0 ? text.length : next);
  }

  @override
  bool operator ==(Object other) =>
      other is Edit &&
      other.text == text &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(text, start, end);
}

/// Wraps the selection in [marker], or unwraps it when it is already
/// wrapped — a bold button that cannot un-bold is half a button.
///
/// With nothing selected it inserts the pair and puts the caret
/// between them, so typing carries straight on.
Edit toggleWrap(Edit at, String marker) {
  final width = marker.length;
  if (!at.collapsed) {
    final before = at.start >= width
        ? at.text.substring(at.start - width, at.start)
        : '';
    final after = at.end + width <= at.text.length
        ? at.text.substring(at.end, at.end + width)
        : '';
    if (before == marker && after == marker) {
      return Edit(
        at.text.replaceRange(at.end, at.end + width, '').replaceRange(
          at.start - width,
          at.start,
          '',
        ),
        at.start - width,
        at.end - width,
      );
    }
    if (at.selected.startsWith(marker) && at.selected.endsWith(marker)) {
      final inner = at.selected.substring(width, at.selected.length - width);
      return Edit(
        at.text.replaceRange(at.start, at.end, inner),
        at.start,
        at.start + inner.length,
      );
    }
    final wrapped = '$marker${at.selected}$marker';
    return Edit(
      at.text.replaceRange(at.start, at.end, wrapped),
      at.start + width,
      at.end + width,
    );
  }
  return Edit(
    at.text.replaceRange(at.start, at.start, '$marker$marker'),
    at.start + width,
  );
}

/// Cycles a line's heading level: none → H1 → H2 → H3 → none.
Edit cycleHeading(Edit at) {
  final (from, to) = at.line;
  final line = at.text.substring(from, to);
  final match = RegExp(r'^(#{1,6})\s+').firstMatch(line);
  final level = match == null ? 0 : match.group(1)!.length;
  final body = match == null ? line : line.substring(match.end);
  final next = level >= 3 ? 0 : level + 1;
  final replacement = next == 0 ? body : '${'#' * next} $body';
  final shift = replacement.length - line.length;
  return Edit(
    at.text.replaceRange(from, to, replacement),
    (at.start + shift).clamp(from, from + replacement.length),
    (at.end + shift).clamp(from, from + replacement.length),
  );
}

/// Puts [prefix] on every line the selection touches, or takes it off
/// when they all already have it.
Edit togglePrefix(Edit at, String prefix) {
  final (from, to) = at.line;
  final lines = at.text.substring(from, to).split('\n');
  final pattern = RegExp('^${RegExp.escape(prefix)}');
  final allPrefixed = lines.every(
    (line) => line.isEmpty || pattern.hasMatch(line),
  );
  final changed = [
    for (final line in lines)
      if (allPrefixed) line.replaceFirst(pattern, '') else '$prefix$line',
  ].join('\n');
  final shift = allPrefixed ? -prefix.length : prefix.length;
  return Edit(
    at.text.replaceRange(from, to, changed),
    (at.start + shift).clamp(from, from + changed.length),
    (at.end + (shift * lines.length)).clamp(from, from + changed.length),
  );
}

/// A three-column starter table, caret in the first header cell.
const starterTable =
    '| Column | Column | Column |\n'
    '| --- | --- | --- |\n'
    '|  |  |  |';

Edit insertTable(Edit at) {
  final (from, to) = at.line;
  final onBlankLine = at.text.substring(from, to).trim().isEmpty;
  final lead = onBlankLine ? '' : '\n';
  final text = at.text.replaceRange(
    at.start,
    at.end,
    '$lead$starterTable\n',
  );
  // Caret into the first header cell, over the word "Column".
  final start = at.start + lead.length + 2;
  return Edit(text, start, start + 6);
}

/// The rows of the table the caret is in, or null when it is not in
/// one. A table is a run of lines that all start with `|`.
({int start, int end, List<String> rows})? tableAt(Edit at) {
  final lines = at.text.split('\n');
  var offset = 0;
  var caretLine = -1;
  final bounds = <(int, int)>[];
  for (var i = 0; i < lines.length; i++) {
    final end = offset + lines[i].length;
    bounds.add((offset, end));
    if (caretLine < 0 && at.start <= end) caretLine = i;
    offset = end + 1;
  }
  if (caretLine < 0) return null;
  bool isRow(int i) =>
      i >= 0 && i < lines.length && lines[i].trimLeft().startsWith('|');
  if (!isRow(caretLine)) return null;

  var first = caretLine;
  while (isRow(first - 1)) {
    first--;
  }
  var last = caretLine;
  while (isRow(last + 1)) {
    last++;
  }
  return (
    start: bounds[first].$1,
    end: bounds[last].$2,
    rows: lines.sublist(first, last + 1),
  );
}

/// Adds an empty row under the one the caret is in.
Edit? addTableRow(Edit at) {
  final table = tableAt(at);
  if (table == null) return null;
  final columns = _cellsOf(table.rows.first).length;
  final row = '|${List.filled(columns, '  ').join('|')}|';
  final rows = [...table.rows, row];
  final text = at.text.replaceRange(table.start, table.end, rows.join('\n'));
  // Caret into the new row's first cell.
  final caret = table.start +
      rows.take(rows.length - 1).fold<int>(0, (sum, r) => sum + r.length + 1) +
      2;
  return Edit(text, caret);
}

/// Adds a column to every row, the divider included.
Edit? addTableColumn(Edit at) {
  final table = tableAt(at);
  if (table == null) return null;
  final rows = [
    for (final row in table.rows)
      if (_isDivider(row)) '${row.trimRight()} --- |' else '${row.trimRight()}   |',
  ];
  final text = at.text.replaceRange(table.start, table.end, rows.join('\n'));
  return Edit(text, at.start, at.end);
}

/// The `| --- | --- |` line under a header.
///
/// It has to actually contain a dash: `|  |  |` is a perfectly ordinary
/// empty row, and treating it as the divider is how adding a column
/// fills every empty cell in the table with dashes.
bool _isDivider(String row) =>
    RegExp(r'^\s*\|[\s:|-]*-[\s:|-]*\|\s*$').hasMatch(row);

List<String> _cellsOf(String row) {
  final trimmed = row.trim();
  final inner = trimmed.substring(
    trimmed.startsWith('|') ? 1 : 0,
    trimmed.endsWith('|') ? trimmed.length - 1 : trimmed.length,
  );
  return inner.split('|');
}
