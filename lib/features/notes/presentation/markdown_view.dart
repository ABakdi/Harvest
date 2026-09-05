import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/notes/domain/markdown.dart';

/// Renders the markdown a note is written in.
///
/// Hand-rolled rather than pulled in, for the reason the spec gives:
/// the supported list is short and finite, `[[wiki links]]` are not
/// markdown at all, and a renderer that only does what is asked for is
/// a hundred lines rather than a dependency.
class MarkdownView extends StatelessWidget {
  const MarkdownView({
    required this.source,
    required this.onWikiLink,
    this.unresolved = const {},
    super.key,
  });

  final String source;

  /// Tapping `[[a link]]`: opens the note, or offers to create it.
  final void Function(String title) onWikiLink;

  /// Titles that do not exist yet — drawn as an invitation, not an
  /// error (rule: a link to a note I have not written is normal).
  final Set<String> unresolved;

  @override
  Widget build(BuildContext context) {
    final blocks = parseMarkdown(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) _block(context, block),
      ],
    );
  }

  Widget _block(BuildContext context, MarkdownBlock block) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    switch (block.kind) {
      case BlockKind.heading:
        final style = switch (block.level) {
          1 => theme.textTheme.headlineSmall,
          2 => theme.textTheme.titleLarge,
          3 => theme.textTheme.titleMedium,
          _ => theme.textTheme.titleSmall,
        };
        return Padding(
          padding: const EdgeInsets.only(
            top: HarvestSpacing.md,
            bottom: HarvestSpacing.xs,
          ),
          child: _text(
            context,
            block.spans,
            style?.copyWith(fontWeight: FontWeight.w800),
          ),
        );

      case BlockKind.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: HarvestSpacing.sm),
          child: _text(context, block.spans, theme.textTheme.bodyLarge),
        );

      case BlockKind.bullet:
      case BlockKind.numbered:
        final marker = block.kind == BlockKind.bullet
            ? '•'
            : '${block.level}.';
        return Padding(
          padding: EdgeInsetsDirectional.only(
            start: HarvestSpacing.sm + block.level * 12.0,
            bottom: 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(marker, style: theme.textTheme.bodyLarge),
              ),
              Expanded(
                child: _text(context, block.spans, theme.textTheme.bodyLarge),
              ),
            ],
          ),
        );

      case BlockKind.task:
        return Padding(
          padding: EdgeInsetsDirectional.only(
            start: HarvestSpacing.sm + block.level * 12.0,
            bottom: 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6, top: 3),
                child: Icon(
                  block.checked
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: block.checked ? scheme.secondary : scheme.outline,
                ),
              ),
              Expanded(
                child: _text(
                  context,
                  block.spans,
                  theme.textTheme.bodyLarge?.copyWith(
                    color: block.checked ? scheme.onSurfaceVariant : null,
                    decoration: block.checked
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            ],
          ),
        );

      case BlockKind.quote:
        return Container(
          margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
          padding: const EdgeInsetsDirectional.only(start: HarvestSpacing.md),
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(color: scheme.secondary, width: 3),
            ),
          ),
          child: _text(
            context,
            block.spans,
            theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        );

      case BlockKind.code:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: HarvestSpacing.sm),
          padding: const EdgeInsets.all(HarvestSpacing.sm),
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(HarvestRadii.chip),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              block.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        );

      case BlockKind.rule:
        return const Divider(height: HarvestSpacing.lg);
    }
  }

  Widget _text(
    BuildContext context,
    List<InlineSpanPart> spans,
    TextStyle? base,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SelectableText.rich(
      TextSpan(
        style: base,
        children: [
          for (final span in spans)
            switch (span.kind) {
              InlineKind.text => TextSpan(text: span.text),
              InlineKind.bold => TextSpan(
                text: span.text,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              InlineKind.italic => TextSpan(
                text: span.text,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              InlineKind.code => TextSpan(
                text: span.text,
                style: TextStyle(
                  fontFamily: 'monospace',
                  backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              InlineKind.link => TextSpan(
                text: span.text,
                style: TextStyle(
                  color: scheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: scheme.primary,
                ),
              ),
              InlineKind.wikiLink => TextSpan(
                text: span.text,
                style: TextStyle(
                  color: unresolved.contains(span.target)
                      ? scheme.onSurfaceVariant
                      : scheme.secondary,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationStyle: unresolved.contains(span.target)
                      ? TextDecorationStyle.dashed
                      : TextDecorationStyle.solid,
                  decorationColor: unresolved.contains(span.target)
                      ? scheme.outline
                      : scheme.secondary,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => onWikiLink(span.target!),
              ),
            },
        ],
      ),
    );
  }
}
