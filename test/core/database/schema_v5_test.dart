import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';

/// v5 新列/新表默认值 + v4→v5 迁移旧项目回填（设计文档 §5 五条规则）。
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('peixi_v5'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// 把 v5 库整体回退成忠实 v1 形态：删 v3/v4/v5 新表、knowledge_cards 重建为
  /// 无 SRS 列的旧结构、chapters/characters 重建为无 v5 新列的旧结构、
  /// 删掉全部显式索引（chapters/characters 上的两个已随表删除）。
  /// 回拨 user_version 重开后，迁移链会从头加列/建表/建索引。
  Future<void> downgradeToV1Shape(AppDatabase db) async {
    await db.customStatement('DROP TABLE character_events');
    await db.customStatement('DROP TABLE chapter_embeddings');
    await db.customStatement('DROP TABLE llm_channels');
    await db.customStatement('DROP TABLE llm_cache');
    await db.customStatement('DROP TABLE chapters');
    await db.customStatement('DROP TABLE characters');
    await db.customStatement('DROP TABLE knowledge_cards');
    await db.customStatement('''
      CREATE TABLE chapters (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "project_id" INTEGER NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
        "idx" INTEGER NOT NULL,
        "title" TEXT,
        "start_para" INTEGER NOT NULL,
        "end_para" INTEGER NOT NULL,
        "summary" TEXT
      )
    ''');
    await db.customStatement('''
      CREATE TABLE characters (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "project_id" INTEGER NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
        "name" TEXT NOT NULL,
        "aliases_json" TEXT NOT NULL DEFAULT '[]',
        "speaker_key" TEXT,
        "confidence" REAL,
        "source" TEXT NOT NULL DEFAULT 'auto',
        "color" TEXT
      )
    ''');
    await db.customStatement('''
      CREATE TABLE knowledge_cards (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "project_id" INTEGER NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
        "term" TEXT NOT NULL,
        "title" TEXT NOT NULL,
        "content" TEXT NOT NULL,
        "first_scene_idx" INTEGER,
        "uncertain" INTEGER NOT NULL DEFAULT 0,
        UNIQUE ("project_id", "term")
      )
    ''');
    for (final idx in const [
      'idx_segments_project',
      'idx_scenes_project',
      'idx_questions_project',
      'idx_questions_scene',
      'idx_qa_records_question',
      'idx_paragraphs_project',
      'idx_paragraphs_chapter',
      'idx_annotations_para',
    ]) {
      await db.customStatement('DROP INDEX IF EXISTS $idx');
    }
  }

  test('新建 v5 库：chapters 新列默认值、characters.major 默认 false', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final pid = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'novel', title: '书', sourcePath: '/book.txt', status: 'IMPORTED'));
    final cid = await db.into(db.chapters).insert(
        ChaptersCompanion.insert(projectId: pid, idx: 0, startPara: 0, endPara: 2));
    await db.into(db.characters)
        .insert(CharactersCompanion.insert(projectId: pid, name: '林晚'));

    final ch =
        await (db.select(db.chapters)..where((t) => t.id.equals(cid))).getSingle();
    expect(ch.mapDone, isFalse);
    expect(ch.annotDone, isFalse);
    expect(ch.castIds, '[]');
    expect(ch.digestBefore, isNull);
    final c = await db.select(db.characters).getSingle();
    expect(c.major, isFalse);

    await db.close();
  });

  test('v4 数据库升级到 v5：新列就位 + 旧小说项目按 §5 回填', () async {
    final dbFile = File('${tmp.path}/db.sqlite');

    // 1) 以 v5 结构创建，再手工回退成 v4 形态（删新表、重建无新列的表、回拨版本号）
    var db = AppDatabase(NativeDatabase(dbFile));
    await db.customStatement('DROP TABLE character_events');
    await db.customStatement('DROP TABLE chapter_embeddings');
    await db.customStatement('DROP TABLE chapters');
    await db.customStatement('DROP TABLE characters');
    await db.customStatement('''
      CREATE TABLE chapters (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "project_id" INTEGER NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
        "idx" INTEGER NOT NULL,
        "title" TEXT,
        "start_para" INTEGER NOT NULL,
        "end_para" INTEGER NOT NULL,
        "summary" TEXT
      )
    ''');
    await db.customStatement('''
      CREATE TABLE characters (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "project_id" INTEGER NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
        "name" TEXT NOT NULL,
        "aliases_json" TEXT NOT NULL DEFAULT '[]',
        "speaker_key" TEXT,
        "confidence" REAL,
        "source" TEXT NOT NULL DEFAULT 'auto',
        "color" TEXT
      )
    ''');
    // 旧小说项目：4 章；annotatedPara=8（第三章末段）、digest='旧摘要'
    await db.customStatement(
        "INSERT INTO projects (type, title, source_path, status, meta_json) "
        "VALUES ('novel', '旧书', '/old.txt', 'IMPORTED', "
        '\'{"sourceFilename":"old.txt","paraCount":12,"charCount":300,'
        '"digest":"旧摘要","annotatedPara":8}\')');
    await db.customStatement(
        "INSERT INTO characters (id, project_id, name, aliases_json, source) "
        "VALUES (1, 1, '旧人物', '[]', 'auto')");
    await db.customStatement('''
      INSERT INTO chapters (id, project_id, idx, title, start_para, end_para, summary) VALUES
        (1, 1, 0, '第一章', 0, 2, '第一章摘要'),
        (2, 1, 1, '第二章', 3, 5, NULL),
        (3, 1, 2, '第三章', 6, 8, ''),
        (4, 1, 3, '第四章', 9, 11, '第四章摘要')
    ''');
    await db.customStatement('''
      INSERT INTO paragraphs (id, project_id, chapter_id, idx, text) VALUES
        (1, 1, 1, 0, 'p0'), (2, 1, 1, 1, 'p1'), (3, 1, 1, 2, 'p2'),
        (4, 1, 2, 3, 'p3'), (5, 1, 2, 4, 'p4'), (6, 1, 2, 5, 'p5'),
        (7, 1, 3, 6, 'p6'), (8, 1, 3, 7, 'p7'), (9, 1, 3, 8, 'p8'),
        (10, 1, 4, 9, 'p9'), (11, 1, 4, 10, 'p10'), (12, 1, 4, 11, 'p11')
    ''');
    await db.customStatement(
        "INSERT INTO annotations (id, para_id, type, content_json) VALUES "
        "(1, 1, 'L1', '{\"text\":\"潜\"}'), (2, 5, 'L3', "
        "'{\"term\":\"宗门\",\"text\":\"知识\",\"uncertain\":false}')");
    await db.customStatement(
        "INSERT INTO knowledge_cards (project_id, term, title, content, uncertain) "
        "VALUES (1, '宗门', '宗门', '修行门派', 0)");
    await db.customStatement('PRAGMA user_version = 4');
    await db.close();

    // 2) 重新打开 → onUpgrade(4→5) 自动执行（加列 + 建表 + 回填）
    db = AppDatabase(NativeDatabase(dbFile));

    expect(db.schemaVersion, 6);
    final chapters = await (db.select(db.chapters)
          ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
        .get();
    expect(chapters, hasLength(4));
    final byIdx = {for (final c in chapters) c.idx: c};
    // ① summary 非空 → map_done=1（空字符串不算非空）
    expect(byIdx[0]!.mapDone, isTrue, reason: 'summary 非空章 mapDone=true');
    expect(byIdx[3]!.mapDone, isTrue, reason: 'summary 非空章 mapDone=true');
    expect(byIdx[1]!.mapDone, isFalse, reason: 'summary 为 NULL 的章不回填');
    expect(byIdx[2]!.mapDone, isFalse, reason: '空字符串摘要不算非空');
    // ② annotatedPara(8) >= end_para → annot_done=1
    expect(byIdx[0]!.annotDone, isTrue, reason: 'end_para=2 ≤ 8');
    expect(byIdx[1]!.annotDone, isTrue, reason: 'end_para=5 ≤ 8');
    expect(byIdx[2]!.annotDone, isTrue, reason: 'end_para=8 ≤ 8');
    expect(byIdx[3]!.annotDone, isFalse, reason: 'end_para=11 > 8');
    // ③ 第一个未批注章的 digest_before = 旧滚动摘要
    expect(byIdx[3]!.digestBefore, '旧摘要');
    expect(byIdx[0]!.digestBefore, isNull, reason: '已批注章不需要快照');
    // ④ 批注/人物/知识卡原样保留
    expect(await db.select(db.annotations).get(), hasLength(2));
    final chars = await db.select(db.characters).get();
    expect(chars, hasLength(1));
    expect(chars.single.major, isFalse, reason: '旧人物 major 取默认值');
    expect(await db.select(db.knowledgeCards).get(), hasLength(1));
    // ⑤ meta 回填 chapterCount/annotatedChapters；annotatedPara 保留
    final p = await db.select(db.projects).getSingle();
    final meta = NovelMeta.fromJson(p.metaJson);
    expect(meta.chapterCount, 4);
    expect(meta.annotatedChapters, 3);
    expect(meta.annotatedPara, 8, reason: 'annotatedPara 保留不再使用');
    expect(meta.digest, '旧摘要', reason: 'digest 原样保留');
    // 新表由迁移创建且可用
    await db.into(db.characterEvents).insert(CharacterEventsCompanion.insert(
        projectId: p.id, characterId: chars.single.id, chapterIdx: 3, event: '立誓'));
    await db.into(db.chapterEmbeddings).insert(ChapterEmbeddingsCompanion.insert(
        projectId: p.id, chapterId: chapters.first.id, dim: 4, vectorJson: '[0.1,0.2,0.3,0.4]'));
    expect(await db.select(db.characterEvents).get(), hasLength(1));
    expect(await db.select(db.chapterEmbeddings).get(), hasLength(1));

    await db.close();
  });

  test('忠实 v1 库升级到 v5：索引在全部建表之后创建，库可打开可查询', () async {
    final dbFile = File('${tmp.path}/db.sqlite');

    // 1) 以 v5 结构创建，再整体回退成忠实 v1 形态：无任何显式索引、
    //    knowledge_cards 无 SRS 列、无 llm_cache/llm_channels、
    //    chapters/characters 无 v5 新列、无 character_events/chapter_embeddings，
    //    最后 PRAGMA user_version = 1。
    var db = AppDatabase(NativeDatabase(dbFile));
    await downgradeToV1Shape(db);
    // 旧小说项目：2 章；annotatedPara=3（第一章末段）、digest='卷一摘要'
    await db.customStatement(
        "INSERT INTO projects (type, title, source_path, status, meta_json) "
        "VALUES ('novel', '古书', '/v1.txt', 'IMPORTED', "
        '\'{"sourceFilename":"v1.txt","paraCount":6,"charCount":120,'
        '"digest":"卷一摘要","annotatedPara":3}\')');
    await db.customStatement(
        "INSERT INTO characters (id, project_id, name, aliases_json, source) "
        "VALUES (1, 1, '主角', '[]', 'auto')");
    await db.customStatement('''
      INSERT INTO chapters (id, project_id, idx, title, start_para, end_para, summary) VALUES
        (1, 1, 0, '第一章', 0, 2, '第一章摘要'),
        (2, 1, 1, '第二章', 3, 5, NULL)
    ''');
    await db.customStatement('''
      INSERT INTO paragraphs (id, project_id, chapter_id, idx, text) VALUES
        (1, 1, 1, 0, 'p0'), (2, 1, 1, 1, 'p1'), (3, 1, 1, 2, 'p2'),
        (4, 1, 2, 3, 'p3'), (5, 1, 2, 4, 'p4'), (6, 1, 2, 5, 'p5')
    ''');
    await db.customStatement(
        "INSERT INTO knowledge_cards (project_id, term, title, content, uncertain) "
        "VALUES (1, '灵气', '灵气', '天地灵气', 0)");
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    // 2) 重新打开 → onUpgrade(1→5) 全链执行。曾有 bug：索引循环排在迁移最前，
    //    idx_character_events_* 会建在尚未创建的 character_events 上而报
    //    no such table，库直接打不开。此处必须真实查询验证打开成功。
    db = AppDatabase(NativeDatabase(dbFile));

    final chapters = await (db.select(db.chapters)
          ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
        .get();
    expect(chapters, hasLength(2));
    final byIdx = {for (final c in chapters) c.idx: c};
    // 回填在 v1→v5 全链升级中同样生效（§5 规则①②③）
    expect(byIdx[0]!.mapDone, isTrue, reason: 'summary 非空章 mapDone=true');
    expect(byIdx[0]!.annotDone, isTrue, reason: 'end_para=2 ≤ annotatedPara=3');
    expect(byIdx[0]!.digestBefore, isNull, reason: '已批注章不需要快照');
    expect(byIdx[1]!.mapDone, isFalse, reason: 'summary 为 NULL 的章不回填');
    expect(byIdx[1]!.annotDone, isFalse, reason: 'end_para=5 > annotatedPara=3');
    expect(byIdx[1]!.digestBefore, '卷一摘要', reason: '首个未批注章拿旧滚动摘要');
    // v3 链段：SRS 列就位、旧数据保留
    final card = await db.select(db.knowledgeCards).getSingle();
    expect(card.term, '灵气');
    expect(card.ease, 2.5, reason: 'SRS 列取默认值');
    // v2/v5 索引全部就位——包括建在迁移中才创建的表上的 v5 新索引
    final indexRows =
        await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'index'").get();
    final indexNames = indexRows.map((r) => r.read<String>('name')).toSet();
    expect(
        indexNames,
        containsAll(<String>[
          'idx_chapters_project',
          'idx_paragraphs_chapter',
          'idx_character_events_project',
          'idx_character_events_character',
        ]));
    // user_version 已推进到 5
    final version = await db.customSelect('SELECT * FROM pragma_user_version').getSingle();
    expect(version.read<int>('user_version'), 6);
    // ⑤ meta 回填 chapterCount/annotatedChapters；digest/annotatedPara 原样保留
    final p = await db.select(db.projects).getSingle();
    final meta = jsonDecode(p.metaJson!) as Map<String, dynamic>;
    expect(meta['chapterCount'], 2);
    expect(meta['annotatedChapters'], 1);
    expect(meta['digest'], '卷一摘要', reason: 'digest 原样保留');
    expect(meta['annotatedPara'], 3, reason: 'annotatedPara 保留不再使用');
    // v5 新表由迁移创建且可写（外键指向的人物行原样保留）
    await db.into(db.characterEvents).insert(CharacterEventsCompanion.insert(
        projectId: p.id, characterId: 1, chapterIdx: 1, event: '入门'));
    expect(await db.select(db.characterEvents).get(), hasLength(1));

    await db.close();
  });
}
