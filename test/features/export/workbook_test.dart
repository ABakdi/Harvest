import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/export/domain/export_service.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';
import 'package:harvest/features/export/domain/workbook.dart';

/// The exported workbook's layout (checkpoint C2-2). The point of a
/// spreadsheet over a CSV is that the numbers stay wired to the rows,
/// so what is checked here is mostly the formulas.
void main() {
  ExportData data({
    List<List<Object?>> expenses = const [],
    List<List<Object?>> money = const [],
    List<List<Object?>> debts = const [],
    List<List<Object?>> debtPayments = const [],
    List<List<Object?>> seeds = const [],
    List<List<Object?>> checkIns = const [],
    List<List<Object?>> ledger = const [],
  }) => (
    generatedAt: DateTime.utc(2026, 9, 4, 18, 30),
    seeds: seeds,
    checkIns: checkIns,
    expenses: expenses,
    money: money,
    debts: debts,
    debtPayments: debtPayments,
    focus: const [],
    ledger: ledger,
    streaks: const [],
    settings: const [],
  );

  ExportSheet sheetNamed(List<ExportSheet> sheets, String name) =>
      sheets.firstWhere((sheet) => sheet.name == name);

  group('column letters', () {
    test('count the way a spreadsheet does', () {
      expect(columnLetter(0), 'A');
      expect(columnLetter(25), 'Z');
      expect(columnLetter(26), 'AA');
      expect(columnLetter(27), 'AB');
      expect(columnLetter(51), 'AZ');
      expect(columnLetter(52), 'BA');
    });
  });

  group('templates', () {
    const sheet = ExportSheet(
      name: 'T',
      headers: ['Uuid', 'AmountMinor'],
      rows: [],
      derived: [(header: 'Amount', template: '={AmountMinor}{row}/100')],
    );

    test('resolve column names against the sheet, not a hardcoded letter', () {
      expect(resolveTemplate('={AmountMinor}{row}/100', sheet, 2), '=B2/100');
    });

    test('can name a derived column too', () {
      expect(resolveTemplate('={Amount}{row}', sheet, 5), '=C5');
    });

    test('a column that does not exist is an error, not a wrong cell', () {
      expect(
        () => resolveTemplate('={Nope}{row}', sheet, 2),
        throwsArgumentError,
      );
    });
  });

  group('layout', () {
    test('every table gets a sheet, with Summary first', () {
      final sheets = harvestSheets(data());

      expect(sheets.first.name, SheetNames.summary);
      expect(sheets.map((sheet) => sheet.name), [
        SheetNames.summary,
        SheetNames.seeds,
        SheetNames.checkIns,
        SheetNames.expenses,
        SheetNames.money,
        SheetNames.debts,
        SheetNames.debtPayments,
        SheetNames.focus,
        SheetNames.ledger,
        SheetNames.streaks,
        SheetNames.settings,
      ]);
    });

    test('money keeps its minor units and derives the major (rule X4)', () {
      final expenses = sheetNamed(
        harvestSheets(
          data(
            expenses: const [
              ['e1', '2026-09-01', 'food', 'DZD', 1250, null, null, null],
            ],
          ),
        ),
        SheetNames.expenses,
      );

      expect(expenses.headers, contains('AmountMinor'));
      expect(expenses.rows.single[4], 1250);
      expect(
        expenses.derived.single,
        (header: 'Amount', template: '={AmountMinor}{row}/100'),
      );
    });

    test('what is left on a debt is a formula over its payments', () {
      final debts = sheetNamed(harvestSheets(data()), SheetNames.debts);
      final remaining = debts.derived.last;

      expect(remaining.header, 'Remaining');
      expect(resolveTemplate(remaining.template, debts, 2), '=L2-M2');
    });
  });

  group('summary', () {
    test('is a layout, not a table, so it has no header row', () {
      final summary = harvestSheets(data()).first;

      expect(summary.hasHeaderRow, isFalse);
    });

    test('counts rows with a formula rather than a number', () {
      final summary = harvestSheets(data()).first;
      final seeds = summary.rows.firstWhere(
        (row) => row.first == SheetNames.seeds,
      );

      expect(seeds[1], const Formula('=COUNTA(Seeds!A:A)-1'));
    });

    test('breaks money down per currency, skipping deleted rows', () {
      final summary = harvestSheets(
        data(
          expenses: const [
            ['e1', '2026-09-01', 'food', 'DZD', 1250, null, null, null],
          ],
          money: const [
            [
              'm1',
              '2026-09-01',
              'wallet',
              'manual',
              null,
              'DZD',
              5000,
              null,
              null,
              null,
              null,
            ],
          ],
        ),
      ).first;
      final row = summary.rows.firstWhere((row) => row.first == 'DZD');

      expect(
        row[1],
        const Formula(
          r'=SUMIFS(Money!G:G,Money!F:F,$A{row},Money!C:C,"wallet",'
          'Money!K:K,"")/100',
        ),
      );
      expect(
        row[3],
        const Formula(
          r'=SUMIFS(Expenses!E:E,Expenses!D:D,$A{row},Expenses!H:H,"")/100',
        ),
      );
    });

    test('lists currencies and categories in a stable order', () {
      final summary = harvestSheets(
        data(
          expenses: const [
            ['e1', '2026-09-01', 'transport', 'USD', 1, null, null, null],
            ['e2', '2026-09-01', 'food', 'DZD', 1, null, null, null],
            ['e3', '2026-09-01', 'food', 'EUR', 1, null, null, null],
          ],
        ),
      ).first;
      final labels = summary.rows.map((row) => row.first).toList();

      expect(labels.indexOf('DZD'), lessThan(labels.indexOf('EUR')));
      expect(labels.indexOf('EUR'), lessThan(labels.indexOf('USD')));
      expect(labels.indexOf('food'), lessThan(labels.indexOf('transport')));
    });

    test('bounds the month breakdown at the real last row', () {
      final summary = harvestSheets(
        data(
          expenses: const [
            ['e1', '2026-08-31', 'food', 'DZD', 1, null, null, null],
            ['e2', '2026-09-01', 'food', 'DZD', 1, null, null, null],
          ],
        ),
      ).first;
      final august = summary.rows.firstWhere((row) => row.first == '2026-08');

      // Two data rows plus the header: the range must stop at 3, not
      // run open-ended down the column.
      expect((august[1]! as Formula).text, contains(r'$B$2:$B$3'));
    });

    test(
      'skips the breakdowns entirely when there is nothing to break down',
      () {
        final summary = harvestSheets(data()).first;
        final labels = summary.rows.map((row) => row.first).toList();

        expect(labels, isNot(contains('Currency')));
        expect(labels, isNot(contains('Category')));
        expect(labels, isNot(contains('Month')));
      },
    );
  });

  group('encoding', () {
    test('produces a workbook whose formulas survive a round trip', () {
      final bytes = buildWorkbook(
        harvestSheets(
          data(
            expenses: const [
              ['e1', '2026-09-01', 'food', 'DZD', 1250, null, null, null],
            ],
            ledger: const [
              ['l1', 'xp', 20, 'checkIn', '2026-09-01', null],
            ],
          ),
        ),
      );

      final reopened = Excel.decodeBytes(bytes);
      expect(reopened.tables.keys, contains(SheetNames.summary));
      expect(reopened.tables.keys, isNot(contains('Sheet1')));

      // The derived money column is an equation, not a baked number.
      final expenses = reopened.tables[SheetNames.expenses]!;
      final amount = expenses.rows[1][8]!.value;
      expect(amount, isA<FormulaCellValue>());
      expect((amount! as FormulaCellValue).formula, '=E2/100');

      // And the summary's `{row}` placeholders were resolved to the row
      // each formula actually sits on.
      final summary = reopened.tables[SheetNames.summary]!;
      final formulas = summary.rows
          .expand((row) => row)
          .map((cell) => cell?.value)
          .whereType<FormulaCellValue>()
          .map((cell) => cell.formula);
      expect(formulas, isNotEmpty);
      expect(formulas.every((formula) => !formula.contains('{')), isTrue);
    });

    test('an empty database still exports a readable workbook', () {
      final bytes = buildWorkbook(harvestSheets(data()));

      expect(Excel.decodeBytes(bytes).tables.keys, contains(SheetNames.seeds));
    });
  });

  group('file name', () {
    test('sorts by when it was taken', () {
      expect(
        exportFileName(DateTime(2026, 9, 4, 8, 5)),
        'harvest-2026-09-04-0805.xlsx',
      );
    });
  });
}
