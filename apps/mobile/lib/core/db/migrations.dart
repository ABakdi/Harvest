part of 'database.dart';

/// The steps that bring an older file up to [HarvestDatabase.schemaVersion],
/// kept apart from the tables they change ([[Local-Database]]).
extension _Migrations on HarvestDatabase {
  Future<void> _upgrade(Migrator m, int from) async {
    // A table created in this run already carries the newest
    // columns; later addColumn steps must skip it.
    final expensesJustCreated = from < 2;
    final moneyTxnsJustCreated = from < 6;
    final memoriesJustCreated = from < 10;
    final sessionsJustCreated = from < 12;
    if (from < 2) {
      await m.createTable(expenses);
    }
    if (from < 3) {
      await m.addColumn(commitments, commitments.pausedAt);
    }
    if (from < 4) {
      await m.addColumn(commitments, commitments.note);
      await m.addColumn(commitments, commitments.remindAt);
      await m.addColumn(commitments, commitments.deadline);
      await m.createTable(expenseCategories);
    }
    if (from < 5 && !expensesJustCreated) {
      await m.addColumn(expenses, expenses.currency);
    }
    if (from < 6) {
      await m.createTable(moneyTxns);
      await m.createTable(debts);
      await m.createTable(debtPayments);
    }
    if (from < 7 && !moneyTxnsJustCreated) {
      await m.addColumn(moneyTxns, moneyTxns.kind);
      await m.addColumn(moneyTxns, moneyTxns.reference);
    }
    if (from < 8 && !moneyTxnsJustCreated) {
      await m.addColumn(moneyTxns, moneyTxns.linkUuid);
    }
    if (from < 9) {
      await m.addColumn(commitments, commitments.archiveNote);
      await m.createTable(seedNotes);
    }
    if (from < 10) {
      await m.createTable(notes);
      await m.createTable(noteLinks);
      await m.createTable(albums);
      await m.createTable(memories);
    }
    if (from < 11 && !memoriesJustCreated) {
      await m.addColumn(memories, memories.deletedAt);
    }
    // Phase 4 lands as one migration rather than five: the tables
    // are inert until the feature is switched on, and one upgrade is
    // kinder to a phone than five.
    if (from < 12) {
      await m.createTable(stepDays);
      await m.createTable(bodyWeights);
      await m.createTable(exercises);
      await m.createTable(programs);
      await m.createTable(programDays);
      await m.createTable(programSlots);
      await m.createTable(targetSets);
      await m.createTable(trainingMaxes);
      await m.createTable(workoutSessions);
      await m.createTable(sessionExercises);
      await m.createTable(workoutSets);
    }
    if (from < 13) {
      await m.createTable(sleepSessions);
    }
    if (from < 14 && !sessionsJustCreated) {
      await m.addColumn(workoutSessions, workoutSessions.pausedAt);
      await m.addColumn(workoutSessions, workoutSessions.pausedSeconds);
    }
    // Phase 5 in one step, as phase 4 was: goals, places and voice.
    if (from < 15) {
      await m.addColumn(commitments, commitments.goalUuid);
      await m.createTable(goals);
      await m.createTable(goalItems);
      await m.createTable(locationPoints);
      await m.createTable(geotags);
      await m.createTable(savedPlaces);
      await m.createTable(noteAttachments);
      await m.createIndex(locationPointsDay);
      await m.createIndex(geotagsTarget);
      await m.createIndex(geotagsDay);
    }
    if (from < 16 && !sessionsJustCreated) {
      await m.addColumn(sessionExercises, sessionExercises.skipReason);
    }
    // The files themselves start unsynced, so every hash starts null
    // and is filled in by the first sync that carries the file.
    if (from < 17) {
      if (!memoriesJustCreated) await m.addColumn(memories, memories.fileHash);
      if (from >= 15) {
        await m.addColumn(noteAttachments, noteAttachments.fileHash);
      }
    }
    // Saved places take a note: what I want to remember about a spot
    // ([[Places]]). Existing rows keep a null note, which the editors
    // treat as empty. A box created earlier in this same run (from
    // < 15) is built with the current definition and already carries
    // the column. From 15 to 17 the column must exist *before* the
    // date rewrite below, because that rewrite rebuilds the table
    // from the current definition and would otherwise read a column
    // that is not there yet.
    if (from >= 15 && from < 20) {
      await m.addColumn(savedPlaces, savedPlaces.notes);
    }
    // Categories remember when they were made, so a restored one keeps
    // its place in the list ([[Finances]]). The last edit is the best
    // guess an existing row has, and it keeps today's order. Same
    // ordering rule as above: before the rewrite, which then converts
    // the copied value along with the one it came from.
    if (from >= 4 && from < 21) {
      await m.addColumn(expenseCategories, expenseCategories.createdAt);
      await customStatement(
        'UPDATE expense_categories SET created_at = updated_at',
      );
    }
    // Subtasks ([[Goals]] GL8, M6.13): an item may belong to another
    // item. Every existing item stays top-level, so the column starts
    // null and nothing is rewritten. Same ordering rule as above: a
    // box created in this run (from < 15) already has it, and from 15
    // it is added before the v18 and v22 rebuilds, which copy the
    // table into its current definition.
    if (from >= 15 && from < 24) {
      await m.addColumn(goalItems, goalItems.parentUuid);
    }
    // Every date becomes text, keeping the instant it already held.
    // A table created earlier in this same run is empty and converts
    // to nothing, which costs a statement and no data.
    if (from < 18) {
      await customStatement('PRAGMA foreign_keys = OFF');
      for (final table in allTables) {
        // Tables created later in this run (v19+) do not exist yet;
        // theirs are already text.
        if (table.actualTableName == wishlistItems.actualTableName ||
            table.actualTableName == lists.actualTableName) {
          continue;
        }
        await _datesToText(m, table);
      }
      await customStatement('PRAGMA foreign_keys = ON');
    }
    // The wishlist: one new table ([[Wishlist]]), inert until the tab
    // is built on it, so exactly one step.
    if (from < 19) {
      await m.createTable(wishlistItems);
    }
    // A stamp now comes from the phone's clock, not sqlite's: the SQL
    // default wrote UTC with no zone, which read back as a UTC clock
    // and put every default-stamped time an hour early in Algiers.
    // Dropping a column default means rebuilding the table; then
    // every date that is not already in the app's own spelling is
    // rewritten, keeping its instant.
    // Lists' item columns ([[Lists]]). A wishlist created earlier in
    // this run (from < 19) already has them; from 19 they are added
    // before the v22 rebuild below, which copies each table into its
    // current definition and would otherwise read columns that are not
    // there yet.
    if (from >= 19 && from < 23) {
      await m.addColumn(wishlistItems, wishlistItems.listUuid);
      await m.addColumn(wishlistItems, wishlistItems.mediaType);
      await m.addColumn(wishlistItems, wishlistItems.link);
      await m.addColumn(wishlistItems, wishlistItems.creator);
      await m.addColumn(wishlistItems, wishlistItems.startedAt);
      await m.addColumn(wishlistItems, wishlistItems.rating);
      await m.addColumn(wishlistItems, wishlistItems.seedUuid);
      await m.addColumn(wishlistItems, wishlistItems.noteUuid);
    }
    if (from < 22) {
      await customStatement('PRAGMA foreign_keys = OFF');
      for (final table in allTables) {
        // `lists` arrives in v23, below, already in today's spelling.
        if (table.actualTableName == lists.actualTableName) continue;
        final stamped = table.$columns.any(
          (c) => c.type == DriftSqlType.dateTime && c.clientDefault != null,
        );
        if (stamped) {
          await m.alterTable(TableMigration(table));
        }
        await _datesToLocal(table);
      }
      await customStatement('PRAGMA foreign_keys = ON');
    }
    // Lists ([[Lists]], M6.12): the Wishlist's two lists become two
    // of four built-in ones, under ids every device agrees on, and
    // each item is told which list it is in. Someone who had items
    // keeps seeing them: the feature starts on for them, and off, as
    // every feature does, for everyone else.
    if (from < 23) {
      await m.createTable(lists);
      await seedBuiltInLists();
      await customStatement(
        'UPDATE wishlist_items SET list_uuid = '
        "CASE list WHEN 'buy' THEN ? ELSE ? END WHERE list_uuid IS NULL",
        [BuiltInList.buy.uuid, BuiltInList.wish.uuid],
      );
      final items = await customSelect(
        'SELECT COUNT(*) AS n FROM wishlist_items WHERE deleted_at IS NULL',
      ).getSingle();
      if (items.read<int>('n') > 0) {
        // `FeatureKeys.lists`, and a preference like any other, so it
        // is queued for the other devices too.
        await into(kvSettings).insert(
          KvSettingsCompanion.insert(
            key: 'features.lists',
            valueJson: '"true"',
          ),
          mode: InsertMode.insertOrIgnore,
        );
        await into(outbox).insert(
          OutboxCompanion.insert(
            targetTable: 'kv_settings',
            rowUuid: 'features.lists',
            op: 'update',
          ),
        );
      }
    }
    // Indexes on the filters that run on every change: today's and
    // the week's check-ins, a seed's history, an undo's ledger rows, a
    // pull's outbox lookups, a session's sets, a day's money, a debt's
    // payments, a note's links, a seed-day's note, the trail's edges
    // ([[Audit-v3]] P6-11). Last, after every rebuild above, and no
    // data is touched.
    if (from < 25) {
      for (final index in [
        checkInsDay,
        checkInsSeed,
        seedNotesSeedDay,
        noteLinksFrom,
        noteLinksTo,
        memoriesAlbumDay,
        sessionExercisesSession,
        workoutSetsExercise,
        ledgerReason,
        ledgerDay,
        expensesDay,
        moneyTxnsDay,
        debtPaymentsDebt,
        outboxRow,
        goalItemsGoal,
        locationPointsDayTime,
      ]) {
        // A table rebuilt above (v22 copies every table into its
        // current definition) already has its indexes.
        final there = await customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = ?",
          variables: [Variable.withString(index.entityName)],
        ).get();
        if (there.isEmpty) await m.createIndex(index);
      }
    }
  }

  /// Rewrites one table's UTC dates in the spelling the app writes: the
  /// local clock with its offset, `2026-09-25T16:21:00.000 +01:00`.
  ///
  /// Two spellings are UTC. sqlite's own clock — the old column
  /// default, and the v18 rewrite — writes `2026-09-25 15:21:00`; a
  /// pulled row wrote a `Z`. Both read back as a UTC `DateTime`, whose
  /// clock is the wrong one to show. A date that already carries an
  /// offset was written by the app and is left as it is.
  Future<void> _datesToLocal(TableInfo<Table, Object?> table) async {
    final name = table.actualTableName;
    for (final column in table.$columns) {
      if (column.type != DriftSqlType.dateTime) continue;
      final col = '"${column.name}"';
      final rows = await customSelect(
        'SELECT rowid AS r, $col AS v FROM "$name" '
        "WHERE typeof($col) = 'text' AND ($col GLOB '*Z' OR $col GLOB "
        "'[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] "
        "[0-9][0-9]:[0-9][0-9]:[0-9][0-9]')",
      ).get();
      if (rows.isEmpty) continue;
      await batch((b) {
        for (final row in rows) {
          b.customStatement('UPDATE "$name" SET $col = ? WHERE rowid = ?', [
            typeMapping.mapToSqlVariable(
              readUtcText(row.read<String>('v')).toLocal(),
            ),
            row.read<int>('r'),
          ]);
        }
      });
    }
  }

  /// Rewrites one table's date columns from unix seconds to text.
  ///
  /// `datetime(col, 'unixepoch')` is sqlite's own conversion, so the
  /// instant is the one that was stored; only its spelling changes.
  static Future<void> _datesToText(
    Migrator m,
    TableInfo<Table, Object?> table,
  ) async {
    final transformer = <GeneratedColumn<Object>, Expression<Object>>{};
    for (final column in table.$columns) {
      if (column.type == DriftSqlType.dateTime) {
        transformer[column] = DateTimeExpressions.fromUnixEpoch(
          column.dartCast<int>(),
        );
      }
    }
    if (transformer.isEmpty) return;
    await m.alterTable(
      TableMigration(table, columnTransformer: transformer),
    );
  }
}
