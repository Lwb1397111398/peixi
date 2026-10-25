import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/novel/novel_parser.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';

/// v6：chapters.volume（分章识别升级——章归属卷，阅读器目录分组用）。
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('peixi_v6'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('新建 v6 库：volume 列默认 null，可写入可读回', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final pid = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'novel', title: '书', sourcePath: '/b.txt', status: 'IMPORTED'));
    final c1 = await db.into(db.chapters).insert(ChaptersCompanion.insert(
        projectId: pid, idx: 0, startPara: 0, endPara: 1));
    final c2 = await db.into(db.chapters).insert(ChaptersCompanion.insert(
        projectId: pid,
        idx: 1,
        volume: const Value('第一卷 风起'),
        startPara: 2,
        endPara: 3));

    final rows = await db.select(db.chapters).get();
    final byId = {for (final r in rows) r.id: r};
    expect(byId[c1]!.volume, isNull);
    expect(byId[c2]!.volume, '第一卷 风起');

    await db.close();
  });

  test('v5 库升级到 v6：volume 列就位、旧章数据原样保留', () async {
    final dbFile = File('${tmp.path}/db.sqlite');

    // 1) 以 v6 结构创建，再回退成 v5 形态（chapters 无 volume 列），回拨版本号
    var db = AppDatabase(NativeDatabase(dbFile));
    await db.customStatement('DROP TABLE chapters');
    await db.customStatement('''
      CREATE TABLE chapters (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "project_id" INTEGER NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
        "idx" INTEGER NOT NULL,
        "title" TEXT,
        "start_para" INTEGER NOT NULL,
        "end_para" INTEGER NOT NULL,
        "summary" TEXT,
        "map_done" INTEGER NOT NULL DEFAULT 0,
        "annot_done" INTEGER NOT NULL DEFAULT 0,
        "cast_ids" TEXT NOT NULL DEFAULT '[]',
        "digest_before" TEXT
      )
    ''');
    await db.customStatement(
        "INSERT INTO projects (type, title, source_path, status) "
        "VALUES ('novel', '旧书', '/old.txt', 'READY')");
    await db.customStatement('''
      INSERT INTO chapters (id, project_id, idx, title, start_para, end_para) VALUES
        (1, 1, 0, '第一章', 0, 2),
        (2, 1, 1, '第二章', 3, 5)
    ''');
    await db.customStatement('PRAGMA user_version = 5');
    await db.close();

    // 2) 重开 → onUpgrade(5→6) 加列
    db = AppDatabase(NativeDatabase(dbFile));
    expect(db.schemaVersion, 6);
    final chapters = await db.select(db.chapters).get();
    expect(chapters, hasLength(2));
    expect(chapters.map((c) => c.title).toList(), ['第一章', '第二章']);
    expect(chapters.every((c) => c.volume == null), isTrue,
        reason: '旧章无卷信息，volume 为 null');
    // 加列后可直接写新值
    await (db.update(db.chapters)..where((t) => t.id.equals(1)))
        .write(const ChaptersCompanion(volume: Value('第一卷')));
    expect((await db.select(db.chapters).get()).first.volume, '第一卷');
    // v6 同批：bookmarks 表由迁移创建且可写（先补一行段落满足外键）
    await db.into(db.paragraphs).insert(ParagraphsCompanion.insert(
        projectId: 1, idx: 0, content: '旧段落'));
    await db.into(db.bookmarks).insert(
        BookmarksCompanion.insert(projectId: 1, paraId: 1, note: const Value('备注')));
    expect(await db.select(db.bookmarks).get(), hasLength(1));
    final version =
        await db.customSelect('SELECT * FROM pragma_user_version').getSingle();
    expect(version.read<int>('user_version'), 6);

    await db.close();
  });

  test('导入链路：parseNovel 卷书 → NovelImporter 落库 volume 正确', () async {
    final db = AppDatabase(NativeDatabase.memory());
    const raw = '''
第一卷 风起
第一章 山门
　　少年入门。

第二章 试炼
　　他踏上石阶。

第二卷 云涌
第三章 变故
　　夜里起了风。
''';
    final pid = await NovelImporter(db: db).import(
        title: '卷书', sourcePath: '/juan.txt', doc: parseNovel(raw));

    final chapters = await (db.select(db.chapters)
          ..where((t) => t.projectId.equals(pid)))
        .get();
    expect(chapters, hasLength(3));
    expect(chapters.map((c) => c.title).toList(),
        ['第一章 山门', '第二章 试炼', '第三章 变故']);
    expect(chapters.map((c) => c.volume).toList(),
        ['第一卷 风起', '第一卷 风起', '第二卷 云涌']);

    await db.close();
  });
}
