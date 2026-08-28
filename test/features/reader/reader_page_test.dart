import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/reader/reader_page.dart';
import 'package:peixi/providers.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => db.close());

  Future<void> seed() async {
    await db.into(db.projects).insert(ProjectsCompanion.insert(
          type: 'novel',
          title: '测试小说',
          sourcePath: '/book.txt',
          status: 'READY',
        ));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        projectId: 1,
        idx: 0,
        title: const Value('第一章 山门'),
        startPara: 0,
        endPara: 1));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        projectId: 1,
        idx: 1,
        title: const Value('第二章 客栈'),
        startPara: 2,
        endPara: 2));
    await db.into(db.paragraphs).insert(ParagraphsCompanion.insert(
        projectId: 1, chapterId: const Value(1), idx: 0, content: '少年背剑而行。'));
    await db.into(db.paragraphs).insert(ParagraphsCompanion.insert(
        projectId: 1, chapterId: const Value(1), idx: 1, content: '风起于青萍之末。'));
    await db.into(db.paragraphs).insert(ParagraphsCompanion.insert(
        projectId: 1, chapterId: const Value(2), idx: 2, content: '店家压低了声音。'));
    await db.into(db.annotations).insert(AnnotationsCompanion.insert(
        paraId: 1,
        type: 'L1',
        contentJson: jsonEncode({'text': '少年表面平静实则紧张'})));
    await db.into(db.annotations).insert(AnnotationsCompanion.insert(
        paraId: 1,
        type: 'L3',
        contentJson: jsonEncode(
            {'term': '拜帖', 'text': '递帖求见的礼数', 'uncertain': true})));
    await db.into(db.annotations).insert(AnnotationsCompanion.insert(
        paraId: 2,
        type: 'L4',
        contentJson: jsonEncode({
          'question': '若你是乙会硬刚吗',
          'perspectives': ['硬刚到底', '虚与委蛇']
        })));
    await db.into(db.annotations).insert(AnnotationsCompanion.insert(
        paraId: 3,
        type: 'L1',
        contentJson: jsonEncode({'text': '第二章批注'})));
    await db.into(db.characters).insert(CharactersCompanion.insert(
        projectId: 1,
        name: '余则成',
        aliasesJson: const Value('热血少年剑客')));
  }

  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsRepoProvider
              .overrideWithValue(SettingsRepository(db, FlutterSecureStorage())),
        ],
        child: MaterialApp(home: child),
      );

  testWidgets('气泡角标渲染；L1/L3 点开底部弹层显示内容', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const ReaderPage(projectId: 1)));
    await tester.pumpAndSettle();

    expect(find.text('少年背剑而行。'), findsOneWidget);
    expect(find.text('风起于青萍之末。'), findsOneWidget);
    expect(find.text('店家压低了声音。'), findsNothing); // 第二章未打开
    expect(find.text('L1'), findsOneWidget);
    expect(find.text('L3'), findsOneWidget);
    expect(find.text('L4'), findsNothing); // L4 是段间卡片不是角标

    // L1 弹层
    await tester.tap(find.text('L1'));
    await tester.pumpAndSettle();
    expect(find.text('L1 潜台词'), findsOneWidget);
    expect(find.text('少年表面平静实则紧张'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    // L3 弹层：词条 + 不确定标记
    await tester.tap(find.text('L3'));
    await tester.pumpAndSettle();
    expect(find.text('L3 知识'), findsOneWidget);
    expect(find.text('拜帖'), findsOneWidget);
    expect(find.text('递帖求见的礼数'), findsOneWidget);
    expect(find.text('不确定，仅供参考'), findsOneWidget);
  });

  testWidgets('L4 段间卡片：提交回答 → 参考视角 → qa_records 落库', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const ReaderPage(projectId: 1)));
    await tester.pumpAndSettle();

    expect(find.text('L4 思考题'), findsOneWidget);
    expect(find.text('若你是乙会硬刚吗'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '我会先稳住他');
    await tester.tap(find.text('提交回答'));
    await tester.pumpAndSettle();

    expect(find.text('我的回答：我会先稳住他'), findsOneWidget);
    expect(find.text('参考视角'), findsOneWidget);
    expect(find.text('• 硬刚到底'), findsOneWidget);
    expect(find.text('• 虚与委蛇'), findsOneWidget);

    final recs = await db.select(db.qaRecords).get();
    expect(recs, hasLength(1));
    expect(recs.single.userAnswer, '我会先稳住他');
    expect(recs.single.skipped, isFalse);
    final qs = await db.select(db.questions).get();
    expect(qs.single.question, '若你是乙会硬刚吗');
    expect(jsonDecode(qs.single.perspectivesJson), hasLength(2));
  });

  testWidgets('L4 跳过本题也记录（skipped=true）', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const ReaderPage(projectId: 1)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('跳过本题'));
    await tester.pumpAndSettle();
    expect(find.text('已跳过'), findsOneWidget);
    expect(find.text('• 硬刚到底'), findsOneWidget);

    final recs = await db.select(db.qaRecords).get();
    expect(recs.single.skipped, isTrue);
  });

  testWidgets('阅读设置：夜间背景切换并持久化；字号滑杆生效', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const ReaderPage(projectId: 1)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.text_fields));
    await tester.pumpAndSettle();

    await tester.tap(find.text('夜间'));
    await tester.pumpAndSettle();
    final scaffold = tester.widget<Scaffold>(
        find.descendant(of: find.byType(ReaderPage), matching: find.byType(Scaffold)));
    expect(scaffold.backgroundColor, const Color(0xFF141414));
    final saved = await (db.select(db.settings)
          ..where((t) => t.key.equals('reader.theme')))
        .getSingle();
    expect(saved.value, 'night');

    // 字号滑杆右拖 → 段落字号增大
    await tester.drag(find.byType(Slider).first, const Offset(80, 0));
    await tester.pumpAndSettle();
    final textWidget = tester.widget<Text>(find.text('少年背剑而行。'));
    expect(textWidget.style!.fontSize, greaterThan(17));
    final size = await (db.select(db.settings)
          ..where((t) => t.key.equals('reader.font_size')))
        .getSingle();
    expect(double.parse(size.value), greaterThan(17));
  });

  testWidgets('章节抽屉切换章节', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const ReaderPage(projectId: 1)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    // 抽屉中当前章高亮、目标章未选中
    ListTile tileOf(String title) => tester.widget<ListTile>(find.ancestor(
        of: find.text(title), matching: find.byType(ListTile)));
    expect(tileOf('第一章 山门').selected, isTrue);
    expect(tileOf('第二章 客栈').selected, isFalse);

    await tester.tap(find.text('第二章 客栈'));
    await tester.pumpAndSettle();

    expect(find.text('店家压低了声音。'), findsOneWidget);
    expect(find.text('少年背剑而行。'), findsNothing);
  });

  testWidgets('本书人物列表显示人设', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const ReaderPage(projectId: 1)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.groups));
    await tester.pumpAndSettle();
    expect(find.text('本书人物'), findsOneWidget);
    expect(find.text('余则成'), findsOneWidget);
    expect(find.text('热血少年剑客'), findsOneWidget);
  });
}
