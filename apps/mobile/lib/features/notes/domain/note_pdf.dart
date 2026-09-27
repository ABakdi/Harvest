import 'package:flutter/services.dart';
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
///
/// The app's own fonts go in (Nunito, with IBM Plex Sans Arabic behind
/// it, both under the SIL Open Font Licence): the PDF default is
/// Helvetica, which has no Arabic at all. Each block reads its own
/// direction from its first strong letter, as `dir="auto"` does, and
/// indents from the start of the line, not the left ([[Audit-v3]]
/// Q5-25). [untitled] is the reader's word for a note with no title.
Future<Uint8List> noteToPdf(
  Note note, {
  required String untitled,
  String? subtitle,
  NotePdfFonts? fonts,
}) async {
  final faces = fonts ?? await NotePdfFonts.load();
  final title = note.title.isEmpty ? untitled : note.title;
  final document = pw.Document(
    title: title,
    theme: pw.ThemeData.withFont(
      base: faces.regular,
      bold: faces.bold,
      italic: faces.regular,
      boldItalic: faces.bold,
      fontFallback: [faces.arabic, faces.arabicBold],
    ),
  );
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
        _directed(
          title,
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty)
          _directed(
            subtitle,
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                subtitle,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ),
        pw.SizedBox(height: 14),
        for (final block in blocks) _directedBlock(block),
      ],
    ),
  );

  return document.save();
}

/// The fonts a note's PDF is set in.
class NotePdfFonts {
  const NotePdfFonts({
    required this.regular,
    required this.bold,
    required this.arabic,
    required this.arabicBold,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font arabic;
  final pw.Font arabicBold;

  static Future<NotePdfFonts> load() async {
    Future<pw.Font> font(String file) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$file'));
    return NotePdfFonts(
      regular: await font('Nunito-Regular.ttf'),
      bold: await font('Nunito-Bold.ttf'),
      arabic: await font('IBMPlexSansArabic-Regular.ttf'),
      arabicBold: await font('IBMPlexSansArabic-Bold.ttf'),
    );
  }
}

/// Right to left when the first strong letter of [text] is Arabic or
/// Hebrew script; left to right otherwise, and for text with none.
pw.TextDirection directionOf(String text) {
  for (final rune in text.runes) {
    if (_isRtl(rune)) return pw.TextDirection.rtl;
    if (_isLtr(rune)) return pw.TextDirection.ltr;
  }
  return pw.TextDirection.ltr;
}

bool _isRtl(int rune) =>
    (rune >= 0x0590 && rune <= 0x08FF) ||
    (rune >= 0xFB1D && rune <= 0xFDFF) ||
    (rune >= 0xFE70 && rune <= 0xFEFF);

bool _isLtr(int rune) =>
    (rune >= 0x41 && rune <= 0x5A) ||
    (rune >= 0x61 && rune <= 0x7A) ||
    (rune >= 0xC0 && rune <= 0x24F && rune != 0xD7 && rune != 0xF7) ||
    (rune >= 0x370 && rune <= 0x58F);

pw.Widget _directed(String text, pw.Widget child) =>
    pw.Directionality(textDirection: directionOf(text), child: child);

/// Code keeps left to right whatever it says.
pw.Widget _directedBlock(MarkdownBlock block) {
  final direction = block.kind == BlockKind.code
      ? pw.TextDirection.ltr
      : directionOf(_plain(block.spans));
  return pw.Directionality(
    textDirection: direction,
    child: _block(block, direction),
  );
}

pw.Widget _block(MarkdownBlock block, pw.TextDirection direction) {
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
        padding: pw.EdgeInsetsDirectional.only(
          start: 10 + block.level * 12,
          bottom: 3,
        ),
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
        padding: pw.EdgeInsetsDirectional.only(
          start: 10 + block.level * 12,
          bottom: 3,
        ),
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
        padding: const pw.EdgeInsetsDirectional.only(start: 10),
        // The bar sits at the start of the line: the right in Arabic.
        decoration: pw.BoxDecoration(
          border: direction == pw.TextDirection.rtl
              ? const pw.Border(
                  right: pw.BorderSide(color: PdfColors.grey400, width: 2),
                )
              : const pw.Border(
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
String pdfFileName(Note note, {required String untitled}) =>
    '${safeFileName(note.title.isEmpty ? untitled : note.title)}.pdf';
