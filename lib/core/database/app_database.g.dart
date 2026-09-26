// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _sourcePathMeta = const VerificationMeta(
    'sourcePath',
  );
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
    'source_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failedStageMeta = const VerificationMeta(
    'failedStage',
  );
  @override
  late final GeneratedColumn<String> failedStage = GeneratedColumn<String>(
    'failed_stage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaJsonMeta = const VerificationMeta(
    'metaJson',
  );
  @override
  late final GeneratedColumn<String> metaJson = GeneratedColumn<String>(
    'meta_json',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    title,
    sourcePath,
    status,
    failedStage,
    metaJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    } else if (isInserting) {
      context.missing(_sourcePathMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('failed_stage')) {
      context.handle(
        _failedStageMeta,
        failedStage.isAcceptableOrUnknown(
          data['failed_stage']!,
          _failedStageMeta,
        ),
      );
    }
    if (data.containsKey('meta_json')) {
      context.handle(
        _metaJsonMeta,
        metaJson.isAcceptableOrUnknown(data['meta_json']!, _metaJsonMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      failedStage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failed_stage'],
      ),
      metaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta_json'],
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
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final int id;
  final String type;
  final String title;
  final String sourcePath;
  final String status;
  final String? failedStage;
  final String? metaJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Project({
    required this.id,
    required this.type,
    required this.title,
    required this.sourcePath,
    required this.status,
    this.failedStage,
    this.metaJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    map['source_path'] = Variable<String>(sourcePath);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || failedStage != null) {
      map['failed_stage'] = Variable<String>(failedStage);
    }
    if (!nullToAbsent || metaJson != null) {
      map['meta_json'] = Variable<String>(metaJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      type: Value(type),
      title: Value(title),
      sourcePath: Value(sourcePath),
      status: Value(status),
      failedStage: failedStage == null && nullToAbsent
          ? const Value.absent()
          : Value(failedStage),
      metaJson: metaJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metaJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      sourcePath: serializer.fromJson<String>(json['sourcePath']),
      status: serializer.fromJson<String>(json['status']),
      failedStage: serializer.fromJson<String?>(json['failedStage']),
      metaJson: serializer.fromJson<String?>(json['metaJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'sourcePath': serializer.toJson<String>(sourcePath),
      'status': serializer.toJson<String>(status),
      'failedStage': serializer.toJson<String?>(failedStage),
      'metaJson': serializer.toJson<String?>(metaJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Project copyWith({
    int? id,
    String? type,
    String? title,
    String? sourcePath,
    String? status,
    Value<String?> failedStage = const Value.absent(),
    Value<String?> metaJson = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Project(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    sourcePath: sourcePath ?? this.sourcePath,
    status: status ?? this.status,
    failedStage: failedStage.present ? failedStage.value : this.failedStage,
    metaJson: metaJson.present ? metaJson.value : this.metaJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      status: data.status.present ? data.status.value : this.status,
      failedStage: data.failedStage.present
          ? data.failedStage.value
          : this.failedStage,
      metaJson: data.metaJson.present ? data.metaJson.value : this.metaJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('status: $status, ')
          ..write('failedStage: $failedStage, ')
          ..write('metaJson: $metaJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    title,
    sourcePath,
    status,
    failedStage,
    metaJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.sourcePath == this.sourcePath &&
          other.status == this.status &&
          other.failedStage == this.failedStage &&
          other.metaJson == this.metaJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<int> id;
  final Value<String> type;
  final Value<String> title;
  final Value<String> sourcePath;
  final Value<String> status;
  final Value<String?> failedStage;
  final Value<String?> metaJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.status = const Value.absent(),
    this.failedStage = const Value.absent(),
    this.metaJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ProjectsCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    required String title,
    required String sourcePath,
    required String status,
    this.failedStage = const Value.absent(),
    this.metaJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : type = Value(type),
       title = Value(title),
       sourcePath = Value(sourcePath),
       status = Value(status);
  static Insertable<Project> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? sourcePath,
    Expression<String>? status,
    Expression<String>? failedStage,
    Expression<String>? metaJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (sourcePath != null) 'source_path': sourcePath,
      if (status != null) 'status': status,
      if (failedStage != null) 'failed_stage': failedStage,
      if (metaJson != null) 'meta_json': metaJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ProjectsCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<String>? title,
    Value<String>? sourcePath,
    Value<String>? status,
    Value<String?>? failedStage,
    Value<String?>? metaJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      sourcePath: sourcePath ?? this.sourcePath,
      status: status ?? this.status,
      failedStage: failedStage ?? this.failedStage,
      metaJson: metaJson ?? this.metaJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (failedStage.present) {
      map['failed_stage'] = Variable<String>(failedStage.value);
    }
    if (metaJson.present) {
      map['meta_json'] = Variable<String>(metaJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('status: $status, ')
          ..write('failedStage: $failedStage, ')
          ..write('metaJson: $metaJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $CharactersTable extends Characters
    with TableInfo<$CharactersTable, Character> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharactersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
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
  static const VerificationMeta _aliasesJsonMeta = const VerificationMeta(
    'aliasesJson',
  );
  @override
  late final GeneratedColumn<String> aliasesJson = GeneratedColumn<String>(
    'aliases_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _speakerKeyMeta = const VerificationMeta(
    'speakerKey',
  );
  @override
  late final GeneratedColumn<String> speakerKey = GeneratedColumn<String>(
    'speaker_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('auto'),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    name,
    aliasesJson,
    speakerKey,
    confidence,
    source,
    color,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'characters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Character> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('aliases_json')) {
      context.handle(
        _aliasesJsonMeta,
        aliasesJson.isAcceptableOrUnknown(
          data['aliases_json']!,
          _aliasesJsonMeta,
        ),
      );
    }
    if (data.containsKey('speaker_key')) {
      context.handle(
        _speakerKeyMeta,
        speakerKey.isAcceptableOrUnknown(data['speaker_key']!, _speakerKeyMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Character map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Character(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      aliasesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aliases_json'],
      )!,
      speakerKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_key'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
    );
  }

  @override
  $CharactersTable createAlias(String alias) {
    return $CharactersTable(attachedDatabase, alias);
  }
}

class Character extends DataClass implements Insertable<Character> {
  final int id;
  final int projectId;
  final String name;
  final String aliasesJson;
  final String? speakerKey;
  final double? confidence;
  final String source;
  final String? color;
  const Character({
    required this.id,
    required this.projectId,
    required this.name,
    required this.aliasesJson,
    this.speakerKey,
    this.confidence,
    required this.source,
    this.color,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['name'] = Variable<String>(name);
    map['aliases_json'] = Variable<String>(aliasesJson);
    if (!nullToAbsent || speakerKey != null) {
      map['speaker_key'] = Variable<String>(speakerKey);
    }
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<double>(confidence);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    return map;
  }

  CharactersCompanion toCompanion(bool nullToAbsent) {
    return CharactersCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: Value(name),
      aliasesJson: Value(aliasesJson),
      speakerKey: speakerKey == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerKey),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
      source: Value(source),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
    );
  }

  factory Character.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Character(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      name: serializer.fromJson<String>(json['name']),
      aliasesJson: serializer.fromJson<String>(json['aliasesJson']),
      speakerKey: serializer.fromJson<String?>(json['speakerKey']),
      confidence: serializer.fromJson<double?>(json['confidence']),
      source: serializer.fromJson<String>(json['source']),
      color: serializer.fromJson<String?>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'name': serializer.toJson<String>(name),
      'aliasesJson': serializer.toJson<String>(aliasesJson),
      'speakerKey': serializer.toJson<String?>(speakerKey),
      'confidence': serializer.toJson<double?>(confidence),
      'source': serializer.toJson<String>(source),
      'color': serializer.toJson<String?>(color),
    };
  }

  Character copyWith({
    int? id,
    int? projectId,
    String? name,
    String? aliasesJson,
    Value<String?> speakerKey = const Value.absent(),
    Value<double?> confidence = const Value.absent(),
    String? source,
    Value<String?> color = const Value.absent(),
  }) => Character(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    name: name ?? this.name,
    aliasesJson: aliasesJson ?? this.aliasesJson,
    speakerKey: speakerKey.present ? speakerKey.value : this.speakerKey,
    confidence: confidence.present ? confidence.value : this.confidence,
    source: source ?? this.source,
    color: color.present ? color.value : this.color,
  );
  Character copyWithCompanion(CharactersCompanion data) {
    return Character(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      aliasesJson: data.aliasesJson.present
          ? data.aliasesJson.value
          : this.aliasesJson,
      speakerKey: data.speakerKey.present
          ? data.speakerKey.value
          : this.speakerKey,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      source: data.source.present ? data.source.value : this.source,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Character(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('speakerKey: $speakerKey, ')
          ..write('confidence: $confidence, ')
          ..write('source: $source, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    name,
    aliasesJson,
    speakerKey,
    confidence,
    source,
    color,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Character &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.aliasesJson == this.aliasesJson &&
          other.speakerKey == this.speakerKey &&
          other.confidence == this.confidence &&
          other.source == this.source &&
          other.color == this.color);
}

class CharactersCompanion extends UpdateCompanion<Character> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<String> name;
  final Value<String> aliasesJson;
  final Value<String?> speakerKey;
  final Value<double?> confidence;
  final Value<String> source;
  final Value<String?> color;
  const CharactersCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.aliasesJson = const Value.absent(),
    this.speakerKey = const Value.absent(),
    this.confidence = const Value.absent(),
    this.source = const Value.absent(),
    this.color = const Value.absent(),
  });
  CharactersCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required String name,
    this.aliasesJson = const Value.absent(),
    this.speakerKey = const Value.absent(),
    this.confidence = const Value.absent(),
    this.source = const Value.absent(),
    this.color = const Value.absent(),
  }) : projectId = Value(projectId),
       name = Value(name);
  static Insertable<Character> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? name,
    Expression<String>? aliasesJson,
    Expression<String>? speakerKey,
    Expression<double>? confidence,
    Expression<String>? source,
    Expression<String>? color,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (aliasesJson != null) 'aliases_json': aliasesJson,
      if (speakerKey != null) 'speaker_key': speakerKey,
      if (confidence != null) 'confidence': confidence,
      if (source != null) 'source': source,
      if (color != null) 'color': color,
    });
  }

  CharactersCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<String>? name,
    Value<String>? aliasesJson,
    Value<String?>? speakerKey,
    Value<double?>? confidence,
    Value<String>? source,
    Value<String?>? color,
  }) {
    return CharactersCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      aliasesJson: aliasesJson ?? this.aliasesJson,
      speakerKey: speakerKey ?? this.speakerKey,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      color: color ?? this.color,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (aliasesJson.present) {
      map['aliases_json'] = Variable<String>(aliasesJson.value);
    }
    if (speakerKey.present) {
      map['speaker_key'] = Variable<String>(speakerKey.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CharactersCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('speakerKey: $speakerKey, ')
          ..write('confidence: $confidence, ')
          ..write('source: $source, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }
}

class $SegmentsTable extends Segments with TableInfo<$SegmentsTable, Segment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _idxMeta = const VerificationMeta('idx');
  @override
  late final GeneratedColumn<int> idx = GeneratedColumn<int>(
    'idx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speakerCharIdMeta = const VerificationMeta(
    'speakerCharId',
  );
  @override
  late final GeneratedColumn<int> speakerCharId = GeneratedColumn<int>(
    'speaker_char_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    idx,
    startMs,
    endMs,
    speakerCharId,
    content,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Segment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('idx')) {
      context.handle(
        _idxMeta,
        idx.isAcceptableOrUnknown(data['idx']!, _idxMeta),
      );
    } else if (isInserting) {
      context.missing(_idxMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('speaker_char_id')) {
      context.handle(
        _speakerCharIdMeta,
        speakerCharId.isAcceptableOrUnknown(
          data['speaker_char_id']!,
          _speakerCharIdMeta,
        ),
      );
    }
    if (data.containsKey('text')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['text']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Segment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Segment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      idx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}idx'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
      speakerCharId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}speaker_char_id'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
    );
  }

  @override
  $SegmentsTable createAlias(String alias) {
    return $SegmentsTable(attachedDatabase, alias);
  }
}

class Segment extends DataClass implements Insertable<Segment> {
  final int id;
  final int projectId;
  final int idx;
  final int startMs;
  final int endMs;
  final int? speakerCharId;
  final String content;
  const Segment({
    required this.id,
    required this.projectId,
    required this.idx,
    required this.startMs,
    required this.endMs,
    this.speakerCharId,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['idx'] = Variable<int>(idx);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    if (!nullToAbsent || speakerCharId != null) {
      map['speaker_char_id'] = Variable<int>(speakerCharId);
    }
    map['text'] = Variable<String>(content);
    return map;
  }

  SegmentsCompanion toCompanion(bool nullToAbsent) {
    return SegmentsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      idx: Value(idx),
      startMs: Value(startMs),
      endMs: Value(endMs),
      speakerCharId: speakerCharId == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerCharId),
      content: Value(content),
    );
  }

  factory Segment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Segment(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      idx: serializer.fromJson<int>(json['idx']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      speakerCharId: serializer.fromJson<int?>(json['speakerCharId']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'idx': serializer.toJson<int>(idx),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'speakerCharId': serializer.toJson<int?>(speakerCharId),
      'content': serializer.toJson<String>(content),
    };
  }

  Segment copyWith({
    int? id,
    int? projectId,
    int? idx,
    int? startMs,
    int? endMs,
    Value<int?> speakerCharId = const Value.absent(),
    String? content,
  }) => Segment(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    idx: idx ?? this.idx,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    speakerCharId: speakerCharId.present
        ? speakerCharId.value
        : this.speakerCharId,
    content: content ?? this.content,
  );
  Segment copyWithCompanion(SegmentsCompanion data) {
    return Segment(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      idx: data.idx.present ? data.idx.value : this.idx,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      speakerCharId: data.speakerCharId.present
          ? data.speakerCharId.value
          : this.speakerCharId,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Segment(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('idx: $idx, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('speakerCharId: $speakerCharId, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, projectId, idx, startMs, endMs, speakerCharId, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Segment &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.idx == this.idx &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.speakerCharId == this.speakerCharId &&
          other.content == this.content);
}

class SegmentsCompanion extends UpdateCompanion<Segment> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<int> idx;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<int?> speakerCharId;
  final Value<String> content;
  const SegmentsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.idx = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.speakerCharId = const Value.absent(),
    this.content = const Value.absent(),
  });
  SegmentsCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required int idx,
    required int startMs,
    required int endMs,
    this.speakerCharId = const Value.absent(),
    required String content,
  }) : projectId = Value(projectId),
       idx = Value(idx),
       startMs = Value(startMs),
       endMs = Value(endMs),
       content = Value(content);
  static Insertable<Segment> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<int>? idx,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<int>? speakerCharId,
    Expression<String>? content,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (idx != null) 'idx': idx,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (speakerCharId != null) 'speaker_char_id': speakerCharId,
      if (content != null) 'text': content,
    });
  }

  SegmentsCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<int>? idx,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<int?>? speakerCharId,
    Value<String>? content,
  }) {
    return SegmentsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      idx: idx ?? this.idx,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      speakerCharId: speakerCharId ?? this.speakerCharId,
      content: content ?? this.content,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (idx.present) {
      map['idx'] = Variable<int>(idx.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (speakerCharId.present) {
      map['speaker_char_id'] = Variable<int>(speakerCharId.value);
    }
    if (content.present) {
      map['text'] = Variable<String>(content.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SegmentsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('idx: $idx, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('speakerCharId: $speakerCharId, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }
}

class $ScenesTable extends Scenes with TableInfo<$ScenesTable, Scene> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScenesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _idxMeta = const VerificationMeta('idx');
  @override
  late final GeneratedColumn<int> idx = GeneratedColumn<int>(
    'idx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importanceMeta = const VerificationMeta(
    'importance',
  );
  @override
  late final GeneratedColumn<String> importance = GeneratedColumn<String>(
    'importance',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('normal'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    idx,
    startMs,
    endMs,
    summary,
    importance,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scenes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Scene> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('idx')) {
      context.handle(
        _idxMeta,
        idx.isAcceptableOrUnknown(data['idx']!, _idxMeta),
      );
    } else if (isInserting) {
      context.missing(_idxMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('importance')) {
      context.handle(
        _importanceMeta,
        importance.isAcceptableOrUnknown(data['importance']!, _importanceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Scene map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Scene(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      idx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}idx'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      importance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}importance'],
      )!,
    );
  }

  @override
  $ScenesTable createAlias(String alias) {
    return $ScenesTable(attachedDatabase, alias);
  }
}

class Scene extends DataClass implements Insertable<Scene> {
  final int id;
  final int projectId;
  final int idx;
  final int startMs;
  final int endMs;
  final String? summary;
  final String importance;
  const Scene({
    required this.id,
    required this.projectId,
    required this.idx,
    required this.startMs,
    required this.endMs,
    this.summary,
    required this.importance,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['idx'] = Variable<int>(idx);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    map['importance'] = Variable<String>(importance);
    return map;
  }

  ScenesCompanion toCompanion(bool nullToAbsent) {
    return ScenesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      idx: Value(idx),
      startMs: Value(startMs),
      endMs: Value(endMs),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      importance: Value(importance),
    );
  }

  factory Scene.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Scene(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      idx: serializer.fromJson<int>(json['idx']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      summary: serializer.fromJson<String?>(json['summary']),
      importance: serializer.fromJson<String>(json['importance']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'idx': serializer.toJson<int>(idx),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'summary': serializer.toJson<String?>(summary),
      'importance': serializer.toJson<String>(importance),
    };
  }

  Scene copyWith({
    int? id,
    int? projectId,
    int? idx,
    int? startMs,
    int? endMs,
    Value<String?> summary = const Value.absent(),
    String? importance,
  }) => Scene(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    idx: idx ?? this.idx,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    summary: summary.present ? summary.value : this.summary,
    importance: importance ?? this.importance,
  );
  Scene copyWithCompanion(ScenesCompanion data) {
    return Scene(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      idx: data.idx.present ? data.idx.value : this.idx,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      summary: data.summary.present ? data.summary.value : this.summary,
      importance: data.importance.present
          ? data.importance.value
          : this.importance,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Scene(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('idx: $idx, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('summary: $summary, ')
          ..write('importance: $importance')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, projectId, idx, startMs, endMs, summary, importance);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Scene &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.idx == this.idx &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.summary == this.summary &&
          other.importance == this.importance);
}

class ScenesCompanion extends UpdateCompanion<Scene> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<int> idx;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<String?> summary;
  final Value<String> importance;
  const ScenesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.idx = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.summary = const Value.absent(),
    this.importance = const Value.absent(),
  });
  ScenesCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required int idx,
    required int startMs,
    required int endMs,
    this.summary = const Value.absent(),
    this.importance = const Value.absent(),
  }) : projectId = Value(projectId),
       idx = Value(idx),
       startMs = Value(startMs),
       endMs = Value(endMs);
  static Insertable<Scene> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<int>? idx,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? summary,
    Expression<String>? importance,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (idx != null) 'idx': idx,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (summary != null) 'summary': summary,
      if (importance != null) 'importance': importance,
    });
  }

  ScenesCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<int>? idx,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<String?>? summary,
    Value<String>? importance,
  }) {
    return ScenesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      idx: idx ?? this.idx,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      summary: summary ?? this.summary,
      importance: importance ?? this.importance,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (idx.present) {
      map['idx'] = Variable<int>(idx.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (importance.present) {
      map['importance'] = Variable<String>(importance.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScenesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('idx: $idx, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('summary: $summary, ')
          ..write('importance: $importance')
          ..write(')'))
        .toString();
  }
}

class $CommentariesTable extends Commentaries
    with TableInfo<$CommentariesTable, Commentary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CommentariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sceneIdMeta = const VerificationMeta(
    'sceneId',
  );
  @override
  late final GeneratedColumn<int> sceneId = GeneratedColumn<int>(
    'scene_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES scenes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _l1SubtextMeta = const VerificationMeta(
    'l1Subtext',
  );
  @override
  late final GeneratedColumn<String> l1Subtext = GeneratedColumn<String>(
    'l1_subtext',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _l2PsychologyJsonMeta = const VerificationMeta(
    'l2PsychologyJson',
  );
  @override
  late final GeneratedColumn<String> l2PsychologyJson = GeneratedColumn<String>(
    'l2_psychology_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('done'),
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sceneId,
    l1Subtext,
    l2PsychologyJson,
    status,
    model,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'commentaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Commentary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scene_id')) {
      context.handle(
        _sceneIdMeta,
        sceneId.isAcceptableOrUnknown(data['scene_id']!, _sceneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sceneIdMeta);
    }
    if (data.containsKey('l1_subtext')) {
      context.handle(
        _l1SubtextMeta,
        l1Subtext.isAcceptableOrUnknown(data['l1_subtext']!, _l1SubtextMeta),
      );
    } else if (isInserting) {
      context.missing(_l1SubtextMeta);
    }
    if (data.containsKey('l2_psychology_json')) {
      context.handle(
        _l2PsychologyJsonMeta,
        l2PsychologyJson.isAcceptableOrUnknown(
          data['l2_psychology_json']!,
          _l2PsychologyJsonMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sceneId},
  ];
  @override
  Commentary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Commentary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sceneId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scene_id'],
      )!,
      l1Subtext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}l1_subtext'],
      )!,
      l2PsychologyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}l2_psychology_json'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CommentariesTable createAlias(String alias) {
    return $CommentariesTable(attachedDatabase, alias);
  }
}

class Commentary extends DataClass implements Insertable<Commentary> {
  final int id;
  final int sceneId;
  final String l1Subtext;
  final String? l2PsychologyJson;
  final String status;
  final String model;
  final DateTime createdAt;
  const Commentary({
    required this.id,
    required this.sceneId,
    required this.l1Subtext,
    this.l2PsychologyJson,
    required this.status,
    required this.model,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scene_id'] = Variable<int>(sceneId);
    map['l1_subtext'] = Variable<String>(l1Subtext);
    if (!nullToAbsent || l2PsychologyJson != null) {
      map['l2_psychology_json'] = Variable<String>(l2PsychologyJson);
    }
    map['status'] = Variable<String>(status);
    map['model'] = Variable<String>(model);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CommentariesCompanion toCompanion(bool nullToAbsent) {
    return CommentariesCompanion(
      id: Value(id),
      sceneId: Value(sceneId),
      l1Subtext: Value(l1Subtext),
      l2PsychologyJson: l2PsychologyJson == null && nullToAbsent
          ? const Value.absent()
          : Value(l2PsychologyJson),
      status: Value(status),
      model: Value(model),
      createdAt: Value(createdAt),
    );
  }

  factory Commentary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Commentary(
      id: serializer.fromJson<int>(json['id']),
      sceneId: serializer.fromJson<int>(json['sceneId']),
      l1Subtext: serializer.fromJson<String>(json['l1Subtext']),
      l2PsychologyJson: serializer.fromJson<String?>(json['l2PsychologyJson']),
      status: serializer.fromJson<String>(json['status']),
      model: serializer.fromJson<String>(json['model']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sceneId': serializer.toJson<int>(sceneId),
      'l1Subtext': serializer.toJson<String>(l1Subtext),
      'l2PsychologyJson': serializer.toJson<String?>(l2PsychologyJson),
      'status': serializer.toJson<String>(status),
      'model': serializer.toJson<String>(model),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Commentary copyWith({
    int? id,
    int? sceneId,
    String? l1Subtext,
    Value<String?> l2PsychologyJson = const Value.absent(),
    String? status,
    String? model,
    DateTime? createdAt,
  }) => Commentary(
    id: id ?? this.id,
    sceneId: sceneId ?? this.sceneId,
    l1Subtext: l1Subtext ?? this.l1Subtext,
    l2PsychologyJson: l2PsychologyJson.present
        ? l2PsychologyJson.value
        : this.l2PsychologyJson,
    status: status ?? this.status,
    model: model ?? this.model,
    createdAt: createdAt ?? this.createdAt,
  );
  Commentary copyWithCompanion(CommentariesCompanion data) {
    return Commentary(
      id: data.id.present ? data.id.value : this.id,
      sceneId: data.sceneId.present ? data.sceneId.value : this.sceneId,
      l1Subtext: data.l1Subtext.present ? data.l1Subtext.value : this.l1Subtext,
      l2PsychologyJson: data.l2PsychologyJson.present
          ? data.l2PsychologyJson.value
          : this.l2PsychologyJson,
      status: data.status.present ? data.status.value : this.status,
      model: data.model.present ? data.model.value : this.model,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Commentary(')
          ..write('id: $id, ')
          ..write('sceneId: $sceneId, ')
          ..write('l1Subtext: $l1Subtext, ')
          ..write('l2PsychologyJson: $l2PsychologyJson, ')
          ..write('status: $status, ')
          ..write('model: $model, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sceneId,
    l1Subtext,
    l2PsychologyJson,
    status,
    model,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Commentary &&
          other.id == this.id &&
          other.sceneId == this.sceneId &&
          other.l1Subtext == this.l1Subtext &&
          other.l2PsychologyJson == this.l2PsychologyJson &&
          other.status == this.status &&
          other.model == this.model &&
          other.createdAt == this.createdAt);
}

class CommentariesCompanion extends UpdateCompanion<Commentary> {
  final Value<int> id;
  final Value<int> sceneId;
  final Value<String> l1Subtext;
  final Value<String?> l2PsychologyJson;
  final Value<String> status;
  final Value<String> model;
  final Value<DateTime> createdAt;
  const CommentariesCompanion({
    this.id = const Value.absent(),
    this.sceneId = const Value.absent(),
    this.l1Subtext = const Value.absent(),
    this.l2PsychologyJson = const Value.absent(),
    this.status = const Value.absent(),
    this.model = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CommentariesCompanion.insert({
    this.id = const Value.absent(),
    required int sceneId,
    required String l1Subtext,
    this.l2PsychologyJson = const Value.absent(),
    this.status = const Value.absent(),
    required String model,
    this.createdAt = const Value.absent(),
  }) : sceneId = Value(sceneId),
       l1Subtext = Value(l1Subtext),
       model = Value(model);
  static Insertable<Commentary> custom({
    Expression<int>? id,
    Expression<int>? sceneId,
    Expression<String>? l1Subtext,
    Expression<String>? l2PsychologyJson,
    Expression<String>? status,
    Expression<String>? model,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sceneId != null) 'scene_id': sceneId,
      if (l1Subtext != null) 'l1_subtext': l1Subtext,
      if (l2PsychologyJson != null) 'l2_psychology_json': l2PsychologyJson,
      if (status != null) 'status': status,
      if (model != null) 'model': model,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CommentariesCompanion copyWith({
    Value<int>? id,
    Value<int>? sceneId,
    Value<String>? l1Subtext,
    Value<String?>? l2PsychologyJson,
    Value<String>? status,
    Value<String>? model,
    Value<DateTime>? createdAt,
  }) {
    return CommentariesCompanion(
      id: id ?? this.id,
      sceneId: sceneId ?? this.sceneId,
      l1Subtext: l1Subtext ?? this.l1Subtext,
      l2PsychologyJson: l2PsychologyJson ?? this.l2PsychologyJson,
      status: status ?? this.status,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sceneId.present) {
      map['scene_id'] = Variable<int>(sceneId.value);
    }
    if (l1Subtext.present) {
      map['l1_subtext'] = Variable<String>(l1Subtext.value);
    }
    if (l2PsychologyJson.present) {
      map['l2_psychology_json'] = Variable<String>(l2PsychologyJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommentariesCompanion(')
          ..write('id: $id, ')
          ..write('sceneId: $sceneId, ')
          ..write('l1Subtext: $l1Subtext, ')
          ..write('l2PsychologyJson: $l2PsychologyJson, ')
          ..write('status: $status, ')
          ..write('model: $model, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $KnowledgeCardsTable extends KnowledgeCards
    with TableInfo<$KnowledgeCardsTable, KnowledgeCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnowledgeCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _termMeta = const VerificationMeta('term');
  @override
  late final GeneratedColumn<String> term = GeneratedColumn<String>(
    'term',
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
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstSceneIdxMeta = const VerificationMeta(
    'firstSceneIdx',
  );
  @override
  late final GeneratedColumn<int> firstSceneIdx = GeneratedColumn<int>(
    'first_scene_idx',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uncertainMeta = const VerificationMeta(
    'uncertain',
  );
  @override
  late final GeneratedColumn<bool> uncertain = GeneratedColumn<bool>(
    'uncertain',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("uncertain" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ivlDaysMeta = const VerificationMeta(
    'ivlDays',
  );
  @override
  late final GeneratedColumn<double> ivlDays = GeneratedColumn<double>(
    'ivl_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _easeMeta = const VerificationMeta('ease');
  @override
  late final GeneratedColumn<double> ease = GeneratedColumn<double>(
    'ease',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.5),
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
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReviewAtMeta = const VerificationMeta(
    'lastReviewAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReviewAt = GeneratedColumn<DateTime>(
    'last_review_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    term,
    title,
    content,
    firstSceneIdx,
    uncertain,
    dueAt,
    ivlDays,
    ease,
    reps,
    lapses,
    lastReviewAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'knowledge_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<KnowledgeCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('term')) {
      context.handle(
        _termMeta,
        term.isAcceptableOrUnknown(data['term']!, _termMeta),
      );
    } else if (isInserting) {
      context.missing(_termMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('first_scene_idx')) {
      context.handle(
        _firstSceneIdxMeta,
        firstSceneIdx.isAcceptableOrUnknown(
          data['first_scene_idx']!,
          _firstSceneIdxMeta,
        ),
      );
    }
    if (data.containsKey('uncertain')) {
      context.handle(
        _uncertainMeta,
        uncertain.isAcceptableOrUnknown(data['uncertain']!, _uncertainMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('ivl_days')) {
      context.handle(
        _ivlDaysMeta,
        ivlDays.isAcceptableOrUnknown(data['ivl_days']!, _ivlDaysMeta),
      );
    }
    if (data.containsKey('ease')) {
      context.handle(
        _easeMeta,
        ease.isAcceptableOrUnknown(data['ease']!, _easeMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    }
    if (data.containsKey('last_review_at')) {
      context.handle(
        _lastReviewAtMeta,
        lastReviewAt.isAcceptableOrUnknown(
          data['last_review_at']!,
          _lastReviewAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {projectId, term},
  ];
  @override
  KnowledgeCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnowledgeCard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      term: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}term'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      firstSceneIdx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_scene_idx'],
      ),
      uncertain: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}uncertain'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      ivlDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ivl_days'],
      )!,
      ease: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ease'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      )!,
      lastReviewAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_review_at'],
      ),
    );
  }

  @override
  $KnowledgeCardsTable createAlias(String alias) {
    return $KnowledgeCardsTable(attachedDatabase, alias);
  }
}

class KnowledgeCard extends DataClass implements Insertable<KnowledgeCard> {
  final int id;
  final int projectId;
  final String term;
  final String title;
  final String content;
  final int? firstSceneIdx;
  final bool uncertain;
  final DateTime? dueAt;
  final double ivlDays;
  final double ease;
  final int reps;
  final int lapses;
  final DateTime? lastReviewAt;
  const KnowledgeCard({
    required this.id,
    required this.projectId,
    required this.term,
    required this.title,
    required this.content,
    this.firstSceneIdx,
    required this.uncertain,
    this.dueAt,
    required this.ivlDays,
    required this.ease,
    required this.reps,
    required this.lapses,
    this.lastReviewAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['term'] = Variable<String>(term);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || firstSceneIdx != null) {
      map['first_scene_idx'] = Variable<int>(firstSceneIdx);
    }
    map['uncertain'] = Variable<bool>(uncertain);
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    map['ivl_days'] = Variable<double>(ivlDays);
    map['ease'] = Variable<double>(ease);
    map['reps'] = Variable<int>(reps);
    map['lapses'] = Variable<int>(lapses);
    if (!nullToAbsent || lastReviewAt != null) {
      map['last_review_at'] = Variable<DateTime>(lastReviewAt);
    }
    return map;
  }

  KnowledgeCardsCompanion toCompanion(bool nullToAbsent) {
    return KnowledgeCardsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      term: Value(term),
      title: Value(title),
      content: Value(content),
      firstSceneIdx: firstSceneIdx == null && nullToAbsent
          ? const Value.absent()
          : Value(firstSceneIdx),
      uncertain: Value(uncertain),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      ivlDays: Value(ivlDays),
      ease: Value(ease),
      reps: Value(reps),
      lapses: Value(lapses),
      lastReviewAt: lastReviewAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewAt),
    );
  }

  factory KnowledgeCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnowledgeCard(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      term: serializer.fromJson<String>(json['term']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      firstSceneIdx: serializer.fromJson<int?>(json['firstSceneIdx']),
      uncertain: serializer.fromJson<bool>(json['uncertain']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      ivlDays: serializer.fromJson<double>(json['ivlDays']),
      ease: serializer.fromJson<double>(json['ease']),
      reps: serializer.fromJson<int>(json['reps']),
      lapses: serializer.fromJson<int>(json['lapses']),
      lastReviewAt: serializer.fromJson<DateTime?>(json['lastReviewAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'term': serializer.toJson<String>(term),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'firstSceneIdx': serializer.toJson<int?>(firstSceneIdx),
      'uncertain': serializer.toJson<bool>(uncertain),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'ivlDays': serializer.toJson<double>(ivlDays),
      'ease': serializer.toJson<double>(ease),
      'reps': serializer.toJson<int>(reps),
      'lapses': serializer.toJson<int>(lapses),
      'lastReviewAt': serializer.toJson<DateTime?>(lastReviewAt),
    };
  }

  KnowledgeCard copyWith({
    int? id,
    int? projectId,
    String? term,
    String? title,
    String? content,
    Value<int?> firstSceneIdx = const Value.absent(),
    bool? uncertain,
    Value<DateTime?> dueAt = const Value.absent(),
    double? ivlDays,
    double? ease,
    int? reps,
    int? lapses,
    Value<DateTime?> lastReviewAt = const Value.absent(),
  }) => KnowledgeCard(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    term: term ?? this.term,
    title: title ?? this.title,
    content: content ?? this.content,
    firstSceneIdx: firstSceneIdx.present
        ? firstSceneIdx.value
        : this.firstSceneIdx,
    uncertain: uncertain ?? this.uncertain,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    ivlDays: ivlDays ?? this.ivlDays,
    ease: ease ?? this.ease,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    lastReviewAt: lastReviewAt.present ? lastReviewAt.value : this.lastReviewAt,
  );
  KnowledgeCard copyWithCompanion(KnowledgeCardsCompanion data) {
    return KnowledgeCard(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      term: data.term.present ? data.term.value : this.term,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      firstSceneIdx: data.firstSceneIdx.present
          ? data.firstSceneIdx.value
          : this.firstSceneIdx,
      uncertain: data.uncertain.present ? data.uncertain.value : this.uncertain,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      ivlDays: data.ivlDays.present ? data.ivlDays.value : this.ivlDays,
      ease: data.ease.present ? data.ease.value : this.ease,
      reps: data.reps.present ? data.reps.value : this.reps,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      lastReviewAt: data.lastReviewAt.present
          ? data.lastReviewAt.value
          : this.lastReviewAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeCard(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('term: $term, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('firstSceneIdx: $firstSceneIdx, ')
          ..write('uncertain: $uncertain, ')
          ..write('dueAt: $dueAt, ')
          ..write('ivlDays: $ivlDays, ')
          ..write('ease: $ease, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('lastReviewAt: $lastReviewAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    term,
    title,
    content,
    firstSceneIdx,
    uncertain,
    dueAt,
    ivlDays,
    ease,
    reps,
    lapses,
    lastReviewAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnowledgeCard &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.term == this.term &&
          other.title == this.title &&
          other.content == this.content &&
          other.firstSceneIdx == this.firstSceneIdx &&
          other.uncertain == this.uncertain &&
          other.dueAt == this.dueAt &&
          other.ivlDays == this.ivlDays &&
          other.ease == this.ease &&
          other.reps == this.reps &&
          other.lapses == this.lapses &&
          other.lastReviewAt == this.lastReviewAt);
}

class KnowledgeCardsCompanion extends UpdateCompanion<KnowledgeCard> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<String> term;
  final Value<String> title;
  final Value<String> content;
  final Value<int?> firstSceneIdx;
  final Value<bool> uncertain;
  final Value<DateTime?> dueAt;
  final Value<double> ivlDays;
  final Value<double> ease;
  final Value<int> reps;
  final Value<int> lapses;
  final Value<DateTime?> lastReviewAt;
  const KnowledgeCardsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.term = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.firstSceneIdx = const Value.absent(),
    this.uncertain = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.ivlDays = const Value.absent(),
    this.ease = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.lastReviewAt = const Value.absent(),
  });
  KnowledgeCardsCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required String term,
    required String title,
    required String content,
    this.firstSceneIdx = const Value.absent(),
    this.uncertain = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.ivlDays = const Value.absent(),
    this.ease = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.lastReviewAt = const Value.absent(),
  }) : projectId = Value(projectId),
       term = Value(term),
       title = Value(title),
       content = Value(content);
  static Insertable<KnowledgeCard> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? term,
    Expression<String>? title,
    Expression<String>? content,
    Expression<int>? firstSceneIdx,
    Expression<bool>? uncertain,
    Expression<DateTime>? dueAt,
    Expression<double>? ivlDays,
    Expression<double>? ease,
    Expression<int>? reps,
    Expression<int>? lapses,
    Expression<DateTime>? lastReviewAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (term != null) 'term': term,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (firstSceneIdx != null) 'first_scene_idx': firstSceneIdx,
      if (uncertain != null) 'uncertain': uncertain,
      if (dueAt != null) 'due_at': dueAt,
      if (ivlDays != null) 'ivl_days': ivlDays,
      if (ease != null) 'ease': ease,
      if (reps != null) 'reps': reps,
      if (lapses != null) 'lapses': lapses,
      if (lastReviewAt != null) 'last_review_at': lastReviewAt,
    });
  }

  KnowledgeCardsCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<String>? term,
    Value<String>? title,
    Value<String>? content,
    Value<int?>? firstSceneIdx,
    Value<bool>? uncertain,
    Value<DateTime?>? dueAt,
    Value<double>? ivlDays,
    Value<double>? ease,
    Value<int>? reps,
    Value<int>? lapses,
    Value<DateTime?>? lastReviewAt,
  }) {
    return KnowledgeCardsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      term: term ?? this.term,
      title: title ?? this.title,
      content: content ?? this.content,
      firstSceneIdx: firstSceneIdx ?? this.firstSceneIdx,
      uncertain: uncertain ?? this.uncertain,
      dueAt: dueAt ?? this.dueAt,
      ivlDays: ivlDays ?? this.ivlDays,
      ease: ease ?? this.ease,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      lastReviewAt: lastReviewAt ?? this.lastReviewAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (term.present) {
      map['term'] = Variable<String>(term.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (firstSceneIdx.present) {
      map['first_scene_idx'] = Variable<int>(firstSceneIdx.value);
    }
    if (uncertain.present) {
      map['uncertain'] = Variable<bool>(uncertain.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (ivlDays.present) {
      map['ivl_days'] = Variable<double>(ivlDays.value);
    }
    if (ease.present) {
      map['ease'] = Variable<double>(ease.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (lastReviewAt.present) {
      map['last_review_at'] = Variable<DateTime>(lastReviewAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeCardsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('term: $term, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('firstSceneIdx: $firstSceneIdx, ')
          ..write('uncertain: $uncertain, ')
          ..write('dueAt: $dueAt, ')
          ..write('ivlDays: $ivlDays, ')
          ..write('ease: $ease, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('lastReviewAt: $lastReviewAt')
          ..write(')'))
        .toString();
  }
}

class $QuestionsTable extends Questions
    with TableInfo<$QuestionsTable, Question> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sceneIdMeta = const VerificationMeta(
    'sceneId',
  );
  @override
  late final GeneratedColumn<int> sceneId = GeneratedColumn<int>(
    'scene_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _perspectivesJsonMeta = const VerificationMeta(
    'perspectivesJson',
  );
  @override
  late final GeneratedColumn<String> perspectivesJson = GeneratedColumn<String>(
    'perspectives_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    sceneId,
    question,
    perspectivesJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Question> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('scene_id')) {
      context.handle(
        _sceneIdMeta,
        sceneId.isAcceptableOrUnknown(data['scene_id']!, _sceneIdMeta),
      );
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('perspectives_json')) {
      context.handle(
        _perspectivesJsonMeta,
        perspectivesJson.isAcceptableOrUnknown(
          data['perspectives_json']!,
          _perspectivesJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Question map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Question(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      sceneId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scene_id'],
      ),
      question: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question'],
      )!,
      perspectivesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}perspectives_json'],
      )!,
    );
  }

  @override
  $QuestionsTable createAlias(String alias) {
    return $QuestionsTable(attachedDatabase, alias);
  }
}

class Question extends DataClass implements Insertable<Question> {
  final int id;
  final int projectId;
  final int? sceneId;
  final String question;
  final String perspectivesJson;
  const Question({
    required this.id,
    required this.projectId,
    this.sceneId,
    required this.question,
    required this.perspectivesJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    if (!nullToAbsent || sceneId != null) {
      map['scene_id'] = Variable<int>(sceneId);
    }
    map['question'] = Variable<String>(question);
    map['perspectives_json'] = Variable<String>(perspectivesJson);
    return map;
  }

  QuestionsCompanion toCompanion(bool nullToAbsent) {
    return QuestionsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      sceneId: sceneId == null && nullToAbsent
          ? const Value.absent()
          : Value(sceneId),
      question: Value(question),
      perspectivesJson: Value(perspectivesJson),
    );
  }

  factory Question.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Question(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      sceneId: serializer.fromJson<int?>(json['sceneId']),
      question: serializer.fromJson<String>(json['question']),
      perspectivesJson: serializer.fromJson<String>(json['perspectivesJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'sceneId': serializer.toJson<int?>(sceneId),
      'question': serializer.toJson<String>(question),
      'perspectivesJson': serializer.toJson<String>(perspectivesJson),
    };
  }

  Question copyWith({
    int? id,
    int? projectId,
    Value<int?> sceneId = const Value.absent(),
    String? question,
    String? perspectivesJson,
  }) => Question(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    sceneId: sceneId.present ? sceneId.value : this.sceneId,
    question: question ?? this.question,
    perspectivesJson: perspectivesJson ?? this.perspectivesJson,
  );
  Question copyWithCompanion(QuestionsCompanion data) {
    return Question(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      sceneId: data.sceneId.present ? data.sceneId.value : this.sceneId,
      question: data.question.present ? data.question.value : this.question,
      perspectivesJson: data.perspectivesJson.present
          ? data.perspectivesJson.value
          : this.perspectivesJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Question(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('sceneId: $sceneId, ')
          ..write('question: $question, ')
          ..write('perspectivesJson: $perspectivesJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, projectId, sceneId, question, perspectivesJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Question &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.sceneId == this.sceneId &&
          other.question == this.question &&
          other.perspectivesJson == this.perspectivesJson);
}

class QuestionsCompanion extends UpdateCompanion<Question> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<int?> sceneId;
  final Value<String> question;
  final Value<String> perspectivesJson;
  const QuestionsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.sceneId = const Value.absent(),
    this.question = const Value.absent(),
    this.perspectivesJson = const Value.absent(),
  });
  QuestionsCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    this.sceneId = const Value.absent(),
    required String question,
    this.perspectivesJson = const Value.absent(),
  }) : projectId = Value(projectId),
       question = Value(question);
  static Insertable<Question> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<int>? sceneId,
    Expression<String>? question,
    Expression<String>? perspectivesJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (sceneId != null) 'scene_id': sceneId,
      if (question != null) 'question': question,
      if (perspectivesJson != null) 'perspectives_json': perspectivesJson,
    });
  }

  QuestionsCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<int?>? sceneId,
    Value<String>? question,
    Value<String>? perspectivesJson,
  }) {
    return QuestionsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      sceneId: sceneId ?? this.sceneId,
      question: question ?? this.question,
      perspectivesJson: perspectivesJson ?? this.perspectivesJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (sceneId.present) {
      map['scene_id'] = Variable<int>(sceneId.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (perspectivesJson.present) {
      map['perspectives_json'] = Variable<String>(perspectivesJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuestionsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('sceneId: $sceneId, ')
          ..write('question: $question, ')
          ..write('perspectivesJson: $perspectivesJson')
          ..write(')'))
        .toString();
  }
}

class $QaRecordsTable extends QaRecords
    with TableInfo<$QaRecordsTable, QaRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QaRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<int> questionId = GeneratedColumn<int>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES questions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _userAnswerMeta = const VerificationMeta(
    'userAnswer',
  );
  @override
  late final GeneratedColumn<String> userAnswer = GeneratedColumn<String>(
    'user_answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answeredAtMeta = const VerificationMeta(
    'answeredAt',
  );
  @override
  late final GeneratedColumn<DateTime> answeredAt = GeneratedColumn<DateTime>(
    'answered_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    questionId,
    userAnswer,
    answeredAt,
    skipped,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'qa_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<QaRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('user_answer')) {
      context.handle(
        _userAnswerMeta,
        userAnswer.isAcceptableOrUnknown(data['user_answer']!, _userAnswerMeta),
      );
    } else if (isInserting) {
      context.missing(_userAnswerMeta);
    }
    if (data.containsKey('answered_at')) {
      context.handle(
        _answeredAtMeta,
        answeredAt.isAcceptableOrUnknown(data['answered_at']!, _answeredAtMeta),
      );
    }
    if (data.containsKey('skipped')) {
      context.handle(
        _skippedMeta,
        skipped.isAcceptableOrUnknown(data['skipped']!, _skippedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QaRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QaRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}question_id'],
      )!,
      userAnswer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_answer'],
      )!,
      answeredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}answered_at'],
      )!,
      skipped: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}skipped'],
      )!,
    );
  }

  @override
  $QaRecordsTable createAlias(String alias) {
    return $QaRecordsTable(attachedDatabase, alias);
  }
}

class QaRecord extends DataClass implements Insertable<QaRecord> {
  final int id;
  final int questionId;
  final String userAnswer;
  final DateTime answeredAt;
  final bool skipped;
  const QaRecord({
    required this.id,
    required this.questionId,
    required this.userAnswer,
    required this.answeredAt,
    required this.skipped,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['question_id'] = Variable<int>(questionId);
    map['user_answer'] = Variable<String>(userAnswer);
    map['answered_at'] = Variable<DateTime>(answeredAt);
    map['skipped'] = Variable<bool>(skipped);
    return map;
  }

  QaRecordsCompanion toCompanion(bool nullToAbsent) {
    return QaRecordsCompanion(
      id: Value(id),
      questionId: Value(questionId),
      userAnswer: Value(userAnswer),
      answeredAt: Value(answeredAt),
      skipped: Value(skipped),
    );
  }

  factory QaRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QaRecord(
      id: serializer.fromJson<int>(json['id']),
      questionId: serializer.fromJson<int>(json['questionId']),
      userAnswer: serializer.fromJson<String>(json['userAnswer']),
      answeredAt: serializer.fromJson<DateTime>(json['answeredAt']),
      skipped: serializer.fromJson<bool>(json['skipped']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'questionId': serializer.toJson<int>(questionId),
      'userAnswer': serializer.toJson<String>(userAnswer),
      'answeredAt': serializer.toJson<DateTime>(answeredAt),
      'skipped': serializer.toJson<bool>(skipped),
    };
  }

  QaRecord copyWith({
    int? id,
    int? questionId,
    String? userAnswer,
    DateTime? answeredAt,
    bool? skipped,
  }) => QaRecord(
    id: id ?? this.id,
    questionId: questionId ?? this.questionId,
    userAnswer: userAnswer ?? this.userAnswer,
    answeredAt: answeredAt ?? this.answeredAt,
    skipped: skipped ?? this.skipped,
  );
  QaRecord copyWithCompanion(QaRecordsCompanion data) {
    return QaRecord(
      id: data.id.present ? data.id.value : this.id,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      userAnswer: data.userAnswer.present
          ? data.userAnswer.value
          : this.userAnswer,
      answeredAt: data.answeredAt.present
          ? data.answeredAt.value
          : this.answeredAt,
      skipped: data.skipped.present ? data.skipped.value : this.skipped,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QaRecord(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('userAnswer: $userAnswer, ')
          ..write('answeredAt: $answeredAt, ')
          ..write('skipped: $skipped')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, questionId, userAnswer, answeredAt, skipped);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QaRecord &&
          other.id == this.id &&
          other.questionId == this.questionId &&
          other.userAnswer == this.userAnswer &&
          other.answeredAt == this.answeredAt &&
          other.skipped == this.skipped);
}

class QaRecordsCompanion extends UpdateCompanion<QaRecord> {
  final Value<int> id;
  final Value<int> questionId;
  final Value<String> userAnswer;
  final Value<DateTime> answeredAt;
  final Value<bool> skipped;
  const QaRecordsCompanion({
    this.id = const Value.absent(),
    this.questionId = const Value.absent(),
    this.userAnswer = const Value.absent(),
    this.answeredAt = const Value.absent(),
    this.skipped = const Value.absent(),
  });
  QaRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int questionId,
    required String userAnswer,
    this.answeredAt = const Value.absent(),
    this.skipped = const Value.absent(),
  }) : questionId = Value(questionId),
       userAnswer = Value(userAnswer);
  static Insertable<QaRecord> custom({
    Expression<int>? id,
    Expression<int>? questionId,
    Expression<String>? userAnswer,
    Expression<DateTime>? answeredAt,
    Expression<bool>? skipped,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (questionId != null) 'question_id': questionId,
      if (userAnswer != null) 'user_answer': userAnswer,
      if (answeredAt != null) 'answered_at': answeredAt,
      if (skipped != null) 'skipped': skipped,
    });
  }

  QaRecordsCompanion copyWith({
    Value<int>? id,
    Value<int>? questionId,
    Value<String>? userAnswer,
    Value<DateTime>? answeredAt,
    Value<bool>? skipped,
  }) {
    return QaRecordsCompanion(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      userAnswer: userAnswer ?? this.userAnswer,
      answeredAt: answeredAt ?? this.answeredAt,
      skipped: skipped ?? this.skipped,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<int>(questionId.value);
    }
    if (userAnswer.present) {
      map['user_answer'] = Variable<String>(userAnswer.value);
    }
    if (answeredAt.present) {
      map['answered_at'] = Variable<DateTime>(answeredAt.value);
    }
    if (skipped.present) {
      map['skipped'] = Variable<bool>(skipped.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QaRecordsCompanion(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('userAnswer: $userAnswer, ')
          ..write('answeredAt: $answeredAt, ')
          ..write('skipped: $skipped')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters with TableInfo<$ChaptersTable, Chapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _idxMeta = const VerificationMeta('idx');
  @override
  late final GeneratedColumn<int> idx = GeneratedColumn<int>(
    'idx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _startParaMeta = const VerificationMeta(
    'startPara',
  );
  @override
  late final GeneratedColumn<int> startPara = GeneratedColumn<int>(
    'start_para',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endParaMeta = const VerificationMeta(
    'endPara',
  );
  @override
  late final GeneratedColumn<int> endPara = GeneratedColumn<int>(
    'end_para',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    idx,
    title,
    startPara,
    endPara,
    summary,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Chapter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('idx')) {
      context.handle(
        _idxMeta,
        idx.isAcceptableOrUnknown(data['idx']!, _idxMeta),
      );
    } else if (isInserting) {
      context.missing(_idxMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('start_para')) {
      context.handle(
        _startParaMeta,
        startPara.isAcceptableOrUnknown(data['start_para']!, _startParaMeta),
      );
    } else if (isInserting) {
      context.missing(_startParaMeta);
    }
    if (data.containsKey('end_para')) {
      context.handle(
        _endParaMeta,
        endPara.isAcceptableOrUnknown(data['end_para']!, _endParaMeta),
      );
    } else if (isInserting) {
      context.missing(_endParaMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Chapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chapter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      idx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}idx'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      startPara: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_para'],
      )!,
      endPara: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_para'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class Chapter extends DataClass implements Insertable<Chapter> {
  final int id;
  final int projectId;
  final int idx;
  final String? title;
  final int startPara;
  final int endPara;
  final String? summary;
  const Chapter({
    required this.id,
    required this.projectId,
    required this.idx,
    this.title,
    required this.startPara,
    required this.endPara,
    this.summary,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['idx'] = Variable<int>(idx);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['start_para'] = Variable<int>(startPara);
    map['end_para'] = Variable<int>(endPara);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      id: Value(id),
      projectId: Value(projectId),
      idx: Value(idx),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      startPara: Value(startPara),
      endPara: Value(endPara),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
    );
  }

  factory Chapter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chapter(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      idx: serializer.fromJson<int>(json['idx']),
      title: serializer.fromJson<String?>(json['title']),
      startPara: serializer.fromJson<int>(json['startPara']),
      endPara: serializer.fromJson<int>(json['endPara']),
      summary: serializer.fromJson<String?>(json['summary']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'idx': serializer.toJson<int>(idx),
      'title': serializer.toJson<String?>(title),
      'startPara': serializer.toJson<int>(startPara),
      'endPara': serializer.toJson<int>(endPara),
      'summary': serializer.toJson<String?>(summary),
    };
  }

  Chapter copyWith({
    int? id,
    int? projectId,
    int? idx,
    Value<String?> title = const Value.absent(),
    int? startPara,
    int? endPara,
    Value<String?> summary = const Value.absent(),
  }) => Chapter(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    idx: idx ?? this.idx,
    title: title.present ? title.value : this.title,
    startPara: startPara ?? this.startPara,
    endPara: endPara ?? this.endPara,
    summary: summary.present ? summary.value : this.summary,
  );
  Chapter copyWithCompanion(ChaptersCompanion data) {
    return Chapter(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      idx: data.idx.present ? data.idx.value : this.idx,
      title: data.title.present ? data.title.value : this.title,
      startPara: data.startPara.present ? data.startPara.value : this.startPara,
      endPara: data.endPara.present ? data.endPara.value : this.endPara,
      summary: data.summary.present ? data.summary.value : this.summary,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chapter(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('idx: $idx, ')
          ..write('title: $title, ')
          ..write('startPara: $startPara, ')
          ..write('endPara: $endPara, ')
          ..write('summary: $summary')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, projectId, idx, title, startPara, endPara, summary);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chapter &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.idx == this.idx &&
          other.title == this.title &&
          other.startPara == this.startPara &&
          other.endPara == this.endPara &&
          other.summary == this.summary);
}

class ChaptersCompanion extends UpdateCompanion<Chapter> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<int> idx;
  final Value<String?> title;
  final Value<int> startPara;
  final Value<int> endPara;
  final Value<String?> summary;
  const ChaptersCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.idx = const Value.absent(),
    this.title = const Value.absent(),
    this.startPara = const Value.absent(),
    this.endPara = const Value.absent(),
    this.summary = const Value.absent(),
  });
  ChaptersCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required int idx,
    this.title = const Value.absent(),
    required int startPara,
    required int endPara,
    this.summary = const Value.absent(),
  }) : projectId = Value(projectId),
       idx = Value(idx),
       startPara = Value(startPara),
       endPara = Value(endPara);
  static Insertable<Chapter> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<int>? idx,
    Expression<String>? title,
    Expression<int>? startPara,
    Expression<int>? endPara,
    Expression<String>? summary,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (idx != null) 'idx': idx,
      if (title != null) 'title': title,
      if (startPara != null) 'start_para': startPara,
      if (endPara != null) 'end_para': endPara,
      if (summary != null) 'summary': summary,
    });
  }

  ChaptersCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<int>? idx,
    Value<String?>? title,
    Value<int>? startPara,
    Value<int>? endPara,
    Value<String?>? summary,
  }) {
    return ChaptersCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      idx: idx ?? this.idx,
      title: title ?? this.title,
      startPara: startPara ?? this.startPara,
      endPara: endPara ?? this.endPara,
      summary: summary ?? this.summary,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (idx.present) {
      map['idx'] = Variable<int>(idx.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startPara.present) {
      map['start_para'] = Variable<int>(startPara.value);
    }
    if (endPara.present) {
      map['end_para'] = Variable<int>(endPara.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChaptersCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('idx: $idx, ')
          ..write('title: $title, ')
          ..write('startPara: $startPara, ')
          ..write('endPara: $endPara, ')
          ..write('summary: $summary')
          ..write(')'))
        .toString();
  }
}

class $ParagraphsTable extends Paragraphs
    with TableInfo<$ParagraphsTable, Paragraph> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParagraphsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<int> chapterId = GeneratedColumn<int>(
    'chapter_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idxMeta = const VerificationMeta('idx');
  @override
  late final GeneratedColumn<int> idx = GeneratedColumn<int>(
    'idx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    chapterId,
    idx,
    content,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'paragraphs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Paragraph> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    }
    if (data.containsKey('idx')) {
      context.handle(
        _idxMeta,
        idx.isAcceptableOrUnknown(data['idx']!, _idxMeta),
      );
    } else if (isInserting) {
      context.missing(_idxMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['text']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Paragraph map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Paragraph(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_id'],
      ),
      idx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}idx'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
    );
  }

  @override
  $ParagraphsTable createAlias(String alias) {
    return $ParagraphsTable(attachedDatabase, alias);
  }
}

class Paragraph extends DataClass implements Insertable<Paragraph> {
  final int id;
  final int projectId;
  final int? chapterId;
  final int idx;
  final String content;
  const Paragraph({
    required this.id,
    required this.projectId,
    this.chapterId,
    required this.idx,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    if (!nullToAbsent || chapterId != null) {
      map['chapter_id'] = Variable<int>(chapterId);
    }
    map['idx'] = Variable<int>(idx);
    map['text'] = Variable<String>(content);
    return map;
  }

  ParagraphsCompanion toCompanion(bool nullToAbsent) {
    return ParagraphsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      chapterId: chapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterId),
      idx: Value(idx),
      content: Value(content),
    );
  }

  factory Paragraph.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Paragraph(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      chapterId: serializer.fromJson<int?>(json['chapterId']),
      idx: serializer.fromJson<int>(json['idx']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'chapterId': serializer.toJson<int?>(chapterId),
      'idx': serializer.toJson<int>(idx),
      'content': serializer.toJson<String>(content),
    };
  }

  Paragraph copyWith({
    int? id,
    int? projectId,
    Value<int?> chapterId = const Value.absent(),
    int? idx,
    String? content,
  }) => Paragraph(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    chapterId: chapterId.present ? chapterId.value : this.chapterId,
    idx: idx ?? this.idx,
    content: content ?? this.content,
  );
  Paragraph copyWithCompanion(ParagraphsCompanion data) {
    return Paragraph(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      idx: data.idx.present ? data.idx.value : this.idx,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Paragraph(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('chapterId: $chapterId, ')
          ..write('idx: $idx, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, chapterId, idx, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Paragraph &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.chapterId == this.chapterId &&
          other.idx == this.idx &&
          other.content == this.content);
}

class ParagraphsCompanion extends UpdateCompanion<Paragraph> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<int?> chapterId;
  final Value<int> idx;
  final Value<String> content;
  const ParagraphsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.idx = const Value.absent(),
    this.content = const Value.absent(),
  });
  ParagraphsCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    this.chapterId = const Value.absent(),
    required int idx,
    required String content,
  }) : projectId = Value(projectId),
       idx = Value(idx),
       content = Value(content);
  static Insertable<Paragraph> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<int>? chapterId,
    Expression<int>? idx,
    Expression<String>? content,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (idx != null) 'idx': idx,
      if (content != null) 'text': content,
    });
  }

  ParagraphsCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<int?>? chapterId,
    Value<int>? idx,
    Value<String>? content,
  }) {
    return ParagraphsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      chapterId: chapterId ?? this.chapterId,
      idx: idx ?? this.idx,
      content: content ?? this.content,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<int>(chapterId.value);
    }
    if (idx.present) {
      map['idx'] = Variable<int>(idx.value);
    }
    if (content.present) {
      map['text'] = Variable<String>(content.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParagraphsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('chapterId: $chapterId, ')
          ..write('idx: $idx, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }
}

class $AnnotationsTable extends Annotations
    with TableInfo<$AnnotationsTable, Annotation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnotationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _paraIdMeta = const VerificationMeta('paraId');
  @override
  late final GeneratedColumn<int> paraId = GeneratedColumn<int>(
    'para_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES paragraphs (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _contentJsonMeta = const VerificationMeta(
    'contentJson',
  );
  @override
  late final GeneratedColumn<String> contentJson = GeneratedColumn<String>(
    'content_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, paraId, type, contentJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'annotations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Annotation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('para_id')) {
      context.handle(
        _paraIdMeta,
        paraId.isAcceptableOrUnknown(data['para_id']!, _paraIdMeta),
      );
    } else if (isInserting) {
      context.missing(_paraIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('content_json')) {
      context.handle(
        _contentJsonMeta,
        contentJson.isAcceptableOrUnknown(
          data['content_json']!,
          _contentJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Annotation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Annotation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      paraId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}para_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      contentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_json'],
      )!,
    );
  }

  @override
  $AnnotationsTable createAlias(String alias) {
    return $AnnotationsTable(attachedDatabase, alias);
  }
}

class Annotation extends DataClass implements Insertable<Annotation> {
  final int id;
  final int paraId;
  final String type;
  final String contentJson;
  const Annotation({
    required this.id,
    required this.paraId,
    required this.type,
    required this.contentJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['para_id'] = Variable<int>(paraId);
    map['type'] = Variable<String>(type);
    map['content_json'] = Variable<String>(contentJson);
    return map;
  }

  AnnotationsCompanion toCompanion(bool nullToAbsent) {
    return AnnotationsCompanion(
      id: Value(id),
      paraId: Value(paraId),
      type: Value(type),
      contentJson: Value(contentJson),
    );
  }

  factory Annotation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Annotation(
      id: serializer.fromJson<int>(json['id']),
      paraId: serializer.fromJson<int>(json['paraId']),
      type: serializer.fromJson<String>(json['type']),
      contentJson: serializer.fromJson<String>(json['contentJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'paraId': serializer.toJson<int>(paraId),
      'type': serializer.toJson<String>(type),
      'contentJson': serializer.toJson<String>(contentJson),
    };
  }

  Annotation copyWith({
    int? id,
    int? paraId,
    String? type,
    String? contentJson,
  }) => Annotation(
    id: id ?? this.id,
    paraId: paraId ?? this.paraId,
    type: type ?? this.type,
    contentJson: contentJson ?? this.contentJson,
  );
  Annotation copyWithCompanion(AnnotationsCompanion data) {
    return Annotation(
      id: data.id.present ? data.id.value : this.id,
      paraId: data.paraId.present ? data.paraId.value : this.paraId,
      type: data.type.present ? data.type.value : this.type,
      contentJson: data.contentJson.present
          ? data.contentJson.value
          : this.contentJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Annotation(')
          ..write('id: $id, ')
          ..write('paraId: $paraId, ')
          ..write('type: $type, ')
          ..write('contentJson: $contentJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, paraId, type, contentJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Annotation &&
          other.id == this.id &&
          other.paraId == this.paraId &&
          other.type == this.type &&
          other.contentJson == this.contentJson);
}

class AnnotationsCompanion extends UpdateCompanion<Annotation> {
  final Value<int> id;
  final Value<int> paraId;
  final Value<String> type;
  final Value<String> contentJson;
  const AnnotationsCompanion({
    this.id = const Value.absent(),
    this.paraId = const Value.absent(),
    this.type = const Value.absent(),
    this.contentJson = const Value.absent(),
  });
  AnnotationsCompanion.insert({
    this.id = const Value.absent(),
    required int paraId,
    required String type,
    required String contentJson,
  }) : paraId = Value(paraId),
       type = Value(type),
       contentJson = Value(contentJson);
  static Insertable<Annotation> custom({
    Expression<int>? id,
    Expression<int>? paraId,
    Expression<String>? type,
    Expression<String>? contentJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (paraId != null) 'para_id': paraId,
      if (type != null) 'type': type,
      if (contentJson != null) 'content_json': contentJson,
    });
  }

  AnnotationsCompanion copyWith({
    Value<int>? id,
    Value<int>? paraId,
    Value<String>? type,
    Value<String>? contentJson,
  }) {
    return AnnotationsCompanion(
      id: id ?? this.id,
      paraId: paraId ?? this.paraId,
      type: type ?? this.type,
      contentJson: contentJson ?? this.contentJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (paraId.present) {
      map['para_id'] = Variable<int>(paraId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (contentJson.present) {
      map['content_json'] = Variable<String>(contentJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationsCompanion(')
          ..write('id: $id, ')
          ..write('paraId: $paraId, ')
          ..write('type: $type, ')
          ..write('contentJson: $contentJson')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
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
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LlmLogsTable extends LlmLogs with TableInfo<$LlmLogsTable, LlmLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LlmLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _purposeMeta = const VerificationMeta(
    'purpose',
  );
  @override
  late final GeneratedColumn<String> purpose = GeneratedColumn<String>(
    'purpose',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptTokensMeta = const VerificationMeta(
    'promptTokens',
  );
  @override
  late final GeneratedColumn<int> promptTokens = GeneratedColumn<int>(
    'prompt_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completionTokensMeta = const VerificationMeta(
    'completionTokens',
  );
  @override
  late final GeneratedColumn<int> completionTokens = GeneratedColumn<int>(
    'completion_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    purpose,
    model,
    promptTokens,
    completionTokens,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'llm_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LlmLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    if (data.containsKey('purpose')) {
      context.handle(
        _purposeMeta,
        purpose.isAcceptableOrUnknown(data['purpose']!, _purposeMeta),
      );
    } else if (isInserting) {
      context.missing(_purposeMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('prompt_tokens')) {
      context.handle(
        _promptTokensMeta,
        promptTokens.isAcceptableOrUnknown(
          data['prompt_tokens']!,
          _promptTokensMeta,
        ),
      );
    }
    if (data.containsKey('completion_tokens')) {
      context.handle(
        _completionTokensMeta,
        completionTokens.isAcceptableOrUnknown(
          data['completion_tokens']!,
          _completionTokensMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LlmLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LlmLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      ),
      purpose: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purpose'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      promptTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prompt_tokens'],
      )!,
      completionTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completion_tokens'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LlmLogsTable createAlias(String alias) {
    return $LlmLogsTable(attachedDatabase, alias);
  }
}

class LlmLog extends DataClass implements Insertable<LlmLog> {
  final int id;
  final int? projectId;
  final String purpose;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final DateTime createdAt;
  const LlmLog({
    required this.id,
    this.projectId,
    required this.purpose,
    required this.model,
    required this.promptTokens,
    required this.completionTokens,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<int>(projectId);
    }
    map['purpose'] = Variable<String>(purpose);
    map['model'] = Variable<String>(model);
    map['prompt_tokens'] = Variable<int>(promptTokens);
    map['completion_tokens'] = Variable<int>(completionTokens);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LlmLogsCompanion toCompanion(bool nullToAbsent) {
    return LlmLogsCompanion(
      id: Value(id),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      purpose: Value(purpose),
      model: Value(model),
      promptTokens: Value(promptTokens),
      completionTokens: Value(completionTokens),
      createdAt: Value(createdAt),
    );
  }

  factory LlmLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LlmLog(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int?>(json['projectId']),
      purpose: serializer.fromJson<String>(json['purpose']),
      model: serializer.fromJson<String>(json['model']),
      promptTokens: serializer.fromJson<int>(json['promptTokens']),
      completionTokens: serializer.fromJson<int>(json['completionTokens']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int?>(projectId),
      'purpose': serializer.toJson<String>(purpose),
      'model': serializer.toJson<String>(model),
      'promptTokens': serializer.toJson<int>(promptTokens),
      'completionTokens': serializer.toJson<int>(completionTokens),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LlmLog copyWith({
    int? id,
    Value<int?> projectId = const Value.absent(),
    String? purpose,
    String? model,
    int? promptTokens,
    int? completionTokens,
    DateTime? createdAt,
  }) => LlmLog(
    id: id ?? this.id,
    projectId: projectId.present ? projectId.value : this.projectId,
    purpose: purpose ?? this.purpose,
    model: model ?? this.model,
    promptTokens: promptTokens ?? this.promptTokens,
    completionTokens: completionTokens ?? this.completionTokens,
    createdAt: createdAt ?? this.createdAt,
  );
  LlmLog copyWithCompanion(LlmLogsCompanion data) {
    return LlmLog(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      purpose: data.purpose.present ? data.purpose.value : this.purpose,
      model: data.model.present ? data.model.value : this.model,
      promptTokens: data.promptTokens.present
          ? data.promptTokens.value
          : this.promptTokens,
      completionTokens: data.completionTokens.present
          ? data.completionTokens.value
          : this.completionTokens,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LlmLog(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('purpose: $purpose, ')
          ..write('model: $model, ')
          ..write('promptTokens: $promptTokens, ')
          ..write('completionTokens: $completionTokens, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    purpose,
    model,
    promptTokens,
    completionTokens,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LlmLog &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.purpose == this.purpose &&
          other.model == this.model &&
          other.promptTokens == this.promptTokens &&
          other.completionTokens == this.completionTokens &&
          other.createdAt == this.createdAt);
}

class LlmLogsCompanion extends UpdateCompanion<LlmLog> {
  final Value<int> id;
  final Value<int?> projectId;
  final Value<String> purpose;
  final Value<String> model;
  final Value<int> promptTokens;
  final Value<int> completionTokens;
  final Value<DateTime> createdAt;
  const LlmLogsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.purpose = const Value.absent(),
    this.model = const Value.absent(),
    this.promptTokens = const Value.absent(),
    this.completionTokens = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LlmLogsCompanion.insert({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    required String purpose,
    required String model,
    this.promptTokens = const Value.absent(),
    this.completionTokens = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : purpose = Value(purpose),
       model = Value(model);
  static Insertable<LlmLog> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? purpose,
    Expression<String>? model,
    Expression<int>? promptTokens,
    Expression<int>? completionTokens,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (purpose != null) 'purpose': purpose,
      if (model != null) 'model': model,
      if (promptTokens != null) 'prompt_tokens': promptTokens,
      if (completionTokens != null) 'completion_tokens': completionTokens,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LlmLogsCompanion copyWith({
    Value<int>? id,
    Value<int?>? projectId,
    Value<String>? purpose,
    Value<String>? model,
    Value<int>? promptTokens,
    Value<int>? completionTokens,
    Value<DateTime>? createdAt,
  }) {
    return LlmLogsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      purpose: purpose ?? this.purpose,
      model: model ?? this.model,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (purpose.present) {
      map['purpose'] = Variable<String>(purpose.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (promptTokens.present) {
      map['prompt_tokens'] = Variable<int>(promptTokens.value);
    }
    if (completionTokens.present) {
      map['completion_tokens'] = Variable<int>(completionTokens.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LlmLogsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('purpose: $purpose, ')
          ..write('model: $model, ')
          ..write('promptTokens: $promptTokens, ')
          ..write('completionTokens: $completionTokens, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LlmCacheTable extends LlmCache
    with TableInfo<$LlmCacheTable, LlmCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LlmCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responseMeta = const VerificationMeta(
    'response',
  );
  @override
  late final GeneratedColumn<String> response = GeneratedColumn<String>(
    'response',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [key, response, model, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'llm_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<LlmCacheData> instance, {
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
    if (data.containsKey('response')) {
      context.handle(
        _responseMeta,
        response.isAcceptableOrUnknown(data['response']!, _responseMeta),
      );
    } else if (isInserting) {
      context.missing(_responseMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LlmCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LlmCacheData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      response: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LlmCacheTable createAlias(String alias) {
    return $LlmCacheTable(attachedDatabase, alias);
  }
}

class LlmCacheData extends DataClass implements Insertable<LlmCacheData> {
  final String key;
  final String response;
  final String model;
  final DateTime createdAt;
  const LlmCacheData({
    required this.key,
    required this.response,
    required this.model,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['response'] = Variable<String>(response);
    map['model'] = Variable<String>(model);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LlmCacheCompanion toCompanion(bool nullToAbsent) {
    return LlmCacheCompanion(
      key: Value(key),
      response: Value(response),
      model: Value(model),
      createdAt: Value(createdAt),
    );
  }

  factory LlmCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LlmCacheData(
      key: serializer.fromJson<String>(json['key']),
      response: serializer.fromJson<String>(json['response']),
      model: serializer.fromJson<String>(json['model']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'response': serializer.toJson<String>(response),
      'model': serializer.toJson<String>(model),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LlmCacheData copyWith({
    String? key,
    String? response,
    String? model,
    DateTime? createdAt,
  }) => LlmCacheData(
    key: key ?? this.key,
    response: response ?? this.response,
    model: model ?? this.model,
    createdAt: createdAt ?? this.createdAt,
  );
  LlmCacheData copyWithCompanion(LlmCacheCompanion data) {
    return LlmCacheData(
      key: data.key.present ? data.key.value : this.key,
      response: data.response.present ? data.response.value : this.response,
      model: data.model.present ? data.model.value : this.model,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LlmCacheData(')
          ..write('key: $key, ')
          ..write('response: $response, ')
          ..write('model: $model, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, response, model, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LlmCacheData &&
          other.key == this.key &&
          other.response == this.response &&
          other.model == this.model &&
          other.createdAt == this.createdAt);
}

class LlmCacheCompanion extends UpdateCompanion<LlmCacheData> {
  final Value<String> key;
  final Value<String> response;
  final Value<String> model;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LlmCacheCompanion({
    this.key = const Value.absent(),
    this.response = const Value.absent(),
    this.model = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LlmCacheCompanion.insert({
    required String key,
    required String response,
    required String model,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       response = Value(response),
       model = Value(model);
  static Insertable<LlmCacheData> custom({
    Expression<String>? key,
    Expression<String>? response,
    Expression<String>? model,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (response != null) 'response': response,
      if (model != null) 'model': model,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LlmCacheCompanion copyWith({
    Value<String>? key,
    Value<String>? response,
    Value<String>? model,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LlmCacheCompanion(
      key: key ?? this.key,
      response: response ?? this.response,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (response.present) {
      map['response'] = Variable<String>(response.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LlmCacheCompanion(')
          ..write('key: $key, ')
          ..write('response: $response, ')
          ..write('model: $model, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LlmChannelsTable extends LlmChannels
    with TableInfo<$LlmChannelsTable, LlmChannel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LlmChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
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
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  @override
  List<GeneratedColumn> get $columns => [id, name, baseUrl, enabled, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'llm_channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<LlmChannel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LlmChannel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LlmChannel(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LlmChannelsTable createAlias(String alias) {
    return $LlmChannelsTable(attachedDatabase, alias);
  }
}

class LlmChannel extends DataClass implements Insertable<LlmChannel> {
  final int id;
  final String name;
  final String baseUrl;
  final bool enabled;
  final DateTime createdAt;
  const LlmChannel({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.enabled,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['base_url'] = Variable<String>(baseUrl);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LlmChannelsCompanion toCompanion(bool nullToAbsent) {
    return LlmChannelsCompanion(
      id: Value(id),
      name: Value(name),
      baseUrl: Value(baseUrl),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
    );
  }

  factory LlmChannel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LlmChannel(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LlmChannel copyWith({
    int? id,
    String? name,
    String? baseUrl,
    bool? enabled,
    DateTime? createdAt,
  }) => LlmChannel(
    id: id ?? this.id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
  );
  LlmChannel copyWithCompanion(LlmChannelsCompanion data) {
    return LlmChannel(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LlmChannel(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, baseUrl, enabled, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LlmChannel &&
          other.id == this.id &&
          other.name == this.name &&
          other.baseUrl == this.baseUrl &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt);
}

class LlmChannelsCompanion extends UpdateCompanion<LlmChannel> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> baseUrl;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  const LlmChannelsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LlmChannelsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String baseUrl,
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       baseUrl = Value(baseUrl);
  static Insertable<LlmChannel> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? baseUrl,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (baseUrl != null) 'base_url': baseUrl,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LlmChannelsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? baseUrl,
    Value<bool>? enabled,
    Value<DateTime>? createdAt,
  }) {
    return LlmChannelsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LlmChannelsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $CharactersTable characters = $CharactersTable(this);
  late final $SegmentsTable segments = $SegmentsTable(this);
  late final $ScenesTable scenes = $ScenesTable(this);
  late final $CommentariesTable commentaries = $CommentariesTable(this);
  late final $KnowledgeCardsTable knowledgeCards = $KnowledgeCardsTable(this);
  late final $QuestionsTable questions = $QuestionsTable(this);
  late final $QaRecordsTable qaRecords = $QaRecordsTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $ParagraphsTable paragraphs = $ParagraphsTable(this);
  late final $AnnotationsTable annotations = $AnnotationsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $LlmLogsTable llmLogs = $LlmLogsTable(this);
  late final $LlmCacheTable llmCache = $LlmCacheTable(this);
  late final $LlmChannelsTable llmChannels = $LlmChannelsTable(this);
  late final Index idxCharactersProject = Index(
    'idx_characters_project',
    'CREATE INDEX idx_characters_project ON characters (project_id)',
  );
  late final Index idxSegmentsProject = Index(
    'idx_segments_project',
    'CREATE INDEX idx_segments_project ON segments (project_id)',
  );
  late final Index idxScenesProject = Index(
    'idx_scenes_project',
    'CREATE INDEX idx_scenes_project ON scenes (project_id)',
  );
  late final Index idxQuestionsProject = Index(
    'idx_questions_project',
    'CREATE INDEX idx_questions_project ON questions (project_id)',
  );
  late final Index idxQuestionsScene = Index(
    'idx_questions_scene',
    'CREATE INDEX idx_questions_scene ON questions (scene_id)',
  );
  late final Index idxQaRecordsQuestion = Index(
    'idx_qa_records_question',
    'CREATE INDEX idx_qa_records_question ON qa_records (question_id)',
  );
  late final Index idxChaptersProject = Index(
    'idx_chapters_project',
    'CREATE INDEX idx_chapters_project ON chapters (project_id)',
  );
  late final Index idxParagraphsProject = Index(
    'idx_paragraphs_project',
    'CREATE INDEX idx_paragraphs_project ON paragraphs (project_id)',
  );
  late final Index idxParagraphsChapter = Index(
    'idx_paragraphs_chapter',
    'CREATE INDEX idx_paragraphs_chapter ON paragraphs (chapter_id)',
  );
  late final Index idxAnnotationsPara = Index(
    'idx_annotations_para',
    'CREATE INDEX idx_annotations_para ON annotations (para_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projects,
    characters,
    segments,
    scenes,
    commentaries,
    knowledgeCards,
    questions,
    qaRecords,
    chapters,
    paragraphs,
    annotations,
    settings,
    llmLogs,
    llmCache,
    llmChannels,
    idxCharactersProject,
    idxSegmentsProject,
    idxScenesProject,
    idxQuestionsProject,
    idxQuestionsScene,
    idxQaRecordsQuestion,
    idxChaptersProject,
    idxParagraphsProject,
    idxParagraphsChapter,
    idxAnnotationsPara,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('characters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('scenes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'scenes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('commentaries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('knowledge_cards', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('questions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('qa_records', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chapters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('paragraphs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'paragraphs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('annotations', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ProjectsTableCreateCompanionBuilder = ProjectsCompanion Function({
  Value<int> id,
  required String type,
  required String title,
  required String sourcePath,
  required String status,
  Value<String?> failedStage,
  Value<String?> metaJson,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$ProjectsTableUpdateCompanionBuilder = ProjectsCompanion Function({
  Value<int> id,
  Value<String> type,
  Value<String> title,
  Value<String> sourcePath,
  Value<String> status,
  Value<String?> failedStage,
  Value<String?> metaJson,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CharactersTable, List<Character>>
  _charactersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.characters,
    aliasName: 'projects__id__characters__project_id',
  );

  $$CharactersTableProcessedTableManager get charactersRefs {
    final manager = $$CharactersTableTableManager(
      $_db,
      $_db.characters,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_charactersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SegmentsTable, List<Segment>> _segmentsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.segments,
    aliasName: 'projects__id__segments__project_id',
  );

  $$SegmentsTableProcessedTableManager get segmentsRefs {
    final manager = $$SegmentsTableTableManager(
      $_db,
      $_db.segments,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_segmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ScenesTable, List<Scene>> _scenesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.scenes,
    aliasName: 'projects__id__scenes__project_id',
  );

  $$ScenesTableProcessedTableManager get scenesRefs {
    final manager = $$ScenesTableTableManager(
      $_db,
      $_db.scenes,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_scenesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$KnowledgeCardsTable, List<KnowledgeCard>>
  _knowledgeCardsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.knowledgeCards,
    aliasName: 'projects__id__knowledge_cards__project_id',
  );

  $$KnowledgeCardsTableProcessedTableManager get knowledgeCardsRefs {
    final manager = $$KnowledgeCardsTableTableManager(
      $_db,
      $_db.knowledgeCards,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_knowledgeCardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$QuestionsTable, List<Question>>
  _questionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.questions,
    aliasName: 'projects__id__questions__project_id',
  );

  $$QuestionsTableProcessedTableManager get questionsRefs {
    final manager = $$QuestionsTableTableManager(
      $_db,
      $_db.questions,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_questionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ChaptersTable, List<Chapter>> _chaptersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.chapters,
    aliasName: 'projects__id__chapters__project_id',
  );

  $$ChaptersTableProcessedTableManager get chaptersRefs {
    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_chaptersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ParagraphsTable, List<Paragraph>>
  _paragraphsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.paragraphs,
    aliasName: 'projects__id__paragraphs__project_id',
  );

  $$ParagraphsTableProcessedTableManager get paragraphsRefs {
    final manager = $$ParagraphsTableTableManager(
      $_db,
      $_db.paragraphs,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_paragraphsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
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

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failedStage => $composableBuilder(
    column: $table.failedStage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
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

  Expression<bool> charactersRefs(
    Expression<bool> Function($$CharactersTableFilterComposer f) f,
  ) {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableFilterComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> segmentsRefs(
    Expression<bool> Function($$SegmentsTableFilterComposer f) f,
  ) {
    final $$SegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.segments,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SegmentsTableFilterComposer(
            $db: $db,
            $table: $db.segments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scenesRefs(
    Expression<bool> Function($$ScenesTableFilterComposer f) f,
  ) {
    final $$ScenesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableFilterComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> knowledgeCardsRefs(
    Expression<bool> Function($$KnowledgeCardsTableFilterComposer f) f,
  ) {
    final $$KnowledgeCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.knowledgeCards,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KnowledgeCardsTableFilterComposer(
            $db: $db,
            $table: $db.knowledgeCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> questionsRefs(
    Expression<bool> Function($$QuestionsTableFilterComposer f) f,
  ) {
    final $$QuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableFilterComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> chaptersRefs(
    Expression<bool> Function($$ChaptersTableFilterComposer f) f,
  ) {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> paragraphsRefs(
    Expression<bool> Function($$ParagraphsTableFilterComposer f) f,
  ) {
    final $$ParagraphsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.paragraphs,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParagraphsTableFilterComposer(
            $db: $db,
            $table: $db.paragraphs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
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

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failedStage => $composableBuilder(
    column: $table.failedStage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metaJson => $composableBuilder(
    column: $table.metaJson,
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

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get failedStage => $composableBuilder(
    column: $table.failedStage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metaJson =>
      $composableBuilder(column: $table.metaJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> charactersRefs<T extends Object>(
    Expression<T> Function($$CharactersTableAnnotationComposer a) f,
  ) {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableAnnotationComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> segmentsRefs<T extends Object>(
    Expression<T> Function($$SegmentsTableAnnotationComposer a) f,
  ) {
    final $$SegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.segments,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.segments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> scenesRefs<T extends Object>(
    Expression<T> Function($$ScenesTableAnnotationComposer a) f,
  ) {
    final $$ScenesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableAnnotationComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> knowledgeCardsRefs<T extends Object>(
    Expression<T> Function($$KnowledgeCardsTableAnnotationComposer a) f,
  ) {
    final $$KnowledgeCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.knowledgeCards,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KnowledgeCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.knowledgeCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> questionsRefs<T extends Object>(
    Expression<T> Function($$QuestionsTableAnnotationComposer a) f,
  ) {
    final $$QuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> chaptersRefs<T extends Object>(
    Expression<T> Function($$ChaptersTableAnnotationComposer a) f,
  ) {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> paragraphsRefs<T extends Object>(
    Expression<T> Function($$ParagraphsTableAnnotationComposer a) f,
  ) {
    final $$ParagraphsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.paragraphs,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParagraphsTableAnnotationComposer(
            $db: $db,
            $table: $db.paragraphs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, $$ProjectsTableReferences),
          Project,
          PrefetchHooks Function({
            bool charactersRefs,
            bool segmentsRefs,
            bool scenesRefs,
            bool knowledgeCardsRefs,
            bool questionsRefs,
            bool chaptersRefs,
            bool paragraphsRefs,
          })
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> sourcePath = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> failedStage = const Value.absent(),
                Value<String?> metaJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                type: type,
                title: title,
                sourcePath: sourcePath,
                status: status,
                failedStage: failedStage,
                metaJson: metaJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String type,
                required String title,
                required String sourcePath,
                required String status,
                Value<String?> failedStage = const Value.absent(),
                Value<String?> metaJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                type: type,
                title: title,
                sourcePath: sourcePath,
                status: status,
                failedStage: failedStage,
                metaJson: metaJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProjectsTable, Project>(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                charactersRefs = false,
                segmentsRefs = false,
                scenesRefs = false,
                knowledgeCardsRefs = false,
                questionsRefs = false,
                chaptersRefs = false,
                paragraphsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (charactersRefs) db.characters,
                    if (segmentsRefs) db.segments,
                    if (scenesRefs) db.scenes,
                    if (knowledgeCardsRefs) db.knowledgeCards,
                    if (questionsRefs) db.questions,
                    if (chaptersRefs) db.chapters,
                    if (paragraphsRefs) db.paragraphs,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (charactersRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Character
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._charactersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).charactersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (segmentsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Segment
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._segmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).segmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scenesRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Scene
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._scenesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).scenesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (knowledgeCardsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          KnowledgeCard
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._knowledgeCardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).knowledgeCardsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (questionsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Question
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._questionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).questionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (chaptersRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Chapter
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._chaptersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).chaptersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (paragraphsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Paragraph
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._paragraphsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).paragraphsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
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

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, $$ProjectsTableReferences),
      Project,
      PrefetchHooks Function({
        bool charactersRefs,
        bool segmentsRefs,
        bool scenesRefs,
        bool knowledgeCardsRefs,
        bool questionsRefs,
        bool chaptersRefs,
        bool paragraphsRefs,
      })
    >;
typedef $$CharactersTableCreateCompanionBuilder = CharactersCompanion Function({
  Value<int> id,
  required int projectId,
  required String name,
  Value<String> aliasesJson,
  Value<String?> speakerKey,
  Value<double?> confidence,
  Value<String> source,
  Value<String?> color,
});
typedef $$CharactersTableUpdateCompanionBuilder = CharactersCompanion Function({
  Value<int> id,
  Value<int> projectId,
  Value<String> name,
  Value<String> aliasesJson,
  Value<String?> speakerKey,
  Value<double?> confidence,
  Value<String> source,
  Value<String?> color,
});

final class $$CharactersTableReferences
    extends BaseReferences<_$AppDatabase, $CharactersTable, Character> {
  $$CharactersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('characters__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CharactersTableFilterComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speakerKey => $composableBuilder(
    column: $table.speakerKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CharactersTableOrderingComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speakerKey => $composableBuilder(
    column: $table.speakerKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CharactersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get speakerKey => $composableBuilder(
    column: $table.speakerKey,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CharactersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CharactersTable,
          Character,
          $$CharactersTableFilterComposer,
          $$CharactersTableOrderingComposer,
          $$CharactersTableAnnotationComposer,
          $$CharactersTableCreateCompanionBuilder,
          $$CharactersTableUpdateCompanionBuilder,
          (Character, $$CharactersTableReferences),
          Character,
          PrefetchHooks Function({bool projectId})
        > {
  $$CharactersTableTableManager(_$AppDatabase db, $CharactersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharactersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CharactersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CharactersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> aliasesJson = const Value.absent(),
                Value<String?> speakerKey = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> color = const Value.absent(),
              }) => CharactersCompanion(
                id: id,
                projectId: projectId,
                name: name,
                aliasesJson: aliasesJson,
                speakerKey: speakerKey,
                confidence: confidence,
                source: source,
                color: color,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required String name,
                Value<String> aliasesJson = const Value.absent(),
                Value<String?> speakerKey = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> color = const Value.absent(),
              }) => CharactersCompanion.insert(
                id: id,
                projectId: projectId,
                name: name,
                aliasesJson: aliasesJson,
                speakerKey: speakerKey,
                confidence: confidence,
                source: source,
                color: color,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CharactersTable, Character>(table),
                  $$CharactersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
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
                    if (projectId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.projectId,
                        referencedTable: $$CharactersTableReferences
                            ._projectIdTable(db),
                        referencedColumn: $$CharactersTableReferences
                            ._projectIdTable(db)
                            .id,
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

typedef $$CharactersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CharactersTable,
      Character,
      $$CharactersTableFilterComposer,
      $$CharactersTableOrderingComposer,
      $$CharactersTableAnnotationComposer,
      $$CharactersTableCreateCompanionBuilder,
      $$CharactersTableUpdateCompanionBuilder,
      (Character, $$CharactersTableReferences),
      Character,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$SegmentsTableCreateCompanionBuilder = SegmentsCompanion Function({
  Value<int> id,
  required int projectId,
  required int idx,
  required int startMs,
  required int endMs,
  Value<int?> speakerCharId,
  required String content,
});
typedef $$SegmentsTableUpdateCompanionBuilder = SegmentsCompanion Function({
  Value<int> id,
  Value<int> projectId,
  Value<int> idx,
  Value<int> startMs,
  Value<int> endMs,
  Value<int?> speakerCharId,
  Value<String> content,
});

final class $$SegmentsTableReferences
    extends BaseReferences<_$AppDatabase, $SegmentsTable, Segment> {
  $$SegmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('segments__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $SegmentsTable> {
  $$SegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get speakerCharId => $composableBuilder(
    column: $table.speakerCharId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $SegmentsTable> {
  $$SegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get speakerCharId => $composableBuilder(
    column: $table.speakerCharId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SegmentsTable> {
  $$SegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idx =>
      $composableBuilder(column: $table.idx, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<int> get speakerCharId => $composableBuilder(
    column: $table.speakerCharId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SegmentsTable,
          Segment,
          $$SegmentsTableFilterComposer,
          $$SegmentsTableOrderingComposer,
          $$SegmentsTableAnnotationComposer,
          $$SegmentsTableCreateCompanionBuilder,
          $$SegmentsTableUpdateCompanionBuilder,
          (Segment, $$SegmentsTableReferences),
          Segment,
          PrefetchHooks Function({bool projectId})
        > {
  $$SegmentsTableTableManager(_$AppDatabase db, $SegmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<int> idx = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<int?> speakerCharId = const Value.absent(),
                Value<String> content = const Value.absent(),
              }) => SegmentsCompanion(
                id: id,
                projectId: projectId,
                idx: idx,
                startMs: startMs,
                endMs: endMs,
                speakerCharId: speakerCharId,
                content: content,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required int idx,
                required int startMs,
                required int endMs,
                Value<int?> speakerCharId = const Value.absent(),
                required String content,
              }) => SegmentsCompanion.insert(
                id: id,
                projectId: projectId,
                idx: idx,
                startMs: startMs,
                endMs: endMs,
                speakerCharId: speakerCharId,
                content: content,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SegmentsTable, Segment>(table),
                  $$SegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
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
                    if (projectId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.projectId,
                        referencedTable: $$SegmentsTableReferences
                            ._projectIdTable(db),
                        referencedColumn: $$SegmentsTableReferences
                            ._projectIdTable(db)
                            .id,
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

typedef $$SegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SegmentsTable,
      Segment,
      $$SegmentsTableFilterComposer,
      $$SegmentsTableOrderingComposer,
      $$SegmentsTableAnnotationComposer,
      $$SegmentsTableCreateCompanionBuilder,
      $$SegmentsTableUpdateCompanionBuilder,
      (Segment, $$SegmentsTableReferences),
      Segment,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$ScenesTableCreateCompanionBuilder = ScenesCompanion Function({
  Value<int> id,
  required int projectId,
  required int idx,
  required int startMs,
  required int endMs,
  Value<String?> summary,
  Value<String> importance,
});
typedef $$ScenesTableUpdateCompanionBuilder = ScenesCompanion Function({
  Value<int> id,
  Value<int> projectId,
  Value<int> idx,
  Value<int> startMs,
  Value<int> endMs,
  Value<String?> summary,
  Value<String> importance,
});

final class $$ScenesTableReferences
    extends BaseReferences<_$AppDatabase, $ScenesTable, Scene> {
  $$ScenesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('scenes__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CommentariesTable, List<Commentary>>
  _commentariesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.commentaries,
    aliasName: 'scenes__id__commentaries__scene_id',
  );

  $$CommentariesTableProcessedTableManager get commentariesRefs {
    final manager = $$CommentariesTableTableManager(
      $_db,
      $_db.commentaries,
    ).filter((f) => f.sceneId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_commentariesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ScenesTableFilterComposer
    extends Composer<_$AppDatabase, $ScenesTable> {
  $$ScenesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> commentariesRefs(
    Expression<bool> Function($$CommentariesTableFilterComposer f) f,
  ) {
    final $$CommentariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.commentaries,
      getReferencedColumn: (t) => t.sceneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommentariesTableFilterComposer(
            $db: $db,
            $table: $db.commentaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ScenesTableOrderingComposer
    extends Composer<_$AppDatabase, $ScenesTable> {
  $$ScenesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScenesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScenesTable> {
  $$ScenesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idx =>
      $composableBuilder(column: $table.idx, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> commentariesRefs<T extends Object>(
    Expression<T> Function($$CommentariesTableAnnotationComposer a) f,
  ) {
    final $$CommentariesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.commentaries,
      getReferencedColumn: (t) => t.sceneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CommentariesTableAnnotationComposer(
            $db: $db,
            $table: $db.commentaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ScenesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScenesTable,
          Scene,
          $$ScenesTableFilterComposer,
          $$ScenesTableOrderingComposer,
          $$ScenesTableAnnotationComposer,
          $$ScenesTableCreateCompanionBuilder,
          $$ScenesTableUpdateCompanionBuilder,
          (Scene, $$ScenesTableReferences),
          Scene,
          PrefetchHooks Function({bool projectId, bool commentariesRefs})
        > {
  $$ScenesTableTableManager(_$AppDatabase db, $ScenesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScenesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScenesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScenesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<int> idx = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String> importance = const Value.absent(),
              }) => ScenesCompanion(
                id: id,
                projectId: projectId,
                idx: idx,
                startMs: startMs,
                endMs: endMs,
                summary: summary,
                importance: importance,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required int idx,
                required int startMs,
                required int endMs,
                Value<String?> summary = const Value.absent(),
                Value<String> importance = const Value.absent(),
              }) => ScenesCompanion.insert(
                id: id,
                projectId: projectId,
                idx: idx,
                startMs: startMs,
                endMs: endMs,
                summary: summary,
                importance: importance,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScenesTable, Scene>(table),
                  $$ScenesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({projectId = false, commentariesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (commentariesRefs) db.commentaries,
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
                        if (projectId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.projectId,
                            referencedTable: $$ScenesTableReferences
                                ._projectIdTable(db),
                            referencedColumn: $$ScenesTableReferences
                                ._projectIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (commentariesRefs)
                        await $_getPrefetchedData<
                          Scene,
                          $ScenesTable,
                          Commentary
                        >(
                          currentTable: table,
                          referencedTable: $$ScenesTableReferences
                              ._commentariesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScenesTableReferences(
                                db,
                                table,
                                p0,
                              ).commentariesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sceneId == item.id,
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

typedef $$ScenesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScenesTable,
      Scene,
      $$ScenesTableFilterComposer,
      $$ScenesTableOrderingComposer,
      $$ScenesTableAnnotationComposer,
      $$ScenesTableCreateCompanionBuilder,
      $$ScenesTableUpdateCompanionBuilder,
      (Scene, $$ScenesTableReferences),
      Scene,
      PrefetchHooks Function({bool projectId, bool commentariesRefs})
    >;
typedef $$CommentariesTableCreateCompanionBuilder =
    CommentariesCompanion Function({
      Value<int> id,
      required int sceneId,
      required String l1Subtext,
      Value<String?> l2PsychologyJson,
      Value<String> status,
      required String model,
      Value<DateTime> createdAt,
    });
typedef $$CommentariesTableUpdateCompanionBuilder =
    CommentariesCompanion Function({
      Value<int> id,
      Value<int> sceneId,
      Value<String> l1Subtext,
      Value<String?> l2PsychologyJson,
      Value<String> status,
      Value<String> model,
      Value<DateTime> createdAt,
    });

final class $$CommentariesTableReferences
    extends BaseReferences<_$AppDatabase, $CommentariesTable, Commentary> {
  $$CommentariesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ScenesTable _sceneIdTable(_$AppDatabase db) =>
      db.scenes.createAlias('commentaries__scene_id__scenes__id');

  $$ScenesTableProcessedTableManager get sceneId {
    final $_column = $_itemColumn<int>('scene_id')!;

    final manager = $$ScenesTableTableManager(
      $_db,
      $_db.scenes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sceneIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CommentariesTableFilterComposer
    extends Composer<_$AppDatabase, $CommentariesTable> {
  $$CommentariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get l1Subtext => $composableBuilder(
    column: $table.l1Subtext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get l2PsychologyJson => $composableBuilder(
    column: $table.l2PsychologyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ScenesTableFilterComposer get sceneId {
    final $$ScenesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sceneId,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableFilterComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CommentariesTableOrderingComposer
    extends Composer<_$AppDatabase, $CommentariesTable> {
  $$CommentariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get l1Subtext => $composableBuilder(
    column: $table.l1Subtext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get l2PsychologyJson => $composableBuilder(
    column: $table.l2PsychologyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ScenesTableOrderingComposer get sceneId {
    final $$ScenesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sceneId,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableOrderingComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CommentariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CommentariesTable> {
  $$CommentariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get l1Subtext =>
      $composableBuilder(column: $table.l1Subtext, builder: (column) => column);

  GeneratedColumn<String> get l2PsychologyJson => $composableBuilder(
    column: $table.l2PsychologyJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ScenesTableAnnotationComposer get sceneId {
    final $$ScenesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sceneId,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableAnnotationComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CommentariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CommentariesTable,
          Commentary,
          $$CommentariesTableFilterComposer,
          $$CommentariesTableOrderingComposer,
          $$CommentariesTableAnnotationComposer,
          $$CommentariesTableCreateCompanionBuilder,
          $$CommentariesTableUpdateCompanionBuilder,
          (Commentary, $$CommentariesTableReferences),
          Commentary,
          PrefetchHooks Function({bool sceneId})
        > {
  $$CommentariesTableTableManager(_$AppDatabase db, $CommentariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CommentariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CommentariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CommentariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sceneId = const Value.absent(),
                Value<String> l1Subtext = const Value.absent(),
                Value<String?> l2PsychologyJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CommentariesCompanion(
                id: id,
                sceneId: sceneId,
                l1Subtext: l1Subtext,
                l2PsychologyJson: l2PsychologyJson,
                status: status,
                model: model,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sceneId,
                required String l1Subtext,
                Value<String?> l2PsychologyJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                required String model,
                Value<DateTime> createdAt = const Value.absent(),
              }) => CommentariesCompanion.insert(
                id: id,
                sceneId: sceneId,
                l1Subtext: l1Subtext,
                l2PsychologyJson: l2PsychologyJson,
                status: status,
                model: model,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CommentariesTable, Commentary>(table),
                  $$CommentariesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sceneId = false}) {
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
                    if (sceneId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sceneId,
                        referencedTable: $$CommentariesTableReferences
                            ._sceneIdTable(db),
                        referencedColumn: $$CommentariesTableReferences
                            ._sceneIdTable(db)
                            .id,
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

typedef $$CommentariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CommentariesTable,
      Commentary,
      $$CommentariesTableFilterComposer,
      $$CommentariesTableOrderingComposer,
      $$CommentariesTableAnnotationComposer,
      $$CommentariesTableCreateCompanionBuilder,
      $$CommentariesTableUpdateCompanionBuilder,
      (Commentary, $$CommentariesTableReferences),
      Commentary,
      PrefetchHooks Function({bool sceneId})
    >;
typedef $$KnowledgeCardsTableCreateCompanionBuilder =
    KnowledgeCardsCompanion Function({
      Value<int> id,
      required int projectId,
      required String term,
      required String title,
      required String content,
      Value<int?> firstSceneIdx,
      Value<bool> uncertain,
      Value<DateTime?> dueAt,
      Value<double> ivlDays,
      Value<double> ease,
      Value<int> reps,
      Value<int> lapses,
      Value<DateTime?> lastReviewAt,
    });
typedef $$KnowledgeCardsTableUpdateCompanionBuilder =
    KnowledgeCardsCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<String> term,
      Value<String> title,
      Value<String> content,
      Value<int?> firstSceneIdx,
      Value<bool> uncertain,
      Value<DateTime?> dueAt,
      Value<double> ivlDays,
      Value<double> ease,
      Value<int> reps,
      Value<int> lapses,
      Value<DateTime?> lastReviewAt,
    });

final class $$KnowledgeCardsTableReferences
    extends BaseReferences<_$AppDatabase, $KnowledgeCardsTable, KnowledgeCard> {
  $$KnowledgeCardsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('knowledge_cards__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$KnowledgeCardsTableFilterComposer
    extends Composer<_$AppDatabase, $KnowledgeCardsTable> {
  $$KnowledgeCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get term => $composableBuilder(
    column: $table.term,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstSceneIdx => $composableBuilder(
    column: $table.firstSceneIdx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get uncertain => $composableBuilder(
    column: $table.uncertain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ivlDays => $composableBuilder(
    column: $table.ivlDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ease => $composableBuilder(
    column: $table.ease,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReviewAt => $composableBuilder(
    column: $table.lastReviewAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KnowledgeCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $KnowledgeCardsTable> {
  $$KnowledgeCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get term => $composableBuilder(
    column: $table.term,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstSceneIdx => $composableBuilder(
    column: $table.firstSceneIdx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get uncertain => $composableBuilder(
    column: $table.uncertain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ivlDays => $composableBuilder(
    column: $table.ivlDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ease => $composableBuilder(
    column: $table.ease,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReviewAt => $composableBuilder(
    column: $table.lastReviewAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KnowledgeCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $KnowledgeCardsTable> {
  $$KnowledgeCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get term =>
      $composableBuilder(column: $table.term, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get firstSceneIdx => $composableBuilder(
    column: $table.firstSceneIdx,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get uncertain =>
      $composableBuilder(column: $table.uncertain, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<double> get ivlDays =>
      $composableBuilder(column: $table.ivlDays, builder: (column) => column);

  GeneratedColumn<double> get ease =>
      $composableBuilder(column: $table.ease, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReviewAt => $composableBuilder(
    column: $table.lastReviewAt,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KnowledgeCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KnowledgeCardsTable,
          KnowledgeCard,
          $$KnowledgeCardsTableFilterComposer,
          $$KnowledgeCardsTableOrderingComposer,
          $$KnowledgeCardsTableAnnotationComposer,
          $$KnowledgeCardsTableCreateCompanionBuilder,
          $$KnowledgeCardsTableUpdateCompanionBuilder,
          (KnowledgeCard, $$KnowledgeCardsTableReferences),
          KnowledgeCard,
          PrefetchHooks Function({bool projectId})
        > {
  $$KnowledgeCardsTableTableManager(
    _$AppDatabase db,
    $KnowledgeCardsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KnowledgeCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KnowledgeCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KnowledgeCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<String> term = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int?> firstSceneIdx = const Value.absent(),
                Value<bool> uncertain = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<double> ivlDays = const Value.absent(),
                Value<double> ease = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<DateTime?> lastReviewAt = const Value.absent(),
              }) => KnowledgeCardsCompanion(
                id: id,
                projectId: projectId,
                term: term,
                title: title,
                content: content,
                firstSceneIdx: firstSceneIdx,
                uncertain: uncertain,
                dueAt: dueAt,
                ivlDays: ivlDays,
                ease: ease,
                reps: reps,
                lapses: lapses,
                lastReviewAt: lastReviewAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required String term,
                required String title,
                required String content,
                Value<int?> firstSceneIdx = const Value.absent(),
                Value<bool> uncertain = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<double> ivlDays = const Value.absent(),
                Value<double> ease = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<DateTime?> lastReviewAt = const Value.absent(),
              }) => KnowledgeCardsCompanion.insert(
                id: id,
                projectId: projectId,
                term: term,
                title: title,
                content: content,
                firstSceneIdx: firstSceneIdx,
                uncertain: uncertain,
                dueAt: dueAt,
                ivlDays: ivlDays,
                ease: ease,
                reps: reps,
                lapses: lapses,
                lastReviewAt: lastReviewAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KnowledgeCardsTable, KnowledgeCard>(table),
                  $$KnowledgeCardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
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
                    if (projectId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.projectId,
                        referencedTable: $$KnowledgeCardsTableReferences
                            ._projectIdTable(db),
                        referencedColumn: $$KnowledgeCardsTableReferences
                            ._projectIdTable(db)
                            .id,
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

typedef $$KnowledgeCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KnowledgeCardsTable,
      KnowledgeCard,
      $$KnowledgeCardsTableFilterComposer,
      $$KnowledgeCardsTableOrderingComposer,
      $$KnowledgeCardsTableAnnotationComposer,
      $$KnowledgeCardsTableCreateCompanionBuilder,
      $$KnowledgeCardsTableUpdateCompanionBuilder,
      (KnowledgeCard, $$KnowledgeCardsTableReferences),
      KnowledgeCard,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$QuestionsTableCreateCompanionBuilder = QuestionsCompanion Function({
  Value<int> id,
  required int projectId,
  Value<int?> sceneId,
  required String question,
  Value<String> perspectivesJson,
});
typedef $$QuestionsTableUpdateCompanionBuilder = QuestionsCompanion Function({
  Value<int> id,
  Value<int> projectId,
  Value<int?> sceneId,
  Value<String> question,
  Value<String> perspectivesJson,
});

final class $$QuestionsTableReferences
    extends BaseReferences<_$AppDatabase, $QuestionsTable, Question> {
  $$QuestionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('questions__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$QaRecordsTable, List<QaRecord>>
  _qaRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.qaRecords,
    aliasName: 'questions__id__qa_records__question_id',
  );

  $$QaRecordsTableProcessedTableManager get qaRecordsRefs {
    final manager = $$QaRecordsTableTableManager(
      $_db,
      $_db.qaRecords,
    ).filter((f) => f.questionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_qaRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$QuestionsTableFilterComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sceneId => $composableBuilder(
    column: $table.sceneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get perspectivesJson => $composableBuilder(
    column: $table.perspectivesJson,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> qaRecordsRefs(
    Expression<bool> Function($$QaRecordsTableFilterComposer f) f,
  ) {
    final $$QaRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.qaRecords,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QaRecordsTableFilterComposer(
            $db: $db,
            $table: $db.qaRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$QuestionsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sceneId => $composableBuilder(
    column: $table.sceneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get perspectivesJson => $composableBuilder(
    column: $table.perspectivesJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuestionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sceneId =>
      $composableBuilder(column: $table.sceneId, builder: (column) => column);

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get perspectivesJson => $composableBuilder(
    column: $table.perspectivesJson,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> qaRecordsRefs<T extends Object>(
    Expression<T> Function($$QaRecordsTableAnnotationComposer a) f,
  ) {
    final $$QaRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.qaRecords,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QaRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.qaRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$QuestionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuestionsTable,
          Question,
          $$QuestionsTableFilterComposer,
          $$QuestionsTableOrderingComposer,
          $$QuestionsTableAnnotationComposer,
          $$QuestionsTableCreateCompanionBuilder,
          $$QuestionsTableUpdateCompanionBuilder,
          (Question, $$QuestionsTableReferences),
          Question,
          PrefetchHooks Function({bool projectId, bool qaRecordsRefs})
        > {
  $$QuestionsTableTableManager(_$AppDatabase db, $QuestionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<int?> sceneId = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String> perspectivesJson = const Value.absent(),
              }) => QuestionsCompanion(
                id: id,
                projectId: projectId,
                sceneId: sceneId,
                question: question,
                perspectivesJson: perspectivesJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                Value<int?> sceneId = const Value.absent(),
                required String question,
                Value<String> perspectivesJson = const Value.absent(),
              }) => QuestionsCompanion.insert(
                id: id,
                projectId: projectId,
                sceneId: sceneId,
                question: question,
                perspectivesJson: perspectivesJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QuestionsTable, Question>(table),
                  $$QuestionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false, qaRecordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (qaRecordsRefs) db.qaRecords],
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
                    if (projectId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.projectId,
                        referencedTable: $$QuestionsTableReferences
                            ._projectIdTable(db),
                        referencedColumn: $$QuestionsTableReferences
                            ._projectIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (qaRecordsRefs)
                    await $_getPrefetchedData<
                      Question,
                      $QuestionsTable,
                      QaRecord
                    >(
                      currentTable: table,
                      referencedTable: $$QuestionsTableReferences
                          ._qaRecordsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$QuestionsTableReferences(
                            db,
                            table,
                            p0,
                          ).qaRecordsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.questionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$QuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuestionsTable,
      Question,
      $$QuestionsTableFilterComposer,
      $$QuestionsTableOrderingComposer,
      $$QuestionsTableAnnotationComposer,
      $$QuestionsTableCreateCompanionBuilder,
      $$QuestionsTableUpdateCompanionBuilder,
      (Question, $$QuestionsTableReferences),
      Question,
      PrefetchHooks Function({bool projectId, bool qaRecordsRefs})
    >;
typedef $$QaRecordsTableCreateCompanionBuilder = QaRecordsCompanion Function({
  Value<int> id,
  required int questionId,
  required String userAnswer,
  Value<DateTime> answeredAt,
  Value<bool> skipped,
});
typedef $$QaRecordsTableUpdateCompanionBuilder = QaRecordsCompanion Function({
  Value<int> id,
  Value<int> questionId,
  Value<String> userAnswer,
  Value<DateTime> answeredAt,
  Value<bool> skipped,
});

final class $$QaRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $QaRecordsTable, QaRecord> {
  $$QaRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $QuestionsTable _questionIdTable(_$AppDatabase db) =>
      db.questions.createAlias('qa_records__question_id__questions__id');

  $$QuestionsTableProcessedTableManager get questionId {
    final $_column = $_itemColumn<int>('question_id')!;

    final manager = $$QuestionsTableTableManager(
      $_db,
      $_db.questions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_questionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$QaRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $QaRecordsTable> {
  $$QaRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userAnswer => $composableBuilder(
    column: $table.userAnswer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get skipped => $composableBuilder(
    column: $table.skipped,
    builder: (column) => ColumnFilters(column),
  );

  $$QuestionsTableFilterComposer get questionId {
    final $$QuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableFilterComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QaRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $QaRecordsTable> {
  $$QaRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userAnswer => $composableBuilder(
    column: $table.userAnswer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get skipped => $composableBuilder(
    column: $table.skipped,
    builder: (column) => ColumnOrderings(column),
  );

  $$QuestionsTableOrderingComposer get questionId {
    final $$QuestionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableOrderingComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QaRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QaRecordsTable> {
  $$QaRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userAnswer => $composableBuilder(
    column: $table.userAnswer,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get skipped =>
      $composableBuilder(column: $table.skipped, builder: (column) => column);

  $$QuestionsTableAnnotationComposer get questionId {
    final $$QuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QaRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QaRecordsTable,
          QaRecord,
          $$QaRecordsTableFilterComposer,
          $$QaRecordsTableOrderingComposer,
          $$QaRecordsTableAnnotationComposer,
          $$QaRecordsTableCreateCompanionBuilder,
          $$QaRecordsTableUpdateCompanionBuilder,
          (QaRecord, $$QaRecordsTableReferences),
          QaRecord,
          PrefetchHooks Function({bool questionId})
        > {
  $$QaRecordsTableTableManager(_$AppDatabase db, $QaRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QaRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QaRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QaRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> questionId = const Value.absent(),
                Value<String> userAnswer = const Value.absent(),
                Value<DateTime> answeredAt = const Value.absent(),
                Value<bool> skipped = const Value.absent(),
              }) => QaRecordsCompanion(
                id: id,
                questionId: questionId,
                userAnswer: userAnswer,
                answeredAt: answeredAt,
                skipped: skipped,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int questionId,
                required String userAnswer,
                Value<DateTime> answeredAt = const Value.absent(),
                Value<bool> skipped = const Value.absent(),
              }) => QaRecordsCompanion.insert(
                id: id,
                questionId: questionId,
                userAnswer: userAnswer,
                answeredAt: answeredAt,
                skipped: skipped,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QaRecordsTable, QaRecord>(table),
                  $$QaRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({questionId = false}) {
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
                    if (questionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.questionId,
                        referencedTable: $$QaRecordsTableReferences
                            ._questionIdTable(db),
                        referencedColumn: $$QaRecordsTableReferences
                            ._questionIdTable(db)
                            .id,
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

typedef $$QaRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QaRecordsTable,
      QaRecord,
      $$QaRecordsTableFilterComposer,
      $$QaRecordsTableOrderingComposer,
      $$QaRecordsTableAnnotationComposer,
      $$QaRecordsTableCreateCompanionBuilder,
      $$QaRecordsTableUpdateCompanionBuilder,
      (QaRecord, $$QaRecordsTableReferences),
      QaRecord,
      PrefetchHooks Function({bool questionId})
    >;
typedef $$ChaptersTableCreateCompanionBuilder = ChaptersCompanion Function({
  Value<int> id,
  required int projectId,
  required int idx,
  Value<String?> title,
  required int startPara,
  required int endPara,
  Value<String?> summary,
});
typedef $$ChaptersTableUpdateCompanionBuilder = ChaptersCompanion Function({
  Value<int> id,
  Value<int> projectId,
  Value<int> idx,
  Value<String?> title,
  Value<int> startPara,
  Value<int> endPara,
  Value<String?> summary,
});

final class $$ChaptersTableReferences
    extends BaseReferences<_$AppDatabase, $ChaptersTable, Chapter> {
  $$ChaptersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('chapters__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startPara => $composableBuilder(
    column: $table.startPara,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endPara => $composableBuilder(
    column: $table.endPara,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startPara => $composableBuilder(
    column: $table.startPara,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endPara => $composableBuilder(
    column: $table.endPara,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get idx =>
      $composableBuilder(column: $table.idx, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get startPara =>
      $composableBuilder(column: $table.startPara, builder: (column) => column);

  GeneratedColumn<int> get endPara =>
      $composableBuilder(column: $table.endPara, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChaptersTable,
          Chapter,
          $$ChaptersTableFilterComposer,
          $$ChaptersTableOrderingComposer,
          $$ChaptersTableAnnotationComposer,
          $$ChaptersTableCreateCompanionBuilder,
          $$ChaptersTableUpdateCompanionBuilder,
          (Chapter, $$ChaptersTableReferences),
          Chapter,
          PrefetchHooks Function({bool projectId})
        > {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<int> idx = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int> startPara = const Value.absent(),
                Value<int> endPara = const Value.absent(),
                Value<String?> summary = const Value.absent(),
              }) => ChaptersCompanion(
                id: id,
                projectId: projectId,
                idx: idx,
                title: title,
                startPara: startPara,
                endPara: endPara,
                summary: summary,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required int idx,
                Value<String?> title = const Value.absent(),
                required int startPara,
                required int endPara,
                Value<String?> summary = const Value.absent(),
              }) => ChaptersCompanion.insert(
                id: id,
                projectId: projectId,
                idx: idx,
                title: title,
                startPara: startPara,
                endPara: endPara,
                summary: summary,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChaptersTable, Chapter>(table),
                  $$ChaptersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
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
                    if (projectId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.projectId,
                        referencedTable: $$ChaptersTableReferences
                            ._projectIdTable(db),
                        referencedColumn: $$ChaptersTableReferences
                            ._projectIdTable(db)
                            .id,
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

typedef $$ChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChaptersTable,
      Chapter,
      $$ChaptersTableFilterComposer,
      $$ChaptersTableOrderingComposer,
      $$ChaptersTableAnnotationComposer,
      $$ChaptersTableCreateCompanionBuilder,
      $$ChaptersTableUpdateCompanionBuilder,
      (Chapter, $$ChaptersTableReferences),
      Chapter,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$ParagraphsTableCreateCompanionBuilder = ParagraphsCompanion Function({
  Value<int> id,
  required int projectId,
  Value<int?> chapterId,
  required int idx,
  required String content,
});
typedef $$ParagraphsTableUpdateCompanionBuilder = ParagraphsCompanion Function({
  Value<int> id,
  Value<int> projectId,
  Value<int?> chapterId,
  Value<int> idx,
  Value<String> content,
});

final class $$ParagraphsTableReferences
    extends BaseReferences<_$AppDatabase, $ParagraphsTable, Paragraph> {
  $$ParagraphsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('paragraphs__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<int>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AnnotationsTable, List<Annotation>>
  _annotationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.annotations,
    aliasName: 'paragraphs__id__annotations__para_id',
  );

  $$AnnotationsTableProcessedTableManager get annotationsRefs {
    final manager = $$AnnotationsTableTableManager(
      $_db,
      $_db.annotations,
    ).filter((f) => f.paraId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_annotationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ParagraphsTableFilterComposer
    extends Composer<_$AppDatabase, $ParagraphsTable> {
  $$ParagraphsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> annotationsRefs(
    Expression<bool> Function($$AnnotationsTableFilterComposer f) f,
  ) {
    final $$AnnotationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.annotations,
      getReferencedColumn: (t) => t.paraId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnnotationsTableFilterComposer(
            $db: $db,
            $table: $db.annotations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ParagraphsTableOrderingComposer
    extends Composer<_$AppDatabase, $ParagraphsTable> {
  $$ParagraphsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ParagraphsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParagraphsTable> {
  $$ParagraphsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get idx =>
      $composableBuilder(column: $table.idx, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> annotationsRefs<T extends Object>(
    Expression<T> Function($$AnnotationsTableAnnotationComposer a) f,
  ) {
    final $$AnnotationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.annotations,
      getReferencedColumn: (t) => t.paraId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnnotationsTableAnnotationComposer(
            $db: $db,
            $table: $db.annotations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ParagraphsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParagraphsTable,
          Paragraph,
          $$ParagraphsTableFilterComposer,
          $$ParagraphsTableOrderingComposer,
          $$ParagraphsTableAnnotationComposer,
          $$ParagraphsTableCreateCompanionBuilder,
          $$ParagraphsTableUpdateCompanionBuilder,
          (Paragraph, $$ParagraphsTableReferences),
          Paragraph,
          PrefetchHooks Function({bool projectId, bool annotationsRefs})
        > {
  $$ParagraphsTableTableManager(_$AppDatabase db, $ParagraphsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParagraphsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParagraphsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParagraphsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<int?> chapterId = const Value.absent(),
                Value<int> idx = const Value.absent(),
                Value<String> content = const Value.absent(),
              }) => ParagraphsCompanion(
                id: id,
                projectId: projectId,
                chapterId: chapterId,
                idx: idx,
                content: content,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                Value<int?> chapterId = const Value.absent(),
                required int idx,
                required String content,
              }) => ParagraphsCompanion.insert(
                id: id,
                projectId: projectId,
                chapterId: chapterId,
                idx: idx,
                content: content,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ParagraphsTable, Paragraph>(table),
                  $$ParagraphsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({projectId = false, annotationsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (annotationsRefs) db.annotations,
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
                        if (projectId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.projectId,
                            referencedTable: $$ParagraphsTableReferences
                                ._projectIdTable(db),
                            referencedColumn: $$ParagraphsTableReferences
                                ._projectIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (annotationsRefs)
                        await $_getPrefetchedData<
                          Paragraph,
                          $ParagraphsTable,
                          Annotation
                        >(
                          currentTable: table,
                          referencedTable: $$ParagraphsTableReferences
                              ._annotationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ParagraphsTableReferences(
                                db,
                                table,
                                p0,
                              ).annotationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.paraId == item.id,
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

typedef $$ParagraphsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParagraphsTable,
      Paragraph,
      $$ParagraphsTableFilterComposer,
      $$ParagraphsTableOrderingComposer,
      $$ParagraphsTableAnnotationComposer,
      $$ParagraphsTableCreateCompanionBuilder,
      $$ParagraphsTableUpdateCompanionBuilder,
      (Paragraph, $$ParagraphsTableReferences),
      Paragraph,
      PrefetchHooks Function({bool projectId, bool annotationsRefs})
    >;
typedef $$AnnotationsTableCreateCompanionBuilder =
    AnnotationsCompanion Function({
      Value<int> id,
      required int paraId,
      required String type,
      required String contentJson,
    });
typedef $$AnnotationsTableUpdateCompanionBuilder =
    AnnotationsCompanion Function({
      Value<int> id,
      Value<int> paraId,
      Value<String> type,
      Value<String> contentJson,
    });

final class $$AnnotationsTableReferences
    extends BaseReferences<_$AppDatabase, $AnnotationsTable, Annotation> {
  $$AnnotationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ParagraphsTable _paraIdTable(_$AppDatabase db) =>
      db.paragraphs.createAlias('annotations__para_id__paragraphs__id');

  $$ParagraphsTableProcessedTableManager get paraId {
    final $_column = $_itemColumn<int>('para_id')!;

    final manager = $$ParagraphsTableTableManager(
      $_db,
      $_db.paragraphs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_paraIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AnnotationsTableFilterComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => ColumnFilters(column),
  );

  $$ParagraphsTableFilterComposer get paraId {
    final $$ParagraphsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paraId,
      referencedTable: $db.paragraphs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParagraphsTableFilterComposer(
            $db: $db,
            $table: $db.paragraphs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnnotationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$ParagraphsTableOrderingComposer get paraId {
    final $$ParagraphsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paraId,
      referencedTable: $db.paragraphs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParagraphsTableOrderingComposer(
            $db: $db,
            $table: $db.paragraphs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnnotationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => column,
  );

  $$ParagraphsTableAnnotationComposer get paraId {
    final $$ParagraphsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paraId,
      referencedTable: $db.paragraphs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParagraphsTableAnnotationComposer(
            $db: $db,
            $table: $db.paragraphs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnnotationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnnotationsTable,
          Annotation,
          $$AnnotationsTableFilterComposer,
          $$AnnotationsTableOrderingComposer,
          $$AnnotationsTableAnnotationComposer,
          $$AnnotationsTableCreateCompanionBuilder,
          $$AnnotationsTableUpdateCompanionBuilder,
          (Annotation, $$AnnotationsTableReferences),
          Annotation,
          PrefetchHooks Function({bool paraId})
        > {
  $$AnnotationsTableTableManager(_$AppDatabase db, $AnnotationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnnotationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnnotationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnnotationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> paraId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> contentJson = const Value.absent(),
              }) => AnnotationsCompanion(
                id: id,
                paraId: paraId,
                type: type,
                contentJson: contentJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int paraId,
                required String type,
                required String contentJson,
              }) => AnnotationsCompanion.insert(
                id: id,
                paraId: paraId,
                type: type,
                contentJson: contentJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AnnotationsTable, Annotation>(table),
                  $$AnnotationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({paraId = false}) {
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
                    if (paraId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.paraId,
                        referencedTable: $$AnnotationsTableReferences
                            ._paraIdTable(db),
                        referencedColumn: $$AnnotationsTableReferences
                            ._paraIdTable(db)
                            .id,
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

typedef $$AnnotationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnnotationsTable,
      Annotation,
      $$AnnotationsTableFilterComposer,
      $$AnnotationsTableOrderingComposer,
      $$AnnotationsTableAnnotationComposer,
      $$AnnotationsTableCreateCompanionBuilder,
      $$AnnotationsTableUpdateCompanionBuilder,
      (Annotation, $$AnnotationsTableReferences),
      Annotation,
      PrefetchHooks Function({bool paraId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
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

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
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

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$LlmLogsTableCreateCompanionBuilder = LlmLogsCompanion Function({
  Value<int> id,
  Value<int?> projectId,
  required String purpose,
  required String model,
  Value<int> promptTokens,
  Value<int> completionTokens,
  Value<DateTime> createdAt,
});
typedef $$LlmLogsTableUpdateCompanionBuilder = LlmLogsCompanion Function({
  Value<int> id,
  Value<int?> projectId,
  Value<String> purpose,
  Value<String> model,
  Value<int> promptTokens,
  Value<int> completionTokens,
  Value<DateTime> createdAt,
});

class $$LlmLogsTableFilterComposer
    extends Composer<_$AppDatabase, $LlmLogsTable> {
  $$LlmLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LlmLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $LlmLogsTable> {
  $$LlmLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LlmLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LlmLogsTable> {
  $$LlmLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get purpose =>
      $composableBuilder(column: $table.purpose, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get promptTokens => $composableBuilder(
    column: $table.promptTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completionTokens => $composableBuilder(
    column: $table.completionTokens,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LlmLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LlmLogsTable,
          LlmLog,
          $$LlmLogsTableFilterComposer,
          $$LlmLogsTableOrderingComposer,
          $$LlmLogsTableAnnotationComposer,
          $$LlmLogsTableCreateCompanionBuilder,
          $$LlmLogsTableUpdateCompanionBuilder,
          (LlmLog, BaseReferences<_$AppDatabase, $LlmLogsTable, LlmLog>),
          LlmLog,
          PrefetchHooks Function()
        > {
  $$LlmLogsTableTableManager(_$AppDatabase db, $LlmLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LlmLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LlmLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LlmLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> projectId = const Value.absent(),
                Value<String> purpose = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int> promptTokens = const Value.absent(),
                Value<int> completionTokens = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LlmLogsCompanion(
                id: id,
                projectId: projectId,
                purpose: purpose,
                model: model,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> projectId = const Value.absent(),
                required String purpose,
                required String model,
                Value<int> promptTokens = const Value.absent(),
                Value<int> completionTokens = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LlmLogsCompanion.insert(
                id: id,
                projectId: projectId,
                purpose: purpose,
                model: model,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LlmLogsTable, LlmLog>(table),
                  BaseReferences<_$AppDatabase, $LlmLogsTable, LlmLog>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LlmLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LlmLogsTable,
      LlmLog,
      $$LlmLogsTableFilterComposer,
      $$LlmLogsTableOrderingComposer,
      $$LlmLogsTableAnnotationComposer,
      $$LlmLogsTableCreateCompanionBuilder,
      $$LlmLogsTableUpdateCompanionBuilder,
      (LlmLog, BaseReferences<_$AppDatabase, $LlmLogsTable, LlmLog>),
      LlmLog,
      PrefetchHooks Function()
    >;
typedef $$LlmCacheTableCreateCompanionBuilder = LlmCacheCompanion Function({
  required String key,
  required String response,
  required String model,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$LlmCacheTableUpdateCompanionBuilder = LlmCacheCompanion Function({
  Value<String> key,
  Value<String> response,
  Value<String> model,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$LlmCacheTableFilterComposer
    extends Composer<_$AppDatabase, $LlmCacheTable> {
  $$LlmCacheTableFilterComposer({
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

  ColumnFilters<String> get response => $composableBuilder(
    column: $table.response,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LlmCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $LlmCacheTable> {
  $$LlmCacheTableOrderingComposer({
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

  ColumnOrderings<String> get response => $composableBuilder(
    column: $table.response,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LlmCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $LlmCacheTable> {
  $$LlmCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get response =>
      $composableBuilder(column: $table.response, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LlmCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LlmCacheTable,
          LlmCacheData,
          $$LlmCacheTableFilterComposer,
          $$LlmCacheTableOrderingComposer,
          $$LlmCacheTableAnnotationComposer,
          $$LlmCacheTableCreateCompanionBuilder,
          $$LlmCacheTableUpdateCompanionBuilder,
          (
            LlmCacheData,
            BaseReferences<_$AppDatabase, $LlmCacheTable, LlmCacheData>,
          ),
          LlmCacheData,
          PrefetchHooks Function()
        > {
  $$LlmCacheTableTableManager(_$AppDatabase db, $LlmCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LlmCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LlmCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LlmCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> response = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LlmCacheCompanion(
                key: key,
                response: response,
                model: model,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String response,
                required String model,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LlmCacheCompanion.insert(
                key: key,
                response: response,
                model: model,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LlmCacheTable, LlmCacheData>(table),
                  BaseReferences<_$AppDatabase, $LlmCacheTable, LlmCacheData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LlmCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LlmCacheTable,
      LlmCacheData,
      $$LlmCacheTableFilterComposer,
      $$LlmCacheTableOrderingComposer,
      $$LlmCacheTableAnnotationComposer,
      $$LlmCacheTableCreateCompanionBuilder,
      $$LlmCacheTableUpdateCompanionBuilder,
      (
        LlmCacheData,
        BaseReferences<_$AppDatabase, $LlmCacheTable, LlmCacheData>,
      ),
      LlmCacheData,
      PrefetchHooks Function()
    >;
typedef $$LlmChannelsTableCreateCompanionBuilder =
    LlmChannelsCompanion Function({
      Value<int> id,
      required String name,
      required String baseUrl,
      Value<bool> enabled,
      Value<DateTime> createdAt,
    });
typedef $$LlmChannelsTableUpdateCompanionBuilder =
    LlmChannelsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> baseUrl,
      Value<bool> enabled,
      Value<DateTime> createdAt,
    });

class $$LlmChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $LlmChannelsTable> {
  $$LlmChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LlmChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $LlmChannelsTable> {
  $$LlmChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LlmChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LlmChannelsTable> {
  $$LlmChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LlmChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LlmChannelsTable,
          LlmChannel,
          $$LlmChannelsTableFilterComposer,
          $$LlmChannelsTableOrderingComposer,
          $$LlmChannelsTableAnnotationComposer,
          $$LlmChannelsTableCreateCompanionBuilder,
          $$LlmChannelsTableUpdateCompanionBuilder,
          (
            LlmChannel,
            BaseReferences<_$AppDatabase, $LlmChannelsTable, LlmChannel>,
          ),
          LlmChannel,
          PrefetchHooks Function()
        > {
  $$LlmChannelsTableTableManager(_$AppDatabase db, $LlmChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LlmChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LlmChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LlmChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LlmChannelsCompanion(
                id: id,
                name: name,
                baseUrl: baseUrl,
                enabled: enabled,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String baseUrl,
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LlmChannelsCompanion.insert(
                id: id,
                name: name,
                baseUrl: baseUrl,
                enabled: enabled,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LlmChannelsTable, LlmChannel>(table),
                  BaseReferences<_$AppDatabase, $LlmChannelsTable, LlmChannel>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LlmChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LlmChannelsTable,
      LlmChannel,
      $$LlmChannelsTableFilterComposer,
      $$LlmChannelsTableOrderingComposer,
      $$LlmChannelsTableAnnotationComposer,
      $$LlmChannelsTableCreateCompanionBuilder,
      $$LlmChannelsTableUpdateCompanionBuilder,
      (
        LlmChannel,
        BaseReferences<_$AppDatabase, $LlmChannelsTable, LlmChannel>,
      ),
      LlmChannel,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$CharactersTableTableManager get characters =>
      $$CharactersTableTableManager(_db, _db.characters);
  $$SegmentsTableTableManager get segments =>
      $$SegmentsTableTableManager(_db, _db.segments);
  $$ScenesTableTableManager get scenes =>
      $$ScenesTableTableManager(_db, _db.scenes);
  $$CommentariesTableTableManager get commentaries =>
      $$CommentariesTableTableManager(_db, _db.commentaries);
  $$KnowledgeCardsTableTableManager get knowledgeCards =>
      $$KnowledgeCardsTableTableManager(_db, _db.knowledgeCards);
  $$QuestionsTableTableManager get questions =>
      $$QuestionsTableTableManager(_db, _db.questions);
  $$QaRecordsTableTableManager get qaRecords =>
      $$QaRecordsTableTableManager(_db, _db.qaRecords);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$ParagraphsTableTableManager get paragraphs =>
      $$ParagraphsTableTableManager(_db, _db.paragraphs);
  $$AnnotationsTableTableManager get annotations =>
      $$AnnotationsTableTableManager(_db, _db.annotations);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$LlmLogsTableTableManager get llmLogs =>
      $$LlmLogsTableTableManager(_db, _db.llmLogs);
  $$LlmCacheTableTableManager get llmCache =>
      $$LlmCacheTableTableManager(_db, _db.llmCache);
  $$LlmChannelsTableTableManager get llmChannels =>
      $$LlmChannelsTableTableManager(_db, _db.llmChannels);
}
