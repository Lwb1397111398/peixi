import 'package:drift/drift.dart';
import 'package:peixi/core/database/novel_backfill.dart';

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

@TableIndex(name: 'idx_characters_project', columns: {#projectId})
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

  /// v5：主要人物标记（地图趟维护；名单进 prompt 按 major + 近期活跃过滤，防膨胀）
  BoolColumn get major => boolean().withDefault(const Constant(false))();
}

@TableIndex(name: 'idx_segments_project', columns: {#projectId})
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

@TableIndex(name: 'idx_scenes_project', columns: {#projectId})
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
  // SRS（间隔重复）调度字段：dueAt 为 null 表示尚未进入复习循环（新卡）
  DateTimeColumn get dueAt => dateTime().nullable()();
  RealColumn get ivlDays => real().withDefault(const Constant(0))();
  RealColumn get ease => real().withDefault(const Constant(2.5))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastReviewAt => dateTime().nullable()();
  @override
  List<Set<Column>> get uniqueKeys => [
        {projectId, term}
      ];
}

@TableIndex(name: 'idx_questions_project', columns: {#projectId})
@TableIndex(name: 'idx_questions_scene', columns: {#sceneId})
class Questions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get sceneId => integer().nullable()();
  TextColumn get question => text()();
  TextColumn get perspectivesJson => text().withDefault(const Constant('[]'))();
}

@TableIndex(name: 'idx_qa_records_question', columns: {#questionId})
class QaRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questionId =>
      integer().references(Questions, #id, onDelete: KeyAction.cascade)();
  TextColumn get userAnswer => text()();
  DateTimeColumn get answeredAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get skipped => boolean().withDefault(const Constant(false))();
}

@TableIndex(name: 'idx_chapters_project', columns: {#projectId})
class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get idx => integer()();
  TextColumn get title => text().nullable()();
  IntColumn get startPara => integer()();
  IntColumn get endPara => integer()();
  TextColumn get summary => text().nullable()();

  // v5：两遍式管线的章级断点列（设计文档 §5，崩溃续跑与调度器衔接全靠它们）
  BoolColumn get mapDone => boolean().withDefault(const Constant(false))();
  BoolColumn get annotDone => boolean().withDefault(const Constant(false))();
  TextColumn get castIds => text().withDefault(const Constant('[]'))(); // JSON List<int>
  TextColumn get digestBefore => text().nullable()(); // 该章开读时的"故事至今"快照

  /// v6：所属卷标题（「第一卷 风起」「Part II」；无卷结构为 null），
  /// 阅读器目录按卷分组用。
  TextColumn get volume => text().nullable()();
}

@TableIndex(name: 'idx_paragraphs_project', columns: {#projectId})
@TableIndex(name: 'idx_paragraphs_chapter', columns: {#chapterId})
class Paragraphs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterId => integer().nullable()();
  IntColumn get idx => integer()();
  TextColumn get content => text().named('text')();
}

@TableIndex(name: 'idx_annotations_para', columns: {#paraId})
class Annotations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get paraId =>
      integer().references(Paragraphs, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()(); // L1|L2|L3|L4
  TextColumn get contentJson => text()();
}

/// v5：人物关键事件时间线（批注趟"前文呼应"的召回源，设计文档 §5）
@TableIndex(name: 'idx_character_events_project', columns: {#projectId})
@TableIndex(name: 'idx_character_events_character', columns: {#characterId})
class CharacterEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get characterId =>
      integer().references(Characters, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterIdx => integer()();
  TextColumn get event => text()();
}

/// v5：语义回忆索引（章摘要向量，cos 相似度在 Dart 侧计算；可选层，默认关）
class ChapterEmbeddings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterId =>
      integer().references(Chapters, #id, onDelete: KeyAction.cascade)();
  IntColumn get dim => integer()();
  TextColumn get vectorJson => text()(); // JSON List<double>
  @override
  List<Set<Column>> get uniqueKeys => [
        {chapterId}
      ];
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

/// LLM 响应缓存：key = sha256(model + jsonMode + messages)。
/// 命中后跳过 HTTP 且不记 llm_logs，token 统计保持真实花费。
class LlmCache extends Table {
  TextColumn get key => text()();
  TextColumn get response => text()();
  TextColumn get model => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {key};
}

/// LLM 渠道（OpenAI 兼容中转站）。api_key 存 secure storage（键 `llm.channel.<id>.api_key`）。
class LlmChannels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
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
  CharacterEvents,
  ChapterEmbeddings,
  Settings,
  LlmLogs,
  LlmCache,
  LlmChannels,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 3) {
            // v2→v3：SRS 调度列 + LLM 响应缓存表（列带默认值，旧行自动填充）
            await m.addColumn(knowledgeCards, knowledgeCards.dueAt);
            await m.addColumn(knowledgeCards, knowledgeCards.ivlDays);
            await m.addColumn(knowledgeCards, knowledgeCards.ease);
            await m.addColumn(knowledgeCards, knowledgeCards.reps);
            await m.addColumn(knowledgeCards, knowledgeCards.lapses);
            await m.addColumn(knowledgeCards, knowledgeCards.lastReviewAt);
            await m.createTable(llmCache);
          }
          if (from < 4) {
            // v3→v4：LLM 渠道表（渠道化模型管理，api_key 在 secure storage）
            await m.createTable(llmChannels);
          }
          if (from < 5) {
            // v4→v5：两遍式管线的章级断点列 + 人物事件线 + 语义回忆索引（设计文档 §5）。
            // 整体包事务：drift 的 onUpgrade 不在事务中运行（user_version 要等
            // 全部迁移成功后才写入），而回填是逐章 UPDATE（几千章=数千条语句），
            // 中途被杀后重跑会撞 duplicate column，库永久打不开。SQLite DDL 是
            // 事务性的：失败整体回滚、重跑干净。
            await transaction(() async {
              await m.addColumn(chapters, chapters.mapDone);
              await m.addColumn(chapters, chapters.annotDone);
              await m.addColumn(chapters, chapters.castIds);
              await m.addColumn(chapters, chapters.digestBefore);
              await m.addColumn(characters, characters.major);
              await m.createTable(characterEvents);
              await m.createTable(chapterEmbeddings);
              await backfillNovelV5(this);
            });
          }
          if (from < 6) {
            // v5→v6：分章识别升级——章归属卷（chapters.volume，阅读器目录分组用）
            await m.addColumn(chapters, chapters.volume);
          }
          if (from < 2) {
            // v1→v2：为按项目/章节/段落/场景等外键式查询补齐索引（v1 为全表扫描）。
            // 必须放在全部建表/加列/回填之后：v5 新索引 idx_character_events_*
            // 指向的 character_events 在上面的 from<5 块才创建，drift 的
            // createIndex 是裸 CREATE INDEX，提前执行会让真实 v1 库升级报
            // no such table 而打不开；且 m.createTable 不会创建 @TableIndex
            // 注解索引，此循环正好补上 v5 新表的索引。
            for (final index in allSchemaEntities.whereType<Index>()) {
              await m.createIndex(index);
            }
          }
        },
        beforeOpen: (details) async {
          // SQLite 默认不启用外键约束，级联删除依赖此 PRAGMA
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
