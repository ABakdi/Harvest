// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CommitmentsTable extends Commitments
    with TableInfo<$CommitmentsTable, Commitment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CommitmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduleJsonMeta = const VerificationMeta(
    'scheduleJson',
  );
  @override
  late final GeneratedColumn<String> scheduleJson = GeneratedColumn<String>(
    'schedule_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalTargetMeta = const VerificationMeta(
    'totalTarget',
  );
  @override
  late final GeneratedColumn<int> totalTarget = GeneratedColumn<int>(
    'total_target',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dailyCommitmentMeta = const VerificationMeta(
    'dailyCommitment',
  );
  @override
  late final GeneratedColumn<int> dailyCommitment = GeneratedColumn<int>(
    'daily_commitment',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDayMeta = const VerificationMeta('dueDay');
  @override
  late final GeneratedColumn<String> dueDay = GeneratedColumn<String>(
    'due_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    type,
    title,
    scheduleJson,
    totalTarget,
    dailyCommitment,
    dueDay,
    archivedAt,
    deletedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'commitments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Commitment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('schedule_json')) {
      context.handle(
        _scheduleJsonMeta,
        scheduleJson.isAcceptableOrUnknown(
          data['schedule_json']!,
          _scheduleJsonMeta,
        ),
      );
    }
    if (data.containsKey('total_target')) {
      context.handle(
        _totalTargetMeta,
        totalTarget.isAcceptableOrUnknown(
          data['total_target']!,
          _totalTargetMeta,
        ),
      );
    }
    if (data.containsKey('daily_commitment')) {
      context.handle(
        _dailyCommitmentMeta,
        dailyCommitment.isAcceptableOrUnknown(
          data['daily_commitment']!,
          _dailyCommitmentMeta,
        ),
      );
    }
    if (data.containsKey('due_day')) {
      context.handle(
        _dueDayMeta,
        dueDay.isAcceptableOrUnknown(data['due_day']!, _dueDayMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  Commitment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Commitment(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      scheduleJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_json'],
      ),
      totalTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_target'],
      ),
      dailyCommitment: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_commitment'],
      ),
      dueDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_day'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CommitmentsTable createAlias(String alias) {
    return $CommitmentsTable(attachedDatabase, alias);
  }
}

class Commitment extends DataClass implements Insertable<Commitment> {
  /// Client-generated UUID; will become the server `_id` when sync arrives.
  final String uuid;

  /// `habit` | `project` | `todo`.
  final String type;
  final String title;

  /// Habit schedule rules, JSON-encoded (null for projects/todos).
  final String? scheduleJson;

  /// Projects only: total units to complete and the daily commitment.
  final int? totalTarget;
  final int? dailyCommitment;

  /// To-dos only: the Harvest Day this is planned for (yyyy-MM-dd).
  final String? dueDay;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Commitment({
    required this.uuid,
    required this.type,
    required this.title,
    this.scheduleJson,
    this.totalTarget,
    this.dailyCommitment,
    this.dueDay,
    this.archivedAt,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || scheduleJson != null) {
      map['schedule_json'] = Variable<String>(scheduleJson);
    }
    if (!nullToAbsent || totalTarget != null) {
      map['total_target'] = Variable<int>(totalTarget);
    }
    if (!nullToAbsent || dailyCommitment != null) {
      map['daily_commitment'] = Variable<int>(dailyCommitment);
    }
    if (!nullToAbsent || dueDay != null) {
      map['due_day'] = Variable<String>(dueDay);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CommitmentsCompanion toCompanion(bool nullToAbsent) {
    return CommitmentsCompanion(
      uuid: Value(uuid),
      type: Value(type),
      title: Value(title),
      scheduleJson: scheduleJson == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduleJson),
      totalTarget: totalTarget == null && nullToAbsent
          ? const Value.absent()
          : Value(totalTarget),
      dailyCommitment: dailyCommitment == null && nullToAbsent
          ? const Value.absent()
          : Value(dailyCommitment),
      dueDay: dueDay == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDay),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Commitment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Commitment(
      uuid: serializer.fromJson<String>(json['uuid']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      scheduleJson: serializer.fromJson<String?>(json['scheduleJson']),
      totalTarget: serializer.fromJson<int?>(json['totalTarget']),
      dailyCommitment: serializer.fromJson<int?>(json['dailyCommitment']),
      dueDay: serializer.fromJson<String?>(json['dueDay']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'scheduleJson': serializer.toJson<String?>(scheduleJson),
      'totalTarget': serializer.toJson<int?>(totalTarget),
      'dailyCommitment': serializer.toJson<int?>(dailyCommitment),
      'dueDay': serializer.toJson<String?>(dueDay),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Commitment copyWith({
    String? uuid,
    String? type,
    String? title,
    Value<String?> scheduleJson = const Value.absent(),
    Value<int?> totalTarget = const Value.absent(),
    Value<int?> dailyCommitment = const Value.absent(),
    Value<String?> dueDay = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Commitment(
    uuid: uuid ?? this.uuid,
    type: type ?? this.type,
    title: title ?? this.title,
    scheduleJson: scheduleJson.present ? scheduleJson.value : this.scheduleJson,
    totalTarget: totalTarget.present ? totalTarget.value : this.totalTarget,
    dailyCommitment: dailyCommitment.present
        ? dailyCommitment.value
        : this.dailyCommitment,
    dueDay: dueDay.present ? dueDay.value : this.dueDay,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Commitment copyWithCompanion(CommitmentsCompanion data) {
    return Commitment(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      scheduleJson: data.scheduleJson.present
          ? data.scheduleJson.value
          : this.scheduleJson,
      totalTarget: data.totalTarget.present
          ? data.totalTarget.value
          : this.totalTarget,
      dailyCommitment: data.dailyCommitment.present
          ? data.dailyCommitment.value
          : this.dailyCommitment,
      dueDay: data.dueDay.present ? data.dueDay.value : this.dueDay,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Commitment(')
          ..write('uuid: $uuid, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('scheduleJson: $scheduleJson, ')
          ..write('totalTarget: $totalTarget, ')
          ..write('dailyCommitment: $dailyCommitment, ')
          ..write('dueDay: $dueDay, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    type,
    title,
    scheduleJson,
    totalTarget,
    dailyCommitment,
    dueDay,
    archivedAt,
    deletedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Commitment &&
          other.uuid == this.uuid &&
          other.type == this.type &&
          other.title == this.title &&
          other.scheduleJson == this.scheduleJson &&
          other.totalTarget == this.totalTarget &&
          other.dailyCommitment == this.dailyCommitment &&
          other.dueDay == this.dueDay &&
          other.archivedAt == this.archivedAt &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CommitmentsCompanion extends UpdateCompanion<Commitment> {
  final Value<String> uuid;
  final Value<String> type;
  final Value<String> title;
  final Value<String?> scheduleJson;
  final Value<int?> totalTarget;
  final Value<int?> dailyCommitment;
  final Value<String?> dueDay;
  final Value<DateTime?> archivedAt;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CommitmentsCompanion({
    this.uuid = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.scheduleJson = const Value.absent(),
    this.totalTarget = const Value.absent(),
    this.dailyCommitment = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CommitmentsCompanion.insert({
    required String uuid,
    required String type,
    required String title,
    this.scheduleJson = const Value.absent(),
    this.totalTarget = const Value.absent(),
    this.dailyCommitment = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       type = Value(type),
       title = Value(title);
  static Insertable<Commitment> custom({
    Expression<String>? uuid,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? scheduleJson,
    Expression<int>? totalTarget,
    Expression<int>? dailyCommitment,
    Expression<String>? dueDay,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (scheduleJson != null) 'schedule_json': scheduleJson,
      if (totalTarget != null) 'total_target': totalTarget,
      if (dailyCommitment != null) 'daily_commitment': dailyCommitment,
      if (dueDay != null) 'due_day': dueDay,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CommitmentsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? type,
    Value<String>? title,
    Value<String?>? scheduleJson,
    Value<int?>? totalTarget,
    Value<int?>? dailyCommitment,
    Value<String?>? dueDay,
    Value<DateTime?>? archivedAt,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CommitmentsCompanion(
      uuid: uuid ?? this.uuid,
      type: type ?? this.type,
      title: title ?? this.title,
      scheduleJson: scheduleJson ?? this.scheduleJson,
      totalTarget: totalTarget ?? this.totalTarget,
      dailyCommitment: dailyCommitment ?? this.dailyCommitment,
      dueDay: dueDay ?? this.dueDay,
      archivedAt: archivedAt ?? this.archivedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (scheduleJson.present) {
      map['schedule_json'] = Variable<String>(scheduleJson.value);
    }
    if (totalTarget.present) {
      map['total_target'] = Variable<int>(totalTarget.value);
    }
    if (dailyCommitment.present) {
      map['daily_commitment'] = Variable<int>(dailyCommitment.value);
    }
    if (dueDay.present) {
      map['due_day'] = Variable<String>(dueDay.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommitmentsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('scheduleJson: $scheduleJson, ')
          ..write('totalTarget: $totalTarget, ')
          ..write('dailyCommitment: $dailyCommitment, ')
          ..write('dueDay: $dueDay, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CheckInsTable extends CheckIns with TableInfo<$CheckInsTable, CheckIn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CheckInsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commitmentUuidMeta = const VerificationMeta(
    'commitmentUuid',
  );
  @override
  late final GeneratedColumn<String> commitmentUuid = GeneratedColumn<String>(
    'commitment_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES commitments (uuid)',
    ),
  );
  static const VerificationMeta _harvestDayMeta = const VerificationMeta(
    'harvestDay',
  );
  @override
  late final GeneratedColumn<String> harvestDay = GeneratedColumn<String>(
    'harvest_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _loggedAtMeta = const VerificationMeta(
    'loggedAt',
  );
  @override
  late final GeneratedColumn<DateTime> loggedAt = GeneratedColumn<DateTime>(
    'logged_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    commitmentUuid,
    harvestDay,
    quantity,
    loggedAt,
    deletedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'check_ins';
  @override
  VerificationContext validateIntegrity(
    Insertable<CheckIn> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('commitment_uuid')) {
      context.handle(
        _commitmentUuidMeta,
        commitmentUuid.isAcceptableOrUnknown(
          data['commitment_uuid']!,
          _commitmentUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_commitmentUuidMeta);
    }
    if (data.containsKey('harvest_day')) {
      context.handle(
        _harvestDayMeta,
        harvestDay.isAcceptableOrUnknown(data['harvest_day']!, _harvestDayMeta),
      );
    } else if (isInserting) {
      context.missing(_harvestDayMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('logged_at')) {
      context.handle(
        _loggedAtMeta,
        loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  CheckIn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CheckIn(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      commitmentUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commitment_uuid'],
      )!,
      harvestDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harvest_day'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      loggedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logged_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CheckInsTable createAlias(String alias) {
    return $CheckInsTable(attachedDatabase, alias);
  }
}

class CheckIn extends DataClass implements Insertable<CheckIn> {
  final String uuid;
  final String commitmentUuid;

  /// The Harvest Day this counts for, computed at write time.
  final String harvestDay;

  /// Units logged: 1 for habits/todos, page/minute counts for projects.
  final int quantity;
  final DateTime loggedAt;
  final DateTime? deletedAt;
  final DateTime updatedAt;
  const CheckIn({
    required this.uuid,
    required this.commitmentUuid,
    required this.harvestDay,
    required this.quantity,
    required this.loggedAt,
    this.deletedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['commitment_uuid'] = Variable<String>(commitmentUuid);
    map['harvest_day'] = Variable<String>(harvestDay);
    map['quantity'] = Variable<int>(quantity);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CheckInsCompanion toCompanion(bool nullToAbsent) {
    return CheckInsCompanion(
      uuid: Value(uuid),
      commitmentUuid: Value(commitmentUuid),
      harvestDay: Value(harvestDay),
      quantity: Value(quantity),
      loggedAt: Value(loggedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CheckIn.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CheckIn(
      uuid: serializer.fromJson<String>(json['uuid']),
      commitmentUuid: serializer.fromJson<String>(json['commitmentUuid']),
      harvestDay: serializer.fromJson<String>(json['harvestDay']),
      quantity: serializer.fromJson<int>(json['quantity']),
      loggedAt: serializer.fromJson<DateTime>(json['loggedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'commitmentUuid': serializer.toJson<String>(commitmentUuid),
      'harvestDay': serializer.toJson<String>(harvestDay),
      'quantity': serializer.toJson<int>(quantity),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CheckIn copyWith({
    String? uuid,
    String? commitmentUuid,
    String? harvestDay,
    int? quantity,
    DateTime? loggedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => CheckIn(
    uuid: uuid ?? this.uuid,
    commitmentUuid: commitmentUuid ?? this.commitmentUuid,
    harvestDay: harvestDay ?? this.harvestDay,
    quantity: quantity ?? this.quantity,
    loggedAt: loggedAt ?? this.loggedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CheckIn copyWithCompanion(CheckInsCompanion data) {
    return CheckIn(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      commitmentUuid: data.commitmentUuid.present
          ? data.commitmentUuid.value
          : this.commitmentUuid,
      harvestDay: data.harvestDay.present
          ? data.harvestDay.value
          : this.harvestDay,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CheckIn(')
          ..write('uuid: $uuid, ')
          ..write('commitmentUuid: $commitmentUuid, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('quantity: $quantity, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    commitmentUuid,
    harvestDay,
    quantity,
    loggedAt,
    deletedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckIn &&
          other.uuid == this.uuid &&
          other.commitmentUuid == this.commitmentUuid &&
          other.harvestDay == this.harvestDay &&
          other.quantity == this.quantity &&
          other.loggedAt == this.loggedAt &&
          other.deletedAt == this.deletedAt &&
          other.updatedAt == this.updatedAt);
}

class CheckInsCompanion extends UpdateCompanion<CheckIn> {
  final Value<String> uuid;
  final Value<String> commitmentUuid;
  final Value<String> harvestDay;
  final Value<int> quantity;
  final Value<DateTime> loggedAt;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CheckInsCompanion({
    this.uuid = const Value.absent(),
    this.commitmentUuid = const Value.absent(),
    this.harvestDay = const Value.absent(),
    this.quantity = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CheckInsCompanion.insert({
    required String uuid,
    required String commitmentUuid,
    required String harvestDay,
    this.quantity = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       commitmentUuid = Value(commitmentUuid),
       harvestDay = Value(harvestDay);
  static Insertable<CheckIn> custom({
    Expression<String>? uuid,
    Expression<String>? commitmentUuid,
    Expression<String>? harvestDay,
    Expression<int>? quantity,
    Expression<DateTime>? loggedAt,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (commitmentUuid != null) 'commitment_uuid': commitmentUuid,
      if (harvestDay != null) 'harvest_day': harvestDay,
      if (quantity != null) 'quantity': quantity,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CheckInsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? commitmentUuid,
    Value<String>? harvestDay,
    Value<int>? quantity,
    Value<DateTime>? loggedAt,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CheckInsCompanion(
      uuid: uuid ?? this.uuid,
      commitmentUuid: commitmentUuid ?? this.commitmentUuid,
      harvestDay: harvestDay ?? this.harvestDay,
      quantity: quantity ?? this.quantity,
      loggedAt: loggedAt ?? this.loggedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (commitmentUuid.present) {
      map['commitment_uuid'] = Variable<String>(commitmentUuid.value);
    }
    if (harvestDay.present) {
      map['harvest_day'] = Variable<String>(harvestDay.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<DateTime>(loggedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CheckInsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('commitmentUuid: $commitmentUuid, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('quantity: $quantity, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StreaksTable extends Streaks with TableInfo<$StreaksTable, Streak> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StreaksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentMeta = const VerificationMeta(
    'current',
  );
  @override
  late final GeneratedColumn<int> current = GeneratedColumn<int>(
    'current',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bestMeta = const VerificationMeta('best');
  @override
  late final GeneratedColumn<int> best = GeneratedColumn<int>(
    'best',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastEarnedDayMeta = const VerificationMeta(
    'lastEarnedDay',
  );
  @override
  late final GeneratedColumn<String> lastEarnedDay = GeneratedColumn<String>(
    'last_earned_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _freezesStoredMeta = const VerificationMeta(
    'freezesStored',
  );
  @override
  late final GeneratedColumn<int> freezesStored = GeneratedColumn<int>(
    'freezes_stored',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scope,
    current,
    best,
    lastEarnedDay,
    freezesStored,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'streaks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Streak> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('current')) {
      context.handle(
        _currentMeta,
        current.isAcceptableOrUnknown(data['current']!, _currentMeta),
      );
    }
    if (data.containsKey('best')) {
      context.handle(
        _bestMeta,
        best.isAcceptableOrUnknown(data['best']!, _bestMeta),
      );
    }
    if (data.containsKey('last_earned_day')) {
      context.handle(
        _lastEarnedDayMeta,
        lastEarnedDay.isAcceptableOrUnknown(
          data['last_earned_day']!,
          _lastEarnedDayMeta,
        ),
      );
    }
    if (data.containsKey('freezes_stored')) {
      context.handle(
        _freezesStoredMeta,
        freezesStored.isAcceptableOrUnknown(
          data['freezes_stored']!,
          _freezesStoredMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope};
  @override
  Streak map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Streak(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      current: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current'],
      )!,
      best: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}best'],
      )!,
      lastEarnedDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_earned_day'],
      ),
      freezesStored: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}freezes_stored'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StreaksTable createAlias(String alias) {
    return $StreaksTable(attachedDatabase, alias);
  }
}

class Streak extends DataClass implements Insertable<Streak> {
  /// `global`, or a commitment uuid for individual streaks.
  final String scope;
  final int current;
  final int best;
  final String? lastEarnedDay;
  final int freezesStored;
  final DateTime updatedAt;
  const Streak({
    required this.scope,
    required this.current,
    required this.best,
    this.lastEarnedDay,
    required this.freezesStored,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['current'] = Variable<int>(current);
    map['best'] = Variable<int>(best);
    if (!nullToAbsent || lastEarnedDay != null) {
      map['last_earned_day'] = Variable<String>(lastEarnedDay);
    }
    map['freezes_stored'] = Variable<int>(freezesStored);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StreaksCompanion toCompanion(bool nullToAbsent) {
    return StreaksCompanion(
      scope: Value(scope),
      current: Value(current),
      best: Value(best),
      lastEarnedDay: lastEarnedDay == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEarnedDay),
      freezesStored: Value(freezesStored),
      updatedAt: Value(updatedAt),
    );
  }

  factory Streak.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Streak(
      scope: serializer.fromJson<String>(json['scope']),
      current: serializer.fromJson<int>(json['current']),
      best: serializer.fromJson<int>(json['best']),
      lastEarnedDay: serializer.fromJson<String?>(json['lastEarnedDay']),
      freezesStored: serializer.fromJson<int>(json['freezesStored']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'current': serializer.toJson<int>(current),
      'best': serializer.toJson<int>(best),
      'lastEarnedDay': serializer.toJson<String?>(lastEarnedDay),
      'freezesStored': serializer.toJson<int>(freezesStored),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Streak copyWith({
    String? scope,
    int? current,
    int? best,
    Value<String?> lastEarnedDay = const Value.absent(),
    int? freezesStored,
    DateTime? updatedAt,
  }) => Streak(
    scope: scope ?? this.scope,
    current: current ?? this.current,
    best: best ?? this.best,
    lastEarnedDay: lastEarnedDay.present
        ? lastEarnedDay.value
        : this.lastEarnedDay,
    freezesStored: freezesStored ?? this.freezesStored,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Streak copyWithCompanion(StreaksCompanion data) {
    return Streak(
      scope: data.scope.present ? data.scope.value : this.scope,
      current: data.current.present ? data.current.value : this.current,
      best: data.best.present ? data.best.value : this.best,
      lastEarnedDay: data.lastEarnedDay.present
          ? data.lastEarnedDay.value
          : this.lastEarnedDay,
      freezesStored: data.freezesStored.present
          ? data.freezesStored.value
          : this.freezesStored,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Streak(')
          ..write('scope: $scope, ')
          ..write('current: $current, ')
          ..write('best: $best, ')
          ..write('lastEarnedDay: $lastEarnedDay, ')
          ..write('freezesStored: $freezesStored, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scope,
    current,
    best,
    lastEarnedDay,
    freezesStored,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Streak &&
          other.scope == this.scope &&
          other.current == this.current &&
          other.best == this.best &&
          other.lastEarnedDay == this.lastEarnedDay &&
          other.freezesStored == this.freezesStored &&
          other.updatedAt == this.updatedAt);
}

class StreaksCompanion extends UpdateCompanion<Streak> {
  final Value<String> scope;
  final Value<int> current;
  final Value<int> best;
  final Value<String?> lastEarnedDay;
  final Value<int> freezesStored;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StreaksCompanion({
    this.scope = const Value.absent(),
    this.current = const Value.absent(),
    this.best = const Value.absent(),
    this.lastEarnedDay = const Value.absent(),
    this.freezesStored = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StreaksCompanion.insert({
    required String scope,
    this.current = const Value.absent(),
    this.best = const Value.absent(),
    this.lastEarnedDay = const Value.absent(),
    this.freezesStored = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scope = Value(scope);
  static Insertable<Streak> custom({
    Expression<String>? scope,
    Expression<int>? current,
    Expression<int>? best,
    Expression<String>? lastEarnedDay,
    Expression<int>? freezesStored,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (current != null) 'current': current,
      if (best != null) 'best': best,
      if (lastEarnedDay != null) 'last_earned_day': lastEarnedDay,
      if (freezesStored != null) 'freezes_stored': freezesStored,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StreaksCompanion copyWith({
    Value<String>? scope,
    Value<int>? current,
    Value<int>? best,
    Value<String?>? lastEarnedDay,
    Value<int>? freezesStored,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StreaksCompanion(
      scope: scope ?? this.scope,
      current: current ?? this.current,
      best: best ?? this.best,
      lastEarnedDay: lastEarnedDay ?? this.lastEarnedDay,
      freezesStored: freezesStored ?? this.freezesStored,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (current.present) {
      map['current'] = Variable<int>(current.value);
    }
    if (best.present) {
      map['best'] = Variable<int>(best.value);
    }
    if (lastEarnedDay.present) {
      map['last_earned_day'] = Variable<String>(lastEarnedDay.value);
    }
    if (freezesStored.present) {
      map['freezes_stored'] = Variable<int>(freezesStored.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StreaksCompanion(')
          ..write('scope: $scope, ')
          ..write('current: $current, ')
          ..write('best: $best, ')
          ..write('lastEarnedDay: $lastEarnedDay, ')
          ..write('freezesStored: $freezesStored, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LedgerTable extends Ledger with TableInfo<$LedgerTable, LedgerData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deltaMeta = const VerificationMeta('delta');
  @override
  late final GeneratedColumn<int> delta = GeneratedColumn<int>(
    'delta',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _harvestDayMeta = const VerificationMeta(
    'harvestDay',
  );
  @override
  late final GeneratedColumn<String> harvestDay = GeneratedColumn<String>(
    'harvest_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loggedAtMeta = const VerificationMeta(
    'loggedAt',
  );
  @override
  late final GeneratedColumn<DateTime> loggedAt = GeneratedColumn<DateTime>(
    'logged_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    kind,
    delta,
    reason,
    harvestDay,
    loggedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('delta')) {
      context.handle(
        _deltaMeta,
        delta.isAcceptableOrUnknown(data['delta']!, _deltaMeta),
      );
    } else if (isInserting) {
      context.missing(_deltaMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('harvest_day')) {
      context.handle(
        _harvestDayMeta,
        harvestDay.isAcceptableOrUnknown(data['harvest_day']!, _harvestDayMeta),
      );
    } else if (isInserting) {
      context.missing(_harvestDayMeta);
    }
    if (data.containsKey('logged_at')) {
      context.handle(
        _loggedAtMeta,
        loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  LedgerData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerData(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      delta: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delta'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      harvestDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harvest_day'],
      )!,
      loggedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logged_at'],
      )!,
    );
  }

  @override
  $LedgerTable createAlias(String alias) {
    return $LedgerTable(attachedDatabase, alias);
  }
}

class LedgerData extends DataClass implements Insertable<LedgerData> {
  final String uuid;

  /// `xp` | `coin`.
  final String kind;
  final int delta;
  final String reason;
  final String harvestDay;
  final DateTime loggedAt;
  const LedgerData({
    required this.uuid,
    required this.kind,
    required this.delta,
    required this.reason,
    required this.harvestDay,
    required this.loggedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['kind'] = Variable<String>(kind);
    map['delta'] = Variable<int>(delta);
    map['reason'] = Variable<String>(reason);
    map['harvest_day'] = Variable<String>(harvestDay);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    return map;
  }

  LedgerCompanion toCompanion(bool nullToAbsent) {
    return LedgerCompanion(
      uuid: Value(uuid),
      kind: Value(kind),
      delta: Value(delta),
      reason: Value(reason),
      harvestDay: Value(harvestDay),
      loggedAt: Value(loggedAt),
    );
  }

  factory LedgerData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerData(
      uuid: serializer.fromJson<String>(json['uuid']),
      kind: serializer.fromJson<String>(json['kind']),
      delta: serializer.fromJson<int>(json['delta']),
      reason: serializer.fromJson<String>(json['reason']),
      harvestDay: serializer.fromJson<String>(json['harvestDay']),
      loggedAt: serializer.fromJson<DateTime>(json['loggedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'kind': serializer.toJson<String>(kind),
      'delta': serializer.toJson<int>(delta),
      'reason': serializer.toJson<String>(reason),
      'harvestDay': serializer.toJson<String>(harvestDay),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
    };
  }

  LedgerData copyWith({
    String? uuid,
    String? kind,
    int? delta,
    String? reason,
    String? harvestDay,
    DateTime? loggedAt,
  }) => LedgerData(
    uuid: uuid ?? this.uuid,
    kind: kind ?? this.kind,
    delta: delta ?? this.delta,
    reason: reason ?? this.reason,
    harvestDay: harvestDay ?? this.harvestDay,
    loggedAt: loggedAt ?? this.loggedAt,
  );
  LedgerData copyWithCompanion(LedgerCompanion data) {
    return LedgerData(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      kind: data.kind.present ? data.kind.value : this.kind,
      delta: data.delta.present ? data.delta.value : this.delta,
      reason: data.reason.present ? data.reason.value : this.reason,
      harvestDay: data.harvestDay.present
          ? data.harvestDay.value
          : this.harvestDay,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerData(')
          ..write('uuid: $uuid, ')
          ..write('kind: $kind, ')
          ..write('delta: $delta, ')
          ..write('reason: $reason, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('loggedAt: $loggedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(uuid, kind, delta, reason, harvestDay, loggedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerData &&
          other.uuid == this.uuid &&
          other.kind == this.kind &&
          other.delta == this.delta &&
          other.reason == this.reason &&
          other.harvestDay == this.harvestDay &&
          other.loggedAt == this.loggedAt);
}

class LedgerCompanion extends UpdateCompanion<LedgerData> {
  final Value<String> uuid;
  final Value<String> kind;
  final Value<int> delta;
  final Value<String> reason;
  final Value<String> harvestDay;
  final Value<DateTime> loggedAt;
  final Value<int> rowid;
  const LedgerCompanion({
    this.uuid = const Value.absent(),
    this.kind = const Value.absent(),
    this.delta = const Value.absent(),
    this.reason = const Value.absent(),
    this.harvestDay = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerCompanion.insert({
    required String uuid,
    required String kind,
    required int delta,
    required String reason,
    required String harvestDay,
    this.loggedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       kind = Value(kind),
       delta = Value(delta),
       reason = Value(reason),
       harvestDay = Value(harvestDay);
  static Insertable<LedgerData> custom({
    Expression<String>? uuid,
    Expression<String>? kind,
    Expression<int>? delta,
    Expression<String>? reason,
    Expression<String>? harvestDay,
    Expression<DateTime>? loggedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (kind != null) 'kind': kind,
      if (delta != null) 'delta': delta,
      if (reason != null) 'reason': reason,
      if (harvestDay != null) 'harvest_day': harvestDay,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerCompanion copyWith({
    Value<String>? uuid,
    Value<String>? kind,
    Value<int>? delta,
    Value<String>? reason,
    Value<String>? harvestDay,
    Value<DateTime>? loggedAt,
    Value<int>? rowid,
  }) {
    return LedgerCompanion(
      uuid: uuid ?? this.uuid,
      kind: kind ?? this.kind,
      delta: delta ?? this.delta,
      reason: reason ?? this.reason,
      harvestDay: harvestDay ?? this.harvestDay,
      loggedAt: loggedAt ?? this.loggedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (delta.present) {
      map['delta'] = Variable<int>(delta.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (harvestDay.present) {
      map['harvest_day'] = Variable<String>(harvestDay.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<DateTime>(loggedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerCompanion(')
          ..write('uuid: $uuid, ')
          ..write('kind: $kind, ')
          ..write('delta: $delta, ')
          ..write('reason: $reason, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuestsTable extends Quests with TableInfo<$QuestsTable, Quest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _harvestDayMeta = const VerificationMeta(
    'harvestDay',
  );
  @override
  late final GeneratedColumn<String> harvestDay = GeneratedColumn<String>(
    'harvest_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<int> progress = GeneratedColumn<int>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<int> target = GeneratedColumn<int>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _claimedAtMeta = const VerificationMeta(
    'claimedAt',
  );
  @override
  late final GeneratedColumn<DateTime> claimedAt = GeneratedColumn<DateTime>(
    'claimed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    harvestDay,
    templateId,
    progress,
    target,
    claimedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quests';
  @override
  VerificationContext validateIntegrity(
    Insertable<Quest> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('harvest_day')) {
      context.handle(
        _harvestDayMeta,
        harvestDay.isAcceptableOrUnknown(data['harvest_day']!, _harvestDayMeta),
      );
    } else if (isInserting) {
      context.missing(_harvestDayMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    if (data.containsKey('claimed_at')) {
      context.handle(
        _claimedAtMeta,
        claimedAt.isAcceptableOrUnknown(data['claimed_at']!, _claimedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  Quest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Quest(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      harvestDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harvest_day'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}progress'],
      )!,
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target'],
      )!,
      claimedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}claimed_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $QuestsTable createAlias(String alias) {
    return $QuestsTable(attachedDatabase, alias);
  }
}

class Quest extends DataClass implements Insertable<Quest> {
  final String uuid;
  final String harvestDay;
  final String templateId;
  final int progress;
  final int target;
  final DateTime? claimedAt;
  final DateTime updatedAt;
  const Quest({
    required this.uuid,
    required this.harvestDay,
    required this.templateId,
    required this.progress,
    required this.target,
    this.claimedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['harvest_day'] = Variable<String>(harvestDay);
    map['template_id'] = Variable<String>(templateId);
    map['progress'] = Variable<int>(progress);
    map['target'] = Variable<int>(target);
    if (!nullToAbsent || claimedAt != null) {
      map['claimed_at'] = Variable<DateTime>(claimedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  QuestsCompanion toCompanion(bool nullToAbsent) {
    return QuestsCompanion(
      uuid: Value(uuid),
      harvestDay: Value(harvestDay),
      templateId: Value(templateId),
      progress: Value(progress),
      target: Value(target),
      claimedAt: claimedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(claimedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Quest.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Quest(
      uuid: serializer.fromJson<String>(json['uuid']),
      harvestDay: serializer.fromJson<String>(json['harvestDay']),
      templateId: serializer.fromJson<String>(json['templateId']),
      progress: serializer.fromJson<int>(json['progress']),
      target: serializer.fromJson<int>(json['target']),
      claimedAt: serializer.fromJson<DateTime?>(json['claimedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'harvestDay': serializer.toJson<String>(harvestDay),
      'templateId': serializer.toJson<String>(templateId),
      'progress': serializer.toJson<int>(progress),
      'target': serializer.toJson<int>(target),
      'claimedAt': serializer.toJson<DateTime?>(claimedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Quest copyWith({
    String? uuid,
    String? harvestDay,
    String? templateId,
    int? progress,
    int? target,
    Value<DateTime?> claimedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => Quest(
    uuid: uuid ?? this.uuid,
    harvestDay: harvestDay ?? this.harvestDay,
    templateId: templateId ?? this.templateId,
    progress: progress ?? this.progress,
    target: target ?? this.target,
    claimedAt: claimedAt.present ? claimedAt.value : this.claimedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Quest copyWithCompanion(QuestsCompanion data) {
    return Quest(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      harvestDay: data.harvestDay.present
          ? data.harvestDay.value
          : this.harvestDay,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      progress: data.progress.present ? data.progress.value : this.progress,
      target: data.target.present ? data.target.value : this.target,
      claimedAt: data.claimedAt.present ? data.claimedAt.value : this.claimedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Quest(')
          ..write('uuid: $uuid, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('templateId: $templateId, ')
          ..write('progress: $progress, ')
          ..write('target: $target, ')
          ..write('claimedAt: $claimedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    harvestDay,
    templateId,
    progress,
    target,
    claimedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Quest &&
          other.uuid == this.uuid &&
          other.harvestDay == this.harvestDay &&
          other.templateId == this.templateId &&
          other.progress == this.progress &&
          other.target == this.target &&
          other.claimedAt == this.claimedAt &&
          other.updatedAt == this.updatedAt);
}

class QuestsCompanion extends UpdateCompanion<Quest> {
  final Value<String> uuid;
  final Value<String> harvestDay;
  final Value<String> templateId;
  final Value<int> progress;
  final Value<int> target;
  final Value<DateTime?> claimedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const QuestsCompanion({
    this.uuid = const Value.absent(),
    this.harvestDay = const Value.absent(),
    this.templateId = const Value.absent(),
    this.progress = const Value.absent(),
    this.target = const Value.absent(),
    this.claimedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuestsCompanion.insert({
    required String uuid,
    required String harvestDay,
    required String templateId,
    this.progress = const Value.absent(),
    required int target,
    this.claimedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       harvestDay = Value(harvestDay),
       templateId = Value(templateId),
       target = Value(target);
  static Insertable<Quest> custom({
    Expression<String>? uuid,
    Expression<String>? harvestDay,
    Expression<String>? templateId,
    Expression<int>? progress,
    Expression<int>? target,
    Expression<DateTime>? claimedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (harvestDay != null) 'harvest_day': harvestDay,
      if (templateId != null) 'template_id': templateId,
      if (progress != null) 'progress': progress,
      if (target != null) 'target': target,
      if (claimedAt != null) 'claimed_at': claimedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuestsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? harvestDay,
    Value<String>? templateId,
    Value<int>? progress,
    Value<int>? target,
    Value<DateTime?>? claimedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return QuestsCompanion(
      uuid: uuid ?? this.uuid,
      harvestDay: harvestDay ?? this.harvestDay,
      templateId: templateId ?? this.templateId,
      progress: progress ?? this.progress,
      target: target ?? this.target,
      claimedAt: claimedAt ?? this.claimedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (harvestDay.present) {
      map['harvest_day'] = Variable<String>(harvestDay.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (progress.present) {
      map['progress'] = Variable<int>(progress.value);
    }
    if (target.present) {
      map['target'] = Variable<int>(target.value);
    }
    if (claimedAt.present) {
      map['claimed_at'] = Variable<DateTime>(claimedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuestsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('templateId: $templateId, ')
          ..write('progress: $progress, ')
          ..write('target: $target, ')
          ..write('claimedAt: $claimedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PomodoroSessionsTable extends PomodoroSessions
    with TableInfo<$PomodoroSessionsTable, PomodoroSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PomodoroSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commitmentUuidMeta = const VerificationMeta(
    'commitmentUuid',
  );
  @override
  late final GeneratedColumn<String> commitmentUuid = GeneratedColumn<String>(
    'commitment_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _focusBlocksMeta = const VerificationMeta(
    'focusBlocks',
  );
  @override
  late final GeneratedColumn<int> focusBlocks = GeneratedColumn<int>(
    'focus_blocks',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _harvestDayMeta = const VerificationMeta(
    'harvestDay',
  );
  @override
  late final GeneratedColumn<String> harvestDay = GeneratedColumn<String>(
    'harvest_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    commitmentUuid,
    focusBlocks,
    harvestDay,
    startedAt,
    endedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pomodoro_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PomodoroSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('commitment_uuid')) {
      context.handle(
        _commitmentUuidMeta,
        commitmentUuid.isAcceptableOrUnknown(
          data['commitment_uuid']!,
          _commitmentUuidMeta,
        ),
      );
    }
    if (data.containsKey('focus_blocks')) {
      context.handle(
        _focusBlocksMeta,
        focusBlocks.isAcceptableOrUnknown(
          data['focus_blocks']!,
          _focusBlocksMeta,
        ),
      );
    }
    if (data.containsKey('harvest_day')) {
      context.handle(
        _harvestDayMeta,
        harvestDay.isAcceptableOrUnknown(data['harvest_day']!, _harvestDayMeta),
      );
    } else if (isInserting) {
      context.missing(_harvestDayMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  PomodoroSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PomodoroSession(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      commitmentUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commitment_uuid'],
      ),
      focusBlocks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}focus_blocks'],
      )!,
      harvestDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harvest_day'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
    );
  }

  @override
  $PomodoroSessionsTable createAlias(String alias) {
    return $PomodoroSessionsTable(attachedDatabase, alias);
  }
}

class PomodoroSession extends DataClass implements Insertable<PomodoroSession> {
  final String uuid;
  final String? commitmentUuid;
  final int focusBlocks;
  final String harvestDay;
  final DateTime startedAt;
  final DateTime? endedAt;
  const PomodoroSession({
    required this.uuid,
    this.commitmentUuid,
    required this.focusBlocks,
    required this.harvestDay,
    required this.startedAt,
    this.endedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    if (!nullToAbsent || commitmentUuid != null) {
      map['commitment_uuid'] = Variable<String>(commitmentUuid);
    }
    map['focus_blocks'] = Variable<int>(focusBlocks);
    map['harvest_day'] = Variable<String>(harvestDay);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    return map;
  }

  PomodoroSessionsCompanion toCompanion(bool nullToAbsent) {
    return PomodoroSessionsCompanion(
      uuid: Value(uuid),
      commitmentUuid: commitmentUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(commitmentUuid),
      focusBlocks: Value(focusBlocks),
      harvestDay: Value(harvestDay),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
    );
  }

  factory PomodoroSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PomodoroSession(
      uuid: serializer.fromJson<String>(json['uuid']),
      commitmentUuid: serializer.fromJson<String?>(json['commitmentUuid']),
      focusBlocks: serializer.fromJson<int>(json['focusBlocks']),
      harvestDay: serializer.fromJson<String>(json['harvestDay']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'commitmentUuid': serializer.toJson<String?>(commitmentUuid),
      'focusBlocks': serializer.toJson<int>(focusBlocks),
      'harvestDay': serializer.toJson<String>(harvestDay),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
    };
  }

  PomodoroSession copyWith({
    String? uuid,
    Value<String?> commitmentUuid = const Value.absent(),
    int? focusBlocks,
    String? harvestDay,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
  }) => PomodoroSession(
    uuid: uuid ?? this.uuid,
    commitmentUuid: commitmentUuid.present
        ? commitmentUuid.value
        : this.commitmentUuid,
    focusBlocks: focusBlocks ?? this.focusBlocks,
    harvestDay: harvestDay ?? this.harvestDay,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
  );
  PomodoroSession copyWithCompanion(PomodoroSessionsCompanion data) {
    return PomodoroSession(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      commitmentUuid: data.commitmentUuid.present
          ? data.commitmentUuid.value
          : this.commitmentUuid,
      focusBlocks: data.focusBlocks.present
          ? data.focusBlocks.value
          : this.focusBlocks,
      harvestDay: data.harvestDay.present
          ? data.harvestDay.value
          : this.harvestDay,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PomodoroSession(')
          ..write('uuid: $uuid, ')
          ..write('commitmentUuid: $commitmentUuid, ')
          ..write('focusBlocks: $focusBlocks, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    commitmentUuid,
    focusBlocks,
    harvestDay,
    startedAt,
    endedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PomodoroSession &&
          other.uuid == this.uuid &&
          other.commitmentUuid == this.commitmentUuid &&
          other.focusBlocks == this.focusBlocks &&
          other.harvestDay == this.harvestDay &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt);
}

class PomodoroSessionsCompanion extends UpdateCompanion<PomodoroSession> {
  final Value<String> uuid;
  final Value<String?> commitmentUuid;
  final Value<int> focusBlocks;
  final Value<String> harvestDay;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> rowid;
  const PomodoroSessionsCompanion({
    this.uuid = const Value.absent(),
    this.commitmentUuid = const Value.absent(),
    this.focusBlocks = const Value.absent(),
    this.harvestDay = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PomodoroSessionsCompanion.insert({
    required String uuid,
    this.commitmentUuid = const Value.absent(),
    this.focusBlocks = const Value.absent(),
    required String harvestDay,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       harvestDay = Value(harvestDay),
       startedAt = Value(startedAt);
  static Insertable<PomodoroSession> custom({
    Expression<String>? uuid,
    Expression<String>? commitmentUuid,
    Expression<int>? focusBlocks,
    Expression<String>? harvestDay,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (commitmentUuid != null) 'commitment_uuid': commitmentUuid,
      if (focusBlocks != null) 'focus_blocks': focusBlocks,
      if (harvestDay != null) 'harvest_day': harvestDay,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PomodoroSessionsCompanion copyWith({
    Value<String>? uuid,
    Value<String?>? commitmentUuid,
    Value<int>? focusBlocks,
    Value<String>? harvestDay,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? rowid,
  }) {
    return PomodoroSessionsCompanion(
      uuid: uuid ?? this.uuid,
      commitmentUuid: commitmentUuid ?? this.commitmentUuid,
      focusBlocks: focusBlocks ?? this.focusBlocks,
      harvestDay: harvestDay ?? this.harvestDay,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (commitmentUuid.present) {
      map['commitment_uuid'] = Variable<String>(commitmentUuid.value);
    }
    if (focusBlocks.present) {
      map['focus_blocks'] = Variable<int>(focusBlocks.value);
    }
    if (harvestDay.present) {
      map['harvest_day'] = Variable<String>(harvestDay.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PomodoroSessionsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('commitmentUuid: $commitmentUuid, ')
          ..write('focusBlocks: $focusBlocks, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _targetTableMeta = const VerificationMeta(
    'targetTable',
  );
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
    'target_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowUuidMeta = const VerificationMeta(
    'rowUuid',
  );
  @override
  late final GeneratedColumn<String> rowUuid = GeneratedColumn<String>(
    'row_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    targetTable,
    rowUuid,
    op,
    queuedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('target_table')) {
      context.handle(
        _targetTableMeta,
        targetTable.isAcceptableOrUnknown(
          data['target_table']!,
          _targetTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('row_uuid')) {
      context.handle(
        _rowUuidMeta,
        rowUuid.isAcceptableOrUnknown(data['row_uuid']!, _rowUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_rowUuidMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      targetTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_table'],
      )!,
      rowUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_uuid'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}queued_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final int seq;
  final String targetTable;
  final String rowUuid;

  /// `insert` | `update` | `delete`.
  final String op;
  final DateTime queuedAt;
  const OutboxData({
    required this.seq,
    required this.targetTable,
    required this.rowUuid,
    required this.op,
    required this.queuedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['target_table'] = Variable<String>(targetTable);
    map['row_uuid'] = Variable<String>(rowUuid);
    map['op'] = Variable<String>(op);
    map['queued_at'] = Variable<DateTime>(queuedAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      seq: Value(seq),
      targetTable: Value(targetTable),
      rowUuid: Value(rowUuid),
      op: Value(op),
      queuedAt: Value(queuedAt),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      seq: serializer.fromJson<int>(json['seq']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      rowUuid: serializer.fromJson<String>(json['rowUuid']),
      op: serializer.fromJson<String>(json['op']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'targetTable': serializer.toJson<String>(targetTable),
      'rowUuid': serializer.toJson<String>(rowUuid),
      'op': serializer.toJson<String>(op),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
    };
  }

  OutboxData copyWith({
    int? seq,
    String? targetTable,
    String? rowUuid,
    String? op,
    DateTime? queuedAt,
  }) => OutboxData(
    seq: seq ?? this.seq,
    targetTable: targetTable ?? this.targetTable,
    rowUuid: rowUuid ?? this.rowUuid,
    op: op ?? this.op,
    queuedAt: queuedAt ?? this.queuedAt,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      seq: data.seq.present ? data.seq.value : this.seq,
      targetTable: data.targetTable.present
          ? data.targetTable.value
          : this.targetTable,
      rowUuid: data.rowUuid.present ? data.rowUuid.value : this.rowUuid,
      op: data.op.present ? data.op.value : this.op,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('seq: $seq, ')
          ..write('targetTable: $targetTable, ')
          ..write('rowUuid: $rowUuid, ')
          ..write('op: $op, ')
          ..write('queuedAt: $queuedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(seq, targetTable, rowUuid, op, queuedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.seq == this.seq &&
          other.targetTable == this.targetTable &&
          other.rowUuid == this.rowUuid &&
          other.op == this.op &&
          other.queuedAt == this.queuedAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<int> seq;
  final Value<String> targetTable;
  final Value<String> rowUuid;
  final Value<String> op;
  final Value<DateTime> queuedAt;
  const OutboxCompanion({
    this.seq = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.rowUuid = const Value.absent(),
    this.op = const Value.absent(),
    this.queuedAt = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String targetTable,
    required String rowUuid,
    required String op,
    this.queuedAt = const Value.absent(),
  }) : targetTable = Value(targetTable),
       rowUuid = Value(rowUuid),
       op = Value(op);
  static Insertable<OutboxData> custom({
    Expression<int>? seq,
    Expression<String>? targetTable,
    Expression<String>? rowUuid,
    Expression<String>? op,
    Expression<DateTime>? queuedAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (targetTable != null) 'target_table': targetTable,
      if (rowUuid != null) 'row_uuid': rowUuid,
      if (op != null) 'op': op,
      if (queuedAt != null) 'queued_at': queuedAt,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? targetTable,
    Value<String>? rowUuid,
    Value<String>? op,
    Value<DateTime>? queuedAt,
  }) {
    return OutboxCompanion(
      seq: seq ?? this.seq,
      targetTable: targetTable ?? this.targetTable,
      rowUuid: rowUuid ?? this.rowUuid,
      op: op ?? this.op,
      queuedAt: queuedAt ?? this.queuedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (targetTable.present) {
      map['target_table'] = Variable<String>(targetTable.value);
    }
    if (rowUuid.present) {
      map['row_uuid'] = Variable<String>(rowUuid.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('targetTable: $targetTable, ')
          ..write('rowUuid: $rowUuid, ')
          ..write('op: $op, ')
          ..write('queuedAt: $queuedAt')
          ..write(')'))
        .toString();
  }
}

class $KvSettingsTable extends KvSettings
    with TableInfo<$KvSettingsTable, KvSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KvSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [key, valueJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kv_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<KvSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KvSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KvSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $KvSettingsTable createAlias(String alias) {
    return $KvSettingsTable(attachedDatabase, alias);
  }
}

class KvSetting extends DataClass implements Insertable<KvSetting> {
  final String key;
  final String valueJson;
  final DateTime updatedAt;
  const KvSetting({
    required this.key,
    required this.valueJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  KvSettingsCompanion toCompanion(bool nullToAbsent) {
    return KvSettingsCompanion(
      key: Value(key),
      valueJson: Value(valueJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory KvSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KvSetting(
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'valueJson': serializer.toJson<String>(valueJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  KvSetting copyWith({String? key, String? valueJson, DateTime? updatedAt}) =>
      KvSetting(
        key: key ?? this.key,
        valueJson: valueJson ?? this.valueJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  KvSetting copyWithCompanion(KvSettingsCompanion data) {
    return KvSetting(
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KvSetting(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, valueJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KvSetting &&
          other.key == this.key &&
          other.valueJson == this.valueJson &&
          other.updatedAt == this.updatedAt);
}

class KvSettingsCompanion extends UpdateCompanion<KvSetting> {
  final Value<String> key;
  final Value<String> valueJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const KvSettingsCompanion({
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KvSettingsCompanion.insert({
    required String key,
    required String valueJson,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       valueJson = Value(valueJson);
  static Insertable<KvSetting> custom({
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KvSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? valueJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return KvSettingsCompanion(
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KvSettingsCompanion(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$HarvestDatabase extends GeneratedDatabase {
  _$HarvestDatabase(QueryExecutor e) : super(e);
  $HarvestDatabaseManager get managers => $HarvestDatabaseManager(this);
  late final $CommitmentsTable commitments = $CommitmentsTable(this);
  late final $CheckInsTable checkIns = $CheckInsTable(this);
  late final $StreaksTable streaks = $StreaksTable(this);
  late final $LedgerTable ledger = $LedgerTable(this);
  late final $QuestsTable quests = $QuestsTable(this);
  late final $PomodoroSessionsTable pomodoroSessions = $PomodoroSessionsTable(
    this,
  );
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $KvSettingsTable kvSettings = $KvSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    commitments,
    checkIns,
    streaks,
    ledger,
    quests,
    pomodoroSessions,
    outbox,
    kvSettings,
  ];
}

typedef $$CommitmentsTableCreateCompanionBuilder =
    CommitmentsCompanion Function({
      required String uuid,
      required String type,
      required String title,
      Value<String?> scheduleJson,
      Value<int?> totalTarget,
      Value<int?> dailyCommitment,
      Value<String?> dueDay,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CommitmentsTableUpdateCompanionBuilder =
    CommitmentsCompanion Function({
      Value<String> uuid,
      Value<String> type,
      Value<String> title,
      Value<String?> scheduleJson,
      Value<int?> totalTarget,
      Value<int?> dailyCommitment,
      Value<String?> dueDay,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$CommitmentsTableReferences
    extends BaseReferences<_$HarvestDatabase, $CommitmentsTable, Commitment> {
  $$CommitmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CheckInsTable, List<CheckIn>> _checkInsRefsTable(
    _$HarvestDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.checkIns,
    aliasName: 'commitments__uuid__check_ins__commitment_uuid',
  );

  $$CheckInsTableProcessedTableManager get checkInsRefs {
    final manager = $$CheckInsTableTableManager($_db, $_db.checkIns).filter(
      (f) => f.commitmentUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!),
    );

    final cache = $_typedResult.readTableOrNull(_checkInsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CommitmentsTableFilterComposer
    extends Composer<_$HarvestDatabase, $CommitmentsTable> {
  $$CommitmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleJson => $composableBuilder(
    column: $table.scheduleJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalTarget => $composableBuilder(
    column: $table.totalTarget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyCommitment => $composableBuilder(
    column: $table.dailyCommitment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> checkInsRefs(
    Expression<bool> Function($$CheckInsTableFilterComposer f) f,
  ) {
    final $$CheckInsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.checkIns,
      getReferencedColumn: (t) => t.commitmentUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CheckInsTableFilterComposer(
            $db: $db,
            $table: $db.checkIns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CommitmentsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $CommitmentsTable> {
  $$CommitmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleJson => $composableBuilder(
    column: $table.scheduleJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalTarget => $composableBuilder(
    column: $table.totalTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyCommitment => $composableBuilder(
    column: $table.dailyCommitment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CommitmentsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $CommitmentsTable> {
  $$CommitmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get scheduleJson => $composableBuilder(
    column: $table.scheduleJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalTarget => $composableBuilder(
    column: $table.totalTarget,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dailyCommitment => $composableBuilder(
    column: $table.dailyCommitment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dueDay =>
      $composableBuilder(column: $table.dueDay, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> checkInsRefs<T extends Object>(
    Expression<T> Function($$CheckInsTableAnnotationComposer a) f,
  ) {
    final $$CheckInsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.checkIns,
      getReferencedColumn: (t) => t.commitmentUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CheckInsTableAnnotationComposer(
            $db: $db,
            $table: $db.checkIns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CommitmentsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $CommitmentsTable,
          Commitment,
          $$CommitmentsTableFilterComposer,
          $$CommitmentsTableOrderingComposer,
          $$CommitmentsTableAnnotationComposer,
          $$CommitmentsTableCreateCompanionBuilder,
          $$CommitmentsTableUpdateCompanionBuilder,
          (Commitment, $$CommitmentsTableReferences),
          Commitment,
          PrefetchHooks Function({bool checkInsRefs})
        > {
  $$CommitmentsTableTableManager(_$HarvestDatabase db, $CommitmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CommitmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CommitmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CommitmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> scheduleJson = const Value.absent(),
                Value<int?> totalTarget = const Value.absent(),
                Value<int?> dailyCommitment = const Value.absent(),
                Value<String?> dueDay = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CommitmentsCompanion(
                uuid: uuid,
                type: type,
                title: title,
                scheduleJson: scheduleJson,
                totalTarget: totalTarget,
                dailyCommitment: dailyCommitment,
                dueDay: dueDay,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String type,
                required String title,
                Value<String?> scheduleJson = const Value.absent(),
                Value<int?> totalTarget = const Value.absent(),
                Value<int?> dailyCommitment = const Value.absent(),
                Value<String?> dueDay = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CommitmentsCompanion.insert(
                uuid: uuid,
                type: type,
                title: title,
                scheduleJson: scheduleJson,
                totalTarget: totalTarget,
                dailyCommitment: dailyCommitment,
                dueDay: dueDay,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CommitmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({checkInsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (checkInsRefs) db.checkIns],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (checkInsRefs)
                    await $_getPrefetchedData<
                      Commitment,
                      $CommitmentsTable,
                      CheckIn
                    >(
                      currentTable: table,
                      referencedTable: $$CommitmentsTableReferences
                          ._checkInsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CommitmentsTableReferences(
                            db,
                            table,
                            p0,
                          ).checkInsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.commitmentUuid == item.uuid,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CommitmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $CommitmentsTable,
      Commitment,
      $$CommitmentsTableFilterComposer,
      $$CommitmentsTableOrderingComposer,
      $$CommitmentsTableAnnotationComposer,
      $$CommitmentsTableCreateCompanionBuilder,
      $$CommitmentsTableUpdateCompanionBuilder,
      (Commitment, $$CommitmentsTableReferences),
      Commitment,
      PrefetchHooks Function({bool checkInsRefs})
    >;
typedef $$CheckInsTableCreateCompanionBuilder = CheckInsCompanion Function({
  required String uuid,
  required String commitmentUuid,
  required String harvestDay,
  Value<int> quantity,
  Value<DateTime> loggedAt,
  Value<DateTime?> deletedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$CheckInsTableUpdateCompanionBuilder = CheckInsCompanion Function({
  Value<String> uuid,
  Value<String> commitmentUuid,
  Value<String> harvestDay,
  Value<int> quantity,
  Value<DateTime> loggedAt,
  Value<DateTime?> deletedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$CheckInsTableReferences
    extends BaseReferences<_$HarvestDatabase, $CheckInsTable, CheckIn> {
  $$CheckInsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CommitmentsTable _commitmentUuidTable(_$HarvestDatabase db) => db
      .commitments
      .createAlias('check_ins__commitment_uuid__commitments__uuid');

  $$CommitmentsTableProcessedTableManager get commitmentUuid {
    final $_column = $_itemColumn<String>('commitment_uuid')!;

    final manager = $$CommitmentsTableTableManager(
      $_db,
      $_db.commitments,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_commitmentUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CheckInsTableFilterComposer
    extends Composer<_$HarvestDatabase, $CheckInsTable> {
  $$CheckInsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CommitmentsTableFilterComposer get commitmentUuid {
    final $$CommitmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.commitmentUuid,
      referencedTable: $db.commitments,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommitmentsTableFilterComposer(
            $db: $db,
            $table: $db.commitments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CheckInsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $CheckInsTable> {
  $$CheckInsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CommitmentsTableOrderingComposer get commitmentUuid {
    final $$CommitmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.commitmentUuid,
      referencedTable: $db.commitments,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommitmentsTableOrderingComposer(
            $db: $db,
            $table: $db.commitments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CheckInsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $CheckInsTable> {
  $$CheckInsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CommitmentsTableAnnotationComposer get commitmentUuid {
    final $$CommitmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.commitmentUuid,
      referencedTable: $db.commitments,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommitmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.commitments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CheckInsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $CheckInsTable,
          CheckIn,
          $$CheckInsTableFilterComposer,
          $$CheckInsTableOrderingComposer,
          $$CheckInsTableAnnotationComposer,
          $$CheckInsTableCreateCompanionBuilder,
          $$CheckInsTableUpdateCompanionBuilder,
          (CheckIn, $$CheckInsTableReferences),
          CheckIn,
          PrefetchHooks Function({bool commitmentUuid})
        > {
  $$CheckInsTableTableManager(_$HarvestDatabase db, $CheckInsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CheckInsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CheckInsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CheckInsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> commitmentUuid = const Value.absent(),
                Value<String> harvestDay = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CheckInsCompanion(
                uuid: uuid,
                commitmentUuid: commitmentUuid,
                harvestDay: harvestDay,
                quantity: quantity,
                loggedAt: loggedAt,
                deletedAt: deletedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String commitmentUuid,
                required String harvestDay,
                Value<int> quantity = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CheckInsCompanion.insert(
                uuid: uuid,
                commitmentUuid: commitmentUuid,
                harvestDay: harvestDay,
                quantity: quantity,
                loggedAt: loggedAt,
                deletedAt: deletedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CheckInsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({commitmentUuid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (commitmentUuid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.commitmentUuid,
                        referencedTable: $$CheckInsTableReferences
                            ._commitmentUuidTable(db),
                        referencedColumn: $$CheckInsTableReferences
                            ._commitmentUuidTable(db)
                            .uuid,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CheckInsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $CheckInsTable,
      CheckIn,
      $$CheckInsTableFilterComposer,
      $$CheckInsTableOrderingComposer,
      $$CheckInsTableAnnotationComposer,
      $$CheckInsTableCreateCompanionBuilder,
      $$CheckInsTableUpdateCompanionBuilder,
      (CheckIn, $$CheckInsTableReferences),
      CheckIn,
      PrefetchHooks Function({bool commitmentUuid})
    >;
typedef $$StreaksTableCreateCompanionBuilder = StreaksCompanion Function({
  required String scope,
  Value<int> current,
  Value<int> best,
  Value<String?> lastEarnedDay,
  Value<int> freezesStored,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$StreaksTableUpdateCompanionBuilder = StreaksCompanion Function({
  Value<String> scope,
  Value<int> current,
  Value<int> best,
  Value<String?> lastEarnedDay,
  Value<int> freezesStored,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$StreaksTableFilterComposer
    extends Composer<_$HarvestDatabase, $StreaksTable> {
  $$StreaksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get current => $composableBuilder(
    column: $table.current,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get best => $composableBuilder(
    column: $table.best,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastEarnedDay => $composableBuilder(
    column: $table.lastEarnedDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get freezesStored => $composableBuilder(
    column: $table.freezesStored,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StreaksTableOrderingComposer
    extends Composer<_$HarvestDatabase, $StreaksTable> {
  $$StreaksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get current => $composableBuilder(
    column: $table.current,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get best => $composableBuilder(
    column: $table.best,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastEarnedDay => $composableBuilder(
    column: $table.lastEarnedDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get freezesStored => $composableBuilder(
    column: $table.freezesStored,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StreaksTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $StreaksTable> {
  $$StreaksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<int> get current =>
      $composableBuilder(column: $table.current, builder: (column) => column);

  GeneratedColumn<int> get best =>
      $composableBuilder(column: $table.best, builder: (column) => column);

  GeneratedColumn<String> get lastEarnedDay => $composableBuilder(
    column: $table.lastEarnedDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get freezesStored => $composableBuilder(
    column: $table.freezesStored,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StreaksTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $StreaksTable,
          Streak,
          $$StreaksTableFilterComposer,
          $$StreaksTableOrderingComposer,
          $$StreaksTableAnnotationComposer,
          $$StreaksTableCreateCompanionBuilder,
          $$StreaksTableUpdateCompanionBuilder,
          (Streak, BaseReferences<_$HarvestDatabase, $StreaksTable, Streak>),
          Streak,
          PrefetchHooks Function()
        > {
  $$StreaksTableTableManager(_$HarvestDatabase db, $StreaksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StreaksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StreaksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StreaksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<int> current = const Value.absent(),
                Value<int> best = const Value.absent(),
                Value<String?> lastEarnedDay = const Value.absent(),
                Value<int> freezesStored = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StreaksCompanion(
                scope: scope,
                current: current,
                best: best,
                lastEarnedDay: lastEarnedDay,
                freezesStored: freezesStored,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                Value<int> current = const Value.absent(),
                Value<int> best = const Value.absent(),
                Value<String?> lastEarnedDay = const Value.absent(),
                Value<int> freezesStored = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StreaksCompanion.insert(
                scope: scope,
                current: current,
                best: best,
                lastEarnedDay: lastEarnedDay,
                freezesStored: freezesStored,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StreaksTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $StreaksTable,
      Streak,
      $$StreaksTableFilterComposer,
      $$StreaksTableOrderingComposer,
      $$StreaksTableAnnotationComposer,
      $$StreaksTableCreateCompanionBuilder,
      $$StreaksTableUpdateCompanionBuilder,
      (Streak, BaseReferences<_$HarvestDatabase, $StreaksTable, Streak>),
      Streak,
      PrefetchHooks Function()
    >;
typedef $$LedgerTableCreateCompanionBuilder = LedgerCompanion Function({
  required String uuid,
  required String kind,
  required int delta,
  required String reason,
  required String harvestDay,
  Value<DateTime> loggedAt,
  Value<int> rowid,
});
typedef $$LedgerTableUpdateCompanionBuilder = LedgerCompanion Function({
  Value<String> uuid,
  Value<String> kind,
  Value<int> delta,
  Value<String> reason,
  Value<String> harvestDay,
  Value<DateTime> loggedAt,
  Value<int> rowid,
});

class $$LedgerTableFilterComposer
    extends Composer<_$HarvestDatabase, $LedgerTable> {
  $$LedgerTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get delta => $composableBuilder(
    column: $table.delta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LedgerTableOrderingComposer
    extends Composer<_$HarvestDatabase, $LedgerTable> {
  $$LedgerTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get delta => $composableBuilder(
    column: $table.delta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgerTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $LedgerTable> {
  $$LedgerTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get delta =>
      $composableBuilder(column: $table.delta, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);
}

class $$LedgerTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $LedgerTable,
          LedgerData,
          $$LedgerTableFilterComposer,
          $$LedgerTableOrderingComposer,
          $$LedgerTableAnnotationComposer,
          $$LedgerTableCreateCompanionBuilder,
          $$LedgerTableUpdateCompanionBuilder,
          (
            LedgerData,
            BaseReferences<_$HarvestDatabase, $LedgerTable, LedgerData>,
          ),
          LedgerData,
          PrefetchHooks Function()
        > {
  $$LedgerTableTableManager(_$HarvestDatabase db, $LedgerTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> delta = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String> harvestDay = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerCompanion(
                uuid: uuid,
                kind: kind,
                delta: delta,
                reason: reason,
                harvestDay: harvestDay,
                loggedAt: loggedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String kind,
                required int delta,
                required String reason,
                required String harvestDay,
                Value<DateTime> loggedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerCompanion.insert(
                uuid: uuid,
                kind: kind,
                delta: delta,
                reason: reason,
                harvestDay: harvestDay,
                loggedAt: loggedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LedgerTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $LedgerTable,
      LedgerData,
      $$LedgerTableFilterComposer,
      $$LedgerTableOrderingComposer,
      $$LedgerTableAnnotationComposer,
      $$LedgerTableCreateCompanionBuilder,
      $$LedgerTableUpdateCompanionBuilder,
      (LedgerData, BaseReferences<_$HarvestDatabase, $LedgerTable, LedgerData>),
      LedgerData,
      PrefetchHooks Function()
    >;
typedef $$QuestsTableCreateCompanionBuilder = QuestsCompanion Function({
  required String uuid,
  required String harvestDay,
  required String templateId,
  Value<int> progress,
  required int target,
  Value<DateTime?> claimedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$QuestsTableUpdateCompanionBuilder = QuestsCompanion Function({
  Value<String> uuid,
  Value<String> harvestDay,
  Value<String> templateId,
  Value<int> progress,
  Value<int> target,
  Value<DateTime?> claimedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$QuestsTableFilterComposer
    extends Composer<_$HarvestDatabase, $QuestsTable> {
  $$QuestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get claimedAt => $composableBuilder(
    column: $table.claimedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuestsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $QuestsTable> {
  $$QuestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get claimedAt => $composableBuilder(
    column: $table.claimedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuestsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $QuestsTable> {
  $$QuestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<int> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<DateTime> get claimedAt =>
      $composableBuilder(column: $table.claimedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$QuestsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $QuestsTable,
          Quest,
          $$QuestsTableFilterComposer,
          $$QuestsTableOrderingComposer,
          $$QuestsTableAnnotationComposer,
          $$QuestsTableCreateCompanionBuilder,
          $$QuestsTableUpdateCompanionBuilder,
          (Quest, BaseReferences<_$HarvestDatabase, $QuestsTable, Quest>),
          Quest,
          PrefetchHooks Function()
        > {
  $$QuestsTableTableManager(_$HarvestDatabase db, $QuestsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> harvestDay = const Value.absent(),
                Value<String> templateId = const Value.absent(),
                Value<int> progress = const Value.absent(),
                Value<int> target = const Value.absent(),
                Value<DateTime?> claimedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestsCompanion(
                uuid: uuid,
                harvestDay: harvestDay,
                templateId: templateId,
                progress: progress,
                target: target,
                claimedAt: claimedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String harvestDay,
                required String templateId,
                Value<int> progress = const Value.absent(),
                required int target,
                Value<DateTime?> claimedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestsCompanion.insert(
                uuid: uuid,
                harvestDay: harvestDay,
                templateId: templateId,
                progress: progress,
                target: target,
                claimedAt: claimedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuestsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $QuestsTable,
      Quest,
      $$QuestsTableFilterComposer,
      $$QuestsTableOrderingComposer,
      $$QuestsTableAnnotationComposer,
      $$QuestsTableCreateCompanionBuilder,
      $$QuestsTableUpdateCompanionBuilder,
      (Quest, BaseReferences<_$HarvestDatabase, $QuestsTable, Quest>),
      Quest,
      PrefetchHooks Function()
    >;
typedef $$PomodoroSessionsTableCreateCompanionBuilder =
    PomodoroSessionsCompanion Function({
      required String uuid,
      Value<String?> commitmentUuid,
      Value<int> focusBlocks,
      required String harvestDay,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<int> rowid,
    });
typedef $$PomodoroSessionsTableUpdateCompanionBuilder =
    PomodoroSessionsCompanion Function({
      Value<String> uuid,
      Value<String?> commitmentUuid,
      Value<int> focusBlocks,
      Value<String> harvestDay,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int> rowid,
    });

class $$PomodoroSessionsTableFilterComposer
    extends Composer<_$HarvestDatabase, $PomodoroSessionsTable> {
  $$PomodoroSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commitmentUuid => $composableBuilder(
    column: $table.commitmentUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get focusBlocks => $composableBuilder(
    column: $table.focusBlocks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PomodoroSessionsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $PomodoroSessionsTable> {
  $$PomodoroSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commitmentUuid => $composableBuilder(
    column: $table.commitmentUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get focusBlocks => $composableBuilder(
    column: $table.focusBlocks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PomodoroSessionsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $PomodoroSessionsTable> {
  $$PomodoroSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get commitmentUuid => $composableBuilder(
    column: $table.commitmentUuid,
    builder: (column) => column,
  );

  GeneratedColumn<int> get focusBlocks => $composableBuilder(
    column: $table.focusBlocks,
    builder: (column) => column,
  );

  GeneratedColumn<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);
}

class $$PomodoroSessionsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $PomodoroSessionsTable,
          PomodoroSession,
          $$PomodoroSessionsTableFilterComposer,
          $$PomodoroSessionsTableOrderingComposer,
          $$PomodoroSessionsTableAnnotationComposer,
          $$PomodoroSessionsTableCreateCompanionBuilder,
          $$PomodoroSessionsTableUpdateCompanionBuilder,
          (
            PomodoroSession,
            BaseReferences<
              _$HarvestDatabase,
              $PomodoroSessionsTable,
              PomodoroSession
            >,
          ),
          PomodoroSession,
          PrefetchHooks Function()
        > {
  $$PomodoroSessionsTableTableManager(
    _$HarvestDatabase db,
    $PomodoroSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PomodoroSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PomodoroSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PomodoroSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String?> commitmentUuid = const Value.absent(),
                Value<int> focusBlocks = const Value.absent(),
                Value<String> harvestDay = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PomodoroSessionsCompanion(
                uuid: uuid,
                commitmentUuid: commitmentUuid,
                focusBlocks: focusBlocks,
                harvestDay: harvestDay,
                startedAt: startedAt,
                endedAt: endedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<String?> commitmentUuid = const Value.absent(),
                Value<int> focusBlocks = const Value.absent(),
                required String harvestDay,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PomodoroSessionsCompanion.insert(
                uuid: uuid,
                commitmentUuid: commitmentUuid,
                focusBlocks: focusBlocks,
                harvestDay: harvestDay,
                startedAt: startedAt,
                endedAt: endedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PomodoroSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $PomodoroSessionsTable,
      PomodoroSession,
      $$PomodoroSessionsTableFilterComposer,
      $$PomodoroSessionsTableOrderingComposer,
      $$PomodoroSessionsTableAnnotationComposer,
      $$PomodoroSessionsTableCreateCompanionBuilder,
      $$PomodoroSessionsTableUpdateCompanionBuilder,
      (
        PomodoroSession,
        BaseReferences<
          _$HarvestDatabase,
          $PomodoroSessionsTable,
          PomodoroSession
        >,
      ),
      PomodoroSession,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  required String targetTable,
  required String rowUuid,
  required String op,
  Value<DateTime> queuedAt,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  Value<String> targetTable,
  Value<String> rowUuid,
  Value<String> op,
  Value<DateTime> queuedAt,
});

class $$OutboxTableFilterComposer
    extends Composer<_$HarvestDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowUuid => $composableBuilder(
    column: $table.rowUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$HarvestDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowUuid => $composableBuilder(
    column: $table.rowUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rowUuid =>
      $composableBuilder(column: $table.rowUuid, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (
            OutboxData,
            BaseReferences<_$HarvestDatabase, $OutboxTable, OutboxData>,
          ),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$HarvestDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> targetTable = const Value.absent(),
                Value<String> rowUuid = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
              }) => OutboxCompanion(
                seq: seq,
                targetTable: targetTable,
                rowUuid: rowUuid,
                op: op,
                queuedAt: queuedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String targetTable,
                required String rowUuid,
                required String op,
                Value<DateTime> queuedAt = const Value.absent(),
              }) => OutboxCompanion.insert(
                seq: seq,
                targetTable: targetTable,
                rowUuid: rowUuid,
                op: op,
                queuedAt: queuedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$HarvestDatabase, $OutboxTable, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $$KvSettingsTableCreateCompanionBuilder = KvSettingsCompanion Function({
  required String key,
  required String valueJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$KvSettingsTableUpdateCompanionBuilder = KvSettingsCompanion Function({
  Value<String> key,
  Value<String> valueJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$KvSettingsTableFilterComposer
    extends Composer<_$HarvestDatabase, $KvSettingsTable> {
  $$KvSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KvSettingsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $KvSettingsTable> {
  $$KvSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KvSettingsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $KvSettingsTable> {
  $$KvSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$KvSettingsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $KvSettingsTable,
          KvSetting,
          $$KvSettingsTableFilterComposer,
          $$KvSettingsTableOrderingComposer,
          $$KvSettingsTableAnnotationComposer,
          $$KvSettingsTableCreateCompanionBuilder,
          $$KvSettingsTableUpdateCompanionBuilder,
          (
            KvSetting,
            BaseReferences<_$HarvestDatabase, $KvSettingsTable, KvSetting>,
          ),
          KvSetting,
          PrefetchHooks Function()
        > {
  $$KvSettingsTableTableManager(_$HarvestDatabase db, $KvSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KvSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KvSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KvSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KvSettingsCompanion(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String valueJson,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KvSettingsCompanion.insert(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KvSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $KvSettingsTable,
      KvSetting,
      $$KvSettingsTableFilterComposer,
      $$KvSettingsTableOrderingComposer,
      $$KvSettingsTableAnnotationComposer,
      $$KvSettingsTableCreateCompanionBuilder,
      $$KvSettingsTableUpdateCompanionBuilder,
      (
        KvSetting,
        BaseReferences<_$HarvestDatabase, $KvSettingsTable, KvSetting>,
      ),
      KvSetting,
      PrefetchHooks Function()
    >;

class $HarvestDatabaseManager {
  final _$HarvestDatabase _db;
  $HarvestDatabaseManager(this._db);
  $$CommitmentsTableTableManager get commitments =>
      $$CommitmentsTableTableManager(_db, _db.commitments);
  $$CheckInsTableTableManager get checkIns =>
      $$CheckInsTableTableManager(_db, _db.checkIns);
  $$StreaksTableTableManager get streaks =>
      $$StreaksTableTableManager(_db, _db.streaks);
  $$LedgerTableTableManager get ledger =>
      $$LedgerTableTableManager(_db, _db.ledger);
  $$QuestsTableTableManager get quests =>
      $$QuestsTableTableManager(_db, _db.quests);
  $$PomodoroSessionsTableTableManager get pomodoroSessions =>
      $$PomodoroSessionsTableTableManager(_db, _db.pomodoroSessions);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$KvSettingsTableTableManager get kvSettings =>
      $$KvSettingsTableTableManager(_db, _db.kvSettings);
}
