import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/cards/cards_page.dart';
import 'package:peixi/features/cards/srs_review_page.dart';
import 'package:peixi/providers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _NoWakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
  @override
  Future<bool> get enabled async => false;
}

void main() {
  late AppDatabase db;

  setUpAll(() => wakelockPlusPlatformInstance = _NoWakelock());

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => db.close());

  Future<void> seed() async {
    await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'video', title: '潜伏', sourcePath: '/a.mkv', status: 'READY'));
    await db.into(db.knowledgeCards).insert(KnowledgeCardsCompanion.insert(
        projectId: 1, term: '军统', title: '军统', content: '调查统计局'));
    await db.into(db.knowledgeCards).insert(KnowledgeCardsCompanion.insert(
        projectId: 1, term: '拜帖', title: '拜帖', content: '递帖求见的礼数'));
  }

  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsRepoProvider
              .overrideWithValue(SettingsRepository(db, FlutterSecureStorage())),
        ],
        child: MaterialApp(home: child),
      );

  /// pumpAndSettle 之外再冲一段假时间：drift watch 的 Timer.run 通知
  /// 不产生帧，若不冲掉会在测试结束时报 pending timer。
  Future<void> flush(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  /// 测试收尾：卸载 widget 树（StreamBuilder 退订 → drift markAsClosed
  /// 排程零时长 Timer），再推进假时间触发它。否则 pending timer 断言失败，
  /// 且 tearDown 里的 db.close() 会永远等不到流关闭而卡死。
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('编辑卡片：修改解释后保存落库', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const CardsPage()));
    await flush(tester);

    await tester.tap(find.text('军统').first);
    await flush(tester);

    // 用 labelText 定位弹窗内字段（页面上还有搜索框）
    await tester.enterText(find.widgetWithText(TextField, '解释'), '国民政府军事委员会调查统计局');
    await tester.tap(find.text('保存'));
    await flush(tester);

    final card = await (db.select(db.knowledgeCards)
          ..where((t) => t.term.equals('军统')))
        .getSingle();
    expect(card.content, '国民政府军事委员会调查统计局');
    await unmount(tester);
  });

  testWidgets('改 term 撞唯一约束：不落库并提示', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const CardsPage()));
    await flush(tester);

    await tester.tap(find.text('拜帖').first);
    await flush(tester);
    await tester.enterText(find.widgetWithText(TextField, '词条'), '军统');
    await tester.tap(find.text('保存'));
    await flush(tester);

    final terms = (await db.select(db.knowledgeCards).get())
        .map((c) => c.term)
        .toSet();
    expect(terms, {'军统', '拜帖'}, reason: '撞约束时保留原词条');
    expect(find.text('保存失败：该词条在同一项目下已存在'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('删除卡片：确认后从库中移除', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const CardsPage()));
    await flush(tester);

    await tester.tap(find.text('拜帖').first);
    await flush(tester);
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await flush(tester);
    await tester.tap(find.widgetWithText(FilledButton, '删除').last);
    await flush(tester);

    final terms = (await db.select(db.knowledgeCards).get())
        .map((c) => c.term)
        .toList();
    expect(terms, ['军统']);
    await unmount(tester);
  });

  testWidgets('复习会话：翻面 → 评分 → 调度落库 → 会话完成', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const SrsReviewPage(projectId: 1)));
    await flush(tester);

    expect(find.text('复习 1/2'), findsOneWidget);
    expect(find.text('显示答案'), findsOneWidget);
    await tester.tap(find.text('显示答案'));
    await flush(tester);
    expect(find.text('递帖求见的礼数'), findsOneWidget);

    await tester.tap(find.textContaining('想起'));
    await flush(tester);
    expect(find.text('复习 2/2'), findsOneWidget);

    await tester.tap(find.text('显示答案'));
    await flush(tester);
    await tester.tap(find.textContaining('忘了'));
    await flush(tester);

    expect(find.textContaining('已复习 2 张'), findsOneWidget);

    final cards = await db.select(db.knowledgeCards).get();
    final byTerm = {for (final c in cards) c.term: c};
    expect(byTerm['拜帖']!.reps, 1, reason: 'good 评分 reps+1');
    expect(byTerm['拜帖']!.ivlDays, 1.0);
    expect(byTerm['军统']!.reps, 0, reason: 'again 清零');
    expect(byTerm['军统']!.lapses, 1);
    expect(byTerm['军统']!.dueAt!.isAfter(DateTime.now()), isTrue,
        reason: 'again 10 分钟后到期');
    await unmount(tester);
  });

  testWidgets('AppBar 显示到期计数', (tester) async {
    await seed();
    await tester.pumpWidget(wrap(const CardsPage()));
    await flush(tester);
    expect(find.text('卡片集（2）· 到期 2'), findsOneWidget,
        reason: 'SRS 列全为默认值 = 全部新卡，均计入到期');
    await unmount(tester);
  });
}
