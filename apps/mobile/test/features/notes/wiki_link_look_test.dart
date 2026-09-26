import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/ui/theme.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/notes/presentation/live_markdown_controller.dart';

/// A link to a note that does not exist yet is drawn differently from
/// one that does — the whole point of writing `[[like this]]` before
/// the note is there ([[Audit-v2]] P3-06).
void main() {
  testWidgets('an unwritten link is faint and dashed', (tester) async {
    late LiveMarkdownController controller;
    await tester.pumpWidget(
      MaterialApp(
        theme: HarvestTheme.light(ThemePreset.harvest),
        home: Builder(
          builder: (context) {
            controller = LiveMarkdownController(
              text: 'See [[Reading]] and [[Nowhere]].',
            )..knownTitles = {'reading'};
            final written = _styleIn(context, controller, 'Reading');
            final unwritten = _styleIn(context, controller, 'Nowhere');
            expect(written.decoration, isNot(TextDecoration.underline));
            expect(unwritten.decoration, TextDecoration.underline);
            expect(unwritten.decorationStyle, TextDecorationStyle.dashed);
            // Same hue, less of it: an unwritten link is still a link.
            expect(unwritten.color!.a, lessThan(written.color!.a));
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('knowing no titles accuses no link', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HarvestTheme.light(ThemePreset.harvest),
        home: Builder(
          builder: (context) {
            final controller = LiveMarkdownController(text: 'See [[Reading]].');
            final style = _styleIn(context, controller, 'Reading');
            expect(style.decoration, isNot(TextDecoration.underline));
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
}

TextStyle _styleIn(
  BuildContext context,
  LiveMarkdownController controller,
  String title,
) {
  final span = controller.buildTextSpan(
    context: context,
    withComposing: false,
  );
  final found = <TextSpan>[];
  void walk(InlineSpan span) {
    if (span is! TextSpan) return;
    if (span.text == title) found.add(span);
    for (final child in span.children ?? const <InlineSpan>[]) {
      if (child is TextSpan) walk(child);
    }
  }

  walk(span);
  expect(found, isNotEmpty, reason: 'no span carried "$title"');
  return found.first.style!;
}
