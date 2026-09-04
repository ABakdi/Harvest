import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/export/data/downloads_gateway.dart';
import 'package:harvest/features/export/data/export_repository.dart';
import 'package:harvest/features/export/domain/export_service.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';

import '../../support/fake_downloads.dart';

/// The export end to end: real database, real workbook, faked folder.
void main() {
  late HarvestDatabase db;
  late FakeDownloadsGateway downloads;
  late ProviderContainer container;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    downloads = FakeDownloadsGateway();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        downloadsGatewayProvider.overrideWithValue(downloads),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> seedRows() async {
    await db
        .into(db.commitments)
        .insert(
          CommitmentsCompanion.insert(uuid: 'c1', type: 'habit', title: 'Read'),
        );
    await db
        .into(db.checkIns)
        .insert(
          CheckInsCompanion.insert(
            uuid: 'k1',
            commitmentUuid: 'c1',
            harvestDay: '2026-09-01',
          ),
        );
    await db
        .into(db.expenses)
        .insert(
          ExpensesCompanion.insert(
            uuid: 'e1',
            amountMinor: 1250,
            category: 'food',
            harvestDay: '2026-09-01',
          ),
        );
    // A soft-deleted row: it must still reach the file (rule X7).
    await db
        .into(db.expenses)
        .insert(
          ExpensesCompanion.insert(
            uuid: 'e2',
            amountMinor: 900,
            category: 'food',
            harvestDay: '2026-09-01',
            deletedAt: Value(DateTime(2026, 9, 2)),
          ),
        );
  }

  test('reads every table, deleted rows included (rule X7)', () async {
    await seedRows();

    final data = await container.read(exportRepositoryProvider).read();

    expect(data.seeds, hasLength(1));
    expect(data.checkIns, hasLength(1));
    expect(data.expenses, hasLength(2));
    expect(data.expenses.last.last, isNotNull); // the deletedAt stamp
  });

  test('saves a named workbook that opens with every sheet', () async {
    await seedRows();

    final path = await container
        .read(exportServiceProvider)
        .exportWorkbook(now: DateTime(2026, 9, 4, 18, 30));

    expect(path, 'Download/harvest-2026-09-04-1830.xlsx');
    expect(downloads.fileName, 'harvest-2026-09-04-1830.xlsx');
    expect(downloads.mimeType, xlsxMimeType);

    final workbook = Excel.decodeBytes(downloads.bytes!);
    expect(
      workbook.tables.keys,
      containsAll(const [
        SheetNames.summary,
        SheetNames.seeds,
        SheetNames.expenses,
      ]),
    );
    // Header row plus the two expenses, deleted one and all.
    expect(workbook.tables[SheetNames.expenses]!.rows, hasLength(3));
  });

  test('an empty database still exports', () async {
    final path = await container
        .read(exportServiceProvider)
        .exportWorkbook(now: DateTime(2026, 9, 4, 9));

    expect(path, endsWith('.xlsx'));
    expect(downloads.bytes, isNotNull);
  });

  test('a refusal is reported, not swallowed', () async {
    downloads.failWith = 'permission';

    await container.read(exportControllerProvider.notifier).run();

    final status = container.read(exportControllerProvider);
    expect(status, isA<ExportFailed>());
    expect((status as ExportFailed).reason, 'permission');
  });

  test('a finished export reports where the file went', () async {
    await container.read(exportControllerProvider.notifier).run();

    final status = container.read(exportControllerProvider);
    expect(status, isA<ExportSaved>());
    expect((status as ExportSaved).path, startsWith('Download/harvest-'));
  });
}
