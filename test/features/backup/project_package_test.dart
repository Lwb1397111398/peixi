import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/backup/project_package.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;
  late String audioDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('peixi_pkg');
    audioDir = '${tmp.path}/audio';
    Directory(audioDir).createSync();
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  /// 全量数据种子：视频项目（含音频文件、评论、问答）+ 小说项目（章节/段落/批注）
  Future<int> seedVideo() async {
    final video = File('${tmp.path}/src.mkv')..writeAsBytesSync(List.filled(8, 1));
    final meta = '{"sourceFilename":"潜伏.S01E03.mkv","durationMs":120000,"audioFormat":"mp3"}';
    final id = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'video', title: '潜伏', sourcePath: video.path, status: 'READY',
        metaJson: Value(meta)));
    File('$audioDir/$id.mp3').writeAsBytesSync(List.filled(64, 2));
    final c1 = await db.into(db.characters).insert(CharactersCompanion.insert(
        projectId: id, name: '余则成', speakerKey: const Value('SPEAKER_00'),
        confidence: const Value(0.9)));
    final s1 = await db.into(db.scenes).insert(ScenesCompanion.insert(
        projectId: id, idx: 0, startMs: 0, endMs: 60000,
        summary: const Value('汇报'), importance: const Value('high')));
    await db.into(db.segments).insert(SegmentsCompanion.insert(
        projectId: id, idx: 0, startMs: 1000, endMs: 3000, content: '站长，出事了',
        speakerCharId: Value(c1)));
    await db.into(db.commentaries).insert(CommentariesCompanion.insert(
        sceneId: s1, l1Subtext: '表面汇报，实则试探', model: 'qwen-plus'));
    await db.into(db.knowledgeCards).insert(KnowledgeCardsCompanion.insert(
        projectId: id, term: '军统', title: '军统', content: '调查统计局',
        firstSceneIdx: const Value(0)));
    final q = await db.into(db.questions).insert(QuestionsCompanion.insert(
        projectId: id, question: '你会怎么回话？', sceneId: Value(s1),
        perspectivesJson: Value(jsonEncode(['稳住', '拖延']))));
    await db.into(db.qaRecords).insert(QaRecordsCompanion.insert(
        questionId: q, userAnswer: '稳住再说', skipped: const Value(false)));
    return id;
  }

  Future<int> seedNovel() async {
    final id = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'novel', title: '暗夜与黎明', sourcePath: '/books/b.txt',
        status: 'READY', metaJson: const Value('{"sourceFilename":"b.txt","paraCount":2}')));
    final ch = await db.into(db.chapters).insert(ChaptersCompanion.insert(
        projectId: id, idx: 0, title: const Value('第一章'),
        startPara: 0, endPara: 1));
    final p1 = await db.into(db.paragraphs).insert(ParagraphsCompanion.insert(
        projectId: id, chapterId: Value(ch), idx: 0, content: '少年背剑而行。'));
    await db.into(db.paragraphs).insert(ParagraphsCompanion.insert(
        projectId: id, chapterId: Value(ch), idx: 1, content: '风起于青萍之末。'));
    await db.into(db.annotations).insert(AnnotationsCompanion.insert(
        paraId: p1, type: 'L1', contentJson: jsonEncode({'text': '暗流涌动'})));
    return id;
  }

  test('视频项目 roundtrip：全表迁移、id 重映射、音频还原、mediaMissing 标记', () async {
    final oldId = await seedVideo();
    final pkg = ProjectPackage(db);
    final zipFile = await pkg.exportProject(oldId,
        outputDir: tmp.path, audioDir: audioDir);
    expect(zipFile.existsSync(), isTrue);
    expect(zipFile.path.endsWith('.peixi.zip'), isTrue);

    // 删除原项目（级联），清空音频
    await (db.delete(db.projects)..where((t) => t.id.equals(oldId))).go();
    File('$audioDir/$oldId.mp3').deleteSync();
    expect(await db.select(db.projects).get(), isEmpty);

    final newId = await pkg.importProject(zipFile, audioDir: audioDir);
    expect(newId, isNot(equals(oldId)));

    final p = await db.select(db.projects).getSingle();
    expect(p.title, '潜伏');
    expect(p.type, 'video');
    final newMeta = jsonDecode(p.metaJson!) as Map;
    expect(newMeta['mediaMissing'], isTrue);
    expect(File('$audioDir/$newId.mp3').existsSync(), isTrue,
        reason: '音频按新项目 id 还原');

    final chars = await db.select(db.characters).get();
    expect(chars.single.name, '余则成');
    expect(chars.single.projectId, newId);
    final segs = await db.select(db.segments).get();
    expect(segs.single.speakerCharId, chars.single.id,
        reason: 'speakerCharId 重映射到新角色 id');
    final scenes = await db.select(db.scenes).get();
    final comms = await db.select(db.commentaries).get();
    expect(comms.single.sceneId, scenes.single.id);
    final cards = await db.select(db.knowledgeCards).get();
    expect(cards.single.projectId, newId);
    final qs = await db.select(db.questions).get();
    expect(qs.single.sceneId, scenes.single.id);
    final records = await db.select(db.qaRecords).get();
    expect(records.single.questionId, qs.single.id);
    expect(records.single.userAnswer, '稳住再说');
    expect(records.single.answeredAt, isA<DateTime>());
  });

  test('小说项目 roundtrip：章节/段落/批注全等', () async {
    final oldId = await seedNovel();
    final pkg = ProjectPackage(db);
    final zipFile = await pkg.exportProject(oldId, outputDir: tmp.path, audioDir: audioDir);
    await (db.delete(db.projects)..where((t) => t.id.equals(oldId))).go();

    final newId = await pkg.importProject(zipFile, audioDir: audioDir);
    final p = await db.select(db.projects).getSingle();
    expect(p.type, 'novel');
    expect(p.status, 'READY');
    expect(jsonDecode(p.metaJson!)['mediaMissing'], isNull,
        reason: '小说不标记媒体缺失');

    final paras = await db.select(db.paragraphs).get();
    expect(paras.map((e) => e.content).toList(),
        unorderedEquals(['少年背剑而行。', '风起于青萍之末。']));
    final anns = await db.select(db.annotations).get();
    expect(anns.single.type, 'L1');
    expect(jsonDecode(anns.single.contentJson)['text'], '暗流涌动');
    // 批注锚定到内容为「少年背剑而行。」的段落
    final anchored = paras.singleWhere((e) => e.id == anns.single.paraId);
    expect(anchored.content, '少年背剑而行。');
  });

  test('导入到已有数据的项目库（id 冲突场景重映射）', () async {
    // 先造一个不相关项目占位
    await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'video', title: '其他项目', sourcePath: '/x.mkv', status: 'READY'));
    final oldId = await seedVideo();
    final pkg = ProjectPackage(db);
    final zipFile = await pkg.exportProject(oldId, outputDir: tmp.path, audioDir: audioDir);
    await (db.delete(db.projects)..where((t) => t.id.equals(oldId))).go();

    final newId = await pkg.importProject(zipFile, audioDir: audioDir);
    final projects = await db.select(db.projects).get();
    expect(projects, hasLength(2));
    expect(projects.map((e) => e.id), contains(newId));
    expect(projects.map((e) => e.title), contains('其他项目'));
    // 导入项目的外键都指向自己
    final segs = await db.select(db.segments).get();
    expect(segs.single.projectId, newId);
  });

  test('损坏包导入抛可读异常', () async {
    final bad = File('${tmp.path}/bad.peixi.zip');
    final archive = Archive()
      ..addFile(ArchiveFile.string('other.txt', 'not a package'));
    await bad.writeAsBytes(ZipEncoder().encode(archive));
    await expectLater(
        ProjectPackage(db).importProject(bad, audioDir: audioDir),
        throwsException);
  });
}
