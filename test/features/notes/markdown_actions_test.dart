import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/notes/domain/markdown_actions.dart';

/// Checkpoint 5, item 4. What the bar above the keyboard does to a body
/// and a caret — the fiddly half of a markdown editor, tested where it
/// is a function rather than a gesture.
void main() {
  group('wrapping', () {
    test('wraps the selection and keeps it selected', () {
      final result = toggleWrap(const Edit('make this bold', 5, 9), '**');
      expect(result.text, 'make **this** bold');
      expect(result.text.substring(result.start, result.end), 'this');
    });

    test('unwraps when the markers are just outside the selection', () {
      final result = toggleWrap(const Edit('make **this** bold', 7, 11), '**');
      expect(result.text, 'make this bold');
      expect(result.text.substring(result.start, result.end), 'this');
    });

    test('unwraps when the markers are inside the selection', () {
      final result = toggleWrap(const Edit('make **this** bold', 5, 13), '**');
      expect(result.text, 'make this bold');
    });

    test('with nothing selected it opens a pair and waits', () {
      final result = toggleWrap(const Edit('say ', 4), '**');
      expect(result.text, 'say ****');
      expect(result.start, 6);
      expect(result.collapsed, isTrue);
    });
  });

  group('headings', () {
    test('cycle none to H1 to H2 to H3 and back', () {
      var at = const Edit('Title', 5);
      at = cycleHeading(at);
      expect(at.text, '# Title');
      at = cycleHeading(at);
      expect(at.text, '## Title');
      at = cycleHeading(at);
      expect(at.text, '### Title');
      at = cycleHeading(at);
      expect(at.text, 'Title');
    });

    test('only touch the line the caret is on', () {
      final result = cycleHeading(const Edit('one\ntwo\nthree', 5));
      expect(result.text, 'one\n# two\nthree');
    });
  });

  group('line prefixes', () {
    test('go on and come off every line the selection touches', () {
      var at = const Edit('milk\neggs', 0, 9);
      at = togglePrefix(at, '- ');
      expect(at.text, '- milk\n- eggs');
      at = togglePrefix(Edit(at.text, 0, at.text.length), '- ');
      expect(at.text, 'milk\neggs');
    });

    test('make a task list out of a plain line', () {
      expect(togglePrefix(const Edit('pay rent', 0), '- [ ] ').text,
          '- [ ] pay rent');
    });
  });

  group('tables', () {
    test('a fresh one lands with the caret in the first header', () {
      final result = insertTable(const Edit('', 0));
      expect(result.text.trim().split('\n').length, 3);
      expect(result.text.substring(result.start, result.end), 'Column');
    });

    test('are recognised only from inside them', () {
      const table = '| a | b |\n| --- | --- |\n| 1 | 2 |';
      expect(tableAt(const Edit('$table\n\nafter', 3)), isNotNull);
      expect(tableAt(const Edit('$table\n\nafter', 40)), isNull);
    });

    test('grow a row that has as many cells as the header', () {
      const table = '| a | b |\n| --- | --- |\n| 1 | 2 |';
      final result = addTableRow(const Edit(table, 2))!;
      final rows = result.text.split('\n');
      expect(rows, hasLength(4));
      expect(rows.last, '|  |  |');
    });

    test('grow a column on every row, divider included', () {
      const table = '| a | b |\n| --- | --- |\n| 1 | 2 |';
      final rows = addTableColumn(const Edit(table, 2))!.text.split('\n');
      expect(rows[0], '| a | b |   |');
      expect(rows[1], '| --- | --- | --- |');
      expect(rows[2], '| 1 | 2 |   |');
    });

    test('an empty row is a row, not a divider', () {
      const table = '| a | b |\n| --- | --- |\n|  |  |';
      final rows = addTableColumn(const Edit(table, 2))!.text.split('\n');
      expect(rows[1], '| --- | --- | --- |');
      // The empty row gets an empty cell, not a row of dashes.
      expect(rows[2], '|  |  |   |');
    });

    test('the row and column buttons do nothing outside a table', () {
      expect(addTableRow(const Edit('just prose', 4)), isNull);
      expect(addTableColumn(const Edit('just prose', 4)), isNull);
    });
  });
}
