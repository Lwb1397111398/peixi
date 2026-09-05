import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/cards/anki_exporter.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('CSV 转义：逗号/引号/换行/标签空格', () async {
    final pid = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'video', title: '潜伏 第二集', sourcePath: '/a.mkv', status: 'READY'));
    await db.into(db.knowledgeCards).insert(KnowledgeCardsCompanion.insert(
        projectId: pid,
        term: '军统, "中统"',
        title: '带,逗号',
        content: '多行\n内容',
        uncertain: const Value(true)));

    final built = await AnkiExporter(db).buildCsv(projectId: pid);
    // back 含换行 → 行跨物理行，必须整串断言
    expect(built.csv, startsWith('front,back,tags\n'));
    expect(
        built.csv,
        contains('"军统, ""中统""","带,逗号\n多行\n内容",'
            'peixi 潜伏_第二集 不确定'));
    expect(built.count, 1);
    expect(built.fileName, contains('peixi_cards_'));
  });

  test('全量导出与按项目导出；title 等于 term 时 back 只含 content', () async {
    final p1 = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'video', title: '潜伏', sourcePath: '/a.mkv', status: 'READY'));
    await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'novel', title: '暗夜', sourcePath: '/b.txt', status: 'READY'));
    await db.into(db.knowledgeCards).insert(KnowledgeCardsCompanion.insert(
        projectId: p1, term: '军统', title: '军统', content: '调查统计局'));
    await db.into(db.knowledgeCards).insert(KnowledgeCardsCompanion.insert(
        projectId: p1, term: '拜帖', title: '拜帖的规矩', content: '递帖求见'));

    final all = await AnkiExporter(db).buildCsv();
    expect(all.count, 2);
    expect(all.csv, contains('peixi 潜伏'));
    expect(all.csv, isNot(contains('peixi 暗夜\n')), reason: '无卡项目不导出');

    final onlyP1 = await AnkiExporter(db).buildCsv(projectId: p1);
    expect(onlyP1.count, 2);

    // title != term → back = 标题换行解释（含换行 → 整字段加引号）
    expect(onlyP1.csv, contains('"拜帖的规矩\n递帖求见"'));
  });

  test('空卡片集导出 count=0', () async {
    final built = await AnkiExporter(db).buildCsv();
    expect(built.count, 0);
  });
}
