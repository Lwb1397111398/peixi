import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/player/commentary_card.dart';
import 'package:peixi/features/player/quiz_overlay.dart';

Scene sceneRow(int id, int idx, {String importance = 'normal', String? summary}) =>
    Scene(
        id: id,
        projectId: 1,
        idx: idx,
        startMs: 0,
        endMs: 100000,
        summary: summary,
        importance: importance);

Commentary commentaryRow(int sceneId, {String l2 = '[]'}) => Commentary(
    id: 1,
    sceneId: sceneId,
    l1Subtext: '表面汇报，实则试探',
    l2PsychologyJson: l2,
    status: 'done',
    model: 'qwen-plus',
    createdAt: DateTime(2026));

KnowledgeCard cardRow(int id, String term) => KnowledgeCard(
    id: id,
    projectId: 1,
    term: term,
    title: term,
    content: '背景知识内容',
    firstSceneIdx: 0,
    uncertain: false);

Widget wrap(Widget child) =>
    MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child));

void main() {
  testWidgets('L1 常显；L2/L3 折叠，点开显示角色分析；胶囊弹出卡片',
      (tester) async {
    const l2 = '[{"character":"余则成","analysis":"谨慎试探"}]';
    await tester.pumpWidget(wrap(SingleChildScrollView(
      child: CommentaryCard(
        scene: sceneRow(1, 0, importance: 'high', summary: '汇报'),
        commentary: commentaryRow(1, l2: l2),
        cards: [cardRow(7, '军统')],
        colorByName: const {'余则成': Colors.red},
      ),
    )));

    expect(find.text('L1 潜台词'), findsOneWidget);
    expect(find.text('表面汇报，实则试探'), findsOneWidget);
    expect(find.text('关键场景'), findsOneWidget);
    expect(find.text('汇报'), findsOneWidget);

    // L2 默认折叠
    expect(find.text('谨慎试探'), findsNothing);
    await tester.tap(find.text('L2 心理'));
    await tester.pumpAndSettle();
    expect(find.textContaining('谨慎试探', findRichText: true), findsOneWidget);
    expect(find.textContaining('余则成', findRichText: true), findsOneWidget);

    // L3 胶囊 → 底部卡片（先展开 L3）
    await tester.tap(find.text('L3 知识'));
    await tester.pumpAndSettle();
    expect(find.text('军统'), findsOneWidget);
    await tester.tap(find.text('军统'));
    await tester.pumpAndSettle();
    expect(find.text('背景知识内容'), findsOneWidget);
  });

  testWidgets('forceExpand（暂停深读）时 L2 直接展开', (tester) async {
    await tester.pumpWidget(wrap(SingleChildScrollView(
      child: CommentaryCard(
        scene: sceneRow(1, 0),
        commentary: commentaryRow(1,
            l2: '[{"character":"李涯","analysis":"急功近利"}]'),
        cards: const [],
        colorByName: const {},
        forceExpand: true,
      ),
    )));
    expect(find.textContaining('急功近利', findRichText: true), findsOneWidget);
  });

  testWidgets('解说缺失占位', (tester) async {
    await tester.pumpWidget(wrap(SingleChildScrollView(
      child: CommentaryCard(
          scene: sceneRow(1, 0), commentary: null, cards: const [], colorByName: const {}),
    )));
    expect(find.textContaining('解说缺失'), findsOneWidget);
  });

  testWidgets('QuizOverlay：提交回答 → perspectives → 继续播放',
      (tester) async {
    String? submitted;
    var resumed = false;
    var skipped = false;
    await tester.pumpWidget(wrap(QuizOverlay(
      question: '如果你是余则成，你会如何接这句话？',
      perspectives: const ['立场角度', '情感角度', '风险角度'],
      onSubmit: (a) => submitted = a,
      onSkip: () => skipped = true,
      onResume: () => resumed = true,
    )));

    await tester.enterText(find.byType(TextField), '我会先稳住他');
    await tester.pump(); // 等监听器刷新按钮可用态
    await tester.tap(find.text('提交回答'));
    await tester.pumpAndSettle();

    expect(submitted, '我会先稳住他');
    expect(skipped, isFalse);
    expect(find.text('立场角度'), findsOneWidget);
    expect(find.text('继续播放'), findsOneWidget);

    await tester.tap(find.text('继续播放'));
    await tester.pump();
    expect(resumed, isTrue);
  });

  testWidgets('QuizOverlay：跳过也记录', (tester) async {
    var skipped = false;
    await tester.pumpWidget(wrap(QuizOverlay(
      question: 'Q',
      perspectives: const [],
      onSubmit: (_) {},
      onSkip: () => skipped = true,
      onResume: () {},
    )));
    await tester.tap(find.text('跳过本题'));
    await tester.pumpAndSettle();
    expect(skipped, isTrue);
    expect(find.text('已跳过。参考视角：'), findsOneWidget);
  });
}
