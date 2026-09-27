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

    expect(db.schemaVersion, 5);
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
}
