import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/features/pipeline/project_meta.dart';

void main() {
  // projects.meta_json 是单一 JSON 列，NovelMeta（管线侧）与 ProjectMeta
  // （阅读/视频侧）是同一份数据的两个类型化视图。任一视图 encode 丢失
  // 对方键都会互毁：徽章更新抹掉阅读进度、保存阅读进度抹掉章计数。
  group('NovelMeta 无损往返', () {
    test('encode 保留非自有键（reading）', () {
      const raw =
          '{"chapterCount":10,"annotatedChapters":3,"reading":{"chapterIdx":4,"scrollOffset":12.5}}';
      final meta = NovelMeta.fromJson(raw);
      expect(meta.chapterCount, 10);
      expect(meta.annotatedChapters, 3);

      final out =
          jsonDecode(meta.encode()) as Map<String, dynamic>;
      expect(out['chapterCount'], 10);
      expect(out['annotatedChapters'], 3);
      expect((out['reading'] as Map)['chapterIdx'], 4);
      expect((out['reading'] as Map)['scrollOffset'], 12.5);
    });

    test('改自有字段不丢非自有键', () {
      const raw =
          '{"chapterCount":10,"annotatedChapters":3,"digest":"旧摘要","reading":{"chapterIdx":1,"scrollOffset":0.0}}';
      final meta = NovelMeta.fromJson(raw);
      meta.annotatedChapters = 4;

      final out = jsonDecode(meta.encode()) as Map<String, dynamic>;
      expect(out['annotatedChapters'], 4);
      expect(out['digest'], '旧摘要');
      expect(out.containsKey('reading'), isTrue);
    });

    test('新建实例 encode 无杂质', () {
      final meta = NovelMeta()..chapterCount = 2;
      final out = jsonDecode(meta.encode()) as Map<String, dynamic>;
      expect(out['chapterCount'], 2);
      expect(out.containsKey('reading'), isFalse);
    });
  });

  group('ProjectMeta 无损往返', () {
    test('encode 保留非自有键（章计数/paraCount 等）', () {
      const raw =
          '{"chapterCount":10,"annotatedChapters":3,"paraCount":100,"charCount":2000,'
          '"annotatedPara":88,"digest":"x","reading":{"chapterIdx":2,"scrollOffset":3.0}}';
      final meta = ProjectMeta.fromJson(raw);

      final out = jsonDecode(meta.encode()) as Map<String, dynamic>;
      expect(out['chapterCount'], 10);
      expect(out['annotatedChapters'], 3);
      expect(out['paraCount'], 100);
      expect(out['charCount'], 2000);
      expect(out['annotatedPara'], 88);
      expect(out['digest'], 'x');
      expect((out['reading'] as Map)['chapterIdx'], 2);
    });

    test('写阅读进度不丢章计数（saveReadingProgress 场景）', () {
      const raw = '{"chapterCount":10,"annotatedChapters":3,"digest":"d"}';
      final meta = ProjectMeta.fromJson(raw)
        ..readingProgress = ReadingProgress(chapterIdx: 7, scrollOffset: 1.5);

      final out = jsonDecode(meta.encode()) as Map<String, dynamic>;
      expect((out['reading'] as Map)['chapterIdx'], 7);
      expect(out['chapterCount'], 10);
      expect(out['annotatedChapters'], 3);
      expect(out['digest'], 'd');
    });
  });

  group('跨视图互写（调度器徽章 ↔ 阅读进度）', () {
    test('NovelMeta 写徽章后再经 ProjectMeta 写进度，两边键全保留', () {
      const raw =
          '{"chapterCount":10,"annotatedChapters":2,"digest":"滚动摘要","reading":{"chapterIdx":5,"scrollOffset":9.0}}';

      // 调度器 _updateBadge：NovelMeta 视图改 annotatedChapters
      final badge = NovelMeta.fromJson(raw)..annotatedChapters = 3;
      final afterBadge = jsonDecode(badge.encode()) as Map<String, dynamic>;

      // 阅读器 saveReadingProgress：ProjectMeta 视图改 reading
      final progress = ProjectMeta.fromJson(jsonEncode(afterBadge))
        ..readingProgress = ReadingProgress(chapterIdx: 6, scrollOffset: 10.0);
      final afterProgress =
          jsonDecode(progress.encode()) as Map<String, dynamic>;

      expect(afterProgress['annotatedChapters'], 3);
      expect(afterProgress['chapterCount'], 10);
      expect(afterProgress['digest'], '滚动摘要');
      expect((afterProgress['reading'] as Map)['chapterIdx'], 6);
    });
  });
}
