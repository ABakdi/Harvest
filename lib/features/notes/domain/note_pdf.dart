import 'dart:typed_data';

import 'package:harvest/features/notes/domain/markdown.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// A note as a page somebody else can read.
///
/// The markdown is rendered rather than dumped: a PDF of `**bold**`
/// with the asterisks still in it would be a text file with a worse
/// extension. Same parser the editor uses, so what comes out is what
/// was on screen.
Future<Uint8List> noteToPdf(Note note, {String? subtitle}) async {
  final document = pw.Document(title: note.title);
  final blocks = parseMarkdown(note.body);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 54, 48, 54),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Text(
          note.title.isEmpty ? 'Untitled' : note.title,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        if (subtitle != null && subtitle.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              subtitle,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
        pw.SizedBox(height: 14),
        for (final block in blocks) _block(block),
      ],
    ),
  );

  return document.save();
}

pw.Widget _block(MarkdownBlock block) {
  switch (block.kind) {
    case BlockKind.heading:
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
        child: pw.Text(
          _plain(block.spans),
          style: pw.TextStyle(
            fontSize: switch (block.level) {
              1 => 19,
              2 => 16,
              3 => 14,
              _ => 12,
            },
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );

    case BlockKind.paragraph:
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: _rich(block.spans),
      );

    case BlockKind.bullet:
    case BlockKind.numbered:
      final marker = block.kind == BlockKind.bullet ? '•' : '${block.level}.';
      return pw.Padding(
        padding: pw.EdgeInsets.only(left: 10 + block.level * 12, bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 16, child: pw.Text(marker)),
            pw.Expanded(child: _rich(block.spans)),
          ],
        ),
      );

    case BlockKind.task:
      return pw.Padding(
        padding: pw.EdgeInsets.only(left: 10 + block.level * 12, bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 16,
              child: pw.Text(block.checked ? '[x]' : '[ ]'),
            ),
            pw.Expanded(
              child: pw.Text(
                _plain(block.spans),
                style: pw.TextStyle(
                  color: block.checked ? PdfColors.grey600 : null,
                  decoration: block.checked
                      ? pw.TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ],
        ),
      );

    case BlockKind.quote:
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.only(left: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: PdfColors.grey400, width: 2),
          ),
        ),
        child: pw.Text(
          _plain(block.spans),
          style: pw.TextStyle(
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey700,
          ),
        ),
      );

    case BlockKind.code:
      return pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(8),
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        child: pw.Text(
          block.text,
          style: const pw.TextStyle(fontSize: 10),
        ),
      );

    case BlockKind.rule:
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 10),
        child: pw.Divider(height: 1, color: PdfColors.grey400),
      );
  }
}

/// Bold and italic survive; the rest is text.
pw.Widget _rich(List<InlineSpanPart> spans) => pw.RichText(
  text: pw.TextSpan(
    children: [
      for (final span in spans)
        pw.TextSpan(
          text: span.text,
          style: switch (span.kind) {
            InlineKind.bold => pw.TextStyle(fontWeight: pw.FontWeight.bold),
            InlineKind.italic => pw.TextStyle(fontStyle: pw.FontStyle.italic),
            InlineKind.code => const pw.TextStyle(color: PdfColors.blueGrey800),
            InlineKind.link || InlineKind.wikiLink => const pw.TextStyle(
              color: PdfColors.blue800,
              decoration: pw.TextDecoration.underline,
            ),
            InlineKind.text => null,
          },
        ),
    ],
  ),
);

String _plain(List<InlineSpanPart> spans) =>
    spans.map((span) => span.text).join();

/// `Q4- what now-.pdf` — the same sanitising the archive uses, so a
/// note exported twice by two routes lands on one name.
String pdfFileName(Note note) =>
    '${safeFileName(note.title.isEmpty ? 'Untitled' : note.title)}.pdf';
