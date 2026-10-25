import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/reader/reader.dart';

/// v6 全书搜索 + 书签（ReaderRepository 数据层）。
void main() {
  late AppDatabase db;
  late ReaderRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReaderRepository(db);
  });
  tearDown(() => db.close());

  Future<void> seed() async {
    await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'novel', title: '书', sourcePath: '/x.txt', status: 'READY'));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        projectId: 1,
        idx: 0,
        title: const Value('第一章'),
        startPara: 0,
        endPara: 1));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        projectId: 1,
        idx: 1,
        title: const Value('第二章'),
        startPara: 2,
        endPara: 2));
    const contents = [
      '少年背剑而行，剑名青霜。',
      '店家压低了声音说话。',
      '剑光一闪，青霜出鞘。',
    ];
    for (var i = 0; i < contents.length; i++) {
      await db.into(db.paragraphs).insert(ParagraphsCompanion.insert(
          projectId: 1,
          chapterId: Value(i <= 1 ? 1 : 2),
          idx: i,
          content: contents[i]));
    }
  }

  group('searchParagraphs', () {
    test('命中按段落序号升序，带章名', () async {
      await seed();
      final hits = await repo.searchParagraphs(1, '青霜');
      expect(hits, hasLength(2));
      expect(hits.map((h) => h.paraIdx).toList(), [0, 2]);
      expect(hits.first.chapterTitle, '第一章');
      expect(hits.last.chapterTitle, '第二章');
      expect(hits.first.paraId, greaterThan(0));
    });

    test('ASCII 关键词不区分大小写', () async {
      await seed();
      await db.into(db.paragraphs).insert(ParagraphsCompanion.insert(
          projectId: 1, chapterId: const Value(1), idx: 3, content: 'The Storm came.'));
      final hits = await repo.searchParagraphs(1, 'storm');
      expect(hits, hasLength(1));
      expect(hits.single.paraIdx, 3);
    });

    test('空关键词返回空；无命中返回空', () async {
      await seed();
      expect(await repo.searchParagraphs(1, '  '), isEmpty);
      expect(await repo.searchParagraphs(1, '不存在的词'), isEmpty);
    });

    test('limit 截断', () async {
      await seed();
      final hits = await repo.searchParagraphs(1, '剑', limit: 1);
      expect(hits, hasLength(1));
    });
  });

  group('bookmarks', () {
    test('加书签（带备注）→ 列表新到旧、join 章名与段落；移除后消失', () async {
      await seed();
      await repo.addBookmark(
          projectId: 1, paraId: 1, note: '此处伏笔');
      await repo.addBookmark(projectId: 1, paraId: 3);

      final list = await repo.bookmarksOf(1);
      expect(list, hasLength(2));
      // 新→旧：paraId 3 在前
      expect(list.first.paraId, 3);
      expect(list.first.chapterTitle, '第二章');
      expect(list.first.paraContent, contains('剑光'));
      expect(list.last.note, '此处伏笔');
      expect(list.last.chapterId, 1);

      expect(await repo.bookmarkIdOf(1), isNotNull);
      await repo.removeBookmark(list.first.id);
      final after = await repo.bookmarksOf(1);
      expect(after, hasLength(1));
      expect(after.single.paraId, 1);
    });

    test('段落删除时书签级联删除', () async {
      await seed();
      await repo.addBookmark(projectId: 1, paraId: 2);
      await (db.delete(db.paragraphs)..where((t) => t.id.equals(2))).go();
      expect(await repo.bookmarksOf(1), isEmpty);
    });
  });
}
