import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/novel/novel_parser.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/features/pipeline/novel_pipeline.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';
import 'package:peixi/features/pipeline/project_status.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => db.close());

  final demoDoc = const NovelDoc(chapters: [
    NovelChapter(idx: 0, title: '第一章 山门', paragraphs: ['少年背剑而行。', '风起于青萍之末。']),
    NovelChapter(idx: 1, title: '第二章 客栈', paragraphs: ['店家压低了声音。']),
    NovelChapter(idx: 2, title: null, paragraphs: ['无标题块正文。', '第二段。', '第三段。']),
  ]);

  group('NovelImporter（N1 入库）', () {
    test('projects/chapters/paragraphs 落库，全局 idx 连续', () async {
      final id = await NovelImporter(db: db).import(
          title: '测试小说', sourcePath: 'C:/books/test.txt', doc: demoDoc);

      final p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
          .getSingle();
      expect(p.type, 'novel');
      expect(p.status, 'IMPORTED');
      expect(p.title, '测试小说');
      final meta = NovelMeta.fromJson(p.metaJson);
      expect(meta.paraCount, 6);
      expect(meta.charCount, greaterThan(0));

      final chapters = await (db.select(db.chapters)
            ..where((t) => t.projectId.equals(id))
            ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
          .get();
      expect(chapters, hasLength(3));
      expect(chapters[0].title, '第一章 山门');
      expect(chapters[0].startPara, 0);
      expect(chapters[0].endPara, 1);
      expect(chapters[1].startPara, 2);
      expect(chapters[1].endPara, 2);
      expect(chapters[2].title, isNull);
      expect(chapters[2].startPara, 3);
      expect(chapters[2].endPara, 5);

      final paras = await (db.select(db.paragraphs)
            ..where((t) => t.projectId.equals(id))
            ..orderBy([(pp) => OrderingTerm.asc(pp.idx)]))
          .get();
      expect(paras.map((e) => e.content).toList(), [
        '少年背剑而行。',
        '风起于青萍之末。',
        '店家压低了声音。',
        '无标题块正文。',
        '第二段。',
        '第三段。',
      ]);
      expect(paras.map((e) => e.idx).toList(), [0, 1, 2, 3, 4, 5]);
      // chapterId 正确挂链
      expect(paras[2].chapterId, chapters[1].id);
      expect(paras[4].chapterId, chapters[2].id);
    });
  });

  group('NovelPipelineEngine（调度器语义外壳）', () {
    Future<int> seed() async => db.into(db.projects).insert(
        ProjectsCompanion.insert(
            type: 'novel',
            title: 't',
            sourcePath: '/x.txt',
            status: 'IMPORTED'));

    test('正常路径：runFn 成功完成，外壳不改状态、发 novel 起点事件', () async {
      final id = await seed();
      final calls = <int>[];
      final e = NovelPipelineEngine(db: db);
      e.attachRun((pid) async => calls.add(pid));
      final events = <PipelineEvent>[];
      e.events.listen(events.add);
      await e.run(id);

      expect(calls, [id]);
      final p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
          .getSingle();
      expect(p.status, 'IMPORTED'); // 里程碑由调度器落库，外壳不碰
      expect(events, hasLength(1));
      expect(events.single.stage, 'novel');
      expect(events.single.status, ProjectStatus.imported);
    });

    test('PipelineStageException → FAILED+failed_stage + failed 事件', () async {
      final id = await seed();
      final e = NovelPipelineEngine(db: db);
      e.attachRun((pid) async =>
          throw PipelineStageException('digest', StateError('合成失败')));
      final events = <PipelineEvent>[];
      e.events.listen(events.add);
      await e.run(id);

      final p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
          .getSingle();
      expect(p.status, 'FAILED');
      expect(p.failedStage, 'digest');
      final failed = events.lastWhere((ev) => ev.status == ProjectStatus.failed);
      expect(failed.stage, 'novel');
      expect(failed.detail, contains('digest'));
    });

    test('PipelineCancelled → cancelled 事件，状态不变', () async {
      final id = await seed();
      final e = NovelPipelineEngine(db: db);
      e.attachRun((pid) async => throw const PipelineCancelled());
      final events = <PipelineEvent>[];
      e.events.listen(events.add);
      await e.run(id);

      final p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
          .getSingle();
      expect(p.status, 'IMPORTED'); // 取消不落 FAILED
      expect(events.last.cancelled, isTrue);
      expect(events.last.detail, contains('已取消'));
    });

    test('未知异常兜底 → FAILED+failed_stage=map', () async {
      final id = await seed();
      final e = NovelPipelineEngine(db: db);
      e.attachRun((pid) async => throw Exception('天灾'));
      await e.run(id);
      final p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
          .getSingle();
      expect(p.status, 'FAILED');
      expect(p.failedStage, 'map');
    });

    test('FAILED 项目重跑：起点事件用 IMPORTED；外壳成功路径不写状态（里程碑归调度器）',
        () async {
      final id = await seed();
      final e = NovelPipelineEngine(db: db);
      e.attachRun((pid) async => throw Exception('第一次失败'));
      await e.run(id);

      final events = <PipelineEvent>[];
      e.events.listen(events.add);
      e.attachRun((pid) async {});
      await e.retry(id);
      // 起点事件：FAILED 以 IMPORTED 身份重新出发（外壳语义）
      expect(events.first.status, ProjectStatus.imported);
      // 成功路径外壳不落盘状态——FAILED→里程碑升级由调度器 _setMilestone 负责
      final p = await (db.select(db.projects)..where((t) => t.id.equals(id)))
          .getSingle();
      expect(p.status, 'FAILED');
      expect(p.failedStage, 'map'); // 残留 failed_stage 由首个里程碑清空
    });

    test('isBusy 语义：运行中 true、结束后 false；同项目防并发', () async {
      final id = await seed();
      final e = NovelPipelineEngine(db: db);
      final gate = Completer<void>();
      e.attachRun((pid) async {
        expect(e.isBusy(id), isTrue);
        expect(e.isCancelled(id), isFalse);
        await gate.future;
      });
      final run1 = e.run(id);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(e.isBusy(id), isTrue);

      await e.run(id); // 第二次 run 直接返回（防并发）
      expect(e.isBusy(id), isTrue); // 第一次仍在跑

      e.requestCancel(id);
      expect(e.isCancelled(id), isTrue);
      gate.complete();
      await run1;

      expect(e.isBusy(id), isFalse);
      // 上轮取消标记不带入新一轮（续跑可正常推进）
      e.attachRun((pid) async => expect(e.isCancelled(id), isFalse));
      await e.run(id);
      expect(e.isBusy(id), isFalse);
    });
  });
}
