import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/cards/cards_page.dart';
import 'package:peixi/features/review/review_page.dart';
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
        type: 'video', title: '潜伏', sourcePath: '/a.mkv', status: 'READY'));
    await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'novel', title: '暗夜与黎明', sourcePath: '/b.txt', status: 'READY'));
    // 卡片：潜伏 2 张（1 张不确定），novel 1 张
    await db.into(db.knowledgeCards).insert(KnowledgeCardsCompanion.insert(
        projectId: 1, term: '军统', title: '军统', content: '国民政府军事委员会调查统计局'));
    await db.into(db.knowledgeCards).insert(KnowledgeCardsCompanion.insert(
        projectId: 1,
        term: '拜帖',
        title: '拜帖',
        content: '递帖求见的礼数',
        uncertain: const Value(true)));
    await db.into(db.knowledgeCards).insert(KnowledgeCardsCompanion.insert(
        projectId: 2, term: '锦衣卫', title: '锦衣卫', content: '明代皇帝亲军机构'));
    // 问答：潜伏 1 答 1 跳过
    final q1 = await db.into(db.questions).insert(QuestionsCompanion.insert(
        projectId: 1,
        question: '如果你是余则成会怎么回答站长？',
        perspectivesJson: Value(jsonEncode(['稳住对方', '拖延时间', '反问试探']))));
    final q2 = await db.into(db.questions).insert(QuestionsCompanion.insert(
        projectId: 1,
        question: '翠平该不该烧掉名单？',
        perspectivesJson: Value(jsonEncode(['烧掉保命', '留下保情报']))));
    await db.into(db.qaRecords).insert(QaRecordsCompanion.insert(
        questionId: q1,
        userAnswer: '先稳住，再找机会汇报重庆',
        skipped: const Value(false)));
    await db.into(db.qaRecords).insert(QaRecordsCompanion.insert(
        questionId: q2, userAnswer: '', skipped: const Value(true)));
  }

  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsRepoProvider
              .overrideWithValue(SettingsRepository(db, FlutterSecureStorage())),
        ],
        child: MaterialApp(home: child),
      );

  testWidgets('卡片集：按项目分组渲染 + 不确定标记 + 搜索过滤', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const CardsPage()));
    await tester.pumpAndSettle();

    expect(find.text('卡片集（3）'), findsOneWidget);
    expect(find.text('潜伏'), findsOneWidget); // 分组头
    expect(find.text('军统'), findsOneWidget);
    expect(find.text('拜帖'), findsOneWidget);
    expect(find.text('不确定'), findsOneWidget);
    expect(find.text('锦衣卫'), findsOneWidget);
    expect(find.text('2 张卡片'), findsOneWidget);

    // 搜索"军统" → 只剩命中卡片（搜索词本身也在输入框里匹配）
    await tester.enterText(find.byType(TextField), '军统');
    await tester.pumpAndSettle();
    expect(find.text('军统'), findsWidgets);
    expect(find.text('锦衣卫'), findsNothing);
    expect(find.text('卡片集（1）'), findsNothing); // 总数统计不随搜索变化
  });

  testWidgets('卡片集：空态', (tester) async {
    await tester.pumpWidget(wrap(const CardsPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('还没有知识卡片'), findsOneWidget);
  });

  test('连续答题天数计算', () {
    final today = DateTime(2026, 8, 28, 15, 0);
    DateTime d(int ago) => today.subtract(Duration(days: ago));
    expect(streakDays([], now: today), 0);
    expect(streakDays([d(3)], now: today), 0, reason: '最近答题在 3 天前 → 已断');
    expect(streakDays([d(0)], now: today), 1);
    expect(streakDays([d(1)], now: today), 1, reason: '昨天答题也算连续');
    expect(streakDays([d(0), d(1), d(2)], now: today), 3);
    expect(streakDays([d(0), d(1), d(3)], now: today), 2, reason: '断档后只数连续段');
    expect(streakDays([d(0), d(0)], now: today), 1, reason: '同日去重');
  });

  testWidgets('复盘：统计 + 时间线（回答/跳过/参考视角）', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const ReviewPage()));
    await tester.pumpAndSettle();

    expect(find.text('已答 1'), findsOneWidget);
    expect(find.text('跳过 1'), findsOneWidget);
    expect(find.text('已跳过'), findsOneWidget);
    expect(find.text('我的回答：先稳住，再找机会汇报重庆'), findsOneWidget);
    expect(find.text('• 稳住对方'), findsOneWidget);
    expect(find.text('• 拖延时间'), findsOneWidget);
    expect(find.text('• 反问试探'), findsOneWidget);
    expect(find.textContaining('潜伏 ·'), findsNWidgets(2));
  });

  testWidgets('复盘：空态', (tester) async {
    await tester.pumpWidget(wrap(const ReviewPage()));
    await tester.pumpAndSettle();
    expect(find.text('还没有答题记录'), findsOneWidget);
  });
}
