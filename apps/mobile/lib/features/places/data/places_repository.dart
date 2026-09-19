import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
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
          ),
      ],
    );
  }

  Future<void> savePlace({
    required String name,
    required double latitude,
    required double longitude,
    double radiusM = stayRadiusM,
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
          ),
        );
    await _db.logChange('saved_places', uuid, 'insert');
  });

  Future<void> renamePlace(String uuid, String name) =>
      _db.transaction(() async {
        await (_db.update(
          _db.savedPlaces,
        )..where((p) => p.uuid.equals(uuid))).write(
          SavedPlacesCompanion(
            name: Value(name),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _db.logChange('saved_places', uuid, 'update');
      });

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
