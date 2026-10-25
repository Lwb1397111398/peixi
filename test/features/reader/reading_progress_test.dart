import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/pipeline/project_meta.dart';
import 'package:peixi/features/reader/reader.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  test('ProjectMeta.reading 编码往返', () {
    final meta = ProjectMeta(sourceFilename: 'a.txt')
      ..readingProgress = ReadingProgress(chapterIdx: 12, scrollOffset: 345.5);
    final back = ProjectMeta.fromJson(meta.encode());
    expect(back.readingProgress!.chapterIdx, 12);
    expect(back.readingProgress!.scrollOffset, 345.5);
  });

  test('progressPercent 编码往返；旧数据无该键解析为 null', () {
    final meta = ProjectMeta(sourceFilename: 'a.txt')
      ..readingProgress =
          ReadingProgress(chapterIdx: 3, scrollOffset: 8.0, progressPercent: 0.456);
    final back = ProjectMeta.fromJson(meta.encode());
    expect(back.readingProgress!.progressPercent, 0.456);
    // 旧格式（v6 前的库）没有 progressPercent 键
    final old = ProjectMeta.fromJson(
        '{"reading":{"chapterIdx":3,"scrollOffset":8.0}}');
    expect(old.readingProgress!.progressPercent, isNull);
  });

  test('无 reading 字段/损坏 meta 解析为 null 不抛', () {
    expect(
        ProjectMeta.fromJson('{"sourceFilename":"a"}').readingProgress, isNull);
    expect(ProjectMeta.fromJson('not-json').readingProgress, isNull);
    expect(ProjectMeta.fromJson(null).readingProgress, isNull);
  });

  test('ReaderRepository 保存并读回进度，meta 其它字段不丢', () async {
    final repo = ReaderRepository(db);
    final meta = ProjectMeta(sourceFilename: '小说.txt');
    await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'novel',
        title: '书',
        sourcePath: '/x.txt',
        status: 'READY',
        metaJson: Value(meta.encode())));

    await repo.saveReadingProgress(1, chapterIdx: 3, scrollOffset: 99.0);

    final got = await repo.readingProgress(1);
    expect(got, isNotNull);
    expect(got!.chapterIdx, 3);
    expect(got.scrollOffset, 99.0);
    final raw = ProjectMeta.fromJson(
        (await (db.select(db.projects)..where((t) => t.id.equals(1)))
                .getSingle())
            .metaJson);
    expect(raw.sourceFilename, '小说.txt');
  });

  test('重复保存覆盖旧进度', () async {
    final repo = ReaderRepository(db);
    await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'novel', title: '书', sourcePath: '/x.txt', status: 'READY'));
    await repo.saveReadingProgress(1, chapterIdx: 1, scrollOffset: 10);
    await repo.saveReadingProgress(1, chapterIdx: 5, scrollOffset: 20);
    final got = await repo.readingProgress(1);
    expect(got!.chapterIdx, 5);
    expect(got.scrollOffset, 20.0);
  });

  test('项目不存在时安全返回', () async {
    final repo = ReaderRepository(db);
    expect(await repo.readingProgress(99), isNull);
    await repo.saveReadingProgress(99, chapterIdx: 0, scrollOffset: 0);
  });
}
