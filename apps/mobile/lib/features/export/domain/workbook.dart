import 'package:excel/excel.dart';
import 'package:meta/meta.dart';

/// A cell holding a live formula instead of a value.
///
/// The whole point of exporting a workbook rather than a CSV is that
/// the numbers stay wired to the rows they came from (rule X3), so the
/// builder needs a way to say "this cell is an equation".
@immutable
class Formula {
  const Formula(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is Formula && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => text;
}

/// A column whose value is a formula over the row it sits in.
///
/// `{row}` in the template is replaced with the 1-based spreadsheet row,
/// so `'={amountMinor}{row}/100'` becomes `=E2/100` on the first data
/// row. Column placeholders in braces are resolved against the sheet's
/// own headers, which keeps the templates readable and stops a column
/// reorder from silently pointing a formula at the wrong data.
typedef DerivedColumn = ({String header, String template});

/// One tab of the workbook.
@immutable
class ExportSheet {
  const ExportSheet({
    required this.name,
    required this.headers,
    required this.rows,
    this.derived = const [],
    this.hasHeaderRow = true,
  });

  final String name;

  /// Stored-value column headers, in order.
  final List<String> headers;

  /// One entry per header: `String`, `int`, `double`, `bool`, `Formula`
  /// or null. Timestamps arrive as ISO-8601 text — unambiguous, sorts
  /// correctly, and survives an import without a serial-date guess.
  final List<List<Object?>> rows;

  /// Formula columns appended after [headers].
  final List<DerivedColumn> derived;

  /// Whether [headers] is written as row 1. The Summary is a layout,
  /// not a table, so it labels its own blocks instead.
  final bool hasHeaderRow;

  /// Every header the sheet ends up with, stored and derived alike.
  List<String> get allHeaders => [
    ...headers,
    ...derived.map((column) => column.header),
  ];

  /// The spreadsheet letter of [header] on this sheet.
  ///
  /// Throws rather than guessing: a formula pointing at a column that
  /// does not exist is a bug worth failing a test over.
  String column(String header) {
    final index = allHeaders.indexOf(header);
    if (index < 0) {
      throw ArgumentError.value(header, 'header', 'no such column on $name');
    }
    return columnLetter(index);
  }

  /// The 1-based spreadsheet row of the last data row.
  int get lastRow => rows.length + (hasHeaderRow ? 1 : 0);
}

/// Spreadsheet column letter for a 0-based index: 0 → A, 26 → AA.
String columnLetter(int index) {
  var remaining = index;
  final letters = StringBuffer();
  do {
    letters.write(String.fromCharCode(65 + remaining % 26));
    remaining = remaining ~/ 26 - 1;
  } while (remaining >= 0);
  return String.fromCharCodes(letters.toString().codeUnits.reversed);
}

/// Resolves `{header}` placeholders against [sheet] and `{row}` against
/// [row], leaving the rest of the formula alone.
String resolveTemplate(String template, ExportSheet sheet, int row) =>
    template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
      final name = match[1]!;
      return name == 'row' ? '$row' : sheet.column(name);
    });

/// Renders [sheets] into `.xlsx` bytes.
///
/// Pure: rows in, bytes out. Nothing here touches the database, the
/// filesystem or a plugin, which is what makes the layout testable.
List<int> buildWorkbook(List<ExportSheet> sheets) {
  if (sheets.isEmpty) {
    throw ArgumentError.value(sheets, 'sheets', 'a workbook needs a sheet');
  }
  final excel = Excel.createExcel();
  final headerStyle = CellStyle(bold: true);

  for (final source in sheets) {
    final sheet = excel[source.name];
    final headers = source.allHeaders;
    final offset = source.hasHeaderRow ? 1 : 0;
    if (source.hasHeaderRow) {
      for (var column = 0; column < headers.length; column++) {
        sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
          )
          ..value = TextCellValue(headers[column])
          ..cellStyle = headerStyle;
      }
    }

    for (var index = 0; index < source.rows.length; index++) {
      final rowIndex = index + offset;
      // Spreadsheet rows are 1-based; formulas quote that number.
      final rowNumber = rowIndex + 1;
      final values = source.rows[index];
      for (var column = 0; column < source.headers.length; column++) {
        _write(sheet, column, rowIndex, values[column], source, rowNumber);
      }
      for (var extra = 0; extra < source.derived.length; extra++) {
        _write(
          sheet,
          source.headers.length + extra,
          rowIndex,
          Formula(source.derived[extra].template),
          source,
          rowNumber,
        );
      }
    }

    for (var column = 0; column < headers.length; column++) {
      sheet.setColumnAutoFit(column);
    }
  }

  // `Sheet1` is created with the workbook and nothing was written to it.
  if (excel.tables.containsKey('Sheet1') &&
      !sheets.any((sheet) => sheet.name == 'Sheet1')) {
    excel.delete('Sheet1');
  }
  excel.setDefaultSheet(sheets.first.name);

  final bytes = excel.encode();
  if (bytes == null) throw StateError('the workbook could not be encoded');
  return bytes;
}

void _write(
  Sheet sheet,
  int column,
  int rowIndex,
  Object? value,
  ExportSheet source,
  int rowNumber,
) {
  sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: rowIndex))
      .value = switch (value) {
    null => null,
    // Every formula goes through the same resolver, wherever it came
    // from, so `{row}` means the same thing in a summary cell as it
    // does in a derived column.
    final Formula formula => FormulaCellValue(
      resolveTemplate(formula.text, source, rowNumber),
    ),
    final int number => IntCellValue(number),
    final double number => DoubleCellValue(number),
    final bool flag => BoolCellValue(flag),
    _ => TextCellValue('$value'),
  };
}
