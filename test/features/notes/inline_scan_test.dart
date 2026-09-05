import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/notes/domain/markdown.dart';

/// Checkpoint 5, item 3. The live editor draws the markers rather than
/// throwing them away, and it can only do that if the scan gives every
/// character back — a character it loses is a character the caret
/// cannot reach.
void main() {
  String rebuilt(String source) => scanInline(source)
      .map((part) => '${part.open}${part.text}${part.close}')
      .join();

  test('rebuilds the line exactly, whatever is in it', () {
    const lines = [
      'plain text',
      'a **bold** word',
      'a *soft* word and _another_',
      'code `x = 1` inline',
      'see [[Sleep log]] tonight',
      'the [docs](https://example.org) say',
      'mixed **bold** and [[link]] and `code`',
      '2 * 3 * 4 is not italic',
      '',
    ];
    for (final line in lines) {
      expect(rebuilt(line), line, reason: line);
    }
  });

  test('keeps the markers a reader would not need', () {
    final bold = scanInline('a **word**').last;
    expect(bold.kind, InlineKind.bold);
    expect(bold.open, '**');
    expect(bold.close, '**');
    expect(bold.text, 'word');
  });

  test('a link keeps its whole tail as the closing marker', () {
    final link = scanInline('[docs](https://example.org)').single;
    expect(link.kind, InlineKind.link);
    expect(link.open, '[');
    expect(link.text, 'docs');
    expect(link.close, '](https://example.org)');
    expect(link.target, 'https://example.org');
  });

  test('a wiki link points at the title it wraps', () {
    final link = scanInline('see [[Sleep log]]').last;
    expect(link.kind, InlineKind.wikiLink);
    expect(link.target, 'Sleep log');
  });
}
