import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:harvest/features/notes/domain/note_pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// An Arabic note turned into a PDF keeps its letters, reads right to
/// left, and a note with no title gets the reader's word for it
/// ([[Audit-v3]] Q5-25).
void main() {
  pw.Font font(String file) => pw.Font.ttf(
    File('assets/fonts/$file').readAsBytesSync().buffer.asByteData(),
  );
  final fonts = NotePdfFonts(
    regular: font('Nunito-Regular.ttf'),
    bold: font('Nunito-Bold.ttf'),
    arabic: font('IBMPlexSansArabic-Regular.ttf'),
    arabicBold: font('IBMPlexSansArabic-Bold.ttf'),
  );

  Note note(String title, String body) => Note(
    uuid: 'n',
    title: title,
    body: body,
    createdAt: DateTime(2026, 9, 27),
    updatedAt: DateTime(2026, 9, 27),
  );

  test('a block reads its direction from its first strong letter', () {
    expect(directionOf('مرحبا بالعالم'), pw.TextDirection.rtl);
    expect(directionOf('Hello عالم'), pw.TextDirection.ltr);
    expect(directionOf('12 - ملاحظة'), pw.TextDirection.rtl);
    expect(directionOf('2026'), pw.TextDirection.ltr);
  });

  test('an Arabic note embeds a font that has Arabic in it', () async {
    final bytes = await noteToPdf(
      note('', '# عنوان\n\nفقرة **مهمة** هنا.\n\n- بند\n\n> اقتباس'),
      untitled: 'بلا عنوان',
      fonts: fonts,
    );
    final text = String.fromCharCodes(bytes);
    expect(text, contains('IBMPlexSansArabic'));
    expect(text, isNot(contains('/Helvetica')));
  });

  test("a note with no title is named in the reader's words", () {
    expect(pdfFileName(note('', ''), untitled: 'بلا عنوان'), 'بلا عنوان.pdf');
    expect(pdfFileName(note('Plan', ''), untitled: 'Untitled'), 'Plan.pdf');
  });
}
