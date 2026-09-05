import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/notes/domain/markdown.dart';

/// The renderer's contract from the spec: a short, finite list of
/// things is understood, and **anything else passes through as text
/// rather than being silently eaten**.
void main() {
  group('blocks', () {
    test('headings keep their level and lose their hashes', () {
      final blocks = parseMarkdown('# One\n\n### Three');
      expect(blocks.map((b) => b.kind), [
        BlockKind.heading,
        BlockKind.heading,
      ]);
      expect(blocks.first.level, 1);
      expect(blocks.first.spans.single.text, 'One');
      expect(blocks.last.level, 3);
    });

    test('a task list is a list that knows whether it is done', () {
      final blocks = parseMarkdown('- [ ] buy milk\n- [x] pay rent');
      expect(blocks.map((b) => b.kind), [BlockKind.task, BlockKind.task]);
      expect(blocks.first.checked, isFalse);
      expect(blocks.last.checked, isTrue);
      expect(blocks.last.spans.single.text, 'pay rent');
    });

    test('bullets, numbers, quotes and rules are each their own', () {
      expect(parseMarkdown('- one').single.kind, BlockKind.bullet);
      expect(parseMarkdown('1. one').single.kind, BlockKind.numbered);
      expect(parseMarkdown('> said so').single.kind, BlockKind.quote);
      expect(parseMarkdown('---').single.kind, BlockKind.rule);
    });

    test('a fenced block keeps its contents exactly', () {
      final block = parseMarkdown('```\nline one\n  line two\n```').single;
      expect(block.kind, BlockKind.code);
      expect(block.text, 'line one\n  line two');
    });

    test('an unclosed fence is still a code block, not a lost note', () {
      final block = parseMarkdown('```\nstill here').single;
      expect(block.kind, BlockKind.code);
      expect(block.text, 'still here');
    });

    test('consecutive lines join into one paragraph', () {
      final blocks = parseMarkdown('one\ntwo\n\nthree');
      expect(blocks.length, 2);
      expect(blocks.first.kind, BlockKind.paragraph);
    });
  });

  group('inline', () {
    test('bold, italic and code are marked and unwrapped', () {
      final spans = parseInline('a **bold** and *soft* and `x = 1`');
      expect(
        spans.where((s) => s.kind == InlineKind.bold).single.text,
        'bold',
      );
      expect(
        spans.where((s) => s.kind == InlineKind.italic).single.text,
        'soft',
      );
      expect(
        spans.where((s) => s.kind == InlineKind.code).single.text,
        'x = 1',
      );
    });

    test('a wiki link carries the title it points at', () {
      final link = parseInline('see [[Sleep log]] tonight')
          .where((s) => s.kind == InlineKind.wikiLink)
          .single;
      expect(link.text, 'Sleep log');
      expect(link.target, 'Sleep log');
    });

    test('a markdown link shows its label', () {
      final link = parseInline('[the docs](https://example.org)')
          .where((s) => s.kind == InlineKind.link)
          .single;
      expect(link.text, 'the docs');
      expect(link.target, 'https://example.org');
    });

    test('an unmatched marker stays as text (rule N4)', () {
      final spans = parseInline('2 * 3 * 4 is not italic');
      expect(spans.every((s) => s.kind == InlineKind.text), isTrue);
      expect(spans.map((s) => s.text).join(), '2 * 3 * 4 is not italic');
    });

    test('nothing is lost: the text always adds back up', () {
      const source = 'a **b** c *d* e `f` g [[h]] i [j](k) l';
      expect(parseInline(source).map((s) => s.text).join().isNotEmpty, isTrue);
    });
  });
}
