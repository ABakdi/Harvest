import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/notes/presentation/live_markdown_controller.dart';

/// Checkpoint 5, item 3. The live editor's one hard rule.
///
/// The controller draws markdown by *styling* the text rather than
/// rewriting it, which only works while the drawn spans add back up to
/// the stored string exactly. Break that and the field renders one
/// string while editing another: keystrokes vanish, the caret lands in
/// the wrong place, and it looks like the keyboard is broken. So it is
/// checked here, for every shape of line the editor knows.
void main() {
  String rendered(LiveMarkdownController controller, WidgetTester tester) {
    final span = controller.buildTextSpan(
      context: tester.element(find.byType(SizedBox)),
      withComposing: false,
    );
    return span.toPlainText(includeSemanticsLabels: false);
  }

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: SizedBox())),
  );

  const bodies = [
    '',
    'one line',
    'one\ntwo',
    'one\ntwo\nthree',
    'trailing newline\n',
    '\nleading newline',
    'blank\n\nbetween',
    '# A heading',
    '## Two\ntext under it',
    '- a bullet\n- another',
    '- [ ] undone\n- [x] done',
    '> a quote',
    '---',
    '| a | b |\n| --- | --- |\n| 1 | 2 |',
    '```\ncode\n```',
    'a **bold** and *soft* and `code`',
    'see [[Sleep]] and [docs](https://example.org)',
    '# All\n- of\n> it\n| at | once |\n**together**\n',
  ];

  testWidgets('the drawn spans rebuild the body exactly', (tester) async {
    await pump(tester);
    for (final body in bodies) {
      final controller = LiveMarkdownController(text: body);
      expect(rendered(controller, tester), body, reason: 'body: "$body"');
      controller.dispose();
    }
  });

  testWidgets('and still do with the caret on any line', (tester) async {
    await pump(tester);
    for (final body in bodies) {
      for (var caret = 0; caret <= body.length; caret++) {
        final controller = LiveMarkdownController(text: body)
          ..selection = TextSelection.collapsed(offset: caret);
        expect(
          rendered(controller, tester),
          body,
          reason: 'body: "$body" caret: $caret',
        );
        controller.dispose();
      }
    }
  });

  testWidgets('and with a selection spanning lines', (tester) async {
    await pump(tester);
    const body = '# One\nsome **bold**\n- [ ] a task';
    final controller = LiveMarkdownController(text: body)
      ..selection = const TextSelection(baseOffset: 2, extentOffset: 20);
    expect(rendered(controller, tester), body);
    controller.dispose();
  });

  testWidgets('raw mode draws the body untouched', (tester) async {
    await pump(tester);
    final controller = LiveMarkdownController(text: '# A\n**b**')..raw = true;
    expect(rendered(controller, tester), '# A\n**b**');
    controller.dispose();
  });
}
