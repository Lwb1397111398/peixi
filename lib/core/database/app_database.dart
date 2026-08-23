import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// 设计稿第三节全部 12 张表。状态一律 TEXT 存枚举字面量。
/// *_json 字段按原文存 TEXT（JSON 字符串），由业务层编解码。

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // 'video' | 'novel'
  TextColumn get title => text()();
  TextColumn get sourcePath => text()();
  // IMPORTED/AUDIO_READY/UPLOADED/ASR_DONE/MAPPED/WAIT_CALIBRATION/
  // SEGMENTED/COMMENTARY_DONE/READY/FAILED（校准后置 CALIBRATED）
  TextColumn get status => text()();
  TextColumn get failedStage => text().nullable()();
  TextColumn get metaJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Characters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get aliasesJson => text().withDefault(const Constant('[]'))();
  TextColumn get speakerKey => text().nullable()(); // SPEAKER_00 等
  RealColumn get confidence => real().nullable()();
  TextColumn get source => text().withDefault(const Constant('auto'))(); // auto|manual
  TextColumn get color => text().nullable()();
}

class Segments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get idx => integer()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  IntColumn get speakerCharId => integer().nullable()();
  // 列名保持设计稿的 text；Dart 侧 getter 不能叫 text（与 Table.text() 冲突）
  TextColumn get content => text().named('text')();
}

class Scenes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get idx => integer()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  TextColumn get summary => text().nullable()();
  TextColumn get importance => text().withDefault(const Constant('normal'))();
}

class Commentaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sceneId =>
      integer().references(Scenes, #id, onDelete: KeyAction.cascade)();
  TextColumn get l1Subtext => text()();
  TextColumn get l2PsychologyJson => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('done'))();
  TextColumn get model => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  List<Set<Column>> get uniqueKeys => [
        {sceneId}
      ];
}

class KnowledgeCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get term => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  IntColumn get firstSceneIdx => integer().nullable()();
  BoolColumn get uncertain => boolean().withDefault(const Constant(false))();
  @override
  List<Set<Column>> get uniqueKeys => [
        {projectId, term}
      ];
}

class Questions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get sceneId => integer().nullable()();
  TextColumn get question => text()();
  TextColumn get perspectivesJson => text().withDefault(const Constant('[]'))();
}

class QaRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questionId =>
      integer().references(Questions, #id, onDelete: KeyAction.cascade)();
  TextColumn get userAnswer => text()();
  DateTimeColumn get answeredAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get skipped => boolean().withDefault(const Constant(false))();
}

class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get idx => integer()();
  TextColumn get title => text().nullable()();
  IntColumn get startPara => integer()();
  IntColumn get endPara => integer()();
  TextColumn get summary => text().nullable()();
}

class Paragraphs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterId => integer().nullable()();
  IntColumn get idx => integer()();
  TextColumn get content => text().named('text')();
}

class Annotations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get paraId =>
      integer().references(Paragraphs, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()(); // L1|L2|L3|L4
  TextColumn get contentJson => text()();
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class LlmLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().nullable()();
  TextColumn get purpose => text()();
  TextColumn get model => text()();
  IntColumn get promptTokens => integer().withDefault(const Constant(0))();
  IntColumn get completionTokens => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [
  Projects,
  Characters,
  Segments,
  Scenes,
  Commentaries,
  KnowledgeCards,
  Questions,
  QaRecords,
  Chapters,
  Paragraphs,
  Annotations,
  Settings,
  LlmLogs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // SQLite 默认不启用外键约束，级联删除依赖此 PRAGMA
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
