// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CommitmentsTable extends Commitments
    with TableInfo<$CommitmentsTable, CommitmentRow> {
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
  static const VerificationMeta _pausedAtMeta = const VerificationMeta(
    'pausedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pausedAt = GeneratedColumn<DateTime>(
    'paused_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindAtMeta = const VerificationMeta(
    'remindAt',
  );
  @override
  late final GeneratedColumn<String> remindAt = GeneratedColumn<String>(
    'remind_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deadlineMeta = const VerificationMeta(
    'deadline',
  );
  @override
  late final GeneratedColumn<String> deadline = GeneratedColumn<String>(
    'deadline',
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
  static const VerificationMeta _archiveNoteMeta = const VerificationMeta(
    'archiveNote',
  );
  @override
  late final GeneratedColumn<String> archiveNote = GeneratedColumn<String>(
    'archive_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    pausedAt,
    note,
    remindAt,
    deadline,
    archivedAt,
    archiveNote,
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
    Insertable<CommitmentRow> instance, {
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
    if (data.containsKey('paused_at')) {
      context.handle(
        _pausedAtMeta,
        pausedAt.isAcceptableOrUnknown(data['paused_at']!, _pausedAtMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('remind_at')) {
      context.handle(
        _remindAtMeta,
        remindAt.isAcceptableOrUnknown(data['remind_at']!, _remindAtMeta),
      );
    }
    if (data.containsKey('deadline')) {
      context.handle(
        _deadlineMeta,
        deadline.isAcceptableOrUnknown(data['deadline']!, _deadlineMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('archive_note')) {
      context.handle(
        _archiveNoteMeta,
        archiveNote.isAcceptableOrUnknown(
          data['archive_note']!,
          _archiveNoteMeta,
        ),
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
  CommitmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CommitmentRow(
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
      pausedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paused_at'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      remindAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remind_at'],
      ),
      deadline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deadline'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      archiveNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archive_note'],
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

class CommitmentRow extends DataClass implements Insertable<CommitmentRow> {
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

  /// Habits only: vacation mode — paused habits are neither due nor
  /// judged, and their streak survives the break.
  final DateTime? pausedAt;

  /// Free-form note shown with the seed.
  final String? note;

  /// Per-seed reminder time ("HH:mm"), fired on days the seed is due.
  final String? remindAt;

  /// Accomplish-before day (yyyy-MM-dd); overdue seeds turn urgent.
  final String? deadline;
  final DateTime? archivedAt;

  /// Why this seed was put away — written when it is archived, and the
  /// only thing the archive can tell me later that the title cannot.
  final String? archiveNote;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CommitmentRow({
    required this.uuid,
    required this.type,
    required this.title,
    this.scheduleJson,
    this.totalTarget,
    this.dailyCommitment,
    this.dueDay,
    this.pausedAt,
    this.note,
    this.remindAt,
    this.deadline,
    this.archivedAt,
    this.archiveNote,
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
    if (!nullToAbsent || pausedAt != null) {
      map['paused_at'] = Variable<DateTime>(pausedAt);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || remindAt != null) {
      map['remind_at'] = Variable<String>(remindAt);
    }
    if (!nullToAbsent || deadline != null) {
      map['deadline'] = Variable<String>(deadline);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || archiveNote != null) {
      map['archive_note'] = Variable<String>(archiveNote);
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
      pausedAt: pausedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      remindAt: remindAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remindAt),
      deadline: deadline == null && nullToAbsent
          ? const Value.absent()
          : Value(deadline),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      archiveNote: archiveNote == null && nullToAbsent
          ? const Value.absent()
          : Value(archiveNote),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CommitmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CommitmentRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      scheduleJson: serializer.fromJson<String?>(json['scheduleJson']),
      totalTarget: serializer.fromJson<int?>(json['totalTarget']),
      dailyCommitment: serializer.fromJson<int?>(json['dailyCommitment']),
      dueDay: serializer.fromJson<String?>(json['dueDay']),
      pausedAt: serializer.fromJson<DateTime?>(json['pausedAt']),
      note: serializer.fromJson<String?>(json['note']),
      remindAt: serializer.fromJson<String?>(json['remindAt']),
      deadline: serializer.fromJson<String?>(json['deadline']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      archiveNote: serializer.fromJson<String?>(json['archiveNote']),
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
      'pausedAt': serializer.toJson<DateTime?>(pausedAt),
      'note': serializer.toJson<String?>(note),
      'remindAt': serializer.toJson<String?>(remindAt),
      'deadline': serializer.toJson<String?>(deadline),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'archiveNote': serializer.toJson<String?>(archiveNote),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CommitmentRow copyWith({
    String? uuid,
    String? type,
    String? title,
    Value<String?> scheduleJson = const Value.absent(),
    Value<int?> totalTarget = const Value.absent(),
    Value<int?> dailyCommitment = const Value.absent(),
    Value<String?> dueDay = const Value.absent(),
    Value<DateTime?> pausedAt = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> remindAt = const Value.absent(),
    Value<String?> deadline = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<String?> archiveNote = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CommitmentRow(
    uuid: uuid ?? this.uuid,
    type: type ?? this.type,
    title: title ?? this.title,
    scheduleJson: scheduleJson.present ? scheduleJson.value : this.scheduleJson,
    totalTarget: totalTarget.present ? totalTarget.value : this.totalTarget,
    dailyCommitment: dailyCommitment.present
        ? dailyCommitment.value
        : this.dailyCommitment,
    dueDay: dueDay.present ? dueDay.value : this.dueDay,
    pausedAt: pausedAt.present ? pausedAt.value : this.pausedAt,
    note: note.present ? note.value : this.note,
    remindAt: remindAt.present ? remindAt.value : this.remindAt,
    deadline: deadline.present ? deadline.value : this.deadline,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    archiveNote: archiveNote.present ? archiveNote.value : this.archiveNote,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CommitmentRow copyWithCompanion(CommitmentsCompanion data) {
    return CommitmentRow(
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
      pausedAt: data.pausedAt.present ? data.pausedAt.value : this.pausedAt,
      note: data.note.present ? data.note.value : this.note,
      remindAt: data.remindAt.present ? data.remindAt.value : this.remindAt,
      deadline: data.deadline.present ? data.deadline.value : this.deadline,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      archiveNote: data.archiveNote.present
          ? data.archiveNote.value
          : this.archiveNote,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CommitmentRow(')
          ..write('uuid: $uuid, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('scheduleJson: $scheduleJson, ')
          ..write('totalTarget: $totalTarget, ')
          ..write('dailyCommitment: $dailyCommitment, ')
          ..write('dueDay: $dueDay, ')
          ..write('pausedAt: $pausedAt, ')
          ..write('note: $note, ')
          ..write('remindAt: $remindAt, ')
          ..write('deadline: $deadline, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('archiveNote: $archiveNote, ')
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
    pausedAt,
    note,
    remindAt,
    deadline,
    archivedAt,
    archiveNote,
    deletedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CommitmentRow &&
          other.uuid == this.uuid &&
          other.type == this.type &&
          other.title == this.title &&
          other.scheduleJson == this.scheduleJson &&
          other.totalTarget == this.totalTarget &&
          other.dailyCommitment == this.dailyCommitment &&
          other.dueDay == this.dueDay &&
          other.pausedAt == this.pausedAt &&
          other.note == this.note &&
          other.remindAt == this.remindAt &&
          other.deadline == this.deadline &&
          other.archivedAt == this.archivedAt &&
          other.archiveNote == this.archiveNote &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CommitmentsCompanion extends UpdateCompanion<CommitmentRow> {
  final Value<String> uuid;
  final Value<String> type;
  final Value<String> title;
  final Value<String?> scheduleJson;
  final Value<int?> totalTarget;
  final Value<int?> dailyCommitment;
  final Value<String?> dueDay;
  final Value<DateTime?> pausedAt;
  final Value<String?> note;
  final Value<String?> remindAt;
  final Value<String?> deadline;
  final Value<DateTime?> archivedAt;
  final Value<String?> archiveNote;
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
    this.pausedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.remindAt = const Value.absent(),
    this.deadline = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.archiveNote = const Value.absent(),
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
    this.pausedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.remindAt = const Value.absent(),
    this.deadline = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.archiveNote = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       type = Value(type),
       title = Value(title);
  static Insertable<CommitmentRow> custom({
    Expression<String>? uuid,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? scheduleJson,
    Expression<int>? totalTarget,
    Expression<int>? dailyCommitment,
    Expression<String>? dueDay,
    Expression<DateTime>? pausedAt,
    Expression<String>? note,
    Expression<String>? remindAt,
    Expression<String>? deadline,
    Expression<DateTime>? archivedAt,
    Expression<String>? archiveNote,
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
      if (pausedAt != null) 'paused_at': pausedAt,
      if (note != null) 'note': note,
      if (remindAt != null) 'remind_at': remindAt,
      if (deadline != null) 'deadline': deadline,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (archiveNote != null) 'archive_note': archiveNote,
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
    Value<DateTime?>? pausedAt,
    Value<String?>? note,
    Value<String?>? remindAt,
    Value<String?>? deadline,
    Value<DateTime?>? archivedAt,
    Value<String?>? archiveNote,
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
      pausedAt: pausedAt ?? this.pausedAt,
      note: note ?? this.note,
      remindAt: remindAt ?? this.remindAt,
      deadline: deadline ?? this.deadline,
      archivedAt: archivedAt ?? this.archivedAt,
      archiveNote: archiveNote ?? this.archiveNote,
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
    if (pausedAt.present) {
      map['paused_at'] = Variable<DateTime>(pausedAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (remindAt.present) {
      map['remind_at'] = Variable<String>(remindAt.value);
    }
    if (deadline.present) {
      map['deadline'] = Variable<String>(deadline.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (archiveNote.present) {
      map['archive_note'] = Variable<String>(archiveNote.value);
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
          ..write('pausedAt: $pausedAt, ')
          ..write('note: $note, ')
          ..write('remindAt: $remindAt, ')
          ..write('deadline: $deadline, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('archiveNote: $archiveNote, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CheckInsTable extends CheckIns
    with TableInfo<$CheckInsTable, CheckInRow> {
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
    Insertable<CheckInRow> instance, {
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
  CheckInRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CheckInRow(
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

class CheckInRow extends DataClass implements Insertable<CheckInRow> {
  final String uuid;
  final String commitmentUuid;

  /// The Harvest Day this counts for, computed at write time.
  final String harvestDay;

  /// Units logged: 1 for habits/todos, page/minute counts for projects.
  final int quantity;
  final DateTime loggedAt;
  final DateTime? deletedAt;
  final DateTime updatedAt;
  const CheckInRow({
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

  factory CheckInRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CheckInRow(
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

  CheckInRow copyWith({
    String? uuid,
    String? commitmentUuid,
    String? harvestDay,
    int? quantity,
    DateTime? loggedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => CheckInRow(
    uuid: uuid ?? this.uuid,
    commitmentUuid: commitmentUuid ?? this.commitmentUuid,
    harvestDay: harvestDay ?? this.harvestDay,
    quantity: quantity ?? this.quantity,
    loggedAt: loggedAt ?? this.loggedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CheckInRow copyWithCompanion(CheckInsCompanion data) {
    return CheckInRow(
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
    return (StringBuffer('CheckInRow(')
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
      (other is CheckInRow &&
          other.uuid == this.uuid &&
          other.commitmentUuid == this.commitmentUuid &&
          other.harvestDay == this.harvestDay &&
          other.quantity == this.quantity &&
          other.loggedAt == this.loggedAt &&
          other.deletedAt == this.deletedAt &&
          other.updatedAt == this.updatedAt);
}

class CheckInsCompanion extends UpdateCompanion<CheckInRow> {
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
  static Insertable<CheckInRow> custom({
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

class $SeedNotesTable extends SeedNotes
    with TableInfo<$SeedNotesTable, SeedNoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeedNotesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
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
    body,
    loggedAt,
    deletedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seed_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeedNoteRow> instance, {
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
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
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
  SeedNoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeedNoteRow(
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
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
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
  $SeedNotesTable createAlias(String alias) {
    return $SeedNotesTable(attachedDatabase, alias);
  }
}

class SeedNoteRow extends DataClass implements Insertable<SeedNoteRow> {
  final String uuid;
  final String commitmentUuid;

  /// The Harvest Day this note belongs to.
  final String harvestDay;
  final String body;
  final DateTime loggedAt;
  final DateTime? deletedAt;
  final DateTime updatedAt;
  const SeedNoteRow({
    required this.uuid,
    required this.commitmentUuid,
    required this.harvestDay,
    required this.body,
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
    map['body'] = Variable<String>(body);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SeedNotesCompanion toCompanion(bool nullToAbsent) {
    return SeedNotesCompanion(
      uuid: Value(uuid),
      commitmentUuid: Value(commitmentUuid),
      harvestDay: Value(harvestDay),
      body: Value(body),
      loggedAt: Value(loggedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SeedNoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeedNoteRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      commitmentUuid: serializer.fromJson<String>(json['commitmentUuid']),
      harvestDay: serializer.fromJson<String>(json['harvestDay']),
      body: serializer.fromJson<String>(json['body']),
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
      'body': serializer.toJson<String>(body),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SeedNoteRow copyWith({
    String? uuid,
    String? commitmentUuid,
    String? harvestDay,
    String? body,
    DateTime? loggedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => SeedNoteRow(
    uuid: uuid ?? this.uuid,
    commitmentUuid: commitmentUuid ?? this.commitmentUuid,
    harvestDay: harvestDay ?? this.harvestDay,
    body: body ?? this.body,
    loggedAt: loggedAt ?? this.loggedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SeedNoteRow copyWithCompanion(SeedNotesCompanion data) {
    return SeedNoteRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      commitmentUuid: data.commitmentUuid.present
          ? data.commitmentUuid.value
          : this.commitmentUuid,
      harvestDay: data.harvestDay.present
          ? data.harvestDay.value
          : this.harvestDay,
      body: data.body.present ? data.body.value : this.body,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeedNoteRow(')
          ..write('uuid: $uuid, ')
          ..write('commitmentUuid: $commitmentUuid, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('body: $body, ')
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
    body,
    loggedAt,
    deletedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeedNoteRow &&
          other.uuid == this.uuid &&
          other.commitmentUuid == this.commitmentUuid &&
          other.harvestDay == this.harvestDay &&
          other.body == this.body &&
          other.loggedAt == this.loggedAt &&
          other.deletedAt == this.deletedAt &&
          other.updatedAt == this.updatedAt);
}

class SeedNotesCompanion extends UpdateCompanion<SeedNoteRow> {
  final Value<String> uuid;
  final Value<String> commitmentUuid;
  final Value<String> harvestDay;
  final Value<String> body;
  final Value<DateTime> loggedAt;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SeedNotesCompanion({
    this.uuid = const Value.absent(),
    this.commitmentUuid = const Value.absent(),
    this.harvestDay = const Value.absent(),
    this.body = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeedNotesCompanion.insert({
    required String uuid,
    required String commitmentUuid,
    required String harvestDay,
    required String body,
    this.loggedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       commitmentUuid = Value(commitmentUuid),
       harvestDay = Value(harvestDay),
       body = Value(body);
  static Insertable<SeedNoteRow> custom({
    Expression<String>? uuid,
    Expression<String>? commitmentUuid,
    Expression<String>? harvestDay,
    Expression<String>? body,
    Expression<DateTime>? loggedAt,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (commitmentUuid != null) 'commitment_uuid': commitmentUuid,
      if (harvestDay != null) 'harvest_day': harvestDay,
      if (body != null) 'body': body,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeedNotesCompanion copyWith({
    Value<String>? uuid,
    Value<String>? commitmentUuid,
    Value<String>? harvestDay,
    Value<String>? body,
    Value<DateTime>? loggedAt,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SeedNotesCompanion(
      uuid: uuid ?? this.uuid,
      commitmentUuid: commitmentUuid ?? this.commitmentUuid,
      harvestDay: harvestDay ?? this.harvestDay,
      body: body ?? this.body,
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
    if (body.present) {
      map['body'] = Variable<String>(body.value);
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
    return (StringBuffer('SeedNotesCompanion(')
          ..write('uuid: $uuid, ')
          ..write('commitmentUuid: $commitmentUuid, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('body: $body, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, NoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
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
  static const VerificationMeta _folderMeta = const VerificationMeta('folder');
  @override
  late final GeneratedColumn<String> folder = GeneratedColumn<String>(
    'folder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    title,
    folder,
    body,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteRow> instance, {
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
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('folder')) {
      context.handle(
        _folderMeta,
        folder.isAcceptableOrUnknown(data['folder']!, _folderMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  NoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      folder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class NoteRow extends DataClass implements Insertable<NoteRow> {
  final String uuid;
  final String title;

  /// Folder path, "" for the root. Slash-separated, created by naming.
  final String folder;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const NoteRow({
    required this.uuid,
    required this.title,
    required this.folder,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['title'] = Variable<String>(title);
    map['folder'] = Variable<String>(folder);
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      uuid: Value(uuid),
      title: Value(title),
      folder: Value(folder),
      body: Value(body),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory NoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      title: serializer.fromJson<String>(json['title']),
      folder: serializer.fromJson<String>(json['folder']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'title': serializer.toJson<String>(title),
      'folder': serializer.toJson<String>(folder),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  NoteRow copyWith({
    String? uuid,
    String? title,
    String? folder,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => NoteRow(
    uuid: uuid ?? this.uuid,
    title: title ?? this.title,
    folder: folder ?? this.folder,
    body: body ?? this.body,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  NoteRow copyWithCompanion(NotesCompanion data) {
    return NoteRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      title: data.title.present ? data.title.value : this.title,
      folder: data.folder.present ? data.folder.value : this.folder,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteRow(')
          ..write('uuid: $uuid, ')
          ..write('title: $title, ')
          ..write('folder: $folder, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(uuid, title, folder, body, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteRow &&
          other.uuid == this.uuid &&
          other.title == this.title &&
          other.folder == this.folder &&
          other.body == this.body &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class NotesCompanion extends UpdateCompanion<NoteRow> {
  final Value<String> uuid;
  final Value<String> title;
  final Value<String> folder;
  final Value<String> body;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const NotesCompanion({
    this.uuid = const Value.absent(),
    this.title = const Value.absent(),
    this.folder = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String uuid,
    required String title,
    this.folder = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       title = Value(title);
  static Insertable<NoteRow> custom({
    Expression<String>? uuid,
    Expression<String>? title,
    Expression<String>? folder,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (title != null) 'title': title,
      if (folder != null) 'folder': folder,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? uuid,
    Value<String>? title,
    Value<String>? folder,
    Value<String>? body,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      uuid: uuid ?? this.uuid,
      title: title ?? this.title,
      folder: folder ?? this.folder,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (folder.present) {
      map['folder'] = Variable<String>(folder.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('uuid: $uuid, ')
          ..write('title: $title, ')
          ..write('folder: $folder, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteLinksTable extends NoteLinks
    with TableInfo<$NoteLinksTable, NoteLinkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromUuidMeta = const VerificationMeta(
    'fromUuid',
  );
  @override
  late final GeneratedColumn<String> fromUuid = GeneratedColumn<String>(
    'from_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (uuid)',
    ),
  );
  static const VerificationMeta _toTitleMeta = const VerificationMeta(
    'toTitle',
  );
  @override
  late final GeneratedColumn<String> toTitle = GeneratedColumn<String>(
    'to_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toUuidMeta = const VerificationMeta('toUuid');
  @override
  late final GeneratedColumn<String> toUuid = GeneratedColumn<String>(
    'to_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [uuid, fromUuid, toTitle, toUuid];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteLinkRow> instance, {
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
    if (data.containsKey('from_uuid')) {
      context.handle(
        _fromUuidMeta,
        fromUuid.isAcceptableOrUnknown(data['from_uuid']!, _fromUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_fromUuidMeta);
    }
    if (data.containsKey('to_title')) {
      context.handle(
        _toTitleMeta,
        toTitle.isAcceptableOrUnknown(data['to_title']!, _toTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_toTitleMeta);
    }
    if (data.containsKey('to_uuid')) {
      context.handle(
        _toUuidMeta,
        toUuid.isAcceptableOrUnknown(data['to_uuid']!, _toUuidMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  NoteLinkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteLinkRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      fromUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_uuid'],
      )!,
      toTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_title'],
      )!,
      toUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_uuid'],
      ),
    );
  }

  @override
  $NoteLinksTable createAlias(String alias) {
    return $NoteLinksTable(attachedDatabase, alias);
  }
}

class NoteLinkRow extends DataClass implements Insertable<NoteLinkRow> {
  final String uuid;
  final String fromUuid;

  /// The title as written between the brackets.
  final String toTitle;

  /// The note that title resolves to, null while it does not exist yet.
  final String? toUuid;
  const NoteLinkRow({
    required this.uuid,
    required this.fromUuid,
    required this.toTitle,
    this.toUuid,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['from_uuid'] = Variable<String>(fromUuid);
    map['to_title'] = Variable<String>(toTitle);
    if (!nullToAbsent || toUuid != null) {
      map['to_uuid'] = Variable<String>(toUuid);
    }
    return map;
  }

  NoteLinksCompanion toCompanion(bool nullToAbsent) {
    return NoteLinksCompanion(
      uuid: Value(uuid),
      fromUuid: Value(fromUuid),
      toTitle: Value(toTitle),
      toUuid: toUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(toUuid),
    );
  }

  factory NoteLinkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteLinkRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      fromUuid: serializer.fromJson<String>(json['fromUuid']),
      toTitle: serializer.fromJson<String>(json['toTitle']),
      toUuid: serializer.fromJson<String?>(json['toUuid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'fromUuid': serializer.toJson<String>(fromUuid),
      'toTitle': serializer.toJson<String>(toTitle),
      'toUuid': serializer.toJson<String?>(toUuid),
    };
  }

  NoteLinkRow copyWith({
    String? uuid,
    String? fromUuid,
    String? toTitle,
    Value<String?> toUuid = const Value.absent(),
  }) => NoteLinkRow(
    uuid: uuid ?? this.uuid,
    fromUuid: fromUuid ?? this.fromUuid,
    toTitle: toTitle ?? this.toTitle,
    toUuid: toUuid.present ? toUuid.value : this.toUuid,
  );
  NoteLinkRow copyWithCompanion(NoteLinksCompanion data) {
    return NoteLinkRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      fromUuid: data.fromUuid.present ? data.fromUuid.value : this.fromUuid,
      toTitle: data.toTitle.present ? data.toTitle.value : this.toTitle,
      toUuid: data.toUuid.present ? data.toUuid.value : this.toUuid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteLinkRow(')
          ..write('uuid: $uuid, ')
          ..write('fromUuid: $fromUuid, ')
          ..write('toTitle: $toTitle, ')
          ..write('toUuid: $toUuid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uuid, fromUuid, toTitle, toUuid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteLinkRow &&
          other.uuid == this.uuid &&
          other.fromUuid == this.fromUuid &&
          other.toTitle == this.toTitle &&
          other.toUuid == this.toUuid);
}

class NoteLinksCompanion extends UpdateCompanion<NoteLinkRow> {
  final Value<String> uuid;
  final Value<String> fromUuid;
  final Value<String> toTitle;
  final Value<String?> toUuid;
  final Value<int> rowid;
  const NoteLinksCompanion({
    this.uuid = const Value.absent(),
    this.fromUuid = const Value.absent(),
    this.toTitle = const Value.absent(),
    this.toUuid = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteLinksCompanion.insert({
    required String uuid,
    required String fromUuid,
    required String toTitle,
    this.toUuid = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       fromUuid = Value(fromUuid),
       toTitle = Value(toTitle);
  static Insertable<NoteLinkRow> custom({
    Expression<String>? uuid,
    Expression<String>? fromUuid,
    Expression<String>? toTitle,
    Expression<String>? toUuid,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (fromUuid != null) 'from_uuid': fromUuid,
      if (toTitle != null) 'to_title': toTitle,
      if (toUuid != null) 'to_uuid': toUuid,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteLinksCompanion copyWith({
    Value<String>? uuid,
    Value<String>? fromUuid,
    Value<String>? toTitle,
    Value<String?>? toUuid,
    Value<int>? rowid,
  }) {
    return NoteLinksCompanion(
      uuid: uuid ?? this.uuid,
      fromUuid: fromUuid ?? this.fromUuid,
      toTitle: toTitle ?? this.toTitle,
      toUuid: toUuid ?? this.toUuid,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (fromUuid.present) {
      map['from_uuid'] = Variable<String>(fromUuid.value);
    }
    if (toTitle.present) {
      map['to_title'] = Variable<String>(toTitle.value);
    }
    if (toUuid.present) {
      map['to_uuid'] = Variable<String>(toUuid.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteLinksCompanion(')
          ..write('uuid: $uuid, ')
          ..write('fromUuid: $fromUuid, ')
          ..write('toTitle: $toTitle, ')
          ..write('toUuid: $toUuid, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlbumsTable extends Albums with TableInfo<$AlbumsTable, AlbumRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlbumsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
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
  static const VerificationMeta _remindAtMeta = const VerificationMeta(
    'remindAt',
  );
  @override
  late final GeneratedColumn<String> remindAt = GeneratedColumn<String>(
    'remind_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    name,
    scheduleJson,
    remindAt,
    note,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'albums';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlbumRow> instance, {
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
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
    if (data.containsKey('remind_at')) {
      context.handle(
        _remindAtMeta,
        remindAt.isAcceptableOrUnknown(data['remind_at']!, _remindAtMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  AlbumRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlbumRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      scheduleJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_json'],
      ),
      remindAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remind_at'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $AlbumsTable createAlias(String alias) {
    return $AlbumsTable(attachedDatabase, alias);
  }
}

class AlbumRow extends DataClass implements Insertable<AlbumRow> {
  final String uuid;
  final String name;

  /// Habit-style schedule rules, JSON-encoded. Null means unscheduled:
  /// an album I add to when I feel like it, not a seed.
  final String? scheduleJson;

  /// "HH:mm" reminder, on days the album is due.
  final String? remindAt;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const AlbumRow({
    required this.uuid,
    required this.name,
    this.scheduleJson,
    this.remindAt,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || scheduleJson != null) {
      map['schedule_json'] = Variable<String>(scheduleJson);
    }
    if (!nullToAbsent || remindAt != null) {
      map['remind_at'] = Variable<String>(remindAt);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  AlbumsCompanion toCompanion(bool nullToAbsent) {
    return AlbumsCompanion(
      uuid: Value(uuid),
      name: Value(name),
      scheduleJson: scheduleJson == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduleJson),
      remindAt: remindAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remindAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory AlbumRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlbumRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      scheduleJson: serializer.fromJson<String?>(json['scheduleJson']),
      remindAt: serializer.fromJson<String?>(json['remindAt']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'scheduleJson': serializer.toJson<String?>(scheduleJson),
      'remindAt': serializer.toJson<String?>(remindAt),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  AlbumRow copyWith({
    String? uuid,
    String? name,
    Value<String?> scheduleJson = const Value.absent(),
    Value<String?> remindAt = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => AlbumRow(
    uuid: uuid ?? this.uuid,
    name: name ?? this.name,
    scheduleJson: scheduleJson.present ? scheduleJson.value : this.scheduleJson,
    remindAt: remindAt.present ? remindAt.value : this.remindAt,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  AlbumRow copyWithCompanion(AlbumsCompanion data) {
    return AlbumRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      scheduleJson: data.scheduleJson.present
          ? data.scheduleJson.value
          : this.scheduleJson,
      remindAt: data.remindAt.present ? data.remindAt.value : this.remindAt,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlbumRow(')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('scheduleJson: $scheduleJson, ')
          ..write('remindAt: $remindAt, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    name,
    scheduleJson,
    remindAt,
    note,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlbumRow &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.scheduleJson == this.scheduleJson &&
          other.remindAt == this.remindAt &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class AlbumsCompanion extends UpdateCompanion<AlbumRow> {
  final Value<String> uuid;
  final Value<String> name;
  final Value<String?> scheduleJson;
  final Value<String?> remindAt;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const AlbumsCompanion({
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.scheduleJson = const Value.absent(),
    this.remindAt = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlbumsCompanion.insert({
    required String uuid,
    required String name,
    this.scheduleJson = const Value.absent(),
    this.remindAt = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       name = Value(name);
  static Insertable<AlbumRow> custom({
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? scheduleJson,
    Expression<String>? remindAt,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (scheduleJson != null) 'schedule_json': scheduleJson,
      if (remindAt != null) 'remind_at': remindAt,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlbumsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? name,
    Value<String?>? scheduleJson,
    Value<String?>? remindAt,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return AlbumsCompanion(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      scheduleJson: scheduleJson ?? this.scheduleJson,
      remindAt: remindAt ?? this.remindAt,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (scheduleJson.present) {
      map['schedule_json'] = Variable<String>(scheduleJson.value);
    }
    if (remindAt.present) {
      map['remind_at'] = Variable<String>(remindAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlbumsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('scheduleJson: $scheduleJson, ')
          ..write('remindAt: $remindAt, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoriesTable extends Memories
    with TableInfo<$MemoriesTable, MemoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumUuidMeta = const VerificationMeta(
    'albumUuid',
  );
  @override
  late final GeneratedColumn<String> albumUuid = GeneratedColumn<String>(
    'album_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES albums (uuid)',
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
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
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
    requiredDuringInsert: false,
    defaultValue: const Constant('photo'),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
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
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    albumUuid,
    harvestDay,
    path,
    kind,
    note,
    capturedAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memories';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryRow> instance, {
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
    if (data.containsKey('album_uuid')) {
      context.handle(
        _albumUuidMeta,
        albumUuid.isAcceptableOrUnknown(data['album_uuid']!, _albumUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_albumUuidMeta);
    }
    if (data.containsKey('harvest_day')) {
      context.handle(
        _harvestDayMeta,
        harvestDay.isAcceptableOrUnknown(data['harvest_day']!, _harvestDayMeta),
      );
    } else if (isInserting) {
      context.missing(_harvestDayMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  MemoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      albumUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_uuid'],
      )!,
      harvestDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harvest_day'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $MemoriesTable createAlias(String alias) {
    return $MemoriesTable(attachedDatabase, alias);
  }
}

class MemoryRow extends DataClass implements Insertable<MemoryRow> {
  final String uuid;
  final String albumUuid;
  final String harvestDay;

  /// Path relative to the gallery directory, so the row survives the
  /// app's storage moving between installs.
  final String path;

  /// `photo` | `video`.
  final String kind;
  final String? note;
  final DateTime capturedAt;
  final DateTime updatedAt;

  /// In the trash since. Null is a memory I still have.
  final DateTime? deletedAt;
  const MemoryRow({
    required this.uuid,
    required this.albumUuid,
    required this.harvestDay,
    required this.path,
    required this.kind,
    this.note,
    required this.capturedAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['album_uuid'] = Variable<String>(albumUuid);
    map['harvest_day'] = Variable<String>(harvestDay);
    map['path'] = Variable<String>(path);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['captured_at'] = Variable<DateTime>(capturedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  MemoriesCompanion toCompanion(bool nullToAbsent) {
    return MemoriesCompanion(
      uuid: Value(uuid),
      albumUuid: Value(albumUuid),
      harvestDay: Value(harvestDay),
      path: Value(path),
      kind: Value(kind),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      capturedAt: Value(capturedAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory MemoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      albumUuid: serializer.fromJson<String>(json['albumUuid']),
      harvestDay: serializer.fromJson<String>(json['harvestDay']),
      path: serializer.fromJson<String>(json['path']),
      kind: serializer.fromJson<String>(json['kind']),
      note: serializer.fromJson<String?>(json['note']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'albumUuid': serializer.toJson<String>(albumUuid),
      'harvestDay': serializer.toJson<String>(harvestDay),
      'path': serializer.toJson<String>(path),
      'kind': serializer.toJson<String>(kind),
      'note': serializer.toJson<String?>(note),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  MemoryRow copyWith({
    String? uuid,
    String? albumUuid,
    String? harvestDay,
    String? path,
    String? kind,
    Value<String?> note = const Value.absent(),
    DateTime? capturedAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => MemoryRow(
    uuid: uuid ?? this.uuid,
    albumUuid: albumUuid ?? this.albumUuid,
    harvestDay: harvestDay ?? this.harvestDay,
    path: path ?? this.path,
    kind: kind ?? this.kind,
    note: note.present ? note.value : this.note,
    capturedAt: capturedAt ?? this.capturedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  MemoryRow copyWithCompanion(MemoriesCompanion data) {
    return MemoryRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      albumUuid: data.albumUuid.present ? data.albumUuid.value : this.albumUuid,
      harvestDay: data.harvestDay.present
          ? data.harvestDay.value
          : this.harvestDay,
      path: data.path.present ? data.path.value : this.path,
      kind: data.kind.present ? data.kind.value : this.kind,
      note: data.note.present ? data.note.value : this.note,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryRow(')
          ..write('uuid: $uuid, ')
          ..write('albumUuid: $albumUuid, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('path: $path, ')
          ..write('kind: $kind, ')
          ..write('note: $note, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    albumUuid,
    harvestDay,
    path,
    kind,
    note,
    capturedAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryRow &&
          other.uuid == this.uuid &&
          other.albumUuid == this.albumUuid &&
          other.harvestDay == this.harvestDay &&
          other.path == this.path &&
          other.kind == this.kind &&
          other.note == this.note &&
          other.capturedAt == this.capturedAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class MemoriesCompanion extends UpdateCompanion<MemoryRow> {
  final Value<String> uuid;
  final Value<String> albumUuid;
  final Value<String> harvestDay;
  final Value<String> path;
  final Value<String> kind;
  final Value<String?> note;
  final Value<DateTime> capturedAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const MemoriesCompanion({
    this.uuid = const Value.absent(),
    this.albumUuid = const Value.absent(),
    this.harvestDay = const Value.absent(),
    this.path = const Value.absent(),
    this.kind = const Value.absent(),
    this.note = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoriesCompanion.insert({
    required String uuid,
    required String albumUuid,
    required String harvestDay,
    required String path,
    this.kind = const Value.absent(),
    this.note = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       albumUuid = Value(albumUuid),
       harvestDay = Value(harvestDay),
       path = Value(path);
  static Insertable<MemoryRow> custom({
    Expression<String>? uuid,
    Expression<String>? albumUuid,
    Expression<String>? harvestDay,
    Expression<String>? path,
    Expression<String>? kind,
    Expression<String>? note,
    Expression<DateTime>? capturedAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (albumUuid != null) 'album_uuid': albumUuid,
      if (harvestDay != null) 'harvest_day': harvestDay,
      if (path != null) 'path': path,
      if (kind != null) 'kind': kind,
      if (note != null) 'note': note,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoriesCompanion copyWith({
    Value<String>? uuid,
    Value<String>? albumUuid,
    Value<String>? harvestDay,
    Value<String>? path,
    Value<String>? kind,
    Value<String?>? note,
    Value<DateTime>? capturedAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return MemoriesCompanion(
      uuid: uuid ?? this.uuid,
      albumUuid: albumUuid ?? this.albumUuid,
      harvestDay: harvestDay ?? this.harvestDay,
      path: path ?? this.path,
      kind: kind ?? this.kind,
      note: note ?? this.note,
      capturedAt: capturedAt ?? this.capturedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (albumUuid.present) {
      map['album_uuid'] = Variable<String>(albumUuid.value);
    }
    if (harvestDay.present) {
      map['harvest_day'] = Variable<String>(harvestDay.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoriesCompanion(')
          ..write('uuid: $uuid, ')
          ..write('albumUuid: $albumUuid, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('path: $path, ')
          ..write('kind: $kind, ')
          ..write('note: $note, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StepDaysTable extends StepDays
    with TableInfo<$StepDaysTable, StepDayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StepDaysTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
    'steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastCounterMeta = const VerificationMeta(
    'lastCounter',
  );
  @override
  late final GeneratedColumn<int> lastCounter = GeneratedColumn<int>(
    'last_counter',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    harvestDay,
    steps,
    lastCounter,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'step_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<StepDayRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('harvest_day')) {
      context.handle(
        _harvestDayMeta,
        harvestDay.isAcceptableOrUnknown(data['harvest_day']!, _harvestDayMeta),
      );
    } else if (isInserting) {
      context.missing(_harvestDayMeta);
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    }
    if (data.containsKey('last_counter')) {
      context.handle(
        _lastCounterMeta,
        lastCounter.isAcceptableOrUnknown(
          data['last_counter']!,
          _lastCounterMeta,
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
  Set<GeneratedColumn> get $primaryKey => {harvestDay};
  @override
  StepDayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StepDayRow(
      harvestDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harvest_day'],
      )!,
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}steps'],
      )!,
      lastCounter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_counter'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StepDaysTable createAlias(String alias) {
    return $StepDaysTable(attachedDatabase, alias);
  }
}

class StepDayRow extends DataClass implements Insertable<StepDayRow> {
  final String harvestDay;
  final int steps;

  /// The sensor's own since-boot count at the last sync. Null before
  /// the first reading of the day.
  final int? lastCounter;
  final DateTime updatedAt;
  const StepDayRow({
    required this.harvestDay,
    required this.steps,
    this.lastCounter,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['harvest_day'] = Variable<String>(harvestDay);
    map['steps'] = Variable<int>(steps);
    if (!nullToAbsent || lastCounter != null) {
      map['last_counter'] = Variable<int>(lastCounter);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StepDaysCompanion toCompanion(bool nullToAbsent) {
    return StepDaysCompanion(
      harvestDay: Value(harvestDay),
      steps: Value(steps),
      lastCounter: lastCounter == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCounter),
      updatedAt: Value(updatedAt),
    );
  }

  factory StepDayRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StepDayRow(
      harvestDay: serializer.fromJson<String>(json['harvestDay']),
      steps: serializer.fromJson<int>(json['steps']),
      lastCounter: serializer.fromJson<int?>(json['lastCounter']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'harvestDay': serializer.toJson<String>(harvestDay),
      'steps': serializer.toJson<int>(steps),
      'lastCounter': serializer.toJson<int?>(lastCounter),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StepDayRow copyWith({
    String? harvestDay,
    int? steps,
    Value<int?> lastCounter = const Value.absent(),
    DateTime? updatedAt,
  }) => StepDayRow(
    harvestDay: harvestDay ?? this.harvestDay,
    steps: steps ?? this.steps,
    lastCounter: lastCounter.present ? lastCounter.value : this.lastCounter,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StepDayRow copyWithCompanion(StepDaysCompanion data) {
    return StepDayRow(
      harvestDay: data.harvestDay.present
          ? data.harvestDay.value
          : this.harvestDay,
      steps: data.steps.present ? data.steps.value : this.steps,
      lastCounter: data.lastCounter.present
          ? data.lastCounter.value
          : this.lastCounter,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StepDayRow(')
          ..write('harvestDay: $harvestDay, ')
          ..write('steps: $steps, ')
          ..write('lastCounter: $lastCounter, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(harvestDay, steps, lastCounter, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StepDayRow &&
          other.harvestDay == this.harvestDay &&
          other.steps == this.steps &&
          other.lastCounter == this.lastCounter &&
          other.updatedAt == this.updatedAt);
}

class StepDaysCompanion extends UpdateCompanion<StepDayRow> {
  final Value<String> harvestDay;
  final Value<int> steps;
  final Value<int?> lastCounter;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StepDaysCompanion({
    this.harvestDay = const Value.absent(),
    this.steps = const Value.absent(),
    this.lastCounter = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StepDaysCompanion.insert({
    required String harvestDay,
    this.steps = const Value.absent(),
    this.lastCounter = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : harvestDay = Value(harvestDay);
  static Insertable<StepDayRow> custom({
    Expression<String>? harvestDay,
    Expression<int>? steps,
    Expression<int>? lastCounter,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (harvestDay != null) 'harvest_day': harvestDay,
      if (steps != null) 'steps': steps,
      if (lastCounter != null) 'last_counter': lastCounter,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StepDaysCompanion copyWith({
    Value<String>? harvestDay,
    Value<int>? steps,
    Value<int?>? lastCounter,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StepDaysCompanion(
      harvestDay: harvestDay ?? this.harvestDay,
      steps: steps ?? this.steps,
      lastCounter: lastCounter ?? this.lastCounter,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (harvestDay.present) {
      map['harvest_day'] = Variable<String>(harvestDay.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (lastCounter.present) {
      map['last_counter'] = Variable<int>(lastCounter.value);
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
    return (StringBuffer('StepDaysCompanion(')
          ..write('harvestDay: $harvestDay, ')
          ..write('steps: $steps, ')
          ..write('lastCounter: $lastCounter, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BodyWeightsTable extends BodyWeights
    with TableInfo<$BodyWeightsTable, BodyWeightRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BodyWeightsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gramsMeta = const VerificationMeta('grams');
  @override
  late final GeneratedColumn<int> grams = GeneratedColumn<int>(
    'grams',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _measuredAtMeta = const VerificationMeta(
    'measuredAt',
  );
  @override
  late final GeneratedColumn<DateTime> measuredAt = GeneratedColumn<DateTime>(
    'measured_at',
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
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    grams,
    harvestDay,
    note,
    measuredAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'body_weights';
  @override
  VerificationContext validateIntegrity(
    Insertable<BodyWeightRow> instance, {
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
    if (data.containsKey('grams')) {
      context.handle(
        _gramsMeta,
        grams.isAcceptableOrUnknown(data['grams']!, _gramsMeta),
      );
    } else if (isInserting) {
      context.missing(_gramsMeta);
    }
    if (data.containsKey('harvest_day')) {
      context.handle(
        _harvestDayMeta,
        harvestDay.isAcceptableOrUnknown(data['harvest_day']!, _harvestDayMeta),
      );
    } else if (isInserting) {
      context.missing(_harvestDayMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('measured_at')) {
      context.handle(
        _measuredAtMeta,
        measuredAt.isAcceptableOrUnknown(data['measured_at']!, _measuredAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  BodyWeightRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BodyWeightRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      grams: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grams'],
      )!,
      harvestDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harvest_day'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      measuredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}measured_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $BodyWeightsTable createAlias(String alias) {
    return $BodyWeightsTable(attachedDatabase, alias);
  }
}

class BodyWeightRow extends DataClass implements Insertable<BodyWeightRow> {
  final String uuid;
  final int grams;
  final String harvestDay;
  final String? note;

  /// More than one a day is allowed — morning and evening are
  /// different facts.
  final DateTime measuredAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const BodyWeightRow({
    required this.uuid,
    required this.grams,
    required this.harvestDay,
    this.note,
    required this.measuredAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['grams'] = Variable<int>(grams);
    map['harvest_day'] = Variable<String>(harvestDay);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['measured_at'] = Variable<DateTime>(measuredAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  BodyWeightsCompanion toCompanion(bool nullToAbsent) {
    return BodyWeightsCompanion(
      uuid: Value(uuid),
      grams: Value(grams),
      harvestDay: Value(harvestDay),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      measuredAt: Value(measuredAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory BodyWeightRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BodyWeightRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      grams: serializer.fromJson<int>(json['grams']),
      harvestDay: serializer.fromJson<String>(json['harvestDay']),
      note: serializer.fromJson<String?>(json['note']),
      measuredAt: serializer.fromJson<DateTime>(json['measuredAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'grams': serializer.toJson<int>(grams),
      'harvestDay': serializer.toJson<String>(harvestDay),
      'note': serializer.toJson<String?>(note),
      'measuredAt': serializer.toJson<DateTime>(measuredAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  BodyWeightRow copyWith({
    String? uuid,
    int? grams,
    String? harvestDay,
    Value<String?> note = const Value.absent(),
    DateTime? measuredAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => BodyWeightRow(
    uuid: uuid ?? this.uuid,
    grams: grams ?? this.grams,
    harvestDay: harvestDay ?? this.harvestDay,
    note: note.present ? note.value : this.note,
    measuredAt: measuredAt ?? this.measuredAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  BodyWeightRow copyWithCompanion(BodyWeightsCompanion data) {
    return BodyWeightRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      grams: data.grams.present ? data.grams.value : this.grams,
      harvestDay: data.harvestDay.present
          ? data.harvestDay.value
          : this.harvestDay,
      note: data.note.present ? data.note.value : this.note,
      measuredAt: data.measuredAt.present
          ? data.measuredAt.value
          : this.measuredAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BodyWeightRow(')
          ..write('uuid: $uuid, ')
          ..write('grams: $grams, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('note: $note, ')
          ..write('measuredAt: $measuredAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    grams,
    harvestDay,
    note,
    measuredAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BodyWeightRow &&
          other.uuid == this.uuid &&
          other.grams == this.grams &&
          other.harvestDay == this.harvestDay &&
          other.note == this.note &&
          other.measuredAt == this.measuredAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class BodyWeightsCompanion extends UpdateCompanion<BodyWeightRow> {
  final Value<String> uuid;
  final Value<int> grams;
  final Value<String> harvestDay;
  final Value<String?> note;
  final Value<DateTime> measuredAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const BodyWeightsCompanion({
    this.uuid = const Value.absent(),
    this.grams = const Value.absent(),
    this.harvestDay = const Value.absent(),
    this.note = const Value.absent(),
    this.measuredAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BodyWeightsCompanion.insert({
    required String uuid,
    required int grams,
    required String harvestDay,
    this.note = const Value.absent(),
    this.measuredAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       grams = Value(grams),
       harvestDay = Value(harvestDay);
  static Insertable<BodyWeightRow> custom({
    Expression<String>? uuid,
    Expression<int>? grams,
    Expression<String>? harvestDay,
    Expression<String>? note,
    Expression<DateTime>? measuredAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (grams != null) 'grams': grams,
      if (harvestDay != null) 'harvest_day': harvestDay,
      if (note != null) 'note': note,
      if (measuredAt != null) 'measured_at': measuredAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BodyWeightsCompanion copyWith({
    Value<String>? uuid,
    Value<int>? grams,
    Value<String>? harvestDay,
    Value<String?>? note,
    Value<DateTime>? measuredAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return BodyWeightsCompanion(
      uuid: uuid ?? this.uuid,
      grams: grams ?? this.grams,
      harvestDay: harvestDay ?? this.harvestDay,
      note: note ?? this.note,
      measuredAt: measuredAt ?? this.measuredAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (grams.present) {
      map['grams'] = Variable<int>(grams.value);
    }
    if (harvestDay.present) {
      map['harvest_day'] = Variable<String>(harvestDay.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (measuredAt.present) {
      map['measured_at'] = Variable<DateTime>(measuredAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BodyWeightsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('grams: $grams, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('note: $note, ')
          ..write('measuredAt: $measuredAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExercisesTable extends Exercises
    with TableInfo<$ExercisesTable, ExerciseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyPartMeta = const VerificationMeta(
    'bodyPart',
  );
  @override
  late final GeneratedColumn<String> bodyPart = GeneratedColumn<String>(
    'body_part',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _equipmentMeta = const VerificationMeta(
    'equipment',
  );
  @override
  late final GeneratedColumn<String> equipment = GeneratedColumn<String>(
    'equipment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    name,
    bodyPart,
    equipment,
    target,
    note,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseRow> instance, {
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('body_part')) {
      context.handle(
        _bodyPartMeta,
        bodyPart.isAcceptableOrUnknown(data['body_part']!, _bodyPartMeta),
      );
    }
    if (data.containsKey('equipment')) {
      context.handle(
        _equipmentMeta,
        equipment.isAcceptableOrUnknown(data['equipment']!, _equipmentMeta),
      );
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  ExerciseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      bodyPart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_part'],
      ),
      equipment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipment'],
      ),
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }
}

class ExerciseRow extends DataClass implements Insertable<ExerciseRow> {
  final String uuid;
  final String name;
  final String? bodyPart;
  final String? equipment;
  final String? target;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const ExerciseRow({
    required this.uuid,
    required this.name,
    this.bodyPart,
    this.equipment,
    this.target,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || bodyPart != null) {
      map['body_part'] = Variable<String>(bodyPart);
    }
    if (!nullToAbsent || equipment != null) {
      map['equipment'] = Variable<String>(equipment);
    }
    if (!nullToAbsent || target != null) {
      map['target'] = Variable<String>(target);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      uuid: Value(uuid),
      name: Value(name),
      bodyPart: bodyPart == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyPart),
      equipment: equipment == null && nullToAbsent
          ? const Value.absent()
          : Value(equipment),
      target: target == null && nullToAbsent
          ? const Value.absent()
          : Value(target),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ExerciseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      bodyPart: serializer.fromJson<String?>(json['bodyPart']),
      equipment: serializer.fromJson<String?>(json['equipment']),
      target: serializer.fromJson<String?>(json['target']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'bodyPart': serializer.toJson<String?>(bodyPart),
      'equipment': serializer.toJson<String?>(equipment),
      'target': serializer.toJson<String?>(target),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ExerciseRow copyWith({
    String? uuid,
    String? name,
    Value<String?> bodyPart = const Value.absent(),
    Value<String?> equipment = const Value.absent(),
    Value<String?> target = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ExerciseRow(
    uuid: uuid ?? this.uuid,
    name: name ?? this.name,
    bodyPart: bodyPart.present ? bodyPart.value : this.bodyPart,
    equipment: equipment.present ? equipment.value : this.equipment,
    target: target.present ? target.value : this.target,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ExerciseRow copyWithCompanion(ExercisesCompanion data) {
    return ExerciseRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      bodyPart: data.bodyPart.present ? data.bodyPart.value : this.bodyPart,
      equipment: data.equipment.present ? data.equipment.value : this.equipment,
      target: data.target.present ? data.target.value : this.target,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseRow(')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('bodyPart: $bodyPart, ')
          ..write('equipment: $equipment, ')
          ..write('target: $target, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    name,
    bodyPart,
    equipment,
    target,
    note,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseRow &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.bodyPart == this.bodyPart &&
          other.equipment == this.equipment &&
          other.target == this.target &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ExercisesCompanion extends UpdateCompanion<ExerciseRow> {
  final Value<String> uuid;
  final Value<String> name;
  final Value<String?> bodyPart;
  final Value<String?> equipment;
  final Value<String?> target;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ExercisesCompanion({
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.bodyPart = const Value.absent(),
    this.equipment = const Value.absent(),
    this.target = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExercisesCompanion.insert({
    required String uuid,
    required String name,
    this.bodyPart = const Value.absent(),
    this.equipment = const Value.absent(),
    this.target = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       name = Value(name);
  static Insertable<ExerciseRow> custom({
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? bodyPart,
    Expression<String>? equipment,
    Expression<String>? target,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (bodyPart != null) 'body_part': bodyPart,
      if (equipment != null) 'equipment': equipment,
      if (target != null) 'target': target,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExercisesCompanion copyWith({
    Value<String>? uuid,
    Value<String>? name,
    Value<String?>? bodyPart,
    Value<String?>? equipment,
    Value<String?>? target,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ExercisesCompanion(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      bodyPart: bodyPart ?? this.bodyPart,
      equipment: equipment ?? this.equipment,
      target: target ?? this.target,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (bodyPart.present) {
      map['body_part'] = Variable<String>(bodyPart.value);
    }
    if (equipment.present) {
      map['equipment'] = Variable<String>(equipment.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('bodyPart: $bodyPart, ')
          ..write('equipment: $equipment, ')
          ..write('target: $target, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgramsTable extends Programs
    with TableInfo<$ProgramsTable, ProgramRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgramsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weeksMeta = const VerificationMeta('weeks');
  @override
  late final GeneratedColumn<int> weeks = GeneratedColumn<int>(
    'weeks',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _albumUuidMeta = const VerificationMeta(
    'albumUuid',
  );
  @override
  late final GeneratedColumn<String> albumUuid = GeneratedColumn<String>(
    'album_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoPromptMeta = const VerificationMeta(
    'photoPrompt',
  );
  @override
  late final GeneratedColumn<String> photoPrompt = GeneratedColumn<String>(
    'photo_prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('after'),
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
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    name,
    note,
    weeks,
    commitmentUuid,
    albumUuid,
    photoPrompt,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'programs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgramRow> instance, {
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('weeks')) {
      context.handle(
        _weeksMeta,
        weeks.isAcceptableOrUnknown(data['weeks']!, _weeksMeta),
      );
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
    if (data.containsKey('album_uuid')) {
      context.handle(
        _albumUuidMeta,
        albumUuid.isAcceptableOrUnknown(data['album_uuid']!, _albumUuidMeta),
      );
    }
    if (data.containsKey('photo_prompt')) {
      context.handle(
        _photoPromptMeta,
        photoPrompt.isAcceptableOrUnknown(
          data['photo_prompt']!,
          _photoPromptMeta,
        ),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  ProgramRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgramRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      weeks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weeks'],
      ),
      commitmentUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commitment_uuid'],
      ),
      albumUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_uuid'],
      ),
      photoPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_prompt'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ProgramsTable createAlias(String alias) {
    return $ProgramsTable(attachedDatabase, alias);
  }
}

class ProgramRow extends DataClass implements Insertable<ProgramRow> {
  final String uuid;
  final String name;
  final String? note;

  /// Null for a program that is just a list of days; a number for one
  /// that cycles over N weeks.
  final int? weeks;

  /// The habit this program is: finishing a session checks it in
  /// ([[Gym]] rule Y4). Null until it is bound to one.
  final String? commitmentUuid;

  /// The album the pictures go to, if I took the offer.
  final String? albumUuid;

  /// `after` | `before` | `never` — when the picture is asked for.
  final String photoPrompt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const ProgramRow({
    required this.uuid,
    required this.name,
    this.note,
    this.weeks,
    this.commitmentUuid,
    this.albumUuid,
    required this.photoPrompt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || weeks != null) {
      map['weeks'] = Variable<int>(weeks);
    }
    if (!nullToAbsent || commitmentUuid != null) {
      map['commitment_uuid'] = Variable<String>(commitmentUuid);
    }
    if (!nullToAbsent || albumUuid != null) {
      map['album_uuid'] = Variable<String>(albumUuid);
    }
    map['photo_prompt'] = Variable<String>(photoPrompt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ProgramsCompanion toCompanion(bool nullToAbsent) {
    return ProgramsCompanion(
      uuid: Value(uuid),
      name: Value(name),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      weeks: weeks == null && nullToAbsent
          ? const Value.absent()
          : Value(weeks),
      commitmentUuid: commitmentUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(commitmentUuid),
      albumUuid: albumUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(albumUuid),
      photoPrompt: Value(photoPrompt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ProgramRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgramRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      note: serializer.fromJson<String?>(json['note']),
      weeks: serializer.fromJson<int?>(json['weeks']),
      commitmentUuid: serializer.fromJson<String?>(json['commitmentUuid']),
      albumUuid: serializer.fromJson<String?>(json['albumUuid']),
      photoPrompt: serializer.fromJson<String>(json['photoPrompt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'note': serializer.toJson<String?>(note),
      'weeks': serializer.toJson<int?>(weeks),
      'commitmentUuid': serializer.toJson<String?>(commitmentUuid),
      'albumUuid': serializer.toJson<String?>(albumUuid),
      'photoPrompt': serializer.toJson<String>(photoPrompt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ProgramRow copyWith({
    String? uuid,
    String? name,
    Value<String?> note = const Value.absent(),
    Value<int?> weeks = const Value.absent(),
    Value<String?> commitmentUuid = const Value.absent(),
    Value<String?> albumUuid = const Value.absent(),
    String? photoPrompt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ProgramRow(
    uuid: uuid ?? this.uuid,
    name: name ?? this.name,
    note: note.present ? note.value : this.note,
    weeks: weeks.present ? weeks.value : this.weeks,
    commitmentUuid: commitmentUuid.present
        ? commitmentUuid.value
        : this.commitmentUuid,
    albumUuid: albumUuid.present ? albumUuid.value : this.albumUuid,
    photoPrompt: photoPrompt ?? this.photoPrompt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ProgramRow copyWithCompanion(ProgramsCompanion data) {
    return ProgramRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      note: data.note.present ? data.note.value : this.note,
      weeks: data.weeks.present ? data.weeks.value : this.weeks,
      commitmentUuid: data.commitmentUuid.present
          ? data.commitmentUuid.value
          : this.commitmentUuid,
      albumUuid: data.albumUuid.present ? data.albumUuid.value : this.albumUuid,
      photoPrompt: data.photoPrompt.present
          ? data.photoPrompt.value
          : this.photoPrompt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgramRow(')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('note: $note, ')
          ..write('weeks: $weeks, ')
          ..write('commitmentUuid: $commitmentUuid, ')
          ..write('albumUuid: $albumUuid, ')
          ..write('photoPrompt: $photoPrompt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    name,
    note,
    weeks,
    commitmentUuid,
    albumUuid,
    photoPrompt,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgramRow &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.note == this.note &&
          other.weeks == this.weeks &&
          other.commitmentUuid == this.commitmentUuid &&
          other.albumUuid == this.albumUuid &&
          other.photoPrompt == this.photoPrompt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ProgramsCompanion extends UpdateCompanion<ProgramRow> {
  final Value<String> uuid;
  final Value<String> name;
  final Value<String?> note;
  final Value<int?> weeks;
  final Value<String?> commitmentUuid;
  final Value<String?> albumUuid;
  final Value<String> photoPrompt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ProgramsCompanion({
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.note = const Value.absent(),
    this.weeks = const Value.absent(),
    this.commitmentUuid = const Value.absent(),
    this.albumUuid = const Value.absent(),
    this.photoPrompt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgramsCompanion.insert({
    required String uuid,
    required String name,
    this.note = const Value.absent(),
    this.weeks = const Value.absent(),
    this.commitmentUuid = const Value.absent(),
    this.albumUuid = const Value.absent(),
    this.photoPrompt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       name = Value(name);
  static Insertable<ProgramRow> custom({
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? note,
    Expression<int>? weeks,
    Expression<String>? commitmentUuid,
    Expression<String>? albumUuid,
    Expression<String>? photoPrompt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (note != null) 'note': note,
      if (weeks != null) 'weeks': weeks,
      if (commitmentUuid != null) 'commitment_uuid': commitmentUuid,
      if (albumUuid != null) 'album_uuid': albumUuid,
      if (photoPrompt != null) 'photo_prompt': photoPrompt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgramsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? name,
    Value<String?>? note,
    Value<int?>? weeks,
    Value<String?>? commitmentUuid,
    Value<String?>? albumUuid,
    Value<String>? photoPrompt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ProgramsCompanion(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      note: note ?? this.note,
      weeks: weeks ?? this.weeks,
      commitmentUuid: commitmentUuid ?? this.commitmentUuid,
      albumUuid: albumUuid ?? this.albumUuid,
      photoPrompt: photoPrompt ?? this.photoPrompt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (weeks.present) {
      map['weeks'] = Variable<int>(weeks.value);
    }
    if (commitmentUuid.present) {
      map['commitment_uuid'] = Variable<String>(commitmentUuid.value);
    }
    if (albumUuid.present) {
      map['album_uuid'] = Variable<String>(albumUuid.value);
    }
    if (photoPrompt.present) {
      map['photo_prompt'] = Variable<String>(photoPrompt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgramsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('note: $note, ')
          ..write('weeks: $weeks, ')
          ..write('commitmentUuid: $commitmentUuid, ')
          ..write('albumUuid: $albumUuid, ')
          ..write('photoPrompt: $photoPrompt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgramDaysTable extends ProgramDays
    with TableInfo<$ProgramDaysTable, ProgramDayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgramDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _programUuidMeta = const VerificationMeta(
    'programUuid',
  );
  @override
  late final GeneratedColumn<String> programUuid = GeneratedColumn<String>(
    'program_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES programs (uuid)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekMeta = const VerificationMeta('week');
  @override
  late final GeneratedColumn<int> week = GeneratedColumn<int>(
    'week',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accessoriesMeta = const VerificationMeta(
    'accessories',
  );
  @override
  late final GeneratedColumn<String> accessories = GeneratedColumn<String>(
    'accessories',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    programUuid,
    name,
    position,
    week,
    accessories,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'program_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgramDayRow> instance, {
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
    if (data.containsKey('program_uuid')) {
      context.handle(
        _programUuidMeta,
        programUuid.isAcceptableOrUnknown(
          data['program_uuid']!,
          _programUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_programUuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('week')) {
      context.handle(
        _weekMeta,
        week.isAcceptableOrUnknown(data['week']!, _weekMeta),
      );
    }
    if (data.containsKey('accessories')) {
      context.handle(
        _accessoriesMeta,
        accessories.isAcceptableOrUnknown(
          data['accessories']!,
          _accessoriesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  ProgramDayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgramDayRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      programUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}program_uuid'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      week: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}week'],
      ),
      accessories: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accessories'],
      ),
    );
  }

  @override
  $ProgramDaysTable createAlias(String alias) {
    return $ProgramDaysTable(attachedDatabase, alias);
  }
}

class ProgramDayRow extends DataClass implements Insertable<ProgramDayRow> {
  final String uuid;
  final String programUuid;
  final String name;
  final int position;

  /// Which week of the cycle, for a program that has them.
  final int? week;

  /// Free text: "Back, Abs". A note, not a prescription.
  final String? accessories;
  const ProgramDayRow({
    required this.uuid,
    required this.programUuid,
    required this.name,
    required this.position,
    this.week,
    this.accessories,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['program_uuid'] = Variable<String>(programUuid);
    map['name'] = Variable<String>(name);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || week != null) {
      map['week'] = Variable<int>(week);
    }
    if (!nullToAbsent || accessories != null) {
      map['accessories'] = Variable<String>(accessories);
    }
    return map;
  }

  ProgramDaysCompanion toCompanion(bool nullToAbsent) {
    return ProgramDaysCompanion(
      uuid: Value(uuid),
      programUuid: Value(programUuid),
      name: Value(name),
      position: Value(position),
      week: week == null && nullToAbsent ? const Value.absent() : Value(week),
      accessories: accessories == null && nullToAbsent
          ? const Value.absent()
          : Value(accessories),
    );
  }

  factory ProgramDayRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgramDayRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      programUuid: serializer.fromJson<String>(json['programUuid']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<int>(json['position']),
      week: serializer.fromJson<int?>(json['week']),
      accessories: serializer.fromJson<String?>(json['accessories']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'programUuid': serializer.toJson<String>(programUuid),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<int>(position),
      'week': serializer.toJson<int?>(week),
      'accessories': serializer.toJson<String?>(accessories),
    };
  }

  ProgramDayRow copyWith({
    String? uuid,
    String? programUuid,
    String? name,
    int? position,
    Value<int?> week = const Value.absent(),
    Value<String?> accessories = const Value.absent(),
  }) => ProgramDayRow(
    uuid: uuid ?? this.uuid,
    programUuid: programUuid ?? this.programUuid,
    name: name ?? this.name,
    position: position ?? this.position,
    week: week.present ? week.value : this.week,
    accessories: accessories.present ? accessories.value : this.accessories,
  );
  ProgramDayRow copyWithCompanion(ProgramDaysCompanion data) {
    return ProgramDayRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      programUuid: data.programUuid.present
          ? data.programUuid.value
          : this.programUuid,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
      week: data.week.present ? data.week.value : this.week,
      accessories: data.accessories.present
          ? data.accessories.value
          : this.accessories,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgramDayRow(')
          ..write('uuid: $uuid, ')
          ..write('programUuid: $programUuid, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('week: $week, ')
          ..write('accessories: $accessories')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(uuid, programUuid, name, position, week, accessories);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgramDayRow &&
          other.uuid == this.uuid &&
          other.programUuid == this.programUuid &&
          other.name == this.name &&
          other.position == this.position &&
          other.week == this.week &&
          other.accessories == this.accessories);
}

class ProgramDaysCompanion extends UpdateCompanion<ProgramDayRow> {
  final Value<String> uuid;
  final Value<String> programUuid;
  final Value<String> name;
  final Value<int> position;
  final Value<int?> week;
  final Value<String?> accessories;
  final Value<int> rowid;
  const ProgramDaysCompanion({
    this.uuid = const Value.absent(),
    this.programUuid = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.week = const Value.absent(),
    this.accessories = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgramDaysCompanion.insert({
    required String uuid,
    required String programUuid,
    required String name,
    required int position,
    this.week = const Value.absent(),
    this.accessories = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       programUuid = Value(programUuid),
       name = Value(name),
       position = Value(position);
  static Insertable<ProgramDayRow> custom({
    Expression<String>? uuid,
    Expression<String>? programUuid,
    Expression<String>? name,
    Expression<int>? position,
    Expression<int>? week,
    Expression<String>? accessories,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (programUuid != null) 'program_uuid': programUuid,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (week != null) 'week': week,
      if (accessories != null) 'accessories': accessories,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgramDaysCompanion copyWith({
    Value<String>? uuid,
    Value<String>? programUuid,
    Value<String>? name,
    Value<int>? position,
    Value<int?>? week,
    Value<String?>? accessories,
    Value<int>? rowid,
  }) {
    return ProgramDaysCompanion(
      uuid: uuid ?? this.uuid,
      programUuid: programUuid ?? this.programUuid,
      name: name ?? this.name,
      position: position ?? this.position,
      week: week ?? this.week,
      accessories: accessories ?? this.accessories,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (programUuid.present) {
      map['program_uuid'] = Variable<String>(programUuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (week.present) {
      map['week'] = Variable<int>(week.value);
    }
    if (accessories.present) {
      map['accessories'] = Variable<String>(accessories.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgramDaysCompanion(')
          ..write('uuid: $uuid, ')
          ..write('programUuid: $programUuid, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('week: $week, ')
          ..write('accessories: $accessories, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgramSlotsTable extends ProgramSlots
    with TableInfo<$ProgramSlotsTable, ProgramSlotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgramSlotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayUuidMeta = const VerificationMeta(
    'dayUuid',
  );
  @override
  late final GeneratedColumn<String> dayUuid = GeneratedColumn<String>(
    'day_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES program_days (uuid)',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restSecondsMeta = const VerificationMeta(
    'restSeconds',
  );
  @override
  late final GeneratedColumn<int> restSeconds = GeneratedColumn<int>(
    'rest_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barGramsMeta = const VerificationMeta(
    'barGrams',
  );
  @override
  late final GeneratedColumn<int> barGrams = GeneratedColumn<int>(
    'bar_grams',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(20000),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    dayUuid,
    exerciseId,
    position,
    restSeconds,
    barGrams,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'program_slots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgramSlotRow> instance, {
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
    if (data.containsKey('day_uuid')) {
      context.handle(
        _dayUuidMeta,
        dayUuid.isAcceptableOrUnknown(data['day_uuid']!, _dayUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_dayUuidMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('rest_seconds')) {
      context.handle(
        _restSecondsMeta,
        restSeconds.isAcceptableOrUnknown(
          data['rest_seconds']!,
          _restSecondsMeta,
        ),
      );
    }
    if (data.containsKey('bar_grams')) {
      context.handle(
        _barGramsMeta,
        barGrams.isAcceptableOrUnknown(data['bar_grams']!, _barGramsMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  ProgramSlotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgramSlotRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      dayUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_uuid'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      restSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_seconds'],
      ),
      barGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bar_grams'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $ProgramSlotsTable createAlias(String alias) {
    return $ProgramSlotsTable(attachedDatabase, alias);
  }
}

class ProgramSlotRow extends DataClass implements Insertable<ProgramSlotRow> {
  final String uuid;
  final String dayUuid;

  /// A catalogue id ("0001") or the uuid of one of my own exercises.
  final String exerciseId;
  final int position;
  final int? restSeconds;

  /// What the bar itself weighs. 20 kg unless told otherwise, because
  /// that is right nearly always ([[Gym]]).
  final int barGrams;
  final String? note;
  const ProgramSlotRow({
    required this.uuid,
    required this.dayUuid,
    required this.exerciseId,
    required this.position,
    this.restSeconds,
    required this.barGrams,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['day_uuid'] = Variable<String>(dayUuid);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || restSeconds != null) {
      map['rest_seconds'] = Variable<int>(restSeconds);
    }
    map['bar_grams'] = Variable<int>(barGrams);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  ProgramSlotsCompanion toCompanion(bool nullToAbsent) {
    return ProgramSlotsCompanion(
      uuid: Value(uuid),
      dayUuid: Value(dayUuid),
      exerciseId: Value(exerciseId),
      position: Value(position),
      restSeconds: restSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(restSeconds),
      barGrams: Value(barGrams),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory ProgramSlotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgramSlotRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      dayUuid: serializer.fromJson<String>(json['dayUuid']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      position: serializer.fromJson<int>(json['position']),
      restSeconds: serializer.fromJson<int?>(json['restSeconds']),
      barGrams: serializer.fromJson<int>(json['barGrams']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'dayUuid': serializer.toJson<String>(dayUuid),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'position': serializer.toJson<int>(position),
      'restSeconds': serializer.toJson<int?>(restSeconds),
      'barGrams': serializer.toJson<int>(barGrams),
      'note': serializer.toJson<String?>(note),
    };
  }

  ProgramSlotRow copyWith({
    String? uuid,
    String? dayUuid,
    String? exerciseId,
    int? position,
    Value<int?> restSeconds = const Value.absent(),
    int? barGrams,
    Value<String?> note = const Value.absent(),
  }) => ProgramSlotRow(
    uuid: uuid ?? this.uuid,
    dayUuid: dayUuid ?? this.dayUuid,
    exerciseId: exerciseId ?? this.exerciseId,
    position: position ?? this.position,
    restSeconds: restSeconds.present ? restSeconds.value : this.restSeconds,
    barGrams: barGrams ?? this.barGrams,
    note: note.present ? note.value : this.note,
  );
  ProgramSlotRow copyWithCompanion(ProgramSlotsCompanion data) {
    return ProgramSlotRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      dayUuid: data.dayUuid.present ? data.dayUuid.value : this.dayUuid,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      position: data.position.present ? data.position.value : this.position,
      restSeconds: data.restSeconds.present
          ? data.restSeconds.value
          : this.restSeconds,
      barGrams: data.barGrams.present ? data.barGrams.value : this.barGrams,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgramSlotRow(')
          ..write('uuid: $uuid, ')
          ..write('dayUuid: $dayUuid, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('position: $position, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('barGrams: $barGrams, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    dayUuid,
    exerciseId,
    position,
    restSeconds,
    barGrams,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgramSlotRow &&
          other.uuid == this.uuid &&
          other.dayUuid == this.dayUuid &&
          other.exerciseId == this.exerciseId &&
          other.position == this.position &&
          other.restSeconds == this.restSeconds &&
          other.barGrams == this.barGrams &&
          other.note == this.note);
}

class ProgramSlotsCompanion extends UpdateCompanion<ProgramSlotRow> {
  final Value<String> uuid;
  final Value<String> dayUuid;
  final Value<String> exerciseId;
  final Value<int> position;
  final Value<int?> restSeconds;
  final Value<int> barGrams;
  final Value<String?> note;
  final Value<int> rowid;
  const ProgramSlotsCompanion({
    this.uuid = const Value.absent(),
    this.dayUuid = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.position = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.barGrams = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgramSlotsCompanion.insert({
    required String uuid,
    required String dayUuid,
    required String exerciseId,
    required int position,
    this.restSeconds = const Value.absent(),
    this.barGrams = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       dayUuid = Value(dayUuid),
       exerciseId = Value(exerciseId),
       position = Value(position);
  static Insertable<ProgramSlotRow> custom({
    Expression<String>? uuid,
    Expression<String>? dayUuid,
    Expression<String>? exerciseId,
    Expression<int>? position,
    Expression<int>? restSeconds,
    Expression<int>? barGrams,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (dayUuid != null) 'day_uuid': dayUuid,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (position != null) 'position': position,
      if (restSeconds != null) 'rest_seconds': restSeconds,
      if (barGrams != null) 'bar_grams': barGrams,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgramSlotsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? dayUuid,
    Value<String>? exerciseId,
    Value<int>? position,
    Value<int?>? restSeconds,
    Value<int>? barGrams,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return ProgramSlotsCompanion(
      uuid: uuid ?? this.uuid,
      dayUuid: dayUuid ?? this.dayUuid,
      exerciseId: exerciseId ?? this.exerciseId,
      position: position ?? this.position,
      restSeconds: restSeconds ?? this.restSeconds,
      barGrams: barGrams ?? this.barGrams,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (dayUuid.present) {
      map['day_uuid'] = Variable<String>(dayUuid.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (restSeconds.present) {
      map['rest_seconds'] = Variable<int>(restSeconds.value);
    }
    if (barGrams.present) {
      map['bar_grams'] = Variable<int>(barGrams.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgramSlotsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('dayUuid: $dayUuid, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('position: $position, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('barGrams: $barGrams, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TargetSetsTable extends TargetSets
    with TableInfo<$TargetSetsTable, TargetSetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TargetSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotUuidMeta = const VerificationMeta(
    'slotUuid',
  );
  @override
  late final GeneratedColumn<String> slotUuid = GeneratedColumn<String>(
    'slot_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES program_slots (uuid)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightGramsMeta = const VerificationMeta(
    'weightGrams',
  );
  @override
  late final GeneratedColumn<int> weightGrams = GeneratedColumn<int>(
    'weight_grams',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _percentTenthsMeta = const VerificationMeta(
    'percentTenths',
  );
  @override
  late final GeneratedColumn<int> percentTenths = GeneratedColumn<int>(
    'percent_tenths',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _openEndedMeta = const VerificationMeta(
    'openEnded',
  );
  @override
  late final GeneratedColumn<bool> openEnded = GeneratedColumn<bool>(
    'open_ended',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("open_ended" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    slotUuid,
    position,
    reps,
    weightGrams,
    percentTenths,
    openEnded,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'target_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<TargetSetRow> instance, {
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
    if (data.containsKey('slot_uuid')) {
      context.handle(
        _slotUuidMeta,
        slotUuid.isAcceptableOrUnknown(data['slot_uuid']!, _slotUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_slotUuidMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('weight_grams')) {
      context.handle(
        _weightGramsMeta,
        weightGrams.isAcceptableOrUnknown(
          data['weight_grams']!,
          _weightGramsMeta,
        ),
      );
    }
    if (data.containsKey('percent_tenths')) {
      context.handle(
        _percentTenthsMeta,
        percentTenths.isAcceptableOrUnknown(
          data['percent_tenths']!,
          _percentTenthsMeta,
        ),
      );
    }
    if (data.containsKey('open_ended')) {
      context.handle(
        _openEndedMeta,
        openEnded.isAcceptableOrUnknown(data['open_ended']!, _openEndedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  TargetSetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TargetSetRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      slotUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot_uuid'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      ),
      weightGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weight_grams'],
      ),
      percentTenths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}percent_tenths'],
      ),
      openEnded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}open_ended'],
      )!,
    );
  }

  @override
  $TargetSetsTable createAlias(String alias) {
    return $TargetSetsTable(attachedDatabase, alias);
  }
}

class TargetSetRow extends DataClass implements Insertable<TargetSetRow> {
  final String uuid;
  final String slotUuid;
  final int position;

  /// Null on an open set — "as many as I can".
  final int? reps;

  /// Exactly one of these two carries the load.
  final int? weightGrams;

  /// Percent of the exercise's training max, ×10 so 82.5% is 825.
  final int? percentTenths;

  /// `1+` / AMRAP — the set that decides whether the weight goes up.
  final bool openEnded;
  const TargetSetRow({
    required this.uuid,
    required this.slotUuid,
    required this.position,
    this.reps,
    this.weightGrams,
    this.percentTenths,
    required this.openEnded,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['slot_uuid'] = Variable<String>(slotUuid);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || reps != null) {
      map['reps'] = Variable<int>(reps);
    }
    if (!nullToAbsent || weightGrams != null) {
      map['weight_grams'] = Variable<int>(weightGrams);
    }
    if (!nullToAbsent || percentTenths != null) {
      map['percent_tenths'] = Variable<int>(percentTenths);
    }
    map['open_ended'] = Variable<bool>(openEnded);
    return map;
  }

  TargetSetsCompanion toCompanion(bool nullToAbsent) {
    return TargetSetsCompanion(
      uuid: Value(uuid),
      slotUuid: Value(slotUuid),
      position: Value(position),
      reps: reps == null && nullToAbsent ? const Value.absent() : Value(reps),
      weightGrams: weightGrams == null && nullToAbsent
          ? const Value.absent()
          : Value(weightGrams),
      percentTenths: percentTenths == null && nullToAbsent
          ? const Value.absent()
          : Value(percentTenths),
      openEnded: Value(openEnded),
    );
  }

  factory TargetSetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TargetSetRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      slotUuid: serializer.fromJson<String>(json['slotUuid']),
      position: serializer.fromJson<int>(json['position']),
      reps: serializer.fromJson<int?>(json['reps']),
      weightGrams: serializer.fromJson<int?>(json['weightGrams']),
      percentTenths: serializer.fromJson<int?>(json['percentTenths']),
      openEnded: serializer.fromJson<bool>(json['openEnded']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'slotUuid': serializer.toJson<String>(slotUuid),
      'position': serializer.toJson<int>(position),
      'reps': serializer.toJson<int?>(reps),
      'weightGrams': serializer.toJson<int?>(weightGrams),
      'percentTenths': serializer.toJson<int?>(percentTenths),
      'openEnded': serializer.toJson<bool>(openEnded),
    };
  }

  TargetSetRow copyWith({
    String? uuid,
    String? slotUuid,
    int? position,
    Value<int?> reps = const Value.absent(),
    Value<int?> weightGrams = const Value.absent(),
    Value<int?> percentTenths = const Value.absent(),
    bool? openEnded,
  }) => TargetSetRow(
    uuid: uuid ?? this.uuid,
    slotUuid: slotUuid ?? this.slotUuid,
    position: position ?? this.position,
    reps: reps.present ? reps.value : this.reps,
    weightGrams: weightGrams.present ? weightGrams.value : this.weightGrams,
    percentTenths: percentTenths.present
        ? percentTenths.value
        : this.percentTenths,
    openEnded: openEnded ?? this.openEnded,
  );
  TargetSetRow copyWithCompanion(TargetSetsCompanion data) {
    return TargetSetRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      slotUuid: data.slotUuid.present ? data.slotUuid.value : this.slotUuid,
      position: data.position.present ? data.position.value : this.position,
      reps: data.reps.present ? data.reps.value : this.reps,
      weightGrams: data.weightGrams.present
          ? data.weightGrams.value
          : this.weightGrams,
      percentTenths: data.percentTenths.present
          ? data.percentTenths.value
          : this.percentTenths,
      openEnded: data.openEnded.present ? data.openEnded.value : this.openEnded,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TargetSetRow(')
          ..write('uuid: $uuid, ')
          ..write('slotUuid: $slotUuid, ')
          ..write('position: $position, ')
          ..write('reps: $reps, ')
          ..write('weightGrams: $weightGrams, ')
          ..write('percentTenths: $percentTenths, ')
          ..write('openEnded: $openEnded')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    slotUuid,
    position,
    reps,
    weightGrams,
    percentTenths,
    openEnded,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TargetSetRow &&
          other.uuid == this.uuid &&
          other.slotUuid == this.slotUuid &&
          other.position == this.position &&
          other.reps == this.reps &&
          other.weightGrams == this.weightGrams &&
          other.percentTenths == this.percentTenths &&
          other.openEnded == this.openEnded);
}

class TargetSetsCompanion extends UpdateCompanion<TargetSetRow> {
  final Value<String> uuid;
  final Value<String> slotUuid;
  final Value<int> position;
  final Value<int?> reps;
  final Value<int?> weightGrams;
  final Value<int?> percentTenths;
  final Value<bool> openEnded;
  final Value<int> rowid;
  const TargetSetsCompanion({
    this.uuid = const Value.absent(),
    this.slotUuid = const Value.absent(),
    this.position = const Value.absent(),
    this.reps = const Value.absent(),
    this.weightGrams = const Value.absent(),
    this.percentTenths = const Value.absent(),
    this.openEnded = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TargetSetsCompanion.insert({
    required String uuid,
    required String slotUuid,
    required int position,
    this.reps = const Value.absent(),
    this.weightGrams = const Value.absent(),
    this.percentTenths = const Value.absent(),
    this.openEnded = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       slotUuid = Value(slotUuid),
       position = Value(position);
  static Insertable<TargetSetRow> custom({
    Expression<String>? uuid,
    Expression<String>? slotUuid,
    Expression<int>? position,
    Expression<int>? reps,
    Expression<int>? weightGrams,
    Expression<int>? percentTenths,
    Expression<bool>? openEnded,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (slotUuid != null) 'slot_uuid': slotUuid,
      if (position != null) 'position': position,
      if (reps != null) 'reps': reps,
      if (weightGrams != null) 'weight_grams': weightGrams,
      if (percentTenths != null) 'percent_tenths': percentTenths,
      if (openEnded != null) 'open_ended': openEnded,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TargetSetsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? slotUuid,
    Value<int>? position,
    Value<int?>? reps,
    Value<int?>? weightGrams,
    Value<int?>? percentTenths,
    Value<bool>? openEnded,
    Value<int>? rowid,
  }) {
    return TargetSetsCompanion(
      uuid: uuid ?? this.uuid,
      slotUuid: slotUuid ?? this.slotUuid,
      position: position ?? this.position,
      reps: reps ?? this.reps,
      weightGrams: weightGrams ?? this.weightGrams,
      percentTenths: percentTenths ?? this.percentTenths,
      openEnded: openEnded ?? this.openEnded,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (slotUuid.present) {
      map['slot_uuid'] = Variable<String>(slotUuid.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (weightGrams.present) {
      map['weight_grams'] = Variable<int>(weightGrams.value);
    }
    if (percentTenths.present) {
      map['percent_tenths'] = Variable<int>(percentTenths.value);
    }
    if (openEnded.present) {
      map['open_ended'] = Variable<bool>(openEnded.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TargetSetsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('slotUuid: $slotUuid, ')
          ..write('position: $position, ')
          ..write('reps: $reps, ')
          ..write('weightGrams: $weightGrams, ')
          ..write('percentTenths: $percentTenths, ')
          ..write('openEnded: $openEnded, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrainingMaxesTable extends TrainingMaxes
    with TableInfo<$TrainingMaxesTable, TrainingMaxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrainingMaxesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _programUuidMeta = const VerificationMeta(
    'programUuid',
  );
  @override
  late final GeneratedColumn<String> programUuid = GeneratedColumn<String>(
    'program_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES programs (uuid)',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gramsMeta = const VerificationMeta('grams');
  @override
  late final GeneratedColumn<int> grams = GeneratedColumn<int>(
    'grams',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  List<GeneratedColumn> get $columns => [
    programUuid,
    exerciseId,
    grams,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'training_maxes';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrainingMaxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('program_uuid')) {
      context.handle(
        _programUuidMeta,
        programUuid.isAcceptableOrUnknown(
          data['program_uuid']!,
          _programUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_programUuidMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('grams')) {
      context.handle(
        _gramsMeta,
        grams.isAcceptableOrUnknown(data['grams']!, _gramsMeta),
      );
    } else if (isInserting) {
      context.missing(_gramsMeta);
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
  Set<GeneratedColumn> get $primaryKey => {programUuid, exerciseId};
  @override
  TrainingMaxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrainingMaxRow(
      programUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}program_uuid'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      grams: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grams'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TrainingMaxesTable createAlias(String alias) {
    return $TrainingMaxesTable(attachedDatabase, alias);
  }
}

class TrainingMaxRow extends DataClass implements Insertable<TrainingMaxRow> {
  final String programUuid;
  final String exerciseId;
  final int grams;
  final DateTime updatedAt;
  const TrainingMaxRow({
    required this.programUuid,
    required this.exerciseId,
    required this.grams,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['program_uuid'] = Variable<String>(programUuid);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['grams'] = Variable<int>(grams);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TrainingMaxesCompanion toCompanion(bool nullToAbsent) {
    return TrainingMaxesCompanion(
      programUuid: Value(programUuid),
      exerciseId: Value(exerciseId),
      grams: Value(grams),
      updatedAt: Value(updatedAt),
    );
  }

  factory TrainingMaxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrainingMaxRow(
      programUuid: serializer.fromJson<String>(json['programUuid']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      grams: serializer.fromJson<int>(json['grams']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'programUuid': serializer.toJson<String>(programUuid),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'grams': serializer.toJson<int>(grams),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TrainingMaxRow copyWith({
    String? programUuid,
    String? exerciseId,
    int? grams,
    DateTime? updatedAt,
  }) => TrainingMaxRow(
    programUuid: programUuid ?? this.programUuid,
    exerciseId: exerciseId ?? this.exerciseId,
    grams: grams ?? this.grams,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TrainingMaxRow copyWithCompanion(TrainingMaxesCompanion data) {
    return TrainingMaxRow(
      programUuid: data.programUuid.present
          ? data.programUuid.value
          : this.programUuid,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      grams: data.grams.present ? data.grams.value : this.grams,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrainingMaxRow(')
          ..write('programUuid: $programUuid, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('grams: $grams, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(programUuid, exerciseId, grams, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrainingMaxRow &&
          other.programUuid == this.programUuid &&
          other.exerciseId == this.exerciseId &&
          other.grams == this.grams &&
          other.updatedAt == this.updatedAt);
}

class TrainingMaxesCompanion extends UpdateCompanion<TrainingMaxRow> {
  final Value<String> programUuid;
  final Value<String> exerciseId;
  final Value<int> grams;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TrainingMaxesCompanion({
    this.programUuid = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.grams = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrainingMaxesCompanion.insert({
    required String programUuid,
    required String exerciseId,
    required int grams,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : programUuid = Value(programUuid),
       exerciseId = Value(exerciseId),
       grams = Value(grams);
  static Insertable<TrainingMaxRow> custom({
    Expression<String>? programUuid,
    Expression<String>? exerciseId,
    Expression<int>? grams,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (programUuid != null) 'program_uuid': programUuid,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (grams != null) 'grams': grams,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrainingMaxesCompanion copyWith({
    Value<String>? programUuid,
    Value<String>? exerciseId,
    Value<int>? grams,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TrainingMaxesCompanion(
      programUuid: programUuid ?? this.programUuid,
      exerciseId: exerciseId ?? this.exerciseId,
      grams: grams ?? this.grams,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (programUuid.present) {
      map['program_uuid'] = Variable<String>(programUuid.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (grams.present) {
      map['grams'] = Variable<int>(grams.value);
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
    return (StringBuffer('TrainingMaxesCompanion(')
          ..write('programUuid: $programUuid, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('grams: $grams, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSessionsTable extends WorkoutSessions
    with TableInfo<$WorkoutSessionsTable, WorkoutSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _programUuidMeta = const VerificationMeta(
    'programUuid',
  );
  @override
  late final GeneratedColumn<String> programUuid = GeneratedColumn<String>(
    'program_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayUuidMeta = const VerificationMeta(
    'dayUuid',
  );
  @override
  late final GeneratedColumn<String> dayUuid = GeneratedColumn<String>(
    'day_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    programUuid,
    dayUuid,
    title,
    harvestDay,
    startedAt,
    endedAt,
    note,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSessionRow> instance, {
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
    if (data.containsKey('program_uuid')) {
      context.handle(
        _programUuidMeta,
        programUuid.isAcceptableOrUnknown(
          data['program_uuid']!,
          _programUuidMeta,
        ),
      );
    }
    if (data.containsKey('day_uuid')) {
      context.handle(
        _dayUuidMeta,
        dayUuid.isAcceptableOrUnknown(data['day_uuid']!, _dayUuidMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
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
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  WorkoutSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSessionRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      programUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}program_uuid'],
      ),
      dayUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_uuid'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
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
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $WorkoutSessionsTable createAlias(String alias) {
    return $WorkoutSessionsTable(attachedDatabase, alias);
  }
}

class WorkoutSessionRow extends DataClass
    implements Insertable<WorkoutSessionRow> {
  final String uuid;
  final String? programUuid;
  final String? dayUuid;

  /// Kept as text so a session survives its program being deleted.
  final String? title;
  final String harvestDay;
  final DateTime startedAt;

  /// Null while the session is still running — which is how an
  /// interrupted workout is found and resumed ([[Gym]] rule Y3).
  final DateTime? endedAt;
  final String? note;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const WorkoutSessionRow({
    required this.uuid,
    this.programUuid,
    this.dayUuid,
    this.title,
    required this.harvestDay,
    required this.startedAt,
    this.endedAt,
    this.note,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    if (!nullToAbsent || programUuid != null) {
      map['program_uuid'] = Variable<String>(programUuid);
    }
    if (!nullToAbsent || dayUuid != null) {
      map['day_uuid'] = Variable<String>(dayUuid);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['harvest_day'] = Variable<String>(harvestDay);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  WorkoutSessionsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSessionsCompanion(
      uuid: Value(uuid),
      programUuid: programUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(programUuid),
      dayUuid: dayUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(dayUuid),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      harvestDay: Value(harvestDay),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory WorkoutSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSessionRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      programUuid: serializer.fromJson<String?>(json['programUuid']),
      dayUuid: serializer.fromJson<String?>(json['dayUuid']),
      title: serializer.fromJson<String?>(json['title']),
      harvestDay: serializer.fromJson<String>(json['harvestDay']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      note: serializer.fromJson<String?>(json['note']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'programUuid': serializer.toJson<String?>(programUuid),
      'dayUuid': serializer.toJson<String?>(dayUuid),
      'title': serializer.toJson<String?>(title),
      'harvestDay': serializer.toJson<String>(harvestDay),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'note': serializer.toJson<String?>(note),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  WorkoutSessionRow copyWith({
    String? uuid,
    Value<String?> programUuid = const Value.absent(),
    Value<String?> dayUuid = const Value.absent(),
    Value<String?> title = const Value.absent(),
    String? harvestDay,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => WorkoutSessionRow(
    uuid: uuid ?? this.uuid,
    programUuid: programUuid.present ? programUuid.value : this.programUuid,
    dayUuid: dayUuid.present ? dayUuid.value : this.dayUuid,
    title: title.present ? title.value : this.title,
    harvestDay: harvestDay ?? this.harvestDay,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    note: note.present ? note.value : this.note,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  WorkoutSessionRow copyWithCompanion(WorkoutSessionsCompanion data) {
    return WorkoutSessionRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      programUuid: data.programUuid.present
          ? data.programUuid.value
          : this.programUuid,
      dayUuid: data.dayUuid.present ? data.dayUuid.value : this.dayUuid,
      title: data.title.present ? data.title.value : this.title,
      harvestDay: data.harvestDay.present
          ? data.harvestDay.value
          : this.harvestDay,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      note: data.note.present ? data.note.value : this.note,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSessionRow(')
          ..write('uuid: $uuid, ')
          ..write('programUuid: $programUuid, ')
          ..write('dayUuid: $dayUuid, ')
          ..write('title: $title, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('note: $note, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    programUuid,
    dayUuid,
    title,
    harvestDay,
    startedAt,
    endedAt,
    note,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSessionRow &&
          other.uuid == this.uuid &&
          other.programUuid == this.programUuid &&
          other.dayUuid == this.dayUuid &&
          other.title == this.title &&
          other.harvestDay == this.harvestDay &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.note == this.note &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class WorkoutSessionsCompanion extends UpdateCompanion<WorkoutSessionRow> {
  final Value<String> uuid;
  final Value<String?> programUuid;
  final Value<String?> dayUuid;
  final Value<String?> title;
  final Value<String> harvestDay;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String?> note;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const WorkoutSessionsCompanion({
    this.uuid = const Value.absent(),
    this.programUuid = const Value.absent(),
    this.dayUuid = const Value.absent(),
    this.title = const Value.absent(),
    this.harvestDay = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutSessionsCompanion.insert({
    required String uuid,
    this.programUuid = const Value.absent(),
    this.dayUuid = const Value.absent(),
    this.title = const Value.absent(),
    required String harvestDay,
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       harvestDay = Value(harvestDay);
  static Insertable<WorkoutSessionRow> custom({
    Expression<String>? uuid,
    Expression<String>? programUuid,
    Expression<String>? dayUuid,
    Expression<String>? title,
    Expression<String>? harvestDay,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? note,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (programUuid != null) 'program_uuid': programUuid,
      if (dayUuid != null) 'day_uuid': dayUuid,
      if (title != null) 'title': title,
      if (harvestDay != null) 'harvest_day': harvestDay,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (note != null) 'note': note,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutSessionsCompanion copyWith({
    Value<String>? uuid,
    Value<String?>? programUuid,
    Value<String?>? dayUuid,
    Value<String?>? title,
    Value<String>? harvestDay,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<String?>? note,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return WorkoutSessionsCompanion(
      uuid: uuid ?? this.uuid,
      programUuid: programUuid ?? this.programUuid,
      dayUuid: dayUuid ?? this.dayUuid,
      title: title ?? this.title,
      harvestDay: harvestDay ?? this.harvestDay,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (programUuid.present) {
      map['program_uuid'] = Variable<String>(programUuid.value);
    }
    if (dayUuid.present) {
      map['day_uuid'] = Variable<String>(dayUuid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
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
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSessionsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('programUuid: $programUuid, ')
          ..write('dayUuid: $dayUuid, ')
          ..write('title: $title, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('note: $note, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionExercisesTable extends SessionExercises
    with TableInfo<$SessionExercisesTable, SessionExerciseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionUuidMeta = const VerificationMeta(
    'sessionUuid',
  );
  @override
  late final GeneratedColumn<String> sessionUuid = GeneratedColumn<String>(
    'session_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_sessions (uuid)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plannedExerciseIdMeta = const VerificationMeta(
    'plannedExerciseId',
  );
  @override
  late final GeneratedColumn<String> plannedExerciseId =
      GeneratedColumn<String>(
        'planned_exercise_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _slotUuidMeta = const VerificationMeta(
    'slotUuid',
  );
  @override
  late final GeneratedColumn<String> slotUuid = GeneratedColumn<String>(
    'slot_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _skippedMeta = const VerificationMeta(
    'skipped',
  );
  @override
  late final GeneratedColumn<bool> skipped = GeneratedColumn<bool>(
    'skipped',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("skipped" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _restSecondsMeta = const VerificationMeta(
    'restSeconds',
  );
  @override
  late final GeneratedColumn<int> restSeconds = GeneratedColumn<int>(
    'rest_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barGramsMeta = const VerificationMeta(
    'barGrams',
  );
  @override
  late final GeneratedColumn<int> barGrams = GeneratedColumn<int>(
    'bar_grams',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(20000),
  );
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    sessionUuid,
    position,
    exerciseId,
    plannedExerciseId,
    slotUuid,
    skipped,
    note,
    restSeconds,
    barGrams,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionExerciseRow> instance, {
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
    if (data.containsKey('session_uuid')) {
      context.handle(
        _sessionUuidMeta,
        sessionUuid.isAcceptableOrUnknown(
          data['session_uuid']!,
          _sessionUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sessionUuidMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('planned_exercise_id')) {
      context.handle(
        _plannedExerciseIdMeta,
        plannedExerciseId.isAcceptableOrUnknown(
          data['planned_exercise_id']!,
          _plannedExerciseIdMeta,
        ),
      );
    }
    if (data.containsKey('slot_uuid')) {
      context.handle(
        _slotUuidMeta,
        slotUuid.isAcceptableOrUnknown(data['slot_uuid']!, _slotUuidMeta),
      );
    }
    if (data.containsKey('skipped')) {
      context.handle(
        _skippedMeta,
        skipped.isAcceptableOrUnknown(data['skipped']!, _skippedMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('rest_seconds')) {
      context.handle(
        _restSecondsMeta,
        restSeconds.isAcceptableOrUnknown(
          data['rest_seconds']!,
          _restSecondsMeta,
        ),
      );
    }
    if (data.containsKey('bar_grams')) {
      context.handle(
        _barGramsMeta,
        barGrams.isAcceptableOrUnknown(data['bar_grams']!, _barGramsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  SessionExerciseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionExerciseRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      sessionUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_uuid'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      plannedExerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}planned_exercise_id'],
      ),
      slotUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot_uuid'],
      ),
      skipped: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}skipped'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      restSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_seconds'],
      ),
      barGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bar_grams'],
      )!,
    );
  }

  @override
  $SessionExercisesTable createAlias(String alias) {
    return $SessionExercisesTable(attachedDatabase, alias);
  }
}

class SessionExerciseRow extends DataClass
    implements Insertable<SessionExerciseRow> {
  final String uuid;
  final String sessionUuid;
  final int position;

  /// What I actually did.
  final String exerciseId;

  /// What the program asked for, when that is not the same thing.
  final String? plannedExerciseId;
  final String? slotUuid;
  final bool skipped;
  final String? note;
  final int? restSeconds;
  final int barGrams;
  const SessionExerciseRow({
    required this.uuid,
    required this.sessionUuid,
    required this.position,
    required this.exerciseId,
    this.plannedExerciseId,
    this.slotUuid,
    required this.skipped,
    this.note,
    this.restSeconds,
    required this.barGrams,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['session_uuid'] = Variable<String>(sessionUuid);
    map['position'] = Variable<int>(position);
    map['exercise_id'] = Variable<String>(exerciseId);
    if (!nullToAbsent || plannedExerciseId != null) {
      map['planned_exercise_id'] = Variable<String>(plannedExerciseId);
    }
    if (!nullToAbsent || slotUuid != null) {
      map['slot_uuid'] = Variable<String>(slotUuid);
    }
    map['skipped'] = Variable<bool>(skipped);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || restSeconds != null) {
      map['rest_seconds'] = Variable<int>(restSeconds);
    }
    map['bar_grams'] = Variable<int>(barGrams);
    return map;
  }

  SessionExercisesCompanion toCompanion(bool nullToAbsent) {
    return SessionExercisesCompanion(
      uuid: Value(uuid),
      sessionUuid: Value(sessionUuid),
      position: Value(position),
      exerciseId: Value(exerciseId),
      plannedExerciseId: plannedExerciseId == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedExerciseId),
      slotUuid: slotUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(slotUuid),
      skipped: Value(skipped),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      restSeconds: restSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(restSeconds),
      barGrams: Value(barGrams),
    );
  }

  factory SessionExerciseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionExerciseRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      sessionUuid: serializer.fromJson<String>(json['sessionUuid']),
      position: serializer.fromJson<int>(json['position']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      plannedExerciseId: serializer.fromJson<String?>(
        json['plannedExerciseId'],
      ),
      slotUuid: serializer.fromJson<String?>(json['slotUuid']),
      skipped: serializer.fromJson<bool>(json['skipped']),
      note: serializer.fromJson<String?>(json['note']),
      restSeconds: serializer.fromJson<int?>(json['restSeconds']),
      barGrams: serializer.fromJson<int>(json['barGrams']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'sessionUuid': serializer.toJson<String>(sessionUuid),
      'position': serializer.toJson<int>(position),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'plannedExerciseId': serializer.toJson<String?>(plannedExerciseId),
      'slotUuid': serializer.toJson<String?>(slotUuid),
      'skipped': serializer.toJson<bool>(skipped),
      'note': serializer.toJson<String?>(note),
      'restSeconds': serializer.toJson<int?>(restSeconds),
      'barGrams': serializer.toJson<int>(barGrams),
    };
  }

  SessionExerciseRow copyWith({
    String? uuid,
    String? sessionUuid,
    int? position,
    String? exerciseId,
    Value<String?> plannedExerciseId = const Value.absent(),
    Value<String?> slotUuid = const Value.absent(),
    bool? skipped,
    Value<String?> note = const Value.absent(),
    Value<int?> restSeconds = const Value.absent(),
    int? barGrams,
  }) => SessionExerciseRow(
    uuid: uuid ?? this.uuid,
    sessionUuid: sessionUuid ?? this.sessionUuid,
    position: position ?? this.position,
    exerciseId: exerciseId ?? this.exerciseId,
    plannedExerciseId: plannedExerciseId.present
        ? plannedExerciseId.value
        : this.plannedExerciseId,
    slotUuid: slotUuid.present ? slotUuid.value : this.slotUuid,
    skipped: skipped ?? this.skipped,
    note: note.present ? note.value : this.note,
    restSeconds: restSeconds.present ? restSeconds.value : this.restSeconds,
    barGrams: barGrams ?? this.barGrams,
  );
  SessionExerciseRow copyWithCompanion(SessionExercisesCompanion data) {
    return SessionExerciseRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      sessionUuid: data.sessionUuid.present
          ? data.sessionUuid.value
          : this.sessionUuid,
      position: data.position.present ? data.position.value : this.position,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      plannedExerciseId: data.plannedExerciseId.present
          ? data.plannedExerciseId.value
          : this.plannedExerciseId,
      slotUuid: data.slotUuid.present ? data.slotUuid.value : this.slotUuid,
      skipped: data.skipped.present ? data.skipped.value : this.skipped,
      note: data.note.present ? data.note.value : this.note,
      restSeconds: data.restSeconds.present
          ? data.restSeconds.value
          : this.restSeconds,
      barGrams: data.barGrams.present ? data.barGrams.value : this.barGrams,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionExerciseRow(')
          ..write('uuid: $uuid, ')
          ..write('sessionUuid: $sessionUuid, ')
          ..write('position: $position, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('plannedExerciseId: $plannedExerciseId, ')
          ..write('slotUuid: $slotUuid, ')
          ..write('skipped: $skipped, ')
          ..write('note: $note, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('barGrams: $barGrams')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    sessionUuid,
    position,
    exerciseId,
    plannedExerciseId,
    slotUuid,
    skipped,
    note,
    restSeconds,
    barGrams,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionExerciseRow &&
          other.uuid == this.uuid &&
          other.sessionUuid == this.sessionUuid &&
          other.position == this.position &&
          other.exerciseId == this.exerciseId &&
          other.plannedExerciseId == this.plannedExerciseId &&
          other.slotUuid == this.slotUuid &&
          other.skipped == this.skipped &&
          other.note == this.note &&
          other.restSeconds == this.restSeconds &&
          other.barGrams == this.barGrams);
}

class SessionExercisesCompanion extends UpdateCompanion<SessionExerciseRow> {
  final Value<String> uuid;
  final Value<String> sessionUuid;
  final Value<int> position;
  final Value<String> exerciseId;
  final Value<String?> plannedExerciseId;
  final Value<String?> slotUuid;
  final Value<bool> skipped;
  final Value<String?> note;
  final Value<int?> restSeconds;
  final Value<int> barGrams;
  final Value<int> rowid;
  const SessionExercisesCompanion({
    this.uuid = const Value.absent(),
    this.sessionUuid = const Value.absent(),
    this.position = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.plannedExerciseId = const Value.absent(),
    this.slotUuid = const Value.absent(),
    this.skipped = const Value.absent(),
    this.note = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.barGrams = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionExercisesCompanion.insert({
    required String uuid,
    required String sessionUuid,
    required int position,
    required String exerciseId,
    this.plannedExerciseId = const Value.absent(),
    this.slotUuid = const Value.absent(),
    this.skipped = const Value.absent(),
    this.note = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.barGrams = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       sessionUuid = Value(sessionUuid),
       position = Value(position),
       exerciseId = Value(exerciseId);
  static Insertable<SessionExerciseRow> custom({
    Expression<String>? uuid,
    Expression<String>? sessionUuid,
    Expression<int>? position,
    Expression<String>? exerciseId,
    Expression<String>? plannedExerciseId,
    Expression<String>? slotUuid,
    Expression<bool>? skipped,
    Expression<String>? note,
    Expression<int>? restSeconds,
    Expression<int>? barGrams,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (sessionUuid != null) 'session_uuid': sessionUuid,
      if (position != null) 'position': position,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (plannedExerciseId != null) 'planned_exercise_id': plannedExerciseId,
      if (slotUuid != null) 'slot_uuid': slotUuid,
      if (skipped != null) 'skipped': skipped,
      if (note != null) 'note': note,
      if (restSeconds != null) 'rest_seconds': restSeconds,
      if (barGrams != null) 'bar_grams': barGrams,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionExercisesCompanion copyWith({
    Value<String>? uuid,
    Value<String>? sessionUuid,
    Value<int>? position,
    Value<String>? exerciseId,
    Value<String?>? plannedExerciseId,
    Value<String?>? slotUuid,
    Value<bool>? skipped,
    Value<String?>? note,
    Value<int?>? restSeconds,
    Value<int>? barGrams,
    Value<int>? rowid,
  }) {
    return SessionExercisesCompanion(
      uuid: uuid ?? this.uuid,
      sessionUuid: sessionUuid ?? this.sessionUuid,
      position: position ?? this.position,
      exerciseId: exerciseId ?? this.exerciseId,
      plannedExerciseId: plannedExerciseId ?? this.plannedExerciseId,
      slotUuid: slotUuid ?? this.slotUuid,
      skipped: skipped ?? this.skipped,
      note: note ?? this.note,
      restSeconds: restSeconds ?? this.restSeconds,
      barGrams: barGrams ?? this.barGrams,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (sessionUuid.present) {
      map['session_uuid'] = Variable<String>(sessionUuid.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (plannedExerciseId.present) {
      map['planned_exercise_id'] = Variable<String>(plannedExerciseId.value);
    }
    if (slotUuid.present) {
      map['slot_uuid'] = Variable<String>(slotUuid.value);
    }
    if (skipped.present) {
      map['skipped'] = Variable<bool>(skipped.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (restSeconds.present) {
      map['rest_seconds'] = Variable<int>(restSeconds.value);
    }
    if (barGrams.present) {
      map['bar_grams'] = Variable<int>(barGrams.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionExercisesCompanion(')
          ..write('uuid: $uuid, ')
          ..write('sessionUuid: $sessionUuid, ')
          ..write('position: $position, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('plannedExerciseId: $plannedExerciseId, ')
          ..write('slotUuid: $slotUuid, ')
          ..write('skipped: $skipped, ')
          ..write('note: $note, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('barGrams: $barGrams, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSetsTable extends WorkoutSets
    with TableInfo<$WorkoutSetsTable, WorkoutSetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionExerciseUuidMeta =
      const VerificationMeta('sessionExerciseUuid');
  @override
  late final GeneratedColumn<String> sessionExerciseUuid =
      GeneratedColumn<String>(
        'session_exercise_uuid',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES session_exercises (uuid)',
        ),
      );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightGramsMeta = const VerificationMeta(
    'weightGrams',
  );
  @override
  late final GeneratedColumn<int> weightGrams = GeneratedColumn<int>(
    'weight_grams',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _targetLabelMeta = const VerificationMeta(
    'targetLabel',
  );
  @override
  late final GeneratedColumn<String> targetLabel = GeneratedColumn<String>(
    'target_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _openEndedMeta = const VerificationMeta(
    'openEnded',
  );
  @override
  late final GeneratedColumn<bool> openEnded = GeneratedColumn<bool>(
    'open_ended',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("open_ended" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    sessionExerciseUuid,
    position,
    weightGrams,
    reps,
    done,
    targetLabel,
    openEnded,
    loggedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSetRow> instance, {
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
    if (data.containsKey('session_exercise_uuid')) {
      context.handle(
        _sessionExerciseUuidMeta,
        sessionExerciseUuid.isAcceptableOrUnknown(
          data['session_exercise_uuid']!,
          _sessionExerciseUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sessionExerciseUuidMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('weight_grams')) {
      context.handle(
        _weightGramsMeta,
        weightGrams.isAcceptableOrUnknown(
          data['weight_grams']!,
          _weightGramsMeta,
        ),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('target_label')) {
      context.handle(
        _targetLabelMeta,
        targetLabel.isAcceptableOrUnknown(
          data['target_label']!,
          _targetLabelMeta,
        ),
      );
    }
    if (data.containsKey('open_ended')) {
      context.handle(
        _openEndedMeta,
        openEnded.isAcceptableOrUnknown(data['open_ended']!, _openEndedMeta),
      );
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
  WorkoutSetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSetRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      sessionExerciseUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_exercise_uuid'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      weightGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weight_grams'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      targetLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_label'],
      ),
      openEnded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}open_ended'],
      )!,
      loggedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logged_at'],
      )!,
    );
  }

  @override
  $WorkoutSetsTable createAlias(String alias) {
    return $WorkoutSetsTable(attachedDatabase, alias);
  }
}

class WorkoutSetRow extends DataClass implements Insertable<WorkoutSetRow> {
  final String uuid;
  final String sessionExerciseUuid;
  final int position;
  final int weightGrams;
  final int reps;
  final bool done;

  /// What this set was asked to be, kept so "did I hit the target?" is
  /// answerable a year later without the program still existing.
  final String? targetLabel;
  final bool openEnded;
  final DateTime loggedAt;
  const WorkoutSetRow({
    required this.uuid,
    required this.sessionExerciseUuid,
    required this.position,
    required this.weightGrams,
    required this.reps,
    required this.done,
    this.targetLabel,
    required this.openEnded,
    required this.loggedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['session_exercise_uuid'] = Variable<String>(sessionExerciseUuid);
    map['position'] = Variable<int>(position);
    map['weight_grams'] = Variable<int>(weightGrams);
    map['reps'] = Variable<int>(reps);
    map['done'] = Variable<bool>(done);
    if (!nullToAbsent || targetLabel != null) {
      map['target_label'] = Variable<String>(targetLabel);
    }
    map['open_ended'] = Variable<bool>(openEnded);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    return map;
  }

  WorkoutSetsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSetsCompanion(
      uuid: Value(uuid),
      sessionExerciseUuid: Value(sessionExerciseUuid),
      position: Value(position),
      weightGrams: Value(weightGrams),
      reps: Value(reps),
      done: Value(done),
      targetLabel: targetLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(targetLabel),
      openEnded: Value(openEnded),
      loggedAt: Value(loggedAt),
    );
  }

  factory WorkoutSetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSetRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      sessionExerciseUuid: serializer.fromJson<String>(
        json['sessionExerciseUuid'],
      ),
      position: serializer.fromJson<int>(json['position']),
      weightGrams: serializer.fromJson<int>(json['weightGrams']),
      reps: serializer.fromJson<int>(json['reps']),
      done: serializer.fromJson<bool>(json['done']),
      targetLabel: serializer.fromJson<String?>(json['targetLabel']),
      openEnded: serializer.fromJson<bool>(json['openEnded']),
      loggedAt: serializer.fromJson<DateTime>(json['loggedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'sessionExerciseUuid': serializer.toJson<String>(sessionExerciseUuid),
      'position': serializer.toJson<int>(position),
      'weightGrams': serializer.toJson<int>(weightGrams),
      'reps': serializer.toJson<int>(reps),
      'done': serializer.toJson<bool>(done),
      'targetLabel': serializer.toJson<String?>(targetLabel),
      'openEnded': serializer.toJson<bool>(openEnded),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
    };
  }

  WorkoutSetRow copyWith({
    String? uuid,
    String? sessionExerciseUuid,
    int? position,
    int? weightGrams,
    int? reps,
    bool? done,
    Value<String?> targetLabel = const Value.absent(),
    bool? openEnded,
    DateTime? loggedAt,
  }) => WorkoutSetRow(
    uuid: uuid ?? this.uuid,
    sessionExerciseUuid: sessionExerciseUuid ?? this.sessionExerciseUuid,
    position: position ?? this.position,
    weightGrams: weightGrams ?? this.weightGrams,
    reps: reps ?? this.reps,
    done: done ?? this.done,
    targetLabel: targetLabel.present ? targetLabel.value : this.targetLabel,
    openEnded: openEnded ?? this.openEnded,
    loggedAt: loggedAt ?? this.loggedAt,
  );
  WorkoutSetRow copyWithCompanion(WorkoutSetsCompanion data) {
    return WorkoutSetRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      sessionExerciseUuid: data.sessionExerciseUuid.present
          ? data.sessionExerciseUuid.value
          : this.sessionExerciseUuid,
      position: data.position.present ? data.position.value : this.position,
      weightGrams: data.weightGrams.present
          ? data.weightGrams.value
          : this.weightGrams,
      reps: data.reps.present ? data.reps.value : this.reps,
      done: data.done.present ? data.done.value : this.done,
      targetLabel: data.targetLabel.present
          ? data.targetLabel.value
          : this.targetLabel,
      openEnded: data.openEnded.present ? data.openEnded.value : this.openEnded,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetRow(')
          ..write('uuid: $uuid, ')
          ..write('sessionExerciseUuid: $sessionExerciseUuid, ')
          ..write('position: $position, ')
          ..write('weightGrams: $weightGrams, ')
          ..write('reps: $reps, ')
          ..write('done: $done, ')
          ..write('targetLabel: $targetLabel, ')
          ..write('openEnded: $openEnded, ')
          ..write('loggedAt: $loggedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    sessionExerciseUuid,
    position,
    weightGrams,
    reps,
    done,
    targetLabel,
    openEnded,
    loggedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSetRow &&
          other.uuid == this.uuid &&
          other.sessionExerciseUuid == this.sessionExerciseUuid &&
          other.position == this.position &&
          other.weightGrams == this.weightGrams &&
          other.reps == this.reps &&
          other.done == this.done &&
          other.targetLabel == this.targetLabel &&
          other.openEnded == this.openEnded &&
          other.loggedAt == this.loggedAt);
}

class WorkoutSetsCompanion extends UpdateCompanion<WorkoutSetRow> {
  final Value<String> uuid;
  final Value<String> sessionExerciseUuid;
  final Value<int> position;
  final Value<int> weightGrams;
  final Value<int> reps;
  final Value<bool> done;
  final Value<String?> targetLabel;
  final Value<bool> openEnded;
  final Value<DateTime> loggedAt;
  final Value<int> rowid;
  const WorkoutSetsCompanion({
    this.uuid = const Value.absent(),
    this.sessionExerciseUuid = const Value.absent(),
    this.position = const Value.absent(),
    this.weightGrams = const Value.absent(),
    this.reps = const Value.absent(),
    this.done = const Value.absent(),
    this.targetLabel = const Value.absent(),
    this.openEnded = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutSetsCompanion.insert({
    required String uuid,
    required String sessionExerciseUuid,
    required int position,
    this.weightGrams = const Value.absent(),
    this.reps = const Value.absent(),
    this.done = const Value.absent(),
    this.targetLabel = const Value.absent(),
    this.openEnded = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       sessionExerciseUuid = Value(sessionExerciseUuid),
       position = Value(position);
  static Insertable<WorkoutSetRow> custom({
    Expression<String>? uuid,
    Expression<String>? sessionExerciseUuid,
    Expression<int>? position,
    Expression<int>? weightGrams,
    Expression<int>? reps,
    Expression<bool>? done,
    Expression<String>? targetLabel,
    Expression<bool>? openEnded,
    Expression<DateTime>? loggedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (sessionExerciseUuid != null)
        'session_exercise_uuid': sessionExerciseUuid,
      if (position != null) 'position': position,
      if (weightGrams != null) 'weight_grams': weightGrams,
      if (reps != null) 'reps': reps,
      if (done != null) 'done': done,
      if (targetLabel != null) 'target_label': targetLabel,
      if (openEnded != null) 'open_ended': openEnded,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutSetsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? sessionExerciseUuid,
    Value<int>? position,
    Value<int>? weightGrams,
    Value<int>? reps,
    Value<bool>? done,
    Value<String?>? targetLabel,
    Value<bool>? openEnded,
    Value<DateTime>? loggedAt,
    Value<int>? rowid,
  }) {
    return WorkoutSetsCompanion(
      uuid: uuid ?? this.uuid,
      sessionExerciseUuid: sessionExerciseUuid ?? this.sessionExerciseUuid,
      position: position ?? this.position,
      weightGrams: weightGrams ?? this.weightGrams,
      reps: reps ?? this.reps,
      done: done ?? this.done,
      targetLabel: targetLabel ?? this.targetLabel,
      openEnded: openEnded ?? this.openEnded,
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
    if (sessionExerciseUuid.present) {
      map['session_exercise_uuid'] = Variable<String>(
        sessionExerciseUuid.value,
      );
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (weightGrams.present) {
      map['weight_grams'] = Variable<int>(weightGrams.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (targetLabel.present) {
      map['target_label'] = Variable<String>(targetLabel.value);
    }
    if (openEnded.present) {
      map['open_ended'] = Variable<bool>(openEnded.value);
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
    return (StringBuffer('WorkoutSetsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('sessionExerciseUuid: $sessionExerciseUuid, ')
          ..write('position: $position, ')
          ..write('weightGrams: $weightGrams, ')
          ..write('reps: $reps, ')
          ..write('done: $done, ')
          ..write('targetLabel: $targetLabel, ')
          ..write('openEnded: $openEnded, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SleepSessionsTable extends SleepSessions
    with TableInfo<$SleepSessionsTable, SleepSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SleepSessionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _fellAsleepAtMeta = const VerificationMeta(
    'fellAsleepAt',
  );
  @override
  late final GeneratedColumn<DateTime> fellAsleepAt = GeneratedColumn<DateTime>(
    'fell_asleep_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wokeAtMeta = const VerificationMeta('wokeAt');
  @override
  late final GeneratedColumn<DateTime> wokeAt = GeneratedColumn<DateTime>(
    'woke_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMinutesMeta = const VerificationMeta(
    'targetMinutes',
  );
  @override
  late final GeneratedColumn<int> targetMinutes = GeneratedColumn<int>(
    'target_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restedStarsMeta = const VerificationMeta(
    'restedStars',
  );
  @override
  late final GeneratedColumn<int> restedStars = GeneratedColumn<int>(
    'rested_stars',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    harvestDay,
    fellAsleepAt,
    wokeAt,
    targetMinutes,
    restedStars,
    note,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sleep_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SleepSessionRow> instance, {
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
    if (data.containsKey('fell_asleep_at')) {
      context.handle(
        _fellAsleepAtMeta,
        fellAsleepAt.isAcceptableOrUnknown(
          data['fell_asleep_at']!,
          _fellAsleepAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fellAsleepAtMeta);
    }
    if (data.containsKey('woke_at')) {
      context.handle(
        _wokeAtMeta,
        wokeAt.isAcceptableOrUnknown(data['woke_at']!, _wokeAtMeta),
      );
    } else if (isInserting) {
      context.missing(_wokeAtMeta);
    }
    if (data.containsKey('target_minutes')) {
      context.handle(
        _targetMinutesMeta,
        targetMinutes.isAcceptableOrUnknown(
          data['target_minutes']!,
          _targetMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetMinutesMeta);
    }
    if (data.containsKey('rested_stars')) {
      context.handle(
        _restedStarsMeta,
        restedStars.isAcceptableOrUnknown(
          data['rested_stars']!,
          _restedStarsMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  SleepSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SleepSessionRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      harvestDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harvest_day'],
      )!,
      fellAsleepAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fell_asleep_at'],
      )!,
      wokeAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}woke_at'],
      )!,
      targetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_minutes'],
      )!,
      restedStars: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rested_stars'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $SleepSessionsTable createAlias(String alias) {
    return $SleepSessionsTable(attachedDatabase, alias);
  }
}

class SleepSessionRow extends DataClass implements Insertable<SleepSessionRow> {
  final String uuid;

  /// The Harvest Day I woke up on: a night is filed under its morning,
  /// because that is the day it decides how I feel.
  final String harvestDay;
  final DateTime fellAsleepAt;
  final DateTime wokeAt;

  /// What the night was meant to be, in minutes, as of that night.
  final int targetMinutes;

  /// 1-5. Null is a legitimate answer at 6 AM.
  final int? restedStars;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const SleepSessionRow({
    required this.uuid,
    required this.harvestDay,
    required this.fellAsleepAt,
    required this.wokeAt,
    required this.targetMinutes,
    this.restedStars,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['harvest_day'] = Variable<String>(harvestDay);
    map['fell_asleep_at'] = Variable<DateTime>(fellAsleepAt);
    map['woke_at'] = Variable<DateTime>(wokeAt);
    map['target_minutes'] = Variable<int>(targetMinutes);
    if (!nullToAbsent || restedStars != null) {
      map['rested_stars'] = Variable<int>(restedStars);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  SleepSessionsCompanion toCompanion(bool nullToAbsent) {
    return SleepSessionsCompanion(
      uuid: Value(uuid),
      harvestDay: Value(harvestDay),
      fellAsleepAt: Value(fellAsleepAt),
      wokeAt: Value(wokeAt),
      targetMinutes: Value(targetMinutes),
      restedStars: restedStars == null && nullToAbsent
          ? const Value.absent()
          : Value(restedStars),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory SleepSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SleepSessionRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      harvestDay: serializer.fromJson<String>(json['harvestDay']),
      fellAsleepAt: serializer.fromJson<DateTime>(json['fellAsleepAt']),
      wokeAt: serializer.fromJson<DateTime>(json['wokeAt']),
      targetMinutes: serializer.fromJson<int>(json['targetMinutes']),
      restedStars: serializer.fromJson<int?>(json['restedStars']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'harvestDay': serializer.toJson<String>(harvestDay),
      'fellAsleepAt': serializer.toJson<DateTime>(fellAsleepAt),
      'wokeAt': serializer.toJson<DateTime>(wokeAt),
      'targetMinutes': serializer.toJson<int>(targetMinutes),
      'restedStars': serializer.toJson<int?>(restedStars),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  SleepSessionRow copyWith({
    String? uuid,
    String? harvestDay,
    DateTime? fellAsleepAt,
    DateTime? wokeAt,
    int? targetMinutes,
    Value<int?> restedStars = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => SleepSessionRow(
    uuid: uuid ?? this.uuid,
    harvestDay: harvestDay ?? this.harvestDay,
    fellAsleepAt: fellAsleepAt ?? this.fellAsleepAt,
    wokeAt: wokeAt ?? this.wokeAt,
    targetMinutes: targetMinutes ?? this.targetMinutes,
    restedStars: restedStars.present ? restedStars.value : this.restedStars,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  SleepSessionRow copyWithCompanion(SleepSessionsCompanion data) {
    return SleepSessionRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      harvestDay: data.harvestDay.present
          ? data.harvestDay.value
          : this.harvestDay,
      fellAsleepAt: data.fellAsleepAt.present
          ? data.fellAsleepAt.value
          : this.fellAsleepAt,
      wokeAt: data.wokeAt.present ? data.wokeAt.value : this.wokeAt,
      targetMinutes: data.targetMinutes.present
          ? data.targetMinutes.value
          : this.targetMinutes,
      restedStars: data.restedStars.present
          ? data.restedStars.value
          : this.restedStars,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SleepSessionRow(')
          ..write('uuid: $uuid, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('fellAsleepAt: $fellAsleepAt, ')
          ..write('wokeAt: $wokeAt, ')
          ..write('targetMinutes: $targetMinutes, ')
          ..write('restedStars: $restedStars, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    harvestDay,
    fellAsleepAt,
    wokeAt,
    targetMinutes,
    restedStars,
    note,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SleepSessionRow &&
          other.uuid == this.uuid &&
          other.harvestDay == this.harvestDay &&
          other.fellAsleepAt == this.fellAsleepAt &&
          other.wokeAt == this.wokeAt &&
          other.targetMinutes == this.targetMinutes &&
          other.restedStars == this.restedStars &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class SleepSessionsCompanion extends UpdateCompanion<SleepSessionRow> {
  final Value<String> uuid;
  final Value<String> harvestDay;
  final Value<DateTime> fellAsleepAt;
  final Value<DateTime> wokeAt;
  final Value<int> targetMinutes;
  final Value<int?> restedStars;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const SleepSessionsCompanion({
    this.uuid = const Value.absent(),
    this.harvestDay = const Value.absent(),
    this.fellAsleepAt = const Value.absent(),
    this.wokeAt = const Value.absent(),
    this.targetMinutes = const Value.absent(),
    this.restedStars = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SleepSessionsCompanion.insert({
    required String uuid,
    required String harvestDay,
    required DateTime fellAsleepAt,
    required DateTime wokeAt,
    required int targetMinutes,
    this.restedStars = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       harvestDay = Value(harvestDay),
       fellAsleepAt = Value(fellAsleepAt),
       wokeAt = Value(wokeAt),
       targetMinutes = Value(targetMinutes);
  static Insertable<SleepSessionRow> custom({
    Expression<String>? uuid,
    Expression<String>? harvestDay,
    Expression<DateTime>? fellAsleepAt,
    Expression<DateTime>? wokeAt,
    Expression<int>? targetMinutes,
    Expression<int>? restedStars,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (harvestDay != null) 'harvest_day': harvestDay,
      if (fellAsleepAt != null) 'fell_asleep_at': fellAsleepAt,
      if (wokeAt != null) 'woke_at': wokeAt,
      if (targetMinutes != null) 'target_minutes': targetMinutes,
      if (restedStars != null) 'rested_stars': restedStars,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SleepSessionsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? harvestDay,
    Value<DateTime>? fellAsleepAt,
    Value<DateTime>? wokeAt,
    Value<int>? targetMinutes,
    Value<int?>? restedStars,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return SleepSessionsCompanion(
      uuid: uuid ?? this.uuid,
      harvestDay: harvestDay ?? this.harvestDay,
      fellAsleepAt: fellAsleepAt ?? this.fellAsleepAt,
      wokeAt: wokeAt ?? this.wokeAt,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      restedStars: restedStars ?? this.restedStars,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (fellAsleepAt.present) {
      map['fell_asleep_at'] = Variable<DateTime>(fellAsleepAt.value);
    }
    if (wokeAt.present) {
      map['woke_at'] = Variable<DateTime>(wokeAt.value);
    }
    if (targetMinutes.present) {
      map['target_minutes'] = Variable<int>(targetMinutes.value);
    }
    if (restedStars.present) {
      map['rested_stars'] = Variable<int>(restedStars.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SleepSessionsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('fellAsleepAt: $fellAsleepAt, ')
          ..write('wokeAt: $wokeAt, ')
          ..write('targetMinutes: $targetMinutes, ')
          ..write('restedStars: $restedStars, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StreaksTable extends Streaks with TableInfo<$StreaksTable, StreakRow> {
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
    Insertable<StreakRow> instance, {
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
  StreakRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StreakRow(
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

class StreakRow extends DataClass implements Insertable<StreakRow> {
  /// `global`, or a commitment uuid for individual streaks.
  final String scope;
  final int current;
  final int best;
  final String? lastEarnedDay;
  final int freezesStored;
  final DateTime updatedAt;
  const StreakRow({
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

  factory StreakRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StreakRow(
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

  StreakRow copyWith({
    String? scope,
    int? current,
    int? best,
    Value<String?> lastEarnedDay = const Value.absent(),
    int? freezesStored,
    DateTime? updatedAt,
  }) => StreakRow(
    scope: scope ?? this.scope,
    current: current ?? this.current,
    best: best ?? this.best,
    lastEarnedDay: lastEarnedDay.present
        ? lastEarnedDay.value
        : this.lastEarnedDay,
    freezesStored: freezesStored ?? this.freezesStored,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StreakRow copyWithCompanion(StreaksCompanion data) {
    return StreakRow(
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
    return (StringBuffer('StreakRow(')
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
      (other is StreakRow &&
          other.scope == this.scope &&
          other.current == this.current &&
          other.best == this.best &&
          other.lastEarnedDay == this.lastEarnedDay &&
          other.freezesStored == this.freezesStored &&
          other.updatedAt == this.updatedAt);
}

class StreaksCompanion extends UpdateCompanion<StreakRow> {
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
  static Insertable<StreakRow> custom({
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

class $ExpensesTable extends Expenses
    with TableInfo<$ExpensesTable, ExpenseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('DZD'),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    amountMinor,
    currency,
    category,
    note,
    harvestDay,
    loggedAt,
    deletedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpenseRow> instance, {
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
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
  ExpenseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpenseRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      harvestDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harvest_day'],
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
  $ExpensesTable createAlias(String alias) {
    return $ExpensesTable(attachedDatabase, alias);
  }
}

class ExpenseRow extends DataClass implements Insertable<ExpenseRow> {
  final String uuid;

  /// Amount in minor units (cents); always positive.
  final int amountMinor;

  /// ISO-ish currency code (DZD / USD / EUR).
  final String currency;

  /// One of the preset category names.
  final String category;
  final String? note;
  final String harvestDay;
  final DateTime loggedAt;
  final DateTime? deletedAt;
  final DateTime updatedAt;
  const ExpenseRow({
    required this.uuid,
    required this.amountMinor,
    required this.currency,
    required this.category,
    this.note,
    required this.harvestDay,
    required this.loggedAt,
    this.deletedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency'] = Variable<String>(currency);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['harvest_day'] = Variable<String>(harvestDay);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ExpensesCompanion toCompanion(bool nullToAbsent) {
    return ExpensesCompanion(
      uuid: Value(uuid),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      category: Value(category),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      harvestDay: Value(harvestDay),
      loggedAt: Value(loggedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ExpenseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpenseRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      category: serializer.fromJson<String>(json['category']),
      note: serializer.fromJson<String?>(json['note']),
      harvestDay: serializer.fromJson<String>(json['harvestDay']),
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
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<String>(currency),
      'category': serializer.toJson<String>(category),
      'note': serializer.toJson<String?>(note),
      'harvestDay': serializer.toJson<String>(harvestDay),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ExpenseRow copyWith({
    String? uuid,
    int? amountMinor,
    String? currency,
    String? category,
    Value<String?> note = const Value.absent(),
    String? harvestDay,
    DateTime? loggedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => ExpenseRow(
    uuid: uuid ?? this.uuid,
    amountMinor: amountMinor ?? this.amountMinor,
    currency: currency ?? this.currency,
    category: category ?? this.category,
    note: note.present ? note.value : this.note,
    harvestDay: harvestDay ?? this.harvestDay,
    loggedAt: loggedAt ?? this.loggedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ExpenseRow copyWithCompanion(ExpensesCompanion data) {
    return ExpenseRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      category: data.category.present ? data.category.value : this.category,
      note: data.note.present ? data.note.value : this.note,
      harvestDay: data.harvestDay.present
          ? data.harvestDay.value
          : this.harvestDay,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseRow(')
          ..write('uuid: $uuid, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('category: $category, ')
          ..write('note: $note, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    amountMinor,
    currency,
    category,
    note,
    harvestDay,
    loggedAt,
    deletedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseRow &&
          other.uuid == this.uuid &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.category == this.category &&
          other.note == this.note &&
          other.harvestDay == this.harvestDay &&
          other.loggedAt == this.loggedAt &&
          other.deletedAt == this.deletedAt &&
          other.updatedAt == this.updatedAt);
}

class ExpensesCompanion extends UpdateCompanion<ExpenseRow> {
  final Value<String> uuid;
  final Value<int> amountMinor;
  final Value<String> currency;
  final Value<String> category;
  final Value<String?> note;
  final Value<String> harvestDay;
  final Value<DateTime> loggedAt;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ExpensesCompanion({
    this.uuid = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.category = const Value.absent(),
    this.note = const Value.absent(),
    this.harvestDay = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpensesCompanion.insert({
    required String uuid,
    required int amountMinor,
    this.currency = const Value.absent(),
    required String category,
    this.note = const Value.absent(),
    required String harvestDay,
    this.loggedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       amountMinor = Value(amountMinor),
       category = Value(category),
       harvestDay = Value(harvestDay);
  static Insertable<ExpenseRow> custom({
    Expression<String>? uuid,
    Expression<int>? amountMinor,
    Expression<String>? currency,
    Expression<String>? category,
    Expression<String>? note,
    Expression<String>? harvestDay,
    Expression<DateTime>? loggedAt,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (category != null) 'category': category,
      if (note != null) 'note': note,
      if (harvestDay != null) 'harvest_day': harvestDay,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpensesCompanion copyWith({
    Value<String>? uuid,
    Value<int>? amountMinor,
    Value<String>? currency,
    Value<String>? category,
    Value<String?>? note,
    Value<String>? harvestDay,
    Value<DateTime>? loggedAt,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ExpensesCompanion(
      uuid: uuid ?? this.uuid,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      note: note ?? this.note,
      harvestDay: harvestDay ?? this.harvestDay,
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
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (harvestDay.present) {
      map['harvest_day'] = Variable<String>(harvestDay.value);
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
    return (StringBuffer('ExpensesCompanion(')
          ..write('uuid: $uuid, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('category: $category, ')
          ..write('note: $note, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExpenseCategoriesTable extends ExpenseCategories
    with TableInfo<$ExpenseCategoriesTable, ExpenseCategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpenseCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    name,
    icon,
    deletedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expense_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpenseCategoryRow> instance, {
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
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
  ExpenseCategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpenseCategoryRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
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
  $ExpenseCategoriesTable createAlias(String alias) {
    return $ExpenseCategoriesTable(attachedDatabase, alias);
  }
}

class ExpenseCategoryRow extends DataClass
    implements Insertable<ExpenseCategoryRow> {
  final String uuid;

  /// Display name; doubles as the key stored on expenses.
  final String name;

  /// Icon key resolved through the app's icon map.
  final String icon;
  final DateTime? deletedAt;
  final DateTime updatedAt;
  const ExpenseCategoryRow({
    required this.uuid,
    required this.name,
    required this.icon,
    this.deletedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ExpenseCategoriesCompanion toCompanion(bool nullToAbsent) {
    return ExpenseCategoriesCompanion(
      uuid: Value(uuid),
      name: Value(name),
      icon: Value(icon),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ExpenseCategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpenseCategoryRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ExpenseCategoryRow copyWith({
    String? uuid,
    String? name,
    String? icon,
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => ExpenseCategoryRow(
    uuid: uuid ?? this.uuid,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ExpenseCategoryRow copyWithCompanion(ExpenseCategoriesCompanion data) {
    return ExpenseCategoryRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseCategoryRow(')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uuid, name, icon, deletedAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseCategoryRow &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.deletedAt == this.deletedAt &&
          other.updatedAt == this.updatedAt);
}

class ExpenseCategoriesCompanion extends UpdateCompanion<ExpenseCategoryRow> {
  final Value<String> uuid;
  final Value<String> name;
  final Value<String> icon;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ExpenseCategoriesCompanion({
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpenseCategoriesCompanion.insert({
    required String uuid,
    required String name,
    required String icon,
    this.deletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       name = Value(name),
       icon = Value(icon);
  static Insertable<ExpenseCategoryRow> custom({
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpenseCategoriesCompanion copyWith({
    Value<String>? uuid,
    Value<String>? name,
    Value<String>? icon,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ExpenseCategoriesCompanion(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      icon: icon ?? this.icon,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
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
    return (StringBuffer('ExpenseCategoriesCompanion(')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MoneyTxnsTable extends MoneyTxns
    with TableInfo<$MoneyTxnsTable, MoneyTxnRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoneyTxnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountMeta = const VerificationMeta(
    'account',
  );
  @override
  late final GeneratedColumn<String> account = GeneratedColumn<String>(
    'account',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deltaMinorMeta = const VerificationMeta(
    'deltaMinor',
  );
  @override
  late final GeneratedColumn<int> deltaMinor = GeneratedColumn<int>(
    'delta_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('DZD'),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _referenceMeta = const VerificationMeta(
    'reference',
  );
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkUuidMeta = const VerificationMeta(
    'linkUuid',
  );
  @override
  late final GeneratedColumn<String> linkUuid = GeneratedColumn<String>(
    'link_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    account,
    deltaMinor,
    currency,
    note,
    kind,
    reference,
    linkUuid,
    harvestDay,
    loggedAt,
    deletedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'money_txns';
  @override
  VerificationContext validateIntegrity(
    Insertable<MoneyTxnRow> instance, {
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
    if (data.containsKey('account')) {
      context.handle(
        _accountMeta,
        account.isAcceptableOrUnknown(data['account']!, _accountMeta),
      );
    } else if (isInserting) {
      context.missing(_accountMeta);
    }
    if (data.containsKey('delta_minor')) {
      context.handle(
        _deltaMinorMeta,
        deltaMinor.isAcceptableOrUnknown(data['delta_minor']!, _deltaMinorMeta),
      );
    } else if (isInserting) {
      context.missing(_deltaMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('reference')) {
      context.handle(
        _referenceMeta,
        reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta),
      );
    }
    if (data.containsKey('link_uuid')) {
      context.handle(
        _linkUuidMeta,
        linkUuid.isAcceptableOrUnknown(data['link_uuid']!, _linkUuidMeta),
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
  MoneyTxnRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MoneyTxnRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      account: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account'],
      )!,
      deltaMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delta_minor'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      reference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference'],
      ),
      linkUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link_uuid'],
      ),
      harvestDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harvest_day'],
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
  $MoneyTxnsTable createAlias(String alias) {
    return $MoneyTxnsTable(attachedDatabase, alias);
  }
}

class MoneyTxnRow extends DataClass implements Insertable<MoneyTxnRow> {
  final String uuid;

  /// 'wallet' | 'savings'.
  final String account;

  /// Minor units, signed: positive deposits, negative withdrawals.
  final int deltaMinor;
  final String currency;
  final String? note;

  /// What caused the movement: 'manual' | 'transfer' | 'expense' | 'debt'
  /// (round 4 — the ledger explains every row).
  final String kind;

  /// Context for [kind]: the counterpart account for a transfer, the
  /// category key for an expense, the person for a debt payment.
  final String? reference;

  /// The row this movement belongs to — the expense uuid for a
  /// wallet-funded expense, the debt payment uuid for a debt. Editing
  /// or deleting that row carries the movement with it (schema v8).
  final String? linkUuid;
  final String harvestDay;
  final DateTime loggedAt;
  final DateTime? deletedAt;
  final DateTime updatedAt;
  const MoneyTxnRow({
    required this.uuid,
    required this.account,
    required this.deltaMinor,
    required this.currency,
    this.note,
    required this.kind,
    this.reference,
    this.linkUuid,
    required this.harvestDay,
    required this.loggedAt,
    this.deletedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['account'] = Variable<String>(account);
    map['delta_minor'] = Variable<int>(deltaMinor);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || reference != null) {
      map['reference'] = Variable<String>(reference);
    }
    if (!nullToAbsent || linkUuid != null) {
      map['link_uuid'] = Variable<String>(linkUuid);
    }
    map['harvest_day'] = Variable<String>(harvestDay);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MoneyTxnsCompanion toCompanion(bool nullToAbsent) {
    return MoneyTxnsCompanion(
      uuid: Value(uuid),
      account: Value(account),
      deltaMinor: Value(deltaMinor),
      currency: Value(currency),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      kind: Value(kind),
      reference: reference == null && nullToAbsent
          ? const Value.absent()
          : Value(reference),
      linkUuid: linkUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(linkUuid),
      harvestDay: Value(harvestDay),
      loggedAt: Value(loggedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MoneyTxnRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MoneyTxnRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      account: serializer.fromJson<String>(json['account']),
      deltaMinor: serializer.fromJson<int>(json['deltaMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      note: serializer.fromJson<String?>(json['note']),
      kind: serializer.fromJson<String>(json['kind']),
      reference: serializer.fromJson<String?>(json['reference']),
      linkUuid: serializer.fromJson<String?>(json['linkUuid']),
      harvestDay: serializer.fromJson<String>(json['harvestDay']),
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
      'account': serializer.toJson<String>(account),
      'deltaMinor': serializer.toJson<int>(deltaMinor),
      'currency': serializer.toJson<String>(currency),
      'note': serializer.toJson<String?>(note),
      'kind': serializer.toJson<String>(kind),
      'reference': serializer.toJson<String?>(reference),
      'linkUuid': serializer.toJson<String?>(linkUuid),
      'harvestDay': serializer.toJson<String>(harvestDay),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MoneyTxnRow copyWith({
    String? uuid,
    String? account,
    int? deltaMinor,
    String? currency,
    Value<String?> note = const Value.absent(),
    String? kind,
    Value<String?> reference = const Value.absent(),
    Value<String?> linkUuid = const Value.absent(),
    String? harvestDay,
    DateTime? loggedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => MoneyTxnRow(
    uuid: uuid ?? this.uuid,
    account: account ?? this.account,
    deltaMinor: deltaMinor ?? this.deltaMinor,
    currency: currency ?? this.currency,
    note: note.present ? note.value : this.note,
    kind: kind ?? this.kind,
    reference: reference.present ? reference.value : this.reference,
    linkUuid: linkUuid.present ? linkUuid.value : this.linkUuid,
    harvestDay: harvestDay ?? this.harvestDay,
    loggedAt: loggedAt ?? this.loggedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MoneyTxnRow copyWithCompanion(MoneyTxnsCompanion data) {
    return MoneyTxnRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      account: data.account.present ? data.account.value : this.account,
      deltaMinor: data.deltaMinor.present
          ? data.deltaMinor.value
          : this.deltaMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      note: data.note.present ? data.note.value : this.note,
      kind: data.kind.present ? data.kind.value : this.kind,
      reference: data.reference.present ? data.reference.value : this.reference,
      linkUuid: data.linkUuid.present ? data.linkUuid.value : this.linkUuid,
      harvestDay: data.harvestDay.present
          ? data.harvestDay.value
          : this.harvestDay,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MoneyTxnRow(')
          ..write('uuid: $uuid, ')
          ..write('account: $account, ')
          ..write('deltaMinor: $deltaMinor, ')
          ..write('currency: $currency, ')
          ..write('note: $note, ')
          ..write('kind: $kind, ')
          ..write('reference: $reference, ')
          ..write('linkUuid: $linkUuid, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    account,
    deltaMinor,
    currency,
    note,
    kind,
    reference,
    linkUuid,
    harvestDay,
    loggedAt,
    deletedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MoneyTxnRow &&
          other.uuid == this.uuid &&
          other.account == this.account &&
          other.deltaMinor == this.deltaMinor &&
          other.currency == this.currency &&
          other.note == this.note &&
          other.kind == this.kind &&
          other.reference == this.reference &&
          other.linkUuid == this.linkUuid &&
          other.harvestDay == this.harvestDay &&
          other.loggedAt == this.loggedAt &&
          other.deletedAt == this.deletedAt &&
          other.updatedAt == this.updatedAt);
}

class MoneyTxnsCompanion extends UpdateCompanion<MoneyTxnRow> {
  final Value<String> uuid;
  final Value<String> account;
  final Value<int> deltaMinor;
  final Value<String> currency;
  final Value<String?> note;
  final Value<String> kind;
  final Value<String?> reference;
  final Value<String?> linkUuid;
  final Value<String> harvestDay;
  final Value<DateTime> loggedAt;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MoneyTxnsCompanion({
    this.uuid = const Value.absent(),
    this.account = const Value.absent(),
    this.deltaMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.note = const Value.absent(),
    this.kind = const Value.absent(),
    this.reference = const Value.absent(),
    this.linkUuid = const Value.absent(),
    this.harvestDay = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MoneyTxnsCompanion.insert({
    required String uuid,
    required String account,
    required int deltaMinor,
    this.currency = const Value.absent(),
    this.note = const Value.absent(),
    this.kind = const Value.absent(),
    this.reference = const Value.absent(),
    this.linkUuid = const Value.absent(),
    required String harvestDay,
    this.loggedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       account = Value(account),
       deltaMinor = Value(deltaMinor),
       harvestDay = Value(harvestDay);
  static Insertable<MoneyTxnRow> custom({
    Expression<String>? uuid,
    Expression<String>? account,
    Expression<int>? deltaMinor,
    Expression<String>? currency,
    Expression<String>? note,
    Expression<String>? kind,
    Expression<String>? reference,
    Expression<String>? linkUuid,
    Expression<String>? harvestDay,
    Expression<DateTime>? loggedAt,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (account != null) 'account': account,
      if (deltaMinor != null) 'delta_minor': deltaMinor,
      if (currency != null) 'currency': currency,
      if (note != null) 'note': note,
      if (kind != null) 'kind': kind,
      if (reference != null) 'reference': reference,
      if (linkUuid != null) 'link_uuid': linkUuid,
      if (harvestDay != null) 'harvest_day': harvestDay,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MoneyTxnsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? account,
    Value<int>? deltaMinor,
    Value<String>? currency,
    Value<String?>? note,
    Value<String>? kind,
    Value<String?>? reference,
    Value<String?>? linkUuid,
    Value<String>? harvestDay,
    Value<DateTime>? loggedAt,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MoneyTxnsCompanion(
      uuid: uuid ?? this.uuid,
      account: account ?? this.account,
      deltaMinor: deltaMinor ?? this.deltaMinor,
      currency: currency ?? this.currency,
      note: note ?? this.note,
      kind: kind ?? this.kind,
      reference: reference ?? this.reference,
      linkUuid: linkUuid ?? this.linkUuid,
      harvestDay: harvestDay ?? this.harvestDay,
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
    if (account.present) {
      map['account'] = Variable<String>(account.value);
    }
    if (deltaMinor.present) {
      map['delta_minor'] = Variable<int>(deltaMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (linkUuid.present) {
      map['link_uuid'] = Variable<String>(linkUuid.value);
    }
    if (harvestDay.present) {
      map['harvest_day'] = Variable<String>(harvestDay.value);
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
    return (StringBuffer('MoneyTxnsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('account: $account, ')
          ..write('deltaMinor: $deltaMinor, ')
          ..write('currency: $currency, ')
          ..write('note: $note, ')
          ..write('kind: $kind, ')
          ..write('reference: $reference, ')
          ..write('linkUuid: $linkUuid, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DebtsTable extends Debts with TableInfo<$DebtsTable, DebtRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebtsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personMeta = const VerificationMeta('person');
  @override
  late final GeneratedColumn<String> person = GeneratedColumn<String>(
    'person',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('DZD'),
  );
  static const VerificationMeta _payOffByMeta = const VerificationMeta(
    'payOffBy',
  );
  @override
  late final GeneratedColumn<String> payOffBy = GeneratedColumn<String>(
    'pay_off_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindAtMeta = const VerificationMeta(
    'remindAt',
  );
  @override
  late final GeneratedColumn<String> remindAt = GeneratedColumn<String>(
    'remind_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _settledAtMeta = const VerificationMeta(
    'settledAt',
  );
  @override
  late final GeneratedColumn<DateTime> settledAt = GeneratedColumn<DateTime>(
    'settled_at',
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
    person,
    amountMinor,
    currency,
    payOffBy,
    remindAt,
    note,
    settledAt,
    createdAt,
    deletedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DebtRow> instance, {
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
    if (data.containsKey('person')) {
      context.handle(
        _personMeta,
        person.isAcceptableOrUnknown(data['person']!, _personMeta),
      );
    } else if (isInserting) {
      context.missing(_personMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('pay_off_by')) {
      context.handle(
        _payOffByMeta,
        payOffBy.isAcceptableOrUnknown(data['pay_off_by']!, _payOffByMeta),
      );
    }
    if (data.containsKey('remind_at')) {
      context.handle(
        _remindAtMeta,
        remindAt.isAcceptableOrUnknown(data['remind_at']!, _remindAtMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('settled_at')) {
      context.handle(
        _settledAtMeta,
        settledAt.isAcceptableOrUnknown(data['settled_at']!, _settledAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
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
  DebtRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DebtRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      person: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      payOffBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pay_off_by'],
      ),
      remindAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remind_at'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      settledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}settled_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
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
  $DebtsTable createAlias(String alias) {
    return $DebtsTable(attachedDatabase, alias);
  }
}

class DebtRow extends DataClass implements Insertable<DebtRow> {
  final String uuid;
  final String person;
  final int amountMinor;
  final String currency;
  final String? payOffBy;

  /// "HH:mm" daily reminder time; a default applies when unset.
  final String? remindAt;
  final String? note;
  final DateTime? settledAt;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final DateTime updatedAt;
  const DebtRow({
    required this.uuid,
    required this.person,
    required this.amountMinor,
    required this.currency,
    this.payOffBy,
    this.remindAt,
    this.note,
    this.settledAt,
    required this.createdAt,
    this.deletedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['person'] = Variable<String>(person);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || payOffBy != null) {
      map['pay_off_by'] = Variable<String>(payOffBy);
    }
    if (!nullToAbsent || remindAt != null) {
      map['remind_at'] = Variable<String>(remindAt);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || settledAt != null) {
      map['settled_at'] = Variable<DateTime>(settledAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DebtsCompanion toCompanion(bool nullToAbsent) {
    return DebtsCompanion(
      uuid: Value(uuid),
      person: Value(person),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      payOffBy: payOffBy == null && nullToAbsent
          ? const Value.absent()
          : Value(payOffBy),
      remindAt: remindAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remindAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      settledAt: settledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(settledAt),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DebtRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DebtRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      person: serializer.fromJson<String>(json['person']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      payOffBy: serializer.fromJson<String?>(json['payOffBy']),
      remindAt: serializer.fromJson<String?>(json['remindAt']),
      note: serializer.fromJson<String?>(json['note']),
      settledAt: serializer.fromJson<DateTime?>(json['settledAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'person': serializer.toJson<String>(person),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<String>(currency),
      'payOffBy': serializer.toJson<String?>(payOffBy),
      'remindAt': serializer.toJson<String?>(remindAt),
      'note': serializer.toJson<String?>(note),
      'settledAt': serializer.toJson<DateTime?>(settledAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DebtRow copyWith({
    String? uuid,
    String? person,
    int? amountMinor,
    String? currency,
    Value<String?> payOffBy = const Value.absent(),
    Value<String?> remindAt = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<DateTime?> settledAt = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => DebtRow(
    uuid: uuid ?? this.uuid,
    person: person ?? this.person,
    amountMinor: amountMinor ?? this.amountMinor,
    currency: currency ?? this.currency,
    payOffBy: payOffBy.present ? payOffBy.value : this.payOffBy,
    remindAt: remindAt.present ? remindAt.value : this.remindAt,
    note: note.present ? note.value : this.note,
    settledAt: settledAt.present ? settledAt.value : this.settledAt,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DebtRow copyWithCompanion(DebtsCompanion data) {
    return DebtRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      person: data.person.present ? data.person.value : this.person,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      payOffBy: data.payOffBy.present ? data.payOffBy.value : this.payOffBy,
      remindAt: data.remindAt.present ? data.remindAt.value : this.remindAt,
      note: data.note.present ? data.note.value : this.note,
      settledAt: data.settledAt.present ? data.settledAt.value : this.settledAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DebtRow(')
          ..write('uuid: $uuid, ')
          ..write('person: $person, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('payOffBy: $payOffBy, ')
          ..write('remindAt: $remindAt, ')
          ..write('note: $note, ')
          ..write('settledAt: $settledAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uuid,
    person,
    amountMinor,
    currency,
    payOffBy,
    remindAt,
    note,
    settledAt,
    createdAt,
    deletedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DebtRow &&
          other.uuid == this.uuid &&
          other.person == this.person &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.payOffBy == this.payOffBy &&
          other.remindAt == this.remindAt &&
          other.note == this.note &&
          other.settledAt == this.settledAt &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt &&
          other.updatedAt == this.updatedAt);
}

class DebtsCompanion extends UpdateCompanion<DebtRow> {
  final Value<String> uuid;
  final Value<String> person;
  final Value<int> amountMinor;
  final Value<String> currency;
  final Value<String?> payOffBy;
  final Value<String?> remindAt;
  final Value<String?> note;
  final Value<DateTime?> settledAt;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DebtsCompanion({
    this.uuid = const Value.absent(),
    this.person = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.payOffBy = const Value.absent(),
    this.remindAt = const Value.absent(),
    this.note = const Value.absent(),
    this.settledAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DebtsCompanion.insert({
    required String uuid,
    required String person,
    required int amountMinor,
    this.currency = const Value.absent(),
    this.payOffBy = const Value.absent(),
    this.remindAt = const Value.absent(),
    this.note = const Value.absent(),
    this.settledAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       person = Value(person),
       amountMinor = Value(amountMinor);
  static Insertable<DebtRow> custom({
    Expression<String>? uuid,
    Expression<String>? person,
    Expression<int>? amountMinor,
    Expression<String>? currency,
    Expression<String>? payOffBy,
    Expression<String>? remindAt,
    Expression<String>? note,
    Expression<DateTime>? settledAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (person != null) 'person': person,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (payOffBy != null) 'pay_off_by': payOffBy,
      if (remindAt != null) 'remind_at': remindAt,
      if (note != null) 'note': note,
      if (settledAt != null) 'settled_at': settledAt,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DebtsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? person,
    Value<int>? amountMinor,
    Value<String>? currency,
    Value<String?>? payOffBy,
    Value<String?>? remindAt,
    Value<String?>? note,
    Value<DateTime?>? settledAt,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DebtsCompanion(
      uuid: uuid ?? this.uuid,
      person: person ?? this.person,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      payOffBy: payOffBy ?? this.payOffBy,
      remindAt: remindAt ?? this.remindAt,
      note: note ?? this.note,
      settledAt: settledAt ?? this.settledAt,
      createdAt: createdAt ?? this.createdAt,
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
    if (person.present) {
      map['person'] = Variable<String>(person.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (payOffBy.present) {
      map['pay_off_by'] = Variable<String>(payOffBy.value);
    }
    if (remindAt.present) {
      map['remind_at'] = Variable<String>(remindAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (settledAt.present) {
      map['settled_at'] = Variable<DateTime>(settledAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('DebtsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('person: $person, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('payOffBy: $payOffBy, ')
          ..write('remindAt: $remindAt, ')
          ..write('note: $note, ')
          ..write('settledAt: $settledAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DebtPaymentsTable extends DebtPayments
    with TableInfo<$DebtPaymentsTable, DebtPaymentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebtPaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _debtUuidMeta = const VerificationMeta(
    'debtUuid',
  );
  @override
  late final GeneratedColumn<String> debtUuid = GeneratedColumn<String>(
    'debt_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES debts (uuid)',
    ),
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [
    uuid,
    debtUuid,
    amountMinor,
    harvestDay,
    loggedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debt_payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<DebtPaymentRow> instance, {
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
    if (data.containsKey('debt_uuid')) {
      context.handle(
        _debtUuidMeta,
        debtUuid.isAcceptableOrUnknown(data['debt_uuid']!, _debtUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_debtUuidMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  DebtPaymentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DebtPaymentRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      debtUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}debt_uuid'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      harvestDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harvest_day'],
      )!,
      loggedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logged_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $DebtPaymentsTable createAlias(String alias) {
    return $DebtPaymentsTable(attachedDatabase, alias);
  }
}

class DebtPaymentRow extends DataClass implements Insertable<DebtPaymentRow> {
  final String uuid;
  final String debtUuid;
  final int amountMinor;
  final String harvestDay;
  final DateTime loggedAt;
  final DateTime? deletedAt;
  const DebtPaymentRow({
    required this.uuid,
    required this.debtUuid,
    required this.amountMinor,
    required this.harvestDay,
    required this.loggedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['debt_uuid'] = Variable<String>(debtUuid);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['harvest_day'] = Variable<String>(harvestDay);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  DebtPaymentsCompanion toCompanion(bool nullToAbsent) {
    return DebtPaymentsCompanion(
      uuid: Value(uuid),
      debtUuid: Value(debtUuid),
      amountMinor: Value(amountMinor),
      harvestDay: Value(harvestDay),
      loggedAt: Value(loggedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory DebtPaymentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DebtPaymentRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      debtUuid: serializer.fromJson<String>(json['debtUuid']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      harvestDay: serializer.fromJson<String>(json['harvestDay']),
      loggedAt: serializer.fromJson<DateTime>(json['loggedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'debtUuid': serializer.toJson<String>(debtUuid),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'harvestDay': serializer.toJson<String>(harvestDay),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  DebtPaymentRow copyWith({
    String? uuid,
    String? debtUuid,
    int? amountMinor,
    String? harvestDay,
    DateTime? loggedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => DebtPaymentRow(
    uuid: uuid ?? this.uuid,
    debtUuid: debtUuid ?? this.debtUuid,
    amountMinor: amountMinor ?? this.amountMinor,
    harvestDay: harvestDay ?? this.harvestDay,
    loggedAt: loggedAt ?? this.loggedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  DebtPaymentRow copyWithCompanion(DebtPaymentsCompanion data) {
    return DebtPaymentRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      debtUuid: data.debtUuid.present ? data.debtUuid.value : this.debtUuid,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      harvestDay: data.harvestDay.present
          ? data.harvestDay.value
          : this.harvestDay,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DebtPaymentRow(')
          ..write('uuid: $uuid, ')
          ..write('debtUuid: $debtUuid, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(uuid, debtUuid, amountMinor, harvestDay, loggedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DebtPaymentRow &&
          other.uuid == this.uuid &&
          other.debtUuid == this.debtUuid &&
          other.amountMinor == this.amountMinor &&
          other.harvestDay == this.harvestDay &&
          other.loggedAt == this.loggedAt &&
          other.deletedAt == this.deletedAt);
}

class DebtPaymentsCompanion extends UpdateCompanion<DebtPaymentRow> {
  final Value<String> uuid;
  final Value<String> debtUuid;
  final Value<int> amountMinor;
  final Value<String> harvestDay;
  final Value<DateTime> loggedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const DebtPaymentsCompanion({
    this.uuid = const Value.absent(),
    this.debtUuid = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.harvestDay = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DebtPaymentsCompanion.insert({
    required String uuid,
    required String debtUuid,
    required int amountMinor,
    required String harvestDay,
    this.loggedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       debtUuid = Value(debtUuid),
       amountMinor = Value(amountMinor),
       harvestDay = Value(harvestDay);
  static Insertable<DebtPaymentRow> custom({
    Expression<String>? uuid,
    Expression<String>? debtUuid,
    Expression<int>? amountMinor,
    Expression<String>? harvestDay,
    Expression<DateTime>? loggedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (debtUuid != null) 'debt_uuid': debtUuid,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (harvestDay != null) 'harvest_day': harvestDay,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DebtPaymentsCompanion copyWith({
    Value<String>? uuid,
    Value<String>? debtUuid,
    Value<int>? amountMinor,
    Value<String>? harvestDay,
    Value<DateTime>? loggedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return DebtPaymentsCompanion(
      uuid: uuid ?? this.uuid,
      debtUuid: debtUuid ?? this.debtUuid,
      amountMinor: amountMinor ?? this.amountMinor,
      harvestDay: harvestDay ?? this.harvestDay,
      loggedAt: loggedAt ?? this.loggedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (debtUuid.present) {
      map['debt_uuid'] = Variable<String>(debtUuid.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (harvestDay.present) {
      map['harvest_day'] = Variable<String>(harvestDay.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<DateTime>(loggedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DebtPaymentsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('debtUuid: $debtUuid, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('harvestDay: $harvestDay, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('deletedAt: $deletedAt, ')
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
  late final $SeedNotesTable seedNotes = $SeedNotesTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $NoteLinksTable noteLinks = $NoteLinksTable(this);
  late final $AlbumsTable albums = $AlbumsTable(this);
  late final $MemoriesTable memories = $MemoriesTable(this);
  late final $StepDaysTable stepDays = $StepDaysTable(this);
  late final $BodyWeightsTable bodyWeights = $BodyWeightsTable(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $ProgramsTable programs = $ProgramsTable(this);
  late final $ProgramDaysTable programDays = $ProgramDaysTable(this);
  late final $ProgramSlotsTable programSlots = $ProgramSlotsTable(this);
  late final $TargetSetsTable targetSets = $TargetSetsTable(this);
  late final $TrainingMaxesTable trainingMaxes = $TrainingMaxesTable(this);
  late final $WorkoutSessionsTable workoutSessions = $WorkoutSessionsTable(
    this,
  );
  late final $SessionExercisesTable sessionExercises = $SessionExercisesTable(
    this,
  );
  late final $WorkoutSetsTable workoutSets = $WorkoutSetsTable(this);
  late final $SleepSessionsTable sleepSessions = $SleepSessionsTable(this);
  late final $StreaksTable streaks = $StreaksTable(this);
  late final $LedgerTable ledger = $LedgerTable(this);
  late final $QuestsTable quests = $QuestsTable(this);
  late final $PomodoroSessionsTable pomodoroSessions = $PomodoroSessionsTable(
    this,
  );
  late final $ExpensesTable expenses = $ExpensesTable(this);
  late final $ExpenseCategoriesTable expenseCategories =
      $ExpenseCategoriesTable(this);
  late final $MoneyTxnsTable moneyTxns = $MoneyTxnsTable(this);
  late final $DebtsTable debts = $DebtsTable(this);
  late final $DebtPaymentsTable debtPayments = $DebtPaymentsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $KvSettingsTable kvSettings = $KvSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    commitments,
    checkIns,
    seedNotes,
    notes,
    noteLinks,
    albums,
    memories,
    stepDays,
    bodyWeights,
    exercises,
    programs,
    programDays,
    programSlots,
    targetSets,
    trainingMaxes,
    workoutSessions,
    sessionExercises,
    workoutSets,
    sleepSessions,
    streaks,
    ledger,
    quests,
    pomodoroSessions,
    expenses,
    expenseCategories,
    moneyTxns,
    debts,
    debtPayments,
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
      Value<DateTime?> pausedAt,
      Value<String?> note,
      Value<String?> remindAt,
      Value<String?> deadline,
      Value<DateTime?> archivedAt,
      Value<String?> archiveNote,
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
      Value<DateTime?> pausedAt,
      Value<String?> note,
      Value<String?> remindAt,
      Value<String?> deadline,
      Value<DateTime?> archivedAt,
      Value<String?> archiveNote,
      Value<DateTime?> deletedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$CommitmentsTableReferences
    extends
        BaseReferences<_$HarvestDatabase, $CommitmentsTable, CommitmentRow> {
  $$CommitmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CheckInsTable, List<CheckInRow>>
  _checkInsRefsTable(_$HarvestDatabase db) => MultiTypedResultKey.fromTable(
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

  static MultiTypedResultKey<$SeedNotesTable, List<SeedNoteRow>>
  _seedNotesRefsTable(_$HarvestDatabase db) => MultiTypedResultKey.fromTable(
    db.seedNotes,
    aliasName: 'commitments__uuid__seed_notes__commitment_uuid',
  );

  $$SeedNotesTableProcessedTableManager get seedNotesRefs {
    final manager = $$SeedNotesTableTableManager($_db, $_db.seedNotes).filter(
      (f) => f.commitmentUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!),
    );

    final cache = $_typedResult.readTableOrNull(_seedNotesRefsTable($_db));
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

  ColumnFilters<DateTime> get pausedAt => $composableBuilder(
    column: $table.pausedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archiveNote => $composableBuilder(
    column: $table.archiveNote,
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

  Expression<bool> seedNotesRefs(
    Expression<bool> Function($$SeedNotesTableFilterComposer f) f,
  ) {
    final $$SeedNotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.seedNotes,
      getReferencedColumn: (t) => t.commitmentUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeedNotesTableFilterComposer(
            $db: $db,
            $table: $db.seedNotes,
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

  ColumnOrderings<DateTime> get pausedAt => $composableBuilder(
    column: $table.pausedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archiveNote => $composableBuilder(
    column: $table.archiveNote,
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

  GeneratedColumn<DateTime> get pausedAt =>
      $composableBuilder(column: $table.pausedAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get remindAt =>
      $composableBuilder(column: $table.remindAt, builder: (column) => column);

  GeneratedColumn<String> get deadline =>
      $composableBuilder(column: $table.deadline, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get archiveNote => $composableBuilder(
    column: $table.archiveNote,
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

  Expression<T> seedNotesRefs<T extends Object>(
    Expression<T> Function($$SeedNotesTableAnnotationComposer a) f,
  ) {
    final $$SeedNotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.seedNotes,
      getReferencedColumn: (t) => t.commitmentUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeedNotesTableAnnotationComposer(
            $db: $db,
            $table: $db.seedNotes,
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
          CommitmentRow,
          $$CommitmentsTableFilterComposer,
          $$CommitmentsTableOrderingComposer,
          $$CommitmentsTableAnnotationComposer,
          $$CommitmentsTableCreateCompanionBuilder,
          $$CommitmentsTableUpdateCompanionBuilder,
          (CommitmentRow, $$CommitmentsTableReferences),
          CommitmentRow,
          PrefetchHooks Function({bool checkInsRefs, bool seedNotesRefs})
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
                Value<DateTime?> pausedAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> remindAt = const Value.absent(),
                Value<String?> deadline = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<String?> archiveNote = const Value.absent(),
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
                pausedAt: pausedAt,
                note: note,
                remindAt: remindAt,
                deadline: deadline,
                archivedAt: archivedAt,
                archiveNote: archiveNote,
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
                Value<DateTime?> pausedAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> remindAt = const Value.absent(),
                Value<String?> deadline = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<String?> archiveNote = const Value.absent(),
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
                pausedAt: pausedAt,
                note: note,
                remindAt: remindAt,
                deadline: deadline,
                archivedAt: archivedAt,
                archiveNote: archiveNote,
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
          prefetchHooksCallback:
              ({checkInsRefs = false, seedNotesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (checkInsRefs) db.checkIns,
                    if (seedNotesRefs) db.seedNotes,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (checkInsRefs)
                        await $_getPrefetchedData<
                          CommitmentRow,
                          $CommitmentsTable,
                          CheckInRow
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
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.commitmentUuid == item.uuid,
                              ),
                          typedResults: items,
                        ),
                      if (seedNotesRefs)
                        await $_getPrefetchedData<
                          CommitmentRow,
                          $CommitmentsTable,
                          SeedNoteRow
                        >(
                          currentTable: table,
                          referencedTable: $$CommitmentsTableReferences
                              ._seedNotesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CommitmentsTableReferences(
                                db,
                                table,
                                p0,
                              ).seedNotesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
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
      CommitmentRow,
      $$CommitmentsTableFilterComposer,
      $$CommitmentsTableOrderingComposer,
      $$CommitmentsTableAnnotationComposer,
      $$CommitmentsTableCreateCompanionBuilder,
      $$CommitmentsTableUpdateCompanionBuilder,
      (CommitmentRow, $$CommitmentsTableReferences),
      CommitmentRow,
      PrefetchHooks Function({bool checkInsRefs, bool seedNotesRefs})
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
    extends BaseReferences<_$HarvestDatabase, $CheckInsTable, CheckInRow> {
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
          CheckInRow,
          $$CheckInsTableFilterComposer,
          $$CheckInsTableOrderingComposer,
          $$CheckInsTableAnnotationComposer,
          $$CheckInsTableCreateCompanionBuilder,
          $$CheckInsTableUpdateCompanionBuilder,
          (CheckInRow, $$CheckInsTableReferences),
          CheckInRow,
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
      CheckInRow,
      $$CheckInsTableFilterComposer,
      $$CheckInsTableOrderingComposer,
      $$CheckInsTableAnnotationComposer,
      $$CheckInsTableCreateCompanionBuilder,
      $$CheckInsTableUpdateCompanionBuilder,
      (CheckInRow, $$CheckInsTableReferences),
      CheckInRow,
      PrefetchHooks Function({bool commitmentUuid})
    >;
typedef $$SeedNotesTableCreateCompanionBuilder = SeedNotesCompanion Function({
  required String uuid,
  required String commitmentUuid,
  required String harvestDay,
  required String body,
  Value<DateTime> loggedAt,
  Value<DateTime?> deletedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$SeedNotesTableUpdateCompanionBuilder = SeedNotesCompanion Function({
  Value<String> uuid,
  Value<String> commitmentUuid,
  Value<String> harvestDay,
  Value<String> body,
  Value<DateTime> loggedAt,
  Value<DateTime?> deletedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$SeedNotesTableReferences
    extends BaseReferences<_$HarvestDatabase, $SeedNotesTable, SeedNoteRow> {
  $$SeedNotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CommitmentsTable _commitmentUuidTable(_$HarvestDatabase db) => db
      .commitments
      .createAlias('seed_notes__commitment_uuid__commitments__uuid');

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

class $$SeedNotesTableFilterComposer
    extends Composer<_$HarvestDatabase, $SeedNotesTable> {
  $$SeedNotesTableFilterComposer({
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

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
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

class $$SeedNotesTableOrderingComposer
    extends Composer<_$HarvestDatabase, $SeedNotesTable> {
  $$SeedNotesTableOrderingComposer({
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

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
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

class $$SeedNotesTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $SeedNotesTable> {
  $$SeedNotesTableAnnotationComposer({
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

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

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

class $$SeedNotesTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $SeedNotesTable,
          SeedNoteRow,
          $$SeedNotesTableFilterComposer,
          $$SeedNotesTableOrderingComposer,
          $$SeedNotesTableAnnotationComposer,
          $$SeedNotesTableCreateCompanionBuilder,
          $$SeedNotesTableUpdateCompanionBuilder,
          (SeedNoteRow, $$SeedNotesTableReferences),
          SeedNoteRow,
          PrefetchHooks Function({bool commitmentUuid})
        > {
  $$SeedNotesTableTableManager(_$HarvestDatabase db, $SeedNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeedNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeedNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeedNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> commitmentUuid = const Value.absent(),
                Value<String> harvestDay = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeedNotesCompanion(
                uuid: uuid,
                commitmentUuid: commitmentUuid,
                harvestDay: harvestDay,
                body: body,
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
                required String body,
                Value<DateTime> loggedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeedNotesCompanion.insert(
                uuid: uuid,
                commitmentUuid: commitmentUuid,
                harvestDay: harvestDay,
                body: body,
                loggedAt: loggedAt,
                deletedAt: deletedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SeedNotesTableReferences(db, table, e),
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
                        referencedTable: $$SeedNotesTableReferences
                            ._commitmentUuidTable(db),
                        referencedColumn: $$SeedNotesTableReferences
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

typedef $$SeedNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $SeedNotesTable,
      SeedNoteRow,
      $$SeedNotesTableFilterComposer,
      $$SeedNotesTableOrderingComposer,
      $$SeedNotesTableAnnotationComposer,
      $$SeedNotesTableCreateCompanionBuilder,
      $$SeedNotesTableUpdateCompanionBuilder,
      (SeedNoteRow, $$SeedNotesTableReferences),
      SeedNoteRow,
      PrefetchHooks Function({bool commitmentUuid})
    >;
typedef $$NotesTableCreateCompanionBuilder = NotesCompanion Function({
  required String uuid,
  required String title,
  Value<String> folder,
  Value<String> body,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$NotesTableUpdateCompanionBuilder = NotesCompanion Function({
  Value<String> uuid,
  Value<String> title,
  Value<String> folder,
  Value<String> body,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$NotesTableReferences
    extends BaseReferences<_$HarvestDatabase, $NotesTable, NoteRow> {
  $$NotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NoteLinksTable, List<NoteLinkRow>>
  _noteLinksRefsTable(_$HarvestDatabase db) => MultiTypedResultKey.fromTable(
    db.noteLinks,
    aliasName: 'notes__uuid__note_links__from_uuid',
  );

  $$NoteLinksTableProcessedTableManager get noteLinksRefs {
    final manager = $$NoteLinksTableTableManager(
      $_db,
      $_db.noteLinks,
    ).filter((f) => f.fromUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!));

    final cache = $_typedResult.readTableOrNull(_noteLinksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NotesTableFilterComposer
    extends Composer<_$HarvestDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> noteLinksRefs(
    Expression<bool> Function($$NoteLinksTableFilterComposer f) f,
  ) {
    final $$NoteLinksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.noteLinks,
      getReferencedColumn: (t) => t.fromUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteLinksTableFilterComposer(
            $db: $db,
            $table: $db.noteLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotesTableOrderingComposer
    extends Composer<_$HarvestDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> noteLinksRefs<T extends Object>(
    Expression<T> Function($$NoteLinksTableAnnotationComposer a) f,
  ) {
    final $$NoteLinksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.noteLinks,
      getReferencedColumn: (t) => t.fromUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteLinksTableAnnotationComposer(
            $db: $db,
            $table: $db.noteLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $NotesTable,
          NoteRow,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (NoteRow, $$NotesTableReferences),
          NoteRow,
          PrefetchHooks Function({bool noteLinksRefs})
        > {
  $$NotesTableTableManager(_$HarvestDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> folder = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                uuid: uuid,
                title: title,
                folder: folder,
                body: body,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String title,
                Value<String> folder = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                uuid: uuid,
                title: title,
                folder: folder,
                body: body,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$NotesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({noteLinksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (noteLinksRefs) db.noteLinks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (noteLinksRefs)
                    await $_getPrefetchedData<
                      NoteRow,
                      $NotesTable,
                      NoteLinkRow
                    >(
                      currentTable: table,
                      referencedTable: $$NotesTableReferences
                          ._noteLinksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$NotesTableReferences(db, table, p0).noteLinksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.fromUuid == item.uuid),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $NotesTable,
      NoteRow,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (NoteRow, $$NotesTableReferences),
      NoteRow,
      PrefetchHooks Function({bool noteLinksRefs})
    >;
typedef $$NoteLinksTableCreateCompanionBuilder = NoteLinksCompanion Function({
  required String uuid,
  required String fromUuid,
  required String toTitle,
  Value<String?> toUuid,
  Value<int> rowid,
});
typedef $$NoteLinksTableUpdateCompanionBuilder = NoteLinksCompanion Function({
  Value<String> uuid,
  Value<String> fromUuid,
  Value<String> toTitle,
  Value<String?> toUuid,
  Value<int> rowid,
});

final class $$NoteLinksTableReferences
    extends BaseReferences<_$HarvestDatabase, $NoteLinksTable, NoteLinkRow> {
  $$NoteLinksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NotesTable _fromUuidTable(_$HarvestDatabase db) =>
      db.notes.createAlias('note_links__from_uuid__notes__uuid');

  $$NotesTableProcessedTableManager get fromUuid {
    final $_column = $_itemColumn<String>('from_uuid')!;

    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fromUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NoteLinksTableFilterComposer
    extends Composer<_$HarvestDatabase, $NoteLinksTable> {
  $$NoteLinksTableFilterComposer({
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

  ColumnFilters<String> get toTitle => $composableBuilder(
    column: $table.toTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toUuid => $composableBuilder(
    column: $table.toUuid,
    builder: (column) => ColumnFilters(column),
  );

  $$NotesTableFilterComposer get fromUuid {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromUuid,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteLinksTableOrderingComposer
    extends Composer<_$HarvestDatabase, $NoteLinksTable> {
  $$NoteLinksTableOrderingComposer({
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

  ColumnOrderings<String> get toTitle => $composableBuilder(
    column: $table.toTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toUuid => $composableBuilder(
    column: $table.toUuid,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotesTableOrderingComposer get fromUuid {
    final $$NotesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromUuid,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableOrderingComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteLinksTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $NoteLinksTable> {
  $$NoteLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get toTitle =>
      $composableBuilder(column: $table.toTitle, builder: (column) => column);

  GeneratedColumn<String> get toUuid =>
      $composableBuilder(column: $table.toUuid, builder: (column) => column);

  $$NotesTableAnnotationComposer get fromUuid {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromUuid,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteLinksTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $NoteLinksTable,
          NoteLinkRow,
          $$NoteLinksTableFilterComposer,
          $$NoteLinksTableOrderingComposer,
          $$NoteLinksTableAnnotationComposer,
          $$NoteLinksTableCreateCompanionBuilder,
          $$NoteLinksTableUpdateCompanionBuilder,
          (NoteLinkRow, $$NoteLinksTableReferences),
          NoteLinkRow,
          PrefetchHooks Function({bool fromUuid})
        > {
  $$NoteLinksTableTableManager(_$HarvestDatabase db, $NoteLinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> fromUuid = const Value.absent(),
                Value<String> toTitle = const Value.absent(),
                Value<String?> toUuid = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteLinksCompanion(
                uuid: uuid,
                fromUuid: fromUuid,
                toTitle: toTitle,
                toUuid: toUuid,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String fromUuid,
                required String toTitle,
                Value<String?> toUuid = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteLinksCompanion.insert(
                uuid: uuid,
                fromUuid: fromUuid,
                toTitle: toTitle,
                toUuid: toUuid,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NoteLinksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({fromUuid = false}) {
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
                    if (fromUuid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.fromUuid,
                        referencedTable: $$NoteLinksTableReferences
                            ._fromUuidTable(db),
                        referencedColumn: $$NoteLinksTableReferences
                            ._fromUuidTable(db)
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

typedef $$NoteLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $NoteLinksTable,
      NoteLinkRow,
      $$NoteLinksTableFilterComposer,
      $$NoteLinksTableOrderingComposer,
      $$NoteLinksTableAnnotationComposer,
      $$NoteLinksTableCreateCompanionBuilder,
      $$NoteLinksTableUpdateCompanionBuilder,
      (NoteLinkRow, $$NoteLinksTableReferences),
      NoteLinkRow,
      PrefetchHooks Function({bool fromUuid})
    >;
typedef $$AlbumsTableCreateCompanionBuilder = AlbumsCompanion Function({
  required String uuid,
  required String name,
  Value<String?> scheduleJson,
  Value<String?> remindAt,
  Value<String?> note,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$AlbumsTableUpdateCompanionBuilder = AlbumsCompanion Function({
  Value<String> uuid,
  Value<String> name,
  Value<String?> scheduleJson,
  Value<String?> remindAt,
  Value<String?> note,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$AlbumsTableReferences
    extends BaseReferences<_$HarvestDatabase, $AlbumsTable, AlbumRow> {
  $$AlbumsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MemoriesTable, List<MemoryRow>>
  _memoriesRefsTable(_$HarvestDatabase db) => MultiTypedResultKey.fromTable(
    db.memories,
    aliasName: 'albums__uuid__memories__album_uuid',
  );

  $$MemoriesTableProcessedTableManager get memoriesRefs {
    final manager = $$MemoriesTableTableManager(
      $_db,
      $_db.memories,
    ).filter((f) => f.albumUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!));

    final cache = $_typedResult.readTableOrNull(_memoriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AlbumsTableFilterComposer
    extends Composer<_$HarvestDatabase, $AlbumsTable> {
  $$AlbumsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleJson => $composableBuilder(
    column: $table.scheduleJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> memoriesRefs(
    Expression<bool> Function($$MemoriesTableFilterComposer f) f,
  ) {
    final $$MemoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.memories,
      getReferencedColumn: (t) => t.albumUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoriesTableFilterComposer(
            $db: $db,
            $table: $db.memories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlbumsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $AlbumsTable> {
  $$AlbumsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleJson => $composableBuilder(
    column: $table.scheduleJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlbumsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $AlbumsTable> {
  $$AlbumsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get scheduleJson => $composableBuilder(
    column: $table.scheduleJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remindAt =>
      $composableBuilder(column: $table.remindAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> memoriesRefs<T extends Object>(
    Expression<T> Function($$MemoriesTableAnnotationComposer a) f,
  ) {
    final $$MemoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.memories,
      getReferencedColumn: (t) => t.albumUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.memories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlbumsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $AlbumsTable,
          AlbumRow,
          $$AlbumsTableFilterComposer,
          $$AlbumsTableOrderingComposer,
          $$AlbumsTableAnnotationComposer,
          $$AlbumsTableCreateCompanionBuilder,
          $$AlbumsTableUpdateCompanionBuilder,
          (AlbumRow, $$AlbumsTableReferences),
          AlbumRow,
          PrefetchHooks Function({bool memoriesRefs})
        > {
  $$AlbumsTableTableManager(_$HarvestDatabase db, $AlbumsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlbumsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlbumsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlbumsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> scheduleJson = const Value.absent(),
                Value<String?> remindAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlbumsCompanion(
                uuid: uuid,
                name: name,
                scheduleJson: scheduleJson,
                remindAt: remindAt,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String name,
                Value<String?> scheduleJson = const Value.absent(),
                Value<String?> remindAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlbumsCompanion.insert(
                uuid: uuid,
                name: name,
                scheduleJson: scheduleJson,
                remindAt: remindAt,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$AlbumsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({memoriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (memoriesRefs) db.memories],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (memoriesRefs)
                    await $_getPrefetchedData<
                      AlbumRow,
                      $AlbumsTable,
                      MemoryRow
                    >(
                      currentTable: table,
                      referencedTable: $$AlbumsTableReferences
                          ._memoriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AlbumsTableReferences(db, table, p0).memoriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.albumUuid == item.uuid,
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

typedef $$AlbumsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $AlbumsTable,
      AlbumRow,
      $$AlbumsTableFilterComposer,
      $$AlbumsTableOrderingComposer,
      $$AlbumsTableAnnotationComposer,
      $$AlbumsTableCreateCompanionBuilder,
      $$AlbumsTableUpdateCompanionBuilder,
      (AlbumRow, $$AlbumsTableReferences),
      AlbumRow,
      PrefetchHooks Function({bool memoriesRefs})
    >;
typedef $$MemoriesTableCreateCompanionBuilder = MemoriesCompanion Function({
  required String uuid,
  required String albumUuid,
  required String harvestDay,
  required String path,
  Value<String> kind,
  Value<String?> note,
  Value<DateTime> capturedAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$MemoriesTableUpdateCompanionBuilder = MemoriesCompanion Function({
  Value<String> uuid,
  Value<String> albumUuid,
  Value<String> harvestDay,
  Value<String> path,
  Value<String> kind,
  Value<String?> note,
  Value<DateTime> capturedAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$MemoriesTableReferences
    extends BaseReferences<_$HarvestDatabase, $MemoriesTable, MemoryRow> {
  $$MemoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AlbumsTable _albumUuidTable(_$HarvestDatabase db) =>
      db.albums.createAlias('memories__album_uuid__albums__uuid');

  $$AlbumsTableProcessedTableManager get albumUuid {
    final $_column = $_itemColumn<String>('album_uuid')!;

    final manager = $$AlbumsTableTableManager(
      $_db,
      $_db.albums,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_albumUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MemoriesTableFilterComposer
    extends Composer<_$HarvestDatabase, $MemoriesTable> {
  $$MemoriesTableFilterComposer({
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

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AlbumsTableFilterComposer get albumUuid {
    final $$AlbumsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumUuid,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableFilterComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoriesTableOrderingComposer
    extends Composer<_$HarvestDatabase, $MemoriesTable> {
  $$MemoriesTableOrderingComposer({
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

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AlbumsTableOrderingComposer get albumUuid {
    final $$AlbumsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumUuid,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableOrderingComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoriesTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $MemoriesTable> {
  $$MemoriesTableAnnotationComposer({
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

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$AlbumsTableAnnotationComposer get albumUuid {
    final $$AlbumsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumUuid,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableAnnotationComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoriesTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $MemoriesTable,
          MemoryRow,
          $$MemoriesTableFilterComposer,
          $$MemoriesTableOrderingComposer,
          $$MemoriesTableAnnotationComposer,
          $$MemoriesTableCreateCompanionBuilder,
          $$MemoriesTableUpdateCompanionBuilder,
          (MemoryRow, $$MemoriesTableReferences),
          MemoryRow,
          PrefetchHooks Function({bool albumUuid})
        > {
  $$MemoriesTableTableManager(_$HarvestDatabase db, $MemoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> albumUuid = const Value.absent(),
                Value<String> harvestDay = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoriesCompanion(
                uuid: uuid,
                albumUuid: albumUuid,
                harvestDay: harvestDay,
                path: path,
                kind: kind,
                note: note,
                capturedAt: capturedAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String albumUuid,
                required String harvestDay,
                required String path,
                Value<String> kind = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoriesCompanion.insert(
                uuid: uuid,
                albumUuid: albumUuid,
                harvestDay: harvestDay,
                path: path,
                kind: kind,
                note: note,
                capturedAt: capturedAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({albumUuid = false}) {
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
                    if (albumUuid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.albumUuid,
                        referencedTable: $$MemoriesTableReferences
                            ._albumUuidTable(db),
                        referencedColumn: $$MemoriesTableReferences
                            ._albumUuidTable(db)
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

typedef $$MemoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $MemoriesTable,
      MemoryRow,
      $$MemoriesTableFilterComposer,
      $$MemoriesTableOrderingComposer,
      $$MemoriesTableAnnotationComposer,
      $$MemoriesTableCreateCompanionBuilder,
      $$MemoriesTableUpdateCompanionBuilder,
      (MemoryRow, $$MemoriesTableReferences),
      MemoryRow,
      PrefetchHooks Function({bool albumUuid})
    >;
typedef $$StepDaysTableCreateCompanionBuilder = StepDaysCompanion Function({
  required String harvestDay,
  Value<int> steps,
  Value<int?> lastCounter,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$StepDaysTableUpdateCompanionBuilder = StepDaysCompanion Function({
  Value<String> harvestDay,
  Value<int> steps,
  Value<int?> lastCounter,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$StepDaysTableFilterComposer
    extends Composer<_$HarvestDatabase, $StepDaysTable> {
  $$StepDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastCounter => $composableBuilder(
    column: $table.lastCounter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StepDaysTableOrderingComposer
    extends Composer<_$HarvestDatabase, $StepDaysTable> {
  $$StepDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastCounter => $composableBuilder(
    column: $table.lastCounter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StepDaysTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $StepDaysTable> {
  $$StepDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<int> get lastCounter => $composableBuilder(
    column: $table.lastCounter,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StepDaysTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $StepDaysTable,
          StepDayRow,
          $$StepDaysTableFilterComposer,
          $$StepDaysTableOrderingComposer,
          $$StepDaysTableAnnotationComposer,
          $$StepDaysTableCreateCompanionBuilder,
          $$StepDaysTableUpdateCompanionBuilder,
          (
            StepDayRow,
            BaseReferences<_$HarvestDatabase, $StepDaysTable, StepDayRow>,
          ),
          StepDayRow,
          PrefetchHooks Function()
        > {
  $$StepDaysTableTableManager(_$HarvestDatabase db, $StepDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StepDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StepDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StepDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> harvestDay = const Value.absent(),
                Value<int> steps = const Value.absent(),
                Value<int?> lastCounter = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StepDaysCompanion(
                harvestDay: harvestDay,
                steps: steps,
                lastCounter: lastCounter,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String harvestDay,
                Value<int> steps = const Value.absent(),
                Value<int?> lastCounter = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StepDaysCompanion.insert(
                harvestDay: harvestDay,
                steps: steps,
                lastCounter: lastCounter,
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

typedef $$StepDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $StepDaysTable,
      StepDayRow,
      $$StepDaysTableFilterComposer,
      $$StepDaysTableOrderingComposer,
      $$StepDaysTableAnnotationComposer,
      $$StepDaysTableCreateCompanionBuilder,
      $$StepDaysTableUpdateCompanionBuilder,
      (
        StepDayRow,
        BaseReferences<_$HarvestDatabase, $StepDaysTable, StepDayRow>,
      ),
      StepDayRow,
      PrefetchHooks Function()
    >;
typedef $$BodyWeightsTableCreateCompanionBuilder =
    BodyWeightsCompanion Function({
      required String uuid,
      required int grams,
      required String harvestDay,
      Value<String?> note,
      Value<DateTime> measuredAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$BodyWeightsTableUpdateCompanionBuilder =
    BodyWeightsCompanion Function({
      Value<String> uuid,
      Value<int> grams,
      Value<String> harvestDay,
      Value<String?> note,
      Value<DateTime> measuredAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$BodyWeightsTableFilterComposer
    extends Composer<_$HarvestDatabase, $BodyWeightsTable> {
  $$BodyWeightsTableFilterComposer({
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

  ColumnFilters<int> get grams => $composableBuilder(
    column: $table.grams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BodyWeightsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $BodyWeightsTable> {
  $$BodyWeightsTableOrderingComposer({
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

  ColumnOrderings<int> get grams => $composableBuilder(
    column: $table.grams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BodyWeightsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $BodyWeightsTable> {
  $$BodyWeightsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get grams =>
      $composableBuilder(column: $table.grams, builder: (column) => column);

  GeneratedColumn<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$BodyWeightsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $BodyWeightsTable,
          BodyWeightRow,
          $$BodyWeightsTableFilterComposer,
          $$BodyWeightsTableOrderingComposer,
          $$BodyWeightsTableAnnotationComposer,
          $$BodyWeightsTableCreateCompanionBuilder,
          $$BodyWeightsTableUpdateCompanionBuilder,
          (
            BodyWeightRow,
            BaseReferences<_$HarvestDatabase, $BodyWeightsTable, BodyWeightRow>,
          ),
          BodyWeightRow,
          PrefetchHooks Function()
        > {
  $$BodyWeightsTableTableManager(_$HarvestDatabase db, $BodyWeightsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BodyWeightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BodyWeightsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BodyWeightsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<int> grams = const Value.absent(),
                Value<String> harvestDay = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> measuredAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BodyWeightsCompanion(
                uuid: uuid,
                grams: grams,
                harvestDay: harvestDay,
                note: note,
                measuredAt: measuredAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required int grams,
                required String harvestDay,
                Value<String?> note = const Value.absent(),
                Value<DateTime> measuredAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BodyWeightsCompanion.insert(
                uuid: uuid,
                grams: grams,
                harvestDay: harvestDay,
                note: note,
                measuredAt: measuredAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BodyWeightsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $BodyWeightsTable,
      BodyWeightRow,
      $$BodyWeightsTableFilterComposer,
      $$BodyWeightsTableOrderingComposer,
      $$BodyWeightsTableAnnotationComposer,
      $$BodyWeightsTableCreateCompanionBuilder,
      $$BodyWeightsTableUpdateCompanionBuilder,
      (
        BodyWeightRow,
        BaseReferences<_$HarvestDatabase, $BodyWeightsTable, BodyWeightRow>,
      ),
      BodyWeightRow,
      PrefetchHooks Function()
    >;
typedef $$ExercisesTableCreateCompanionBuilder = ExercisesCompanion Function({
  required String uuid,
  required String name,
  Value<String?> bodyPart,
  Value<String?> equipment,
  Value<String?> target,
  Value<String?> note,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$ExercisesTableUpdateCompanionBuilder = ExercisesCompanion Function({
  Value<String> uuid,
  Value<String> name,
  Value<String?> bodyPart,
  Value<String?> equipment,
  Value<String?> target,
  Value<String?> note,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$ExercisesTableFilterComposer
    extends Composer<_$HarvestDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyPart => $composableBuilder(
    column: $table.bodyPart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExercisesTableOrderingComposer
    extends Composer<_$HarvestDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyPart => $composableBuilder(
    column: $table.bodyPart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExercisesTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get bodyPart =>
      $composableBuilder(column: $table.bodyPart, builder: (column) => column);

  GeneratedColumn<String> get equipment =>
      $composableBuilder(column: $table.equipment, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ExercisesTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $ExercisesTable,
          ExerciseRow,
          $$ExercisesTableFilterComposer,
          $$ExercisesTableOrderingComposer,
          $$ExercisesTableAnnotationComposer,
          $$ExercisesTableCreateCompanionBuilder,
          $$ExercisesTableUpdateCompanionBuilder,
          (
            ExerciseRow,
            BaseReferences<_$HarvestDatabase, $ExercisesTable, ExerciseRow>,
          ),
          ExerciseRow,
          PrefetchHooks Function()
        > {
  $$ExercisesTableTableManager(_$HarvestDatabase db, $ExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> bodyPart = const Value.absent(),
                Value<String?> equipment = const Value.absent(),
                Value<String?> target = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExercisesCompanion(
                uuid: uuid,
                name: name,
                bodyPart: bodyPart,
                equipment: equipment,
                target: target,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String name,
                Value<String?> bodyPart = const Value.absent(),
                Value<String?> equipment = const Value.absent(),
                Value<String?> target = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExercisesCompanion.insert(
                uuid: uuid,
                name: name,
                bodyPart: bodyPart,
                equipment: equipment,
                target: target,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $ExercisesTable,
      ExerciseRow,
      $$ExercisesTableFilterComposer,
      $$ExercisesTableOrderingComposer,
      $$ExercisesTableAnnotationComposer,
      $$ExercisesTableCreateCompanionBuilder,
      $$ExercisesTableUpdateCompanionBuilder,
      (
        ExerciseRow,
        BaseReferences<_$HarvestDatabase, $ExercisesTable, ExerciseRow>,
      ),
      ExerciseRow,
      PrefetchHooks Function()
    >;
typedef $$ProgramsTableCreateCompanionBuilder = ProgramsCompanion Function({
  required String uuid,
  required String name,
  Value<String?> note,
  Value<int?> weeks,
  Value<String?> commitmentUuid,
  Value<String?> albumUuid,
  Value<String> photoPrompt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$ProgramsTableUpdateCompanionBuilder = ProgramsCompanion Function({
  Value<String> uuid,
  Value<String> name,
  Value<String?> note,
  Value<int?> weeks,
  Value<String?> commitmentUuid,
  Value<String?> albumUuid,
  Value<String> photoPrompt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$ProgramsTableReferences
    extends BaseReferences<_$HarvestDatabase, $ProgramsTable, ProgramRow> {
  $$ProgramsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProgramDaysTable, List<ProgramDayRow>>
  _programDaysRefsTable(_$HarvestDatabase db) => MultiTypedResultKey.fromTable(
    db.programDays,
    aliasName: 'programs__uuid__program_days__program_uuid',
  );

  $$ProgramDaysTableProcessedTableManager get programDaysRefs {
    final manager = $$ProgramDaysTableTableManager($_db, $_db.programDays)
        .filter(
          (f) => f.programUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!),
        );

    final cache = $_typedResult.readTableOrNull(_programDaysRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TrainingMaxesTable, List<TrainingMaxRow>>
  _trainingMaxesRefsTable(_$HarvestDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.trainingMaxes,
        aliasName: 'programs__uuid__training_maxes__program_uuid',
      );

  $$TrainingMaxesTableProcessedTableManager get trainingMaxesRefs {
    final manager = $$TrainingMaxesTableTableManager($_db, $_db.trainingMaxes)
        .filter(
          (f) => f.programUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!),
        );

    final cache = $_typedResult.readTableOrNull(_trainingMaxesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProgramsTableFilterComposer
    extends Composer<_$HarvestDatabase, $ProgramsTable> {
  $$ProgramsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weeks => $composableBuilder(
    column: $table.weeks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commitmentUuid => $composableBuilder(
    column: $table.commitmentUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumUuid => $composableBuilder(
    column: $table.albumUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPrompt => $composableBuilder(
    column: $table.photoPrompt,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> programDaysRefs(
    Expression<bool> Function($$ProgramDaysTableFilterComposer f) f,
  ) {
    final $$ProgramDaysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.programDays,
      getReferencedColumn: (t) => t.programUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramDaysTableFilterComposer(
            $db: $db,
            $table: $db.programDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> trainingMaxesRefs(
    Expression<bool> Function($$TrainingMaxesTableFilterComposer f) f,
  ) {
    final $$TrainingMaxesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.trainingMaxes,
      getReferencedColumn: (t) => t.programUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingMaxesTableFilterComposer(
            $db: $db,
            $table: $db.trainingMaxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProgramsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $ProgramsTable> {
  $$ProgramsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weeks => $composableBuilder(
    column: $table.weeks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commitmentUuid => $composableBuilder(
    column: $table.commitmentUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumUuid => $composableBuilder(
    column: $table.albumUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPrompt => $composableBuilder(
    column: $table.photoPrompt,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProgramsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $ProgramsTable> {
  $$ProgramsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get weeks =>
      $composableBuilder(column: $table.weeks, builder: (column) => column);

  GeneratedColumn<String> get commitmentUuid => $composableBuilder(
    column: $table.commitmentUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumUuid =>
      $composableBuilder(column: $table.albumUuid, builder: (column) => column);

  GeneratedColumn<String> get photoPrompt => $composableBuilder(
    column: $table.photoPrompt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> programDaysRefs<T extends Object>(
    Expression<T> Function($$ProgramDaysTableAnnotationComposer a) f,
  ) {
    final $$ProgramDaysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.programDays,
      getReferencedColumn: (t) => t.programUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramDaysTableAnnotationComposer(
            $db: $db,
            $table: $db.programDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> trainingMaxesRefs<T extends Object>(
    Expression<T> Function($$TrainingMaxesTableAnnotationComposer a) f,
  ) {
    final $$TrainingMaxesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.trainingMaxes,
      getReferencedColumn: (t) => t.programUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingMaxesTableAnnotationComposer(
            $db: $db,
            $table: $db.trainingMaxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProgramsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $ProgramsTable,
          ProgramRow,
          $$ProgramsTableFilterComposer,
          $$ProgramsTableOrderingComposer,
          $$ProgramsTableAnnotationComposer,
          $$ProgramsTableCreateCompanionBuilder,
          $$ProgramsTableUpdateCompanionBuilder,
          (ProgramRow, $$ProgramsTableReferences),
          ProgramRow,
          PrefetchHooks Function({bool programDaysRefs, bool trainingMaxesRefs})
        > {
  $$ProgramsTableTableManager(_$HarvestDatabase db, $ProgramsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgramsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgramsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgramsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> weeks = const Value.absent(),
                Value<String?> commitmentUuid = const Value.absent(),
                Value<String?> albumUuid = const Value.absent(),
                Value<String> photoPrompt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgramsCompanion(
                uuid: uuid,
                name: name,
                note: note,
                weeks: weeks,
                commitmentUuid: commitmentUuid,
                albumUuid: albumUuid,
                photoPrompt: photoPrompt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String name,
                Value<String?> note = const Value.absent(),
                Value<int?> weeks = const Value.absent(),
                Value<String?> commitmentUuid = const Value.absent(),
                Value<String?> albumUuid = const Value.absent(),
                Value<String> photoPrompt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgramsCompanion.insert(
                uuid: uuid,
                name: name,
                note: note,
                weeks: weeks,
                commitmentUuid: commitmentUuid,
                albumUuid: albumUuid,
                photoPrompt: photoPrompt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProgramsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({programDaysRefs = false, trainingMaxesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (programDaysRefs) db.programDays,
                    if (trainingMaxesRefs) db.trainingMaxes,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (programDaysRefs)
                        await $_getPrefetchedData<
                          ProgramRow,
                          $ProgramsTable,
                          ProgramDayRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProgramsTableReferences
                              ._programDaysRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProgramsTableReferences(
                                db,
                                table,
                                p0,
                              ).programDaysRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.programUuid == item.uuid,
                              ),
                          typedResults: items,
                        ),
                      if (trainingMaxesRefs)
                        await $_getPrefetchedData<
                          ProgramRow,
                          $ProgramsTable,
                          TrainingMaxRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProgramsTableReferences
                              ._trainingMaxesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProgramsTableReferences(
                                db,
                                table,
                                p0,
                              ).trainingMaxesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.programUuid == item.uuid,
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

typedef $$ProgramsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $ProgramsTable,
      ProgramRow,
      $$ProgramsTableFilterComposer,
      $$ProgramsTableOrderingComposer,
      $$ProgramsTableAnnotationComposer,
      $$ProgramsTableCreateCompanionBuilder,
      $$ProgramsTableUpdateCompanionBuilder,
      (ProgramRow, $$ProgramsTableReferences),
      ProgramRow,
      PrefetchHooks Function({bool programDaysRefs, bool trainingMaxesRefs})
    >;
typedef $$ProgramDaysTableCreateCompanionBuilder =
    ProgramDaysCompanion Function({
      required String uuid,
      required String programUuid,
      required String name,
      required int position,
      Value<int?> week,
      Value<String?> accessories,
      Value<int> rowid,
    });
typedef $$ProgramDaysTableUpdateCompanionBuilder =
    ProgramDaysCompanion Function({
      Value<String> uuid,
      Value<String> programUuid,
      Value<String> name,
      Value<int> position,
      Value<int?> week,
      Value<String?> accessories,
      Value<int> rowid,
    });

final class $$ProgramDaysTableReferences
    extends
        BaseReferences<_$HarvestDatabase, $ProgramDaysTable, ProgramDayRow> {
  $$ProgramDaysTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProgramsTable _programUuidTable(_$HarvestDatabase db) =>
      db.programs.createAlias('program_days__program_uuid__programs__uuid');

  $$ProgramsTableProcessedTableManager get programUuid {
    final $_column = $_itemColumn<String>('program_uuid')!;

    final manager = $$ProgramsTableTableManager(
      $_db,
      $_db.programs,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_programUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ProgramSlotsTable, List<ProgramSlotRow>>
  _programSlotsRefsTable(_$HarvestDatabase db) => MultiTypedResultKey.fromTable(
    db.programSlots,
    aliasName: 'program_days__uuid__program_slots__day_uuid',
  );

  $$ProgramSlotsTableProcessedTableManager get programSlotsRefs {
    final manager = $$ProgramSlotsTableTableManager(
      $_db,
      $_db.programSlots,
    ).filter((f) => f.dayUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!));

    final cache = $_typedResult.readTableOrNull(_programSlotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProgramDaysTableFilterComposer
    extends Composer<_$HarvestDatabase, $ProgramDaysTable> {
  $$ProgramDaysTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get week => $composableBuilder(
    column: $table.week,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accessories => $composableBuilder(
    column: $table.accessories,
    builder: (column) => ColumnFilters(column),
  );

  $$ProgramsTableFilterComposer get programUuid {
    final $$ProgramsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.programUuid,
      referencedTable: $db.programs,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramsTableFilterComposer(
            $db: $db,
            $table: $db.programs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> programSlotsRefs(
    Expression<bool> Function($$ProgramSlotsTableFilterComposer f) f,
  ) {
    final $$ProgramSlotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.programSlots,
      getReferencedColumn: (t) => t.dayUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramSlotsTableFilterComposer(
            $db: $db,
            $table: $db.programSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProgramDaysTableOrderingComposer
    extends Composer<_$HarvestDatabase, $ProgramDaysTable> {
  $$ProgramDaysTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get week => $composableBuilder(
    column: $table.week,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accessories => $composableBuilder(
    column: $table.accessories,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProgramsTableOrderingComposer get programUuid {
    final $$ProgramsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.programUuid,
      referencedTable: $db.programs,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramsTableOrderingComposer(
            $db: $db,
            $table: $db.programs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProgramDaysTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $ProgramDaysTable> {
  $$ProgramDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get week =>
      $composableBuilder(column: $table.week, builder: (column) => column);

  GeneratedColumn<String> get accessories => $composableBuilder(
    column: $table.accessories,
    builder: (column) => column,
  );

  $$ProgramsTableAnnotationComposer get programUuid {
    final $$ProgramsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.programUuid,
      referencedTable: $db.programs,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramsTableAnnotationComposer(
            $db: $db,
            $table: $db.programs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> programSlotsRefs<T extends Object>(
    Expression<T> Function($$ProgramSlotsTableAnnotationComposer a) f,
  ) {
    final $$ProgramSlotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.programSlots,
      getReferencedColumn: (t) => t.dayUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramSlotsTableAnnotationComposer(
            $db: $db,
            $table: $db.programSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProgramDaysTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $ProgramDaysTable,
          ProgramDayRow,
          $$ProgramDaysTableFilterComposer,
          $$ProgramDaysTableOrderingComposer,
          $$ProgramDaysTableAnnotationComposer,
          $$ProgramDaysTableCreateCompanionBuilder,
          $$ProgramDaysTableUpdateCompanionBuilder,
          (ProgramDayRow, $$ProgramDaysTableReferences),
          ProgramDayRow,
          PrefetchHooks Function({bool programUuid, bool programSlotsRefs})
        > {
  $$ProgramDaysTableTableManager(_$HarvestDatabase db, $ProgramDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgramDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgramDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgramDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> programUuid = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> week = const Value.absent(),
                Value<String?> accessories = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgramDaysCompanion(
                uuid: uuid,
                programUuid: programUuid,
                name: name,
                position: position,
                week: week,
                accessories: accessories,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String programUuid,
                required String name,
                required int position,
                Value<int?> week = const Value.absent(),
                Value<String?> accessories = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgramDaysCompanion.insert(
                uuid: uuid,
                programUuid: programUuid,
                name: name,
                position: position,
                week: week,
                accessories: accessories,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProgramDaysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({programUuid = false, programSlotsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (programSlotsRefs) db.programSlots,
                  ],
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
                        if (programUuid) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.programUuid,
                            referencedTable: $$ProgramDaysTableReferences
                                ._programUuidTable(db),
                            referencedColumn: $$ProgramDaysTableReferences
                                ._programUuidTable(db)
                                .uuid,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (programSlotsRefs)
                        await $_getPrefetchedData<
                          ProgramDayRow,
                          $ProgramDaysTable,
                          ProgramSlotRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProgramDaysTableReferences
                              ._programSlotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProgramDaysTableReferences(
                                db,
                                table,
                                p0,
                              ).programSlotsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.dayUuid == item.uuid,
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

typedef $$ProgramDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $ProgramDaysTable,
      ProgramDayRow,
      $$ProgramDaysTableFilterComposer,
      $$ProgramDaysTableOrderingComposer,
      $$ProgramDaysTableAnnotationComposer,
      $$ProgramDaysTableCreateCompanionBuilder,
      $$ProgramDaysTableUpdateCompanionBuilder,
      (ProgramDayRow, $$ProgramDaysTableReferences),
      ProgramDayRow,
      PrefetchHooks Function({bool programUuid, bool programSlotsRefs})
    >;
typedef $$ProgramSlotsTableCreateCompanionBuilder =
    ProgramSlotsCompanion Function({
      required String uuid,
      required String dayUuid,
      required String exerciseId,
      required int position,
      Value<int?> restSeconds,
      Value<int> barGrams,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$ProgramSlotsTableUpdateCompanionBuilder =
    ProgramSlotsCompanion Function({
      Value<String> uuid,
      Value<String> dayUuid,
      Value<String> exerciseId,
      Value<int> position,
      Value<int?> restSeconds,
      Value<int> barGrams,
      Value<String?> note,
      Value<int> rowid,
    });

final class $$ProgramSlotsTableReferences
    extends
        BaseReferences<_$HarvestDatabase, $ProgramSlotsTable, ProgramSlotRow> {
  $$ProgramSlotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProgramDaysTable _dayUuidTable(_$HarvestDatabase db) =>
      db.programDays.createAlias('program_slots__day_uuid__program_days__uuid');

  $$ProgramDaysTableProcessedTableManager get dayUuid {
    final $_column = $_itemColumn<String>('day_uuid')!;

    final manager = $$ProgramDaysTableTableManager(
      $_db,
      $_db.programDays,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_dayUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TargetSetsTable, List<TargetSetRow>>
  _targetSetsRefsTable(_$HarvestDatabase db) => MultiTypedResultKey.fromTable(
    db.targetSets,
    aliasName: 'program_slots__uuid__target_sets__slot_uuid',
  );

  $$TargetSetsTableProcessedTableManager get targetSetsRefs {
    final manager = $$TargetSetsTableTableManager(
      $_db,
      $_db.targetSets,
    ).filter((f) => f.slotUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!));

    final cache = $_typedResult.readTableOrNull(_targetSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProgramSlotsTableFilterComposer
    extends Composer<_$HarvestDatabase, $ProgramSlotsTable> {
  $$ProgramSlotsTableFilterComposer({
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

  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get barGrams => $composableBuilder(
    column: $table.barGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$ProgramDaysTableFilterComposer get dayUuid {
    final $$ProgramDaysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayUuid,
      referencedTable: $db.programDays,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramDaysTableFilterComposer(
            $db: $db,
            $table: $db.programDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> targetSetsRefs(
    Expression<bool> Function($$TargetSetsTableFilterComposer f) f,
  ) {
    final $$TargetSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.targetSets,
      getReferencedColumn: (t) => t.slotUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TargetSetsTableFilterComposer(
            $db: $db,
            $table: $db.targetSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProgramSlotsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $ProgramSlotsTable> {
  $$ProgramSlotsTableOrderingComposer({
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

  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get barGrams => $composableBuilder(
    column: $table.barGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProgramDaysTableOrderingComposer get dayUuid {
    final $$ProgramDaysTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayUuid,
      referencedTable: $db.programDays,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramDaysTableOrderingComposer(
            $db: $db,
            $table: $db.programDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProgramSlotsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $ProgramSlotsTable> {
  $$ProgramSlotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get barGrams =>
      $composableBuilder(column: $table.barGrams, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$ProgramDaysTableAnnotationComposer get dayUuid {
    final $$ProgramDaysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayUuid,
      referencedTable: $db.programDays,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramDaysTableAnnotationComposer(
            $db: $db,
            $table: $db.programDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> targetSetsRefs<T extends Object>(
    Expression<T> Function($$TargetSetsTableAnnotationComposer a) f,
  ) {
    final $$TargetSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.targetSets,
      getReferencedColumn: (t) => t.slotUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TargetSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.targetSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProgramSlotsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $ProgramSlotsTable,
          ProgramSlotRow,
          $$ProgramSlotsTableFilterComposer,
          $$ProgramSlotsTableOrderingComposer,
          $$ProgramSlotsTableAnnotationComposer,
          $$ProgramSlotsTableCreateCompanionBuilder,
          $$ProgramSlotsTableUpdateCompanionBuilder,
          (ProgramSlotRow, $$ProgramSlotsTableReferences),
          ProgramSlotRow,
          PrefetchHooks Function({bool dayUuid, bool targetSetsRefs})
        > {
  $$ProgramSlotsTableTableManager(
    _$HarvestDatabase db,
    $ProgramSlotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgramSlotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgramSlotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgramSlotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> dayUuid = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> restSeconds = const Value.absent(),
                Value<int> barGrams = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgramSlotsCompanion(
                uuid: uuid,
                dayUuid: dayUuid,
                exerciseId: exerciseId,
                position: position,
                restSeconds: restSeconds,
                barGrams: barGrams,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String dayUuid,
                required String exerciseId,
                required int position,
                Value<int?> restSeconds = const Value.absent(),
                Value<int> barGrams = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgramSlotsCompanion.insert(
                uuid: uuid,
                dayUuid: dayUuid,
                exerciseId: exerciseId,
                position: position,
                restSeconds: restSeconds,
                barGrams: barGrams,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProgramSlotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({dayUuid = false, targetSetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (targetSetsRefs) db.targetSets],
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
                    if (dayUuid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.dayUuid,
                        referencedTable: $$ProgramSlotsTableReferences
                            ._dayUuidTable(db),
                        referencedColumn: $$ProgramSlotsTableReferences
                            ._dayUuidTable(db)
                            .uuid,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (targetSetsRefs)
                    await $_getPrefetchedData<
                      ProgramSlotRow,
                      $ProgramSlotsTable,
                      TargetSetRow
                    >(
                      currentTable: table,
                      referencedTable: $$ProgramSlotsTableReferences
                          ._targetSetsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ProgramSlotsTableReferences(
                            db,
                            table,
                            p0,
                          ).targetSetsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.slotUuid == item.uuid),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProgramSlotsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $ProgramSlotsTable,
      ProgramSlotRow,
      $$ProgramSlotsTableFilterComposer,
      $$ProgramSlotsTableOrderingComposer,
      $$ProgramSlotsTableAnnotationComposer,
      $$ProgramSlotsTableCreateCompanionBuilder,
      $$ProgramSlotsTableUpdateCompanionBuilder,
      (ProgramSlotRow, $$ProgramSlotsTableReferences),
      ProgramSlotRow,
      PrefetchHooks Function({bool dayUuid, bool targetSetsRefs})
    >;
typedef $$TargetSetsTableCreateCompanionBuilder = TargetSetsCompanion Function({
  required String uuid,
  required String slotUuid,
  required int position,
  Value<int?> reps,
  Value<int?> weightGrams,
  Value<int?> percentTenths,
  Value<bool> openEnded,
  Value<int> rowid,
});
typedef $$TargetSetsTableUpdateCompanionBuilder = TargetSetsCompanion Function({
  Value<String> uuid,
  Value<String> slotUuid,
  Value<int> position,
  Value<int?> reps,
  Value<int?> weightGrams,
  Value<int?> percentTenths,
  Value<bool> openEnded,
  Value<int> rowid,
});

final class $$TargetSetsTableReferences
    extends BaseReferences<_$HarvestDatabase, $TargetSetsTable, TargetSetRow> {
  $$TargetSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProgramSlotsTable _slotUuidTable(_$HarvestDatabase db) => db
      .programSlots
      .createAlias('target_sets__slot_uuid__program_slots__uuid');

  $$ProgramSlotsTableProcessedTableManager get slotUuid {
    final $_column = $_itemColumn<String>('slot_uuid')!;

    final manager = $$ProgramSlotsTableTableManager(
      $_db,
      $_db.programSlots,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_slotUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TargetSetsTableFilterComposer
    extends Composer<_$HarvestDatabase, $TargetSetsTable> {
  $$TargetSetsTableFilterComposer({
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

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get percentTenths => $composableBuilder(
    column: $table.percentTenths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get openEnded => $composableBuilder(
    column: $table.openEnded,
    builder: (column) => ColumnFilters(column),
  );

  $$ProgramSlotsTableFilterComposer get slotUuid {
    final $$ProgramSlotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotUuid,
      referencedTable: $db.programSlots,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramSlotsTableFilterComposer(
            $db: $db,
            $table: $db.programSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TargetSetsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $TargetSetsTable> {
  $$TargetSetsTableOrderingComposer({
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

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get percentTenths => $composableBuilder(
    column: $table.percentTenths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get openEnded => $composableBuilder(
    column: $table.openEnded,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProgramSlotsTableOrderingComposer get slotUuid {
    final $$ProgramSlotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotUuid,
      referencedTable: $db.programSlots,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramSlotsTableOrderingComposer(
            $db: $db,
            $table: $db.programSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TargetSetsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $TargetSetsTable> {
  $$TargetSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => column,
  );

  GeneratedColumn<int> get percentTenths => $composableBuilder(
    column: $table.percentTenths,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get openEnded =>
      $composableBuilder(column: $table.openEnded, builder: (column) => column);

  $$ProgramSlotsTableAnnotationComposer get slotUuid {
    final $$ProgramSlotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotUuid,
      referencedTable: $db.programSlots,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramSlotsTableAnnotationComposer(
            $db: $db,
            $table: $db.programSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TargetSetsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $TargetSetsTable,
          TargetSetRow,
          $$TargetSetsTableFilterComposer,
          $$TargetSetsTableOrderingComposer,
          $$TargetSetsTableAnnotationComposer,
          $$TargetSetsTableCreateCompanionBuilder,
          $$TargetSetsTableUpdateCompanionBuilder,
          (TargetSetRow, $$TargetSetsTableReferences),
          TargetSetRow,
          PrefetchHooks Function({bool slotUuid})
        > {
  $$TargetSetsTableTableManager(_$HarvestDatabase db, $TargetSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TargetSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TargetSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TargetSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> slotUuid = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<int?> weightGrams = const Value.absent(),
                Value<int?> percentTenths = const Value.absent(),
                Value<bool> openEnded = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TargetSetsCompanion(
                uuid: uuid,
                slotUuid: slotUuid,
                position: position,
                reps: reps,
                weightGrams: weightGrams,
                percentTenths: percentTenths,
                openEnded: openEnded,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String slotUuid,
                required int position,
                Value<int?> reps = const Value.absent(),
                Value<int?> weightGrams = const Value.absent(),
                Value<int?> percentTenths = const Value.absent(),
                Value<bool> openEnded = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TargetSetsCompanion.insert(
                uuid: uuid,
                slotUuid: slotUuid,
                position: position,
                reps: reps,
                weightGrams: weightGrams,
                percentTenths: percentTenths,
                openEnded: openEnded,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TargetSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({slotUuid = false}) {
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
                    if (slotUuid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.slotUuid,
                        referencedTable: $$TargetSetsTableReferences
                            ._slotUuidTable(db),
                        referencedColumn: $$TargetSetsTableReferences
                            ._slotUuidTable(db)
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

typedef $$TargetSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $TargetSetsTable,
      TargetSetRow,
      $$TargetSetsTableFilterComposer,
      $$TargetSetsTableOrderingComposer,
      $$TargetSetsTableAnnotationComposer,
      $$TargetSetsTableCreateCompanionBuilder,
      $$TargetSetsTableUpdateCompanionBuilder,
      (TargetSetRow, $$TargetSetsTableReferences),
      TargetSetRow,
      PrefetchHooks Function({bool slotUuid})
    >;
typedef $$TrainingMaxesTableCreateCompanionBuilder =
    TrainingMaxesCompanion Function({
      required String programUuid,
      required String exerciseId,
      required int grams,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$TrainingMaxesTableUpdateCompanionBuilder =
    TrainingMaxesCompanion Function({
      Value<String> programUuid,
      Value<String> exerciseId,
      Value<int> grams,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TrainingMaxesTableReferences
    extends
        BaseReferences<_$HarvestDatabase, $TrainingMaxesTable, TrainingMaxRow> {
  $$TrainingMaxesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProgramsTable _programUuidTable(_$HarvestDatabase db) =>
      db.programs.createAlias('training_maxes__program_uuid__programs__uuid');

  $$ProgramsTableProcessedTableManager get programUuid {
    final $_column = $_itemColumn<String>('program_uuid')!;

    final manager = $$ProgramsTableTableManager(
      $_db,
      $_db.programs,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_programUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TrainingMaxesTableFilterComposer
    extends Composer<_$HarvestDatabase, $TrainingMaxesTable> {
  $$TrainingMaxesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get grams => $composableBuilder(
    column: $table.grams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProgramsTableFilterComposer get programUuid {
    final $$ProgramsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.programUuid,
      referencedTable: $db.programs,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramsTableFilterComposer(
            $db: $db,
            $table: $db.programs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrainingMaxesTableOrderingComposer
    extends Composer<_$HarvestDatabase, $TrainingMaxesTable> {
  $$TrainingMaxesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get grams => $composableBuilder(
    column: $table.grams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProgramsTableOrderingComposer get programUuid {
    final $$ProgramsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.programUuid,
      referencedTable: $db.programs,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramsTableOrderingComposer(
            $db: $db,
            $table: $db.programs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrainingMaxesTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $TrainingMaxesTable> {
  $$TrainingMaxesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get grams =>
      $composableBuilder(column: $table.grams, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProgramsTableAnnotationComposer get programUuid {
    final $$ProgramsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.programUuid,
      referencedTable: $db.programs,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramsTableAnnotationComposer(
            $db: $db,
            $table: $db.programs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrainingMaxesTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $TrainingMaxesTable,
          TrainingMaxRow,
          $$TrainingMaxesTableFilterComposer,
          $$TrainingMaxesTableOrderingComposer,
          $$TrainingMaxesTableAnnotationComposer,
          $$TrainingMaxesTableCreateCompanionBuilder,
          $$TrainingMaxesTableUpdateCompanionBuilder,
          (TrainingMaxRow, $$TrainingMaxesTableReferences),
          TrainingMaxRow,
          PrefetchHooks Function({bool programUuid})
        > {
  $$TrainingMaxesTableTableManager(
    _$HarvestDatabase db,
    $TrainingMaxesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrainingMaxesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrainingMaxesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrainingMaxesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> programUuid = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<int> grams = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainingMaxesCompanion(
                programUuid: programUuid,
                exerciseId: exerciseId,
                grams: grams,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String programUuid,
                required String exerciseId,
                required int grams,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainingMaxesCompanion.insert(
                programUuid: programUuid,
                exerciseId: exerciseId,
                grams: grams,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TrainingMaxesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({programUuid = false}) {
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
                    if (programUuid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.programUuid,
                        referencedTable: $$TrainingMaxesTableReferences
                            ._programUuidTable(db),
                        referencedColumn: $$TrainingMaxesTableReferences
                            ._programUuidTable(db)
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

typedef $$TrainingMaxesTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $TrainingMaxesTable,
      TrainingMaxRow,
      $$TrainingMaxesTableFilterComposer,
      $$TrainingMaxesTableOrderingComposer,
      $$TrainingMaxesTableAnnotationComposer,
      $$TrainingMaxesTableCreateCompanionBuilder,
      $$TrainingMaxesTableUpdateCompanionBuilder,
      (TrainingMaxRow, $$TrainingMaxesTableReferences),
      TrainingMaxRow,
      PrefetchHooks Function({bool programUuid})
    >;
typedef $$WorkoutSessionsTableCreateCompanionBuilder =
    WorkoutSessionsCompanion Function({
      required String uuid,
      Value<String?> programUuid,
      Value<String?> dayUuid,
      Value<String?> title,
      required String harvestDay,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<String?> note,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$WorkoutSessionsTableUpdateCompanionBuilder =
    WorkoutSessionsCompanion Function({
      Value<String> uuid,
      Value<String?> programUuid,
      Value<String?> dayUuid,
      Value<String?> title,
      Value<String> harvestDay,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<String?> note,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$WorkoutSessionsTableReferences
    extends
        BaseReferences<
          _$HarvestDatabase,
          $WorkoutSessionsTable,
          WorkoutSessionRow
        > {
  $$WorkoutSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SessionExercisesTable, List<SessionExerciseRow>>
  _sessionExercisesRefsTable(_$HarvestDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.sessionExercises,
        aliasName: 'workout_sessions__uuid__session_exercises__session_uuid',
      );

  $$SessionExercisesTableProcessedTableManager get sessionExercisesRefs {
    final manager =
        $$SessionExercisesTableTableManager($_db, $_db.sessionExercises).filter(
          (f) => f.sessionUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _sessionExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutSessionsTableFilterComposer
    extends Composer<_$HarvestDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableFilterComposer({
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

  ColumnFilters<String> get programUuid => $composableBuilder(
    column: $table.programUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayUuid => $composableBuilder(
    column: $table.dayUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
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

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sessionExercisesRefs(
    Expression<bool> Function($$SessionExercisesTableFilterComposer f) f,
  ) {
    final $$SessionExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.sessionUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableFilterComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutSessionsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableOrderingComposer({
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

  ColumnOrderings<String> get programUuid => $composableBuilder(
    column: $table.programUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayUuid => $composableBuilder(
    column: $table.dayUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
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

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutSessionsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get programUuid => $composableBuilder(
    column: $table.programUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dayUuid =>
      $composableBuilder(column: $table.dayUuid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> sessionExercisesRefs<T extends Object>(
    Expression<T> Function($$SessionExercisesTableAnnotationComposer a) f,
  ) {
    final $$SessionExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.sessionUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutSessionsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $WorkoutSessionsTable,
          WorkoutSessionRow,
          $$WorkoutSessionsTableFilterComposer,
          $$WorkoutSessionsTableOrderingComposer,
          $$WorkoutSessionsTableAnnotationComposer,
          $$WorkoutSessionsTableCreateCompanionBuilder,
          $$WorkoutSessionsTableUpdateCompanionBuilder,
          (WorkoutSessionRow, $$WorkoutSessionsTableReferences),
          WorkoutSessionRow,
          PrefetchHooks Function({bool sessionExercisesRefs})
        > {
  $$WorkoutSessionsTableTableManager(
    _$HarvestDatabase db,
    $WorkoutSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String?> programUuid = const Value.absent(),
                Value<String?> dayUuid = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> harvestDay = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSessionsCompanion(
                uuid: uuid,
                programUuid: programUuid,
                dayUuid: dayUuid,
                title: title,
                harvestDay: harvestDay,
                startedAt: startedAt,
                endedAt: endedAt,
                note: note,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                Value<String?> programUuid = const Value.absent(),
                Value<String?> dayUuid = const Value.absent(),
                Value<String?> title = const Value.absent(),
                required String harvestDay,
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSessionsCompanion.insert(
                uuid: uuid,
                programUuid: programUuid,
                dayUuid: dayUuid,
                title: title,
                harvestDay: harvestDay,
                startedAt: startedAt,
                endedAt: endedAt,
                note: note,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkoutSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionExercisesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sessionExercisesRefs) db.sessionExercises,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionExercisesRefs)
                    await $_getPrefetchedData<
                      WorkoutSessionRow,
                      $WorkoutSessionsTable,
                      SessionExerciseRow
                    >(
                      currentTable: table,
                      referencedTable: $$WorkoutSessionsTableReferences
                          ._sessionExercisesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WorkoutSessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).sessionExercisesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.sessionUuid == item.uuid,
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

typedef $$WorkoutSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $WorkoutSessionsTable,
      WorkoutSessionRow,
      $$WorkoutSessionsTableFilterComposer,
      $$WorkoutSessionsTableOrderingComposer,
      $$WorkoutSessionsTableAnnotationComposer,
      $$WorkoutSessionsTableCreateCompanionBuilder,
      $$WorkoutSessionsTableUpdateCompanionBuilder,
      (WorkoutSessionRow, $$WorkoutSessionsTableReferences),
      WorkoutSessionRow,
      PrefetchHooks Function({bool sessionExercisesRefs})
    >;
typedef $$SessionExercisesTableCreateCompanionBuilder =
    SessionExercisesCompanion Function({
      required String uuid,
      required String sessionUuid,
      required int position,
      required String exerciseId,
      Value<String?> plannedExerciseId,
      Value<String?> slotUuid,
      Value<bool> skipped,
      Value<String?> note,
      Value<int?> restSeconds,
      Value<int> barGrams,
      Value<int> rowid,
    });
typedef $$SessionExercisesTableUpdateCompanionBuilder =
    SessionExercisesCompanion Function({
      Value<String> uuid,
      Value<String> sessionUuid,
      Value<int> position,
      Value<String> exerciseId,
      Value<String?> plannedExerciseId,
      Value<String?> slotUuid,
      Value<bool> skipped,
      Value<String?> note,
      Value<int?> restSeconds,
      Value<int> barGrams,
      Value<int> rowid,
    });

final class $$SessionExercisesTableReferences
    extends
        BaseReferences<
          _$HarvestDatabase,
          $SessionExercisesTable,
          SessionExerciseRow
        > {
  $$SessionExercisesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkoutSessionsTable _sessionUuidTable(_$HarvestDatabase db) => db
      .workoutSessions
      .createAlias('session_exercises__session_uuid__workout_sessions__uuid');

  $$WorkoutSessionsTableProcessedTableManager get sessionUuid {
    final $_column = $_itemColumn<String>('session_uuid')!;

    final manager = $$WorkoutSessionsTableTableManager(
      $_db,
      $_db.workoutSessions,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$WorkoutSetsTable, List<WorkoutSetRow>>
  _workoutSetsRefsTable(_$HarvestDatabase db) => MultiTypedResultKey.fromTable(
    db.workoutSets,
    aliasName: 'session_exercises__uuid__workout_sets__session_exercise_uuid',
  );

  $$WorkoutSetsTableProcessedTableManager get workoutSetsRefs {
    final manager = $$WorkoutSetsTableTableManager($_db, $_db.workoutSets)
        .filter(
          (f) => f.sessionExerciseUuid.uuid.sqlEquals(
            $_itemColumn<String>('uuid')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_workoutSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionExercisesTableFilterComposer
    extends Composer<_$HarvestDatabase, $SessionExercisesTable> {
  $$SessionExercisesTableFilterComposer({
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

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plannedExerciseId => $composableBuilder(
    column: $table.plannedExerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slotUuid => $composableBuilder(
    column: $table.slotUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get skipped => $composableBuilder(
    column: $table.skipped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get barGrams => $composableBuilder(
    column: $table.barGrams,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkoutSessionsTableFilterComposer get sessionUuid {
    final $$WorkoutSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionUuid,
      referencedTable: $db.workoutSessions,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSessionsTableFilterComposer(
            $db: $db,
            $table: $db.workoutSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> workoutSetsRefs(
    Expression<bool> Function($$WorkoutSetsTableFilterComposer f) f,
  ) {
    final $$WorkoutSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.sessionExerciseUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableFilterComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionExercisesTableOrderingComposer
    extends Composer<_$HarvestDatabase, $SessionExercisesTable> {
  $$SessionExercisesTableOrderingComposer({
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

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plannedExerciseId => $composableBuilder(
    column: $table.plannedExerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slotUuid => $composableBuilder(
    column: $table.slotUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get skipped => $composableBuilder(
    column: $table.skipped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get barGrams => $composableBuilder(
    column: $table.barGrams,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutSessionsTableOrderingComposer get sessionUuid {
    final $$WorkoutSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionUuid,
      referencedTable: $db.workoutSessions,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.workoutSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionExercisesTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $SessionExercisesTable> {
  $$SessionExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plannedExerciseId => $composableBuilder(
    column: $table.plannedExerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get slotUuid =>
      $composableBuilder(column: $table.slotUuid, builder: (column) => column);

  GeneratedColumn<bool> get skipped =>
      $composableBuilder(column: $table.skipped, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get barGrams =>
      $composableBuilder(column: $table.barGrams, builder: (column) => column);

  $$WorkoutSessionsTableAnnotationComposer get sessionUuid {
    final $$WorkoutSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionUuid,
      referencedTable: $db.workoutSessions,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> workoutSetsRefs<T extends Object>(
    Expression<T> Function($$WorkoutSetsTableAnnotationComposer a) f,
  ) {
    final $$WorkoutSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.sessionExerciseUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionExercisesTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $SessionExercisesTable,
          SessionExerciseRow,
          $$SessionExercisesTableFilterComposer,
          $$SessionExercisesTableOrderingComposer,
          $$SessionExercisesTableAnnotationComposer,
          $$SessionExercisesTableCreateCompanionBuilder,
          $$SessionExercisesTableUpdateCompanionBuilder,
          (SessionExerciseRow, $$SessionExercisesTableReferences),
          SessionExerciseRow,
          PrefetchHooks Function({bool sessionUuid, bool workoutSetsRefs})
        > {
  $$SessionExercisesTableTableManager(
    _$HarvestDatabase db,
    $SessionExercisesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> sessionUuid = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<String?> plannedExerciseId = const Value.absent(),
                Value<String?> slotUuid = const Value.absent(),
                Value<bool> skipped = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> restSeconds = const Value.absent(),
                Value<int> barGrams = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionExercisesCompanion(
                uuid: uuid,
                sessionUuid: sessionUuid,
                position: position,
                exerciseId: exerciseId,
                plannedExerciseId: plannedExerciseId,
                slotUuid: slotUuid,
                skipped: skipped,
                note: note,
                restSeconds: restSeconds,
                barGrams: barGrams,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String sessionUuid,
                required int position,
                required String exerciseId,
                Value<String?> plannedExerciseId = const Value.absent(),
                Value<String?> slotUuid = const Value.absent(),
                Value<bool> skipped = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> restSeconds = const Value.absent(),
                Value<int> barGrams = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionExercisesCompanion.insert(
                uuid: uuid,
                sessionUuid: sessionUuid,
                position: position,
                exerciseId: exerciseId,
                plannedExerciseId: plannedExerciseId,
                slotUuid: slotUuid,
                skipped: skipped,
                note: note,
                restSeconds: restSeconds,
                barGrams: barGrams,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionExercisesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sessionUuid = false, workoutSetsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workoutSetsRefs) db.workoutSets,
                  ],
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
                        if (sessionUuid) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sessionUuid,
                            referencedTable: $$SessionExercisesTableReferences
                                ._sessionUuidTable(db),
                            referencedColumn: $$SessionExercisesTableReferences
                                ._sessionUuidTable(db)
                                .uuid,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workoutSetsRefs)
                        await $_getPrefetchedData<
                          SessionExerciseRow,
                          $SessionExercisesTable,
                          WorkoutSetRow
                        >(
                          currentTable: table,
                          referencedTable: $$SessionExercisesTableReferences
                              ._workoutSetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionExercisesTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutSetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionExerciseUuid == item.uuid,
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

typedef $$SessionExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $SessionExercisesTable,
      SessionExerciseRow,
      $$SessionExercisesTableFilterComposer,
      $$SessionExercisesTableOrderingComposer,
      $$SessionExercisesTableAnnotationComposer,
      $$SessionExercisesTableCreateCompanionBuilder,
      $$SessionExercisesTableUpdateCompanionBuilder,
      (SessionExerciseRow, $$SessionExercisesTableReferences),
      SessionExerciseRow,
      PrefetchHooks Function({bool sessionUuid, bool workoutSetsRefs})
    >;
typedef $$WorkoutSetsTableCreateCompanionBuilder =
    WorkoutSetsCompanion Function({
      required String uuid,
      required String sessionExerciseUuid,
      required int position,
      Value<int> weightGrams,
      Value<int> reps,
      Value<bool> done,
      Value<String?> targetLabel,
      Value<bool> openEnded,
      Value<DateTime> loggedAt,
      Value<int> rowid,
    });
typedef $$WorkoutSetsTableUpdateCompanionBuilder =
    WorkoutSetsCompanion Function({
      Value<String> uuid,
      Value<String> sessionExerciseUuid,
      Value<int> position,
      Value<int> weightGrams,
      Value<int> reps,
      Value<bool> done,
      Value<String?> targetLabel,
      Value<bool> openEnded,
      Value<DateTime> loggedAt,
      Value<int> rowid,
    });

final class $$WorkoutSetsTableReferences
    extends
        BaseReferences<_$HarvestDatabase, $WorkoutSetsTable, WorkoutSetRow> {
  $$WorkoutSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionExercisesTable _sessionExerciseUuidTable(
    _$HarvestDatabase db,
  ) => db.sessionExercises.createAlias(
    'workout_sets__session_exercise_uuid__session_exercises__uuid',
  );

  $$SessionExercisesTableProcessedTableManager get sessionExerciseUuid {
    final $_column = $_itemColumn<String>('session_exercise_uuid')!;

    final manager = $$SessionExercisesTableTableManager(
      $_db,
      $_db.sessionExercises,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionExerciseUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkoutSetsTableFilterComposer
    extends Composer<_$HarvestDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableFilterComposer({
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

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetLabel => $composableBuilder(
    column: $table.targetLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get openEnded => $composableBuilder(
    column: $table.openEnded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionExercisesTableFilterComposer get sessionExerciseUuid {
    final $$SessionExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionExerciseUuid,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableFilterComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableOrderingComposer({
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

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetLabel => $composableBuilder(
    column: $table.targetLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get openEnded => $composableBuilder(
    column: $table.openEnded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionExercisesTableOrderingComposer get sessionExerciseUuid {
    final $$SessionExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionExerciseUuid,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<String> get targetLabel => $composableBuilder(
    column: $table.targetLabel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get openEnded =>
      $composableBuilder(column: $table.openEnded, builder: (column) => column);

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  $$SessionExercisesTableAnnotationComposer get sessionExerciseUuid {
    final $$SessionExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionExerciseUuid,
      referencedTable: $db.sessionExercises,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $WorkoutSetsTable,
          WorkoutSetRow,
          $$WorkoutSetsTableFilterComposer,
          $$WorkoutSetsTableOrderingComposer,
          $$WorkoutSetsTableAnnotationComposer,
          $$WorkoutSetsTableCreateCompanionBuilder,
          $$WorkoutSetsTableUpdateCompanionBuilder,
          (WorkoutSetRow, $$WorkoutSetsTableReferences),
          WorkoutSetRow,
          PrefetchHooks Function({bool sessionExerciseUuid})
        > {
  $$WorkoutSetsTableTableManager(_$HarvestDatabase db, $WorkoutSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> sessionExerciseUuid = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> weightGrams = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<String?> targetLabel = const Value.absent(),
                Value<bool> openEnded = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSetsCompanion(
                uuid: uuid,
                sessionExerciseUuid: sessionExerciseUuid,
                position: position,
                weightGrams: weightGrams,
                reps: reps,
                done: done,
                targetLabel: targetLabel,
                openEnded: openEnded,
                loggedAt: loggedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String sessionExerciseUuid,
                required int position,
                Value<int> weightGrams = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<String?> targetLabel = const Value.absent(),
                Value<bool> openEnded = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSetsCompanion.insert(
                uuid: uuid,
                sessionExerciseUuid: sessionExerciseUuid,
                position: position,
                weightGrams: weightGrams,
                reps: reps,
                done: done,
                targetLabel: targetLabel,
                openEnded: openEnded,
                loggedAt: loggedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkoutSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionExerciseUuid = false}) {
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
                    if (sessionExerciseUuid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionExerciseUuid,
                        referencedTable: $$WorkoutSetsTableReferences
                            ._sessionExerciseUuidTable(db),
                        referencedColumn: $$WorkoutSetsTableReferences
                            ._sessionExerciseUuidTable(db)
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

typedef $$WorkoutSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $WorkoutSetsTable,
      WorkoutSetRow,
      $$WorkoutSetsTableFilterComposer,
      $$WorkoutSetsTableOrderingComposer,
      $$WorkoutSetsTableAnnotationComposer,
      $$WorkoutSetsTableCreateCompanionBuilder,
      $$WorkoutSetsTableUpdateCompanionBuilder,
      (WorkoutSetRow, $$WorkoutSetsTableReferences),
      WorkoutSetRow,
      PrefetchHooks Function({bool sessionExerciseUuid})
    >;
typedef $$SleepSessionsTableCreateCompanionBuilder =
    SleepSessionsCompanion Function({
      required String uuid,
      required String harvestDay,
      required DateTime fellAsleepAt,
      required DateTime wokeAt,
      required int targetMinutes,
      Value<int?> restedStars,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$SleepSessionsTableUpdateCompanionBuilder =
    SleepSessionsCompanion Function({
      Value<String> uuid,
      Value<String> harvestDay,
      Value<DateTime> fellAsleepAt,
      Value<DateTime> wokeAt,
      Value<int> targetMinutes,
      Value<int?> restedStars,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$SleepSessionsTableFilterComposer
    extends Composer<_$HarvestDatabase, $SleepSessionsTable> {
  $$SleepSessionsTableFilterComposer({
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

  ColumnFilters<DateTime> get fellAsleepAt => $composableBuilder(
    column: $table.fellAsleepAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get wokeAt => $composableBuilder(
    column: $table.wokeAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetMinutes => $composableBuilder(
    column: $table.targetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restedStars => $composableBuilder(
    column: $table.restedStars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SleepSessionsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $SleepSessionsTable> {
  $$SleepSessionsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get fellAsleepAt => $composableBuilder(
    column: $table.fellAsleepAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get wokeAt => $composableBuilder(
    column: $table.wokeAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetMinutes => $composableBuilder(
    column: $table.targetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restedStars => $composableBuilder(
    column: $table.restedStars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SleepSessionsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $SleepSessionsTable> {
  $$SleepSessionsTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get fellAsleepAt => $composableBuilder(
    column: $table.fellAsleepAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get wokeAt =>
      $composableBuilder(column: $table.wokeAt, builder: (column) => column);

  GeneratedColumn<int> get targetMinutes => $composableBuilder(
    column: $table.targetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get restedStars => $composableBuilder(
    column: $table.restedStars,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$SleepSessionsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $SleepSessionsTable,
          SleepSessionRow,
          $$SleepSessionsTableFilterComposer,
          $$SleepSessionsTableOrderingComposer,
          $$SleepSessionsTableAnnotationComposer,
          $$SleepSessionsTableCreateCompanionBuilder,
          $$SleepSessionsTableUpdateCompanionBuilder,
          (
            SleepSessionRow,
            BaseReferences<
              _$HarvestDatabase,
              $SleepSessionsTable,
              SleepSessionRow
            >,
          ),
          SleepSessionRow,
          PrefetchHooks Function()
        > {
  $$SleepSessionsTableTableManager(
    _$HarvestDatabase db,
    $SleepSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SleepSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SleepSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SleepSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> harvestDay = const Value.absent(),
                Value<DateTime> fellAsleepAt = const Value.absent(),
                Value<DateTime> wokeAt = const Value.absent(),
                Value<int> targetMinutes = const Value.absent(),
                Value<int?> restedStars = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SleepSessionsCompanion(
                uuid: uuid,
                harvestDay: harvestDay,
                fellAsleepAt: fellAsleepAt,
                wokeAt: wokeAt,
                targetMinutes: targetMinutes,
                restedStars: restedStars,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String harvestDay,
                required DateTime fellAsleepAt,
                required DateTime wokeAt,
                required int targetMinutes,
                Value<int?> restedStars = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SleepSessionsCompanion.insert(
                uuid: uuid,
                harvestDay: harvestDay,
                fellAsleepAt: fellAsleepAt,
                wokeAt: wokeAt,
                targetMinutes: targetMinutes,
                restedStars: restedStars,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SleepSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $SleepSessionsTable,
      SleepSessionRow,
      $$SleepSessionsTableFilterComposer,
      $$SleepSessionsTableOrderingComposer,
      $$SleepSessionsTableAnnotationComposer,
      $$SleepSessionsTableCreateCompanionBuilder,
      $$SleepSessionsTableUpdateCompanionBuilder,
      (
        SleepSessionRow,
        BaseReferences<_$HarvestDatabase, $SleepSessionsTable, SleepSessionRow>,
      ),
      SleepSessionRow,
      PrefetchHooks Function()
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
          StreakRow,
          $$StreaksTableFilterComposer,
          $$StreaksTableOrderingComposer,
          $$StreaksTableAnnotationComposer,
          $$StreaksTableCreateCompanionBuilder,
          $$StreaksTableUpdateCompanionBuilder,
          (
            StreakRow,
            BaseReferences<_$HarvestDatabase, $StreaksTable, StreakRow>,
          ),
          StreakRow,
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
      StreakRow,
      $$StreaksTableFilterComposer,
      $$StreaksTableOrderingComposer,
      $$StreaksTableAnnotationComposer,
      $$StreaksTableCreateCompanionBuilder,
      $$StreaksTableUpdateCompanionBuilder,
      (StreakRow, BaseReferences<_$HarvestDatabase, $StreaksTable, StreakRow>),
      StreakRow,
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
typedef $$ExpensesTableCreateCompanionBuilder = ExpensesCompanion Function({
  required String uuid,
  required int amountMinor,
  Value<String> currency,
  required String category,
  Value<String?> note,
  required String harvestDay,
  Value<DateTime> loggedAt,
  Value<DateTime?> deletedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$ExpensesTableUpdateCompanionBuilder = ExpensesCompanion Function({
  Value<String> uuid,
  Value<int> amountMinor,
  Value<String> currency,
  Value<String> category,
  Value<String?> note,
  Value<String> harvestDay,
  Value<DateTime> loggedAt,
  Value<DateTime?> deletedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ExpensesTableFilterComposer
    extends Composer<_$HarvestDatabase, $ExpensesTable> {
  $$ExpensesTableFilterComposer({
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

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExpensesTableOrderingComposer
    extends Composer<_$HarvestDatabase, $ExpensesTable> {
  $$ExpensesTableOrderingComposer({
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

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExpensesTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $ExpensesTable> {
  $$ExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ExpensesTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $ExpensesTable,
          ExpenseRow,
          $$ExpensesTableFilterComposer,
          $$ExpensesTableOrderingComposer,
          $$ExpensesTableAnnotationComposer,
          $$ExpensesTableCreateCompanionBuilder,
          $$ExpensesTableUpdateCompanionBuilder,
          (
            ExpenseRow,
            BaseReferences<_$HarvestDatabase, $ExpensesTable, ExpenseRow>,
          ),
          ExpenseRow,
          PrefetchHooks Function()
        > {
  $$ExpensesTableTableManager(_$HarvestDatabase db, $ExpensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> harvestDay = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion(
                uuid: uuid,
                amountMinor: amountMinor,
                currency: currency,
                category: category,
                note: note,
                harvestDay: harvestDay,
                loggedAt: loggedAt,
                deletedAt: deletedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required int amountMinor,
                Value<String> currency = const Value.absent(),
                required String category,
                Value<String?> note = const Value.absent(),
                required String harvestDay,
                Value<DateTime> loggedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion.insert(
                uuid: uuid,
                amountMinor: amountMinor,
                currency: currency,
                category: category,
                note: note,
                harvestDay: harvestDay,
                loggedAt: loggedAt,
                deletedAt: deletedAt,
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

typedef $$ExpensesTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $ExpensesTable,
      ExpenseRow,
      $$ExpensesTableFilterComposer,
      $$ExpensesTableOrderingComposer,
      $$ExpensesTableAnnotationComposer,
      $$ExpensesTableCreateCompanionBuilder,
      $$ExpensesTableUpdateCompanionBuilder,
      (
        ExpenseRow,
        BaseReferences<_$HarvestDatabase, $ExpensesTable, ExpenseRow>,
      ),
      ExpenseRow,
      PrefetchHooks Function()
    >;
typedef $$ExpenseCategoriesTableCreateCompanionBuilder =
    ExpenseCategoriesCompanion Function({
      required String uuid,
      required String name,
      required String icon,
      Value<DateTime?> deletedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ExpenseCategoriesTableUpdateCompanionBuilder =
    ExpenseCategoriesCompanion Function({
      Value<String> uuid,
      Value<String> name,
      Value<String> icon,
      Value<DateTime?> deletedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ExpenseCategoriesTableFilterComposer
    extends Composer<_$HarvestDatabase, $ExpenseCategoriesTable> {
  $$ExpenseCategoriesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
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
}

class $$ExpenseCategoriesTableOrderingComposer
    extends Composer<_$HarvestDatabase, $ExpenseCategoriesTable> {
  $$ExpenseCategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
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
}

class $$ExpenseCategoriesTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $ExpenseCategoriesTable> {
  $$ExpenseCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ExpenseCategoriesTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $ExpenseCategoriesTable,
          ExpenseCategoryRow,
          $$ExpenseCategoriesTableFilterComposer,
          $$ExpenseCategoriesTableOrderingComposer,
          $$ExpenseCategoriesTableAnnotationComposer,
          $$ExpenseCategoriesTableCreateCompanionBuilder,
          $$ExpenseCategoriesTableUpdateCompanionBuilder,
          (
            ExpenseCategoryRow,
            BaseReferences<
              _$HarvestDatabase,
              $ExpenseCategoriesTable,
              ExpenseCategoryRow
            >,
          ),
          ExpenseCategoryRow,
          PrefetchHooks Function()
        > {
  $$ExpenseCategoriesTableTableManager(
    _$HarvestDatabase db,
    $ExpenseCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpenseCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpenseCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpenseCategoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpenseCategoriesCompanion(
                uuid: uuid,
                name: name,
                icon: icon,
                deletedAt: deletedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String name,
                required String icon,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpenseCategoriesCompanion.insert(
                uuid: uuid,
                name: name,
                icon: icon,
                deletedAt: deletedAt,
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

typedef $$ExpenseCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $ExpenseCategoriesTable,
      ExpenseCategoryRow,
      $$ExpenseCategoriesTableFilterComposer,
      $$ExpenseCategoriesTableOrderingComposer,
      $$ExpenseCategoriesTableAnnotationComposer,
      $$ExpenseCategoriesTableCreateCompanionBuilder,
      $$ExpenseCategoriesTableUpdateCompanionBuilder,
      (
        ExpenseCategoryRow,
        BaseReferences<
          _$HarvestDatabase,
          $ExpenseCategoriesTable,
          ExpenseCategoryRow
        >,
      ),
      ExpenseCategoryRow,
      PrefetchHooks Function()
    >;
typedef $$MoneyTxnsTableCreateCompanionBuilder = MoneyTxnsCompanion Function({
  required String uuid,
  required String account,
  required int deltaMinor,
  Value<String> currency,
  Value<String?> note,
  Value<String> kind,
  Value<String?> reference,
  Value<String?> linkUuid,
  required String harvestDay,
  Value<DateTime> loggedAt,
  Value<DateTime?> deletedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$MoneyTxnsTableUpdateCompanionBuilder = MoneyTxnsCompanion Function({
  Value<String> uuid,
  Value<String> account,
  Value<int> deltaMinor,
  Value<String> currency,
  Value<String?> note,
  Value<String> kind,
  Value<String?> reference,
  Value<String?> linkUuid,
  Value<String> harvestDay,
  Value<DateTime> loggedAt,
  Value<DateTime?> deletedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$MoneyTxnsTableFilterComposer
    extends Composer<_$HarvestDatabase, $MoneyTxnsTable> {
  $$MoneyTxnsTableFilterComposer({
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

  ColumnFilters<String> get account => $composableBuilder(
    column: $table.account,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deltaMinor => $composableBuilder(
    column: $table.deltaMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkUuid => $composableBuilder(
    column: $table.linkUuid,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MoneyTxnsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $MoneyTxnsTable> {
  $$MoneyTxnsTableOrderingComposer({
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

  ColumnOrderings<String> get account => $composableBuilder(
    column: $table.account,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deltaMinor => $composableBuilder(
    column: $table.deltaMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkUuid => $composableBuilder(
    column: $table.linkUuid,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MoneyTxnsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $MoneyTxnsTable> {
  $$MoneyTxnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get account =>
      $composableBuilder(column: $table.account, builder: (column) => column);

  GeneratedColumn<int> get deltaMinor => $composableBuilder(
    column: $table.deltaMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<String> get linkUuid =>
      $composableBuilder(column: $table.linkUuid, builder: (column) => column);

  GeneratedColumn<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MoneyTxnsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $MoneyTxnsTable,
          MoneyTxnRow,
          $$MoneyTxnsTableFilterComposer,
          $$MoneyTxnsTableOrderingComposer,
          $$MoneyTxnsTableAnnotationComposer,
          $$MoneyTxnsTableCreateCompanionBuilder,
          $$MoneyTxnsTableUpdateCompanionBuilder,
          (
            MoneyTxnRow,
            BaseReferences<_$HarvestDatabase, $MoneyTxnsTable, MoneyTxnRow>,
          ),
          MoneyTxnRow,
          PrefetchHooks Function()
        > {
  $$MoneyTxnsTableTableManager(_$HarvestDatabase db, $MoneyTxnsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MoneyTxnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MoneyTxnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MoneyTxnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> account = const Value.absent(),
                Value<int> deltaMinor = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> reference = const Value.absent(),
                Value<String?> linkUuid = const Value.absent(),
                Value<String> harvestDay = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MoneyTxnsCompanion(
                uuid: uuid,
                account: account,
                deltaMinor: deltaMinor,
                currency: currency,
                note: note,
                kind: kind,
                reference: reference,
                linkUuid: linkUuid,
                harvestDay: harvestDay,
                loggedAt: loggedAt,
                deletedAt: deletedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String account,
                required int deltaMinor,
                Value<String> currency = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> reference = const Value.absent(),
                Value<String?> linkUuid = const Value.absent(),
                required String harvestDay,
                Value<DateTime> loggedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MoneyTxnsCompanion.insert(
                uuid: uuid,
                account: account,
                deltaMinor: deltaMinor,
                currency: currency,
                note: note,
                kind: kind,
                reference: reference,
                linkUuid: linkUuid,
                harvestDay: harvestDay,
                loggedAt: loggedAt,
                deletedAt: deletedAt,
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

typedef $$MoneyTxnsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $MoneyTxnsTable,
      MoneyTxnRow,
      $$MoneyTxnsTableFilterComposer,
      $$MoneyTxnsTableOrderingComposer,
      $$MoneyTxnsTableAnnotationComposer,
      $$MoneyTxnsTableCreateCompanionBuilder,
      $$MoneyTxnsTableUpdateCompanionBuilder,
      (
        MoneyTxnRow,
        BaseReferences<_$HarvestDatabase, $MoneyTxnsTable, MoneyTxnRow>,
      ),
      MoneyTxnRow,
      PrefetchHooks Function()
    >;
typedef $$DebtsTableCreateCompanionBuilder = DebtsCompanion Function({
  required String uuid,
  required String person,
  required int amountMinor,
  Value<String> currency,
  Value<String?> payOffBy,
  Value<String?> remindAt,
  Value<String?> note,
  Value<DateTime?> settledAt,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$DebtsTableUpdateCompanionBuilder = DebtsCompanion Function({
  Value<String> uuid,
  Value<String> person,
  Value<int> amountMinor,
  Value<String> currency,
  Value<String?> payOffBy,
  Value<String?> remindAt,
  Value<String?> note,
  Value<DateTime?> settledAt,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$DebtsTableReferences
    extends BaseReferences<_$HarvestDatabase, $DebtsTable, DebtRow> {
  $$DebtsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DebtPaymentsTable, List<DebtPaymentRow>>
  _debtPaymentsRefsTable(_$HarvestDatabase db) => MultiTypedResultKey.fromTable(
    db.debtPayments,
    aliasName: 'debts__uuid__debt_payments__debt_uuid',
  );

  $$DebtPaymentsTableProcessedTableManager get debtPaymentsRefs {
    final manager = $$DebtPaymentsTableTableManager(
      $_db,
      $_db.debtPayments,
    ).filter((f) => f.debtUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!));

    final cache = $_typedResult.readTableOrNull(_debtPaymentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DebtsTableFilterComposer
    extends Composer<_$HarvestDatabase, $DebtsTable> {
  $$DebtsTableFilterComposer({
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

  ColumnFilters<String> get person => $composableBuilder(
    column: $table.person,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payOffBy => $composableBuilder(
    column: $table.payOffBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get settledAt => $composableBuilder(
    column: $table.settledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
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

  Expression<bool> debtPaymentsRefs(
    Expression<bool> Function($$DebtPaymentsTableFilterComposer f) f,
  ) {
    final $$DebtPaymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.debtPayments,
      getReferencedColumn: (t) => t.debtUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtPaymentsTableFilterComposer(
            $db: $db,
            $table: $db.debtPayments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DebtsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $DebtsTable> {
  $$DebtsTableOrderingComposer({
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

  ColumnOrderings<String> get person => $composableBuilder(
    column: $table.person,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payOffBy => $composableBuilder(
    column: $table.payOffBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get settledAt => $composableBuilder(
    column: $table.settledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
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
}

class $$DebtsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $DebtsTable> {
  $$DebtsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get person =>
      $composableBuilder(column: $table.person, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get payOffBy =>
      $composableBuilder(column: $table.payOffBy, builder: (column) => column);

  GeneratedColumn<String> get remindAt =>
      $composableBuilder(column: $table.remindAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get settledAt =>
      $composableBuilder(column: $table.settledAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> debtPaymentsRefs<T extends Object>(
    Expression<T> Function($$DebtPaymentsTableAnnotationComposer a) f,
  ) {
    final $$DebtPaymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.debtPayments,
      getReferencedColumn: (t) => t.debtUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtPaymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.debtPayments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DebtsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $DebtsTable,
          DebtRow,
          $$DebtsTableFilterComposer,
          $$DebtsTableOrderingComposer,
          $$DebtsTableAnnotationComposer,
          $$DebtsTableCreateCompanionBuilder,
          $$DebtsTableUpdateCompanionBuilder,
          (DebtRow, $$DebtsTableReferences),
          DebtRow,
          PrefetchHooks Function({bool debtPaymentsRefs})
        > {
  $$DebtsTableTableManager(_$HarvestDatabase db, $DebtsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebtsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebtsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DebtsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> person = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> payOffBy = const Value.absent(),
                Value<String?> remindAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime?> settledAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebtsCompanion(
                uuid: uuid,
                person: person,
                amountMinor: amountMinor,
                currency: currency,
                payOffBy: payOffBy,
                remindAt: remindAt,
                note: note,
                settledAt: settledAt,
                createdAt: createdAt,
                deletedAt: deletedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String person,
                required int amountMinor,
                Value<String> currency = const Value.absent(),
                Value<String?> payOffBy = const Value.absent(),
                Value<String?> remindAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime?> settledAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebtsCompanion.insert(
                uuid: uuid,
                person: person,
                amountMinor: amountMinor,
                currency: currency,
                payOffBy: payOffBy,
                remindAt: remindAt,
                note: note,
                settledAt: settledAt,
                createdAt: createdAt,
                deletedAt: deletedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$DebtsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({debtPaymentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (debtPaymentsRefs) db.debtPayments],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (debtPaymentsRefs)
                    await $_getPrefetchedData<
                      DebtRow,
                      $DebtsTable,
                      DebtPaymentRow
                    >(
                      currentTable: table,
                      referencedTable: $$DebtsTableReferences
                          ._debtPaymentsRefsTable(db),
                      managerFromTypedResult: (p0) => $$DebtsTableReferences(
                        db,
                        table,
                        p0,
                      ).debtPaymentsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.debtUuid == item.uuid),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DebtsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $DebtsTable,
      DebtRow,
      $$DebtsTableFilterComposer,
      $$DebtsTableOrderingComposer,
      $$DebtsTableAnnotationComposer,
      $$DebtsTableCreateCompanionBuilder,
      $$DebtsTableUpdateCompanionBuilder,
      (DebtRow, $$DebtsTableReferences),
      DebtRow,
      PrefetchHooks Function({bool debtPaymentsRefs})
    >;
typedef $$DebtPaymentsTableCreateCompanionBuilder =
    DebtPaymentsCompanion Function({
      required String uuid,
      required String debtUuid,
      required int amountMinor,
      required String harvestDay,
      Value<DateTime> loggedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$DebtPaymentsTableUpdateCompanionBuilder =
    DebtPaymentsCompanion Function({
      Value<String> uuid,
      Value<String> debtUuid,
      Value<int> amountMinor,
      Value<String> harvestDay,
      Value<DateTime> loggedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$DebtPaymentsTableReferences
    extends
        BaseReferences<_$HarvestDatabase, $DebtPaymentsTable, DebtPaymentRow> {
  $$DebtPaymentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DebtsTable _debtUuidTable(_$HarvestDatabase db) =>
      db.debts.createAlias('debt_payments__debt_uuid__debts__uuid');

  $$DebtsTableProcessedTableManager get debtUuid {
    final $_column = $_itemColumn<String>('debt_uuid')!;

    final manager = $$DebtsTableTableManager(
      $_db,
      $_db.debts,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_debtUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DebtPaymentsTableFilterComposer
    extends Composer<_$HarvestDatabase, $DebtPaymentsTable> {
  $$DebtPaymentsTableFilterComposer({
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

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DebtsTableFilterComposer get debtUuid {
    final $$DebtsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.debtUuid,
      referencedTable: $db.debts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtsTableFilterComposer(
            $db: $db,
            $table: $db.debts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DebtPaymentsTableOrderingComposer
    extends Composer<_$HarvestDatabase, $DebtPaymentsTable> {
  $$DebtPaymentsTableOrderingComposer({
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

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DebtsTableOrderingComposer get debtUuid {
    final $$DebtsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.debtUuid,
      referencedTable: $db.debts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtsTableOrderingComposer(
            $db: $db,
            $table: $db.debts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DebtPaymentsTableAnnotationComposer
    extends Composer<_$HarvestDatabase, $DebtPaymentsTable> {
  $$DebtPaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get harvestDay => $composableBuilder(
    column: $table.harvestDay,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$DebtsTableAnnotationComposer get debtUuid {
    final $$DebtsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.debtUuid,
      referencedTable: $db.debts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtsTableAnnotationComposer(
            $db: $db,
            $table: $db.debts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DebtPaymentsTableTableManager
    extends
        RootTableManager<
          _$HarvestDatabase,
          $DebtPaymentsTable,
          DebtPaymentRow,
          $$DebtPaymentsTableFilterComposer,
          $$DebtPaymentsTableOrderingComposer,
          $$DebtPaymentsTableAnnotationComposer,
          $$DebtPaymentsTableCreateCompanionBuilder,
          $$DebtPaymentsTableUpdateCompanionBuilder,
          (DebtPaymentRow, $$DebtPaymentsTableReferences),
          DebtPaymentRow,
          PrefetchHooks Function({bool debtUuid})
        > {
  $$DebtPaymentsTableTableManager(
    _$HarvestDatabase db,
    $DebtPaymentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebtPaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebtPaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DebtPaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> debtUuid = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> harvestDay = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebtPaymentsCompanion(
                uuid: uuid,
                debtUuid: debtUuid,
                amountMinor: amountMinor,
                harvestDay: harvestDay,
                loggedAt: loggedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String debtUuid,
                required int amountMinor,
                required String harvestDay,
                Value<DateTime> loggedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebtPaymentsCompanion.insert(
                uuid: uuid,
                debtUuid: debtUuid,
                amountMinor: amountMinor,
                harvestDay: harvestDay,
                loggedAt: loggedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DebtPaymentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({debtUuid = false}) {
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
                    if (debtUuid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.debtUuid,
                        referencedTable: $$DebtPaymentsTableReferences
                            ._debtUuidTable(db),
                        referencedColumn: $$DebtPaymentsTableReferences
                            ._debtUuidTable(db)
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

typedef $$DebtPaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$HarvestDatabase,
      $DebtPaymentsTable,
      DebtPaymentRow,
      $$DebtPaymentsTableFilterComposer,
      $$DebtPaymentsTableOrderingComposer,
      $$DebtPaymentsTableAnnotationComposer,
      $$DebtPaymentsTableCreateCompanionBuilder,
      $$DebtPaymentsTableUpdateCompanionBuilder,
      (DebtPaymentRow, $$DebtPaymentsTableReferences),
      DebtPaymentRow,
      PrefetchHooks Function({bool debtUuid})
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
  $$SeedNotesTableTableManager get seedNotes =>
      $$SeedNotesTableTableManager(_db, _db.seedNotes);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$NoteLinksTableTableManager get noteLinks =>
      $$NoteLinksTableTableManager(_db, _db.noteLinks);
  $$AlbumsTableTableManager get albums =>
      $$AlbumsTableTableManager(_db, _db.albums);
  $$MemoriesTableTableManager get memories =>
      $$MemoriesTableTableManager(_db, _db.memories);
  $$StepDaysTableTableManager get stepDays =>
      $$StepDaysTableTableManager(_db, _db.stepDays);
  $$BodyWeightsTableTableManager get bodyWeights =>
      $$BodyWeightsTableTableManager(_db, _db.bodyWeights);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db, _db.exercises);
  $$ProgramsTableTableManager get programs =>
      $$ProgramsTableTableManager(_db, _db.programs);
  $$ProgramDaysTableTableManager get programDays =>
      $$ProgramDaysTableTableManager(_db, _db.programDays);
  $$ProgramSlotsTableTableManager get programSlots =>
      $$ProgramSlotsTableTableManager(_db, _db.programSlots);
  $$TargetSetsTableTableManager get targetSets =>
      $$TargetSetsTableTableManager(_db, _db.targetSets);
  $$TrainingMaxesTableTableManager get trainingMaxes =>
      $$TrainingMaxesTableTableManager(_db, _db.trainingMaxes);
  $$WorkoutSessionsTableTableManager get workoutSessions =>
      $$WorkoutSessionsTableTableManager(_db, _db.workoutSessions);
  $$SessionExercisesTableTableManager get sessionExercises =>
      $$SessionExercisesTableTableManager(_db, _db.sessionExercises);
  $$WorkoutSetsTableTableManager get workoutSets =>
      $$WorkoutSetsTableTableManager(_db, _db.workoutSets);
  $$SleepSessionsTableTableManager get sleepSessions =>
      $$SleepSessionsTableTableManager(_db, _db.sleepSessions);
  $$StreaksTableTableManager get streaks =>
      $$StreaksTableTableManager(_db, _db.streaks);
  $$LedgerTableTableManager get ledger =>
      $$LedgerTableTableManager(_db, _db.ledger);
  $$QuestsTableTableManager get quests =>
      $$QuestsTableTableManager(_db, _db.quests);
  $$PomodoroSessionsTableTableManager get pomodoroSessions =>
      $$PomodoroSessionsTableTableManager(_db, _db.pomodoroSessions);
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db, _db.expenses);
  $$ExpenseCategoriesTableTableManager get expenseCategories =>
      $$ExpenseCategoriesTableTableManager(_db, _db.expenseCategories);
  $$MoneyTxnsTableTableManager get moneyTxns =>
      $$MoneyTxnsTableTableManager(_db, _db.moneyTxns);
  $$DebtsTableTableManager get debts =>
      $$DebtsTableTableManager(_db, _db.debts);
  $$DebtPaymentsTableTableManager get debtPayments =>
      $$DebtPaymentsTableTableManager(_db, _db.debtPayments);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$KvSettingsTableTableManager get kvSettings =>
      $$KvSettingsTableTableManager(_db, _db.kvSettings);
}
