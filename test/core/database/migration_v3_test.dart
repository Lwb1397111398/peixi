import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';

/// v2→v3 迁移：knowledge_cards 补 6 个 SRS 列、新建 llm_cache，
/// 既有数据必须原样保留。
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('peixi_mig'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// 把 v5 新增物回退成 v4 形态（删新表、chapters/characters 重建为无新列的
  /// 旧结构），模拟升级前的旧库——回拨版本号重开后，迁移链会重新加列/建表。
  Future<void> downgradeToV4Shape(AppDatabase db) async {
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
  }

  test('v2 数据库升级到 v3 后旧数据保留、新列取默认值', () async {
    final dbFile = File('${tmp.path}/db.sqlite');

    // 1) 以 v3 结构创建，再手工回退成 v2 形态（删新列对应物、回拨版本号）
    var db = AppDatabase(NativeDatabase(dbFile));
    await db.customStatement('DROP TABLE knowledge_cards');
    await db.customStatement('DROP TABLE llm_cache');
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
    await downgradeToV4Shape(db);
    await db.customStatement(
        "INSERT INTO projects (type, title, source_path, status) "
        "VALUES ('video', '潜伏', '/video.mkv', 'IMPORTED')");
    await db.customStatement(
        "INSERT INTO knowledge_cards (project_id, term, title, content, uncertain) "
        "VALUES (1, '通勤', '通勤的意思', '上下班往返', 1)");
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();

    // 2) 重新打开 → onUpgrade(2→3) 自动执行
    db = AppDatabase(NativeDatabase(dbFile));

    expect(db.schemaVersion, 6); // 沿用最新 schema 版本（v3 步骤已包含在迁移链中）
    final rows = await db.select(db.knowledgeCards).get();
    expect(rows, hasLength(1));
    final card = rows.single;
    expect(card.term, '通勤');
    expect(card.title, '通勤的意思');
    expect(card.content, '上下班往返');
    expect(card.uncertain, isTrue, reason: '旧数据列值不能被迁移改变');
    expect(card.ease, 2.5, reason: '新 SRS 列取默认值');
    expect(card.ivlDays, 0);
    expect(card.reps, 0);
    expect(card.lapses, 0);
    expect(card.dueAt, isNull);
    expect(card.lastReviewAt, isNull);

    // 3) llm_cache 可用
    await db.into(db.llmCache).insertOnConflictUpdate(
        LlmCacheCompanion.insert(key: 'k', response: 'r', model: 'm'));
    expect((await db.select(db.llmCache).get()).single.key, 'k');

    // 4) 新卡片可用 SRS 列正常写入
    await db.into(db.knowledgeCards).insert(KnowledgeCardsCompanion.insert(
        projectId: 1,
        term: '新词',
        title: '新词',
        content: '解释',
        ease: const Value(2.9)));
    final fresh = await (db.select(db.knowledgeCards)
          ..where((t) => t.term.equals('新词')))
        .getSingle();
    expect(fresh.ease, 2.9);

    await db.close();
  });

  test('v3 数据库升级到 v4 后 llm_channels 表存在且可写', () async {
    final dbFile = File('${tmp.path}/db.sqlite');

    // 1) 以 v4 结构创建，再手工回退成 v3 形态（删渠道表、回拨版本号）
    var db = AppDatabase(NativeDatabase(dbFile));
    await db.customStatement('DROP TABLE llm_channels');
    await downgradeToV4Shape(db);
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    // 2) 重新打开 → onUpgrade(3→4) 自动执行
    db = AppDatabase(NativeDatabase(dbFile));

    expect(db.schemaVersion, 6); // 沿用最新 schema 版本（v4 步骤已包含在迁移链中）
    // 3) llm_channels 已由迁移创建，可正常写读
    await db.into(db.llmChannels).insert(
        LlmChannelsCompanion.insert(name: '中转站', baseUrl: 'https://x/v1'));
    final row = await db.select(db.llmChannels).getSingle();
    expect(row.name, '中转站');
    expect(row.baseUrl, 'https://x/v1');

    await db.close();
  });
}
