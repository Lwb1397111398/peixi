// test/core/database/app_database_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  test('projects 全生命周期字段与状态写入读出', () async {
    final id = await db.into(db.projects).insert(ProjectsCompanion.insert(
          type: 'video',
          title: '潜伏 S01E03',
          sourcePath: 'D:/tv/qianfeng.mkv',
          status: 'IMPORTED',
        ));
    final row = await db.select(db.projects).getSingle();
    expect(row.id, id);
    expect(row.status, 'IMPORTED');
    expect(row.createdAt, isA<DateTime>());
    expect(row.updatedAt, isA<DateTime>());
    await (db.update(db.projects)..where((t) => t.id.equals(id)))
        .write(const ProjectsCompanion(status: Value('FAILED'), failedStage: Value('S5_ASR')));
    expect((await db.select(db.projects).getSingle()).failedStage, 'S5_ASR');
  });

  test('scenes/commentaries/questions 级联删除与唯一约束', () async {
    final pid = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'video', title: 't', sourcePath: 'p', status: 'READY'));
    final sid = await db.into(db.scenes).insert(ScenesCompanion.insert(
        projectId: pid, idx: 0, startMs: 0, endMs: 1000));
    final cid = await db.into(db.commentaries).insert(CommentariesCompanion.insert(
        sceneId: sid, l1Subtext: '潜台词', model: 'qwen-plus'));
    final qid = await db.into(db.questions).insert(QuestionsCompanion.insert(
        projectId: pid, sceneId: Value(sid), question: 'q', perspectivesJson: Value('[]')));
    await db.into(db.qaRecords).insert(QaRecordsCompanion.insert(
        questionId: qid, userAnswer: 'a'));

    // commentaries.sceneId 唯一：重复插入应冲突
    expect(
      () => db.into(db.commentaries).insert(
          CommentariesCompanion.insert(sceneId: sid, l1Subtext: 'x', model: 'm')),
      throwsA(isA<Exception>()),
    );

    // 删除 project 级联清掉全部子表
    await (db.delete(db.projects)..where((t) => t.id.equals(pid))).go();
    expect(await db.select(db.scenes).get(), isEmpty);
    expect(await db.select(db.commentaries).get(), isEmpty);
    expect(await db.select(db.questions).get(), isEmpty);
    expect(await db.select(db.qaRecords).get(), isEmpty);
    expect(cid, greaterThan(0));
  });

  test('novel 三表（chapters/paragraphs/annotations）建表可用', () async {
    final pid = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'novel', title: 'n', sourcePath: 'p', status: 'READY'));
    final chid = await db.into(db.chapters)
        .insert(ChaptersCompanion.insert(projectId: pid, idx: 0, startPara: 0, endPara: 10));
    final paid = await db.into(db.paragraphs).insert(
        ParagraphsCompanion.insert(projectId: pid, chapterId: Value(chid), idx: 0, content: '正文'));
    await db.into(db.annotations).insert(
        AnnotationsCompanion.insert(paraId: paid, type: 'L1', contentJson: '{}'));
    expect(await db.select(db.chapters).get(), hasLength(1));
  });

  test('settings 键值与 llm_logs 计数', () async {
    await db.into(db.settings).insert(SettingsCompanion.insert(key: 'k', value: 'v'));
    await db.customStatement(
        "INSERT INTO llm_logs(project_id,purpose,model,prompt_tokens,completion_tokens,created_at) VALUES(1,'解说','qwen-plus',100,200,0)");
    final sum = await db.customSelect(
        'SELECT SUM(prompt_tokens+completion_tokens) AS t FROM llm_logs').getSingle();
    expect(sum.read<int>('t'), 300);
  });
}
