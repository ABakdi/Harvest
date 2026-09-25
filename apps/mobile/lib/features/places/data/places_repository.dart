import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'places_repository.g.dart';

/// The trail, the geotags, and the places I named ([[Places]]).
///
/// Points are append-only (PL4): the only writes after the insert are a
/// whole day's soft delete and its undo.
class PlacesRepository {
  PlacesRepository(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  // --------------------------------------------------------------- trail

  /// Writes one point. Called by the recorder, which runs in the
  /// foreground service's own isolate with its own connection.
  Future<void> addPoint(Fix fix) => _db.transaction(() async {
    final uuid = _uuid.v4();
    await _db
        .into(_db.locationPoints)
        .insert(
          LocationPointsCompanion.insert(
            uuid: uuid,
            harvestDay: HarvestDay.of(fix.at).key,
            recordedAt: fix.at,
            latitude: fix.latitude,
            longitude: fix.longitude,
            accuracyM: Value(fix.accuracyM),
            speedMps: Value(fix.speedMps),
            altitudeM: Value(fix.altitudeM),
          ),
        );
    await _db.logChange('location_points', uuid, 'insert');
  });

  /// The trail across [from]..[to], inclusive, in time order.
  Stream<List<TrailPoint>> watchTrail(HarvestDay from, HarvestDay to) {
    final query = _db.select(_db.locationPoints)
      ..where(
        (p) =>
            p.harvestDay.isBetweenValues(from.key, to.key) &
            p.deletedAt.isNull(),
      )
      ..orderBy([(p) => OrderingTerm.asc(p.recordedAt)]);
    return query.watch().map((rows) => rows.map(_toPoint).toList());
  }

  /// The newest point, if it is recent enough to stand in for a fresh
  /// fix.
  Future<Fix?> lastPointSince(DateTime since) async {
    final row =
        await (_db.select(_db.locationPoints)
              ..where(
                (p) =>
                    p.recordedAt.isBiggerOrEqualValue(since) &
                    p.deletedAt.isNull(),
              )
              ..orderBy([(p) => OrderingTerm.desc(p.recordedAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toPoint(row).fix;
  }

  /// The trail point recorded closest to [at], within [within] either
  /// side: where the phone was when something happened, read back later.
  Future<Fix?> pointNear(DateTime at, Duration within) async {
    final rows =
        await (_db.select(_db.locationPoints)..where(
              (p) =>
                  p.recordedAt.isBetweenValues(
                    at.subtract(within),
                    at.add(within),
                  ) &
                  p.deletedAt.isNull(),
            ))
            .get();
    if (rows.isEmpty) return null;
    rows.sort(
      (a, b) => a.recordedAt
          .difference(at)
          .abs()
          .compareTo(b.recordedAt.difference(at).abs()),
    );
    return _toPoint(rows.first).fix;
  }

  /// How many points today holds, so a runaway sampler is visible.
  Stream<int> watchCountOn(HarvestDay day) {
    final count = _db.locationPoints.uuid.count();
    final query = _db.selectOnly(_db.locationPoints)
      ..addColumns([count])
      ..where(
        _db.locationPoints.harvestDay.equals(day.key) &
            _db.locationPoints.deletedAt.isNull(),
      );
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Deletes one day's trail, softly: [restoreDay] brings it back.
  Future<DateTime> deleteDay(HarvestDay day) async {
    final at = DateTime.now();
    await _setDayDeleted(day, at, only: null);
    return at;
  }

  Future<void> restoreDay(HarvestDay day, DateTime deletedAt) =>
      _setDayDeleted(day, null, only: deletedAt);

  Future<void> _setDayDeleted(
    HarvestDay day,
    DateTime? at, {
    required DateTime? only,
  }) => _db.transaction(() async {
    final rows =
        await (_db.select(_db.locationPoints)..where(
              (p) =>
                  p.harvestDay.equals(day.key) &
                  (only == null
                      ? p.deletedAt.isNull()
                      : p.deletedAt.equals(only)),
            ))
            .get();
    for (final row in rows) {
      await (_db.update(
        _db.locationPoints,
      )..where((p) => p.uuid.equals(row.uuid))).write(
        LocationPointsCompanion(
          deletedAt: Value(at),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _db.logChange('location_points', row.uuid, 'update');
    }
  });

  /// Every point, geotag and saved place, gone for good. Confirmed
  /// in the screen; there is no undo, and sync hears of each purge.
  Future<void> deleteAllHistory() => _db.transaction(() async {
    final points = await _db.select(_db.locationPoints).get();
    final tags = await _db.select(_db.geotags).get();
    final places = await _db.select(_db.savedPlaces).get();
    await _db.delete(_db.locationPoints).go();
    await _db.delete(_db.geotags).go();
    await _db.delete(_db.savedPlaces).go();
    for (final row in points) {
      await _db.logChange('location_points', row.uuid, 'delete');
    }
    for (final row in tags) {
      await _db.logChange('geotags', row.uuid, 'delete');
    }
    for (final row in places) {
      await _db.logChange('saved_places', row.uuid, 'delete');
    }
  });

  // ------------------------------------------------------------- geotags

  /// The day's geotags that found a place, oldest first.
  Stream<List<Geotag>> watchGeotags(HarvestDay from, HarvestDay to) {
    final query = _db.select(_db.geotags)
      ..where(
        (g) =>
            g.harvestDay.isBetweenValues(from.key, to.key) &
            g.deletedAt.isNull(),
      )
      ..orderBy([(g) => OrderingTerm.asc(g.at)]);
    return query.watch().map((rows) => rows.map(_toGeotag).toList());
  }

  /// The geotag of one action, for the "where was it" line under it.
  /// Null when the action never got one (Places off, or its geotag
  /// was deleted with the day's trail).
  Stream<Geotag?> watchGeotagFor(String table, String uuid) {
    final query = _db.select(_db.geotags)
      ..where(
        (g) =>
            g.targetTable.equals(table) &
            g.targetUuid.equals(uuid) &
            g.deletedAt.isNull(),
      )
      ..orderBy([(g) => OrderingTerm.desc(g.at)])
      ..limit(1);
    return query
        .watchSingleOrNull()
        .map((row) => row == null ? null : _toGeotag(row));
  }

  /// Geotags still waiting for a place, live: the filler's queue.
  Stream<List<Geotag>> watchPending() {
    final query = _db.select(_db.geotags)
      ..where((g) => g.state.equals('pending'))
      ..orderBy([(g) => OrderingTerm.asc(g.at)]);
    return query.watch().map((rows) => rows.map(_toGeotag).toList());
  }

  Future<List<Geotag>> pendingOnce() async {
    final rows =
        await (_db.select(_db.geotags)
              ..where((g) => g.state.equals('pending'))
              ..orderBy([(g) => OrderingTerm.asc(g.at)]))
            .get();
    return rows.map(_toGeotag).toList();
  }

  Future<void> resolve(String uuid, Fix? fix) => _db.transaction(() async {
    await (_db.update(_db.geotags)..where((g) => g.uuid.equals(uuid))).write(
      GeotagsCompanion(
        state: Value(fix == null ? 'unavailable' : 'fixed'),
        latitude: Value(fix?.latitude),
        longitude: Value(fix?.longitude),
        accuracyM: Value(fix?.accuracyM),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _db.logChange('geotags', uuid, 'update');
  });

  /// A few words about what a geotag points at, for the timeline: a
  /// note's title, a seed's name, an expense or a movement as money.
  /// Null when the row is gone or has nothing to say.
  Future<GeotagDetail?> detailFor(String table, String uuid) async {
    GeotagDetail? text(String? value) =>
        value == null || value.isEmpty ? null : GeotagText(value);
    switch (table) {
      case 'expenses':
        final row = await (_db.select(
          _db.expenses,
        )..where((e) => e.uuid.equals(uuid))).getSingleOrNull();
        if (row == null) return null;
        return GeotagExpense(
          amountMinor: row.amountMinor,
          currency: Currency.fromCode(row.currency),
          category: row.category,
          note: row.note == null || row.note!.isEmpty ? null : row.note,
        );
      case 'money_txns':
        final row = await (_db.select(
          _db.moneyTxns,
        )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
        if (row == null) return null;
        return GeotagMove(
          MoneyTxn(
            uuid: row.uuid,
            account: MoneyAccount.values.byName(row.account),
            deltaMinor: row.deltaMinor,
            currency: Currency.fromCode(row.currency),
            day:
                HarvestDay.tryParse(row.harvestDay) ??
                HarvestDay.of(row.loggedAt),
            loggedAt: row.loggedAt,
            kind: TxnKind.fromName(row.kind),
            reference: row.reference,
            note: row.note,
          ),
        );
      case 'notes':
        return text((await (_db.select(
          _db.notes,
        )..where((n) => n.uuid.equals(uuid))).getSingleOrNull())?.title);
      case 'commitments':
        return text(await _seedTitle(uuid));
      case 'check_ins':
        final row = await (_db.select(
          _db.checkIns,
        )..where((c) => c.uuid.equals(uuid))).getSingleOrNull();
        return row == null ? null : text(await _seedTitle(row.commitmentUuid));
      case 'seed_notes':
        final row = await (_db.select(
          _db.seedNotes,
        )..where((n) => n.uuid.equals(uuid))).getSingleOrNull();
        return row == null ? null : text(await _seedTitle(row.commitmentUuid));
      case 'memories':
        final row = await (_db.select(
          _db.memories,
        )..where((m) => m.uuid.equals(uuid))).getSingleOrNull();
        if (row == null) return null;
        final album = await (_db.select(
          _db.albums,
        )..where((a) => a.uuid.equals(row.albumUuid))).getSingleOrNull();
        return text(album?.name);
      case 'goals':
        return text((await (_db.select(
          _db.goals,
        )..where((g) => g.uuid.equals(uuid))).getSingleOrNull())?.title);
      case 'goal_items':
        return text((await (_db.select(
          _db.goalItems,
        )..where((i) => i.uuid.equals(uuid))).getSingleOrNull())?.body);
      case 'workout_sessions':
        return text((await (_db.select(
          _db.workoutSessions,
        )..where((w) => w.uuid.equals(uuid))).getSingleOrNull())?.title);
    }
    return null;
  }

  Future<String?> _seedTitle(String uuid) async => (await (_db.select(
    _db.commitments,
  )..where((c) => c.uuid.equals(uuid))).getSingleOrNull())?.title;

  // -------------------------------------------------------- saved places

  Stream<List<SavedPlace>> watchSavedPlaces() {
    final query = _db.select(_db.savedPlaces)
      ..where((p) => p.deletedAt.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.name)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          SavedPlace(
            uuid: row.uuid,
            name: row.name,
            latitude: row.latitude,
            longitude: row.longitude,
            radiusM: row.radiusM,
            notes: row.notes,
          ),
      ],
    );
  }

  Future<void> savePlace({
    required String name,
    required double latitude,
    required double longitude,
    double radiusM = stayRadiusM,
    String? notes,
  }) => _db.transaction(() async {
    final uuid = _uuid.v4();
    await _db
        .into(_db.savedPlaces)
        .insert(
          SavedPlacesCompanion.insert(
            uuid: uuid,
            name: name,
            latitude: latitude,
            longitude: longitude,
            radiusM: Value(radiusM),
            notes: Value(notes),
          ),
        );
    await _db.logChange('saved_places', uuid, 'insert');
  });

  Future<void> renamePlace(String uuid, String name) =>
      updatePlace(uuid, name: name, changeName: true);

  /// The only places a name, a note and a reach are edited; a
  /// coordinate is how a place is found again, and moving it is a new
  /// place. A `change` flag says which field the call is *writing* — the
  /// other stays as it is. Passing `notes: null` with `changeNotes: true`
  /// clears it. [radiusM], when given, is the new reach, held between
  /// [minPlaceRadiusM] and [maxPlaceRadiusM].
  Future<void> updatePlace(
    String uuid, {
    String? name,
    bool changeName = false,
    String? notes,
    bool changeNotes = false,
    double? radiusM,
  }) {
    if (radiusM != null &&
        !(radiusM >= minPlaceRadiusM && radiusM <= maxPlaceRadiusM)) {
      throw ArgumentError.value(radiusM, 'radiusM', 'out of range');
    }
    return _db.transaction(() async {
      await (_db.update(
        _db.savedPlaces,
      )..where((p) => p.uuid.equals(uuid))).write(
        SavedPlacesCompanion(
          name: changeName ? Value(name!) : const Value.absent(),
          notes: changeNotes ? Value(notes) : const Value.absent(),
          radiusM: radiusM == null ? const Value.absent() : Value(radiusM),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _db.logChange('saved_places', uuid, 'update');
    });
  }

  Future<void> forgetPlace(String uuid) => _db.transaction(() async {
    await (_db.update(
      _db.savedPlaces,
    )..where((p) => p.uuid.equals(uuid))).write(
      SavedPlacesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _db.logChange('saved_places', uuid, 'update');
  });

  // ------------------------------------------------------------- mapping

  static TrailPoint _toPoint(LocationPointRow row) => TrailPoint(
    uuid: row.uuid,
    day: HarvestDay.tryParse(row.harvestDay) ?? HarvestDay.of(row.recordedAt),
    fix: Fix(
      latitude: row.latitude,
      longitude: row.longitude,
      at: row.recordedAt,
      accuracyM: row.accuracyM,
      speedMps: row.speedMps,
      altitudeM: row.altitudeM,
    ),
  );

  static Geotag _toGeotag(GeotagRow row) => Geotag(
    uuid: row.uuid,
    targetTable: row.targetTable,
    targetUuid: row.targetUuid,
    day: HarvestDay.tryParse(row.harvestDay) ?? HarvestDay.of(row.at),
    at: row.at,
    state:
        GeotagState.values.where((s) => s.name == row.state).firstOrNull ??
        GeotagState.pending,
    latitude: row.latitude,
    longitude: row.longitude,
    accuracyM: row.accuracyM,
  );
}

@Riverpod(keepAlive: true)
PlacesRepository placesRepository(Ref ref) =>
    PlacesRepository(ref.watch(databaseProvider));
