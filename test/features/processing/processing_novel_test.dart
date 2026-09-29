import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/pipeline/pipeline_controller.dart';
import 'package:peixi/features/processing/processing_page.dart';
import 'package:peixi/providers.dart';

/// 小说处理页（Plan 2 Task 10）：双泳道按 DB 聚合渲染 + token 花费 +
/// 领先徽章 + 单章重批 + 新 failed_stage 口径。
class _StubPipelineController extends PipelineController {
  final retried = <int>[];
  final reannotated = <(int, int)>[];

  /// 非空时 reannotateChapter 挂起，模拟重批进行中（widget 测双击穿透）。
  Completer<void>? hang;

  @override
  Map<int, PipelineState> build() => const {};

  @override
  Future<void> retry(int projectId) async {
    retried.add(projectId);
  }

  @override
  Future<void> reannotateChapter(int projectId, int chapterIdx) async {
    reannotated.add((projectId, chapterIdx));
    if (hang != null) await hang!.future;
  }

  void push(int projectId, PipelineState s) => state = {...state, projectId: s};
}

/// 闸住 llm_logs 的 SELECT：每个命中查询进 FIFO 队列等待放行，
/// 用于让 _reload 停在最后一次查询上，制造新旧两次重载的竞态窗口。
class _LlmLogGate extends QueryInterceptor {
  final queue = <Completer<void>>[];

  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor executor,
      String statement, List<Object?> args) async {
    if (statement.contains('llm_logs')) {
      final c = Completer<void>();
      queue.add(c);
      await c.future;
    }
    return executor.runSelect(statement, args);
  }
}

void main() {
  late AppDatabase db;
  var dbClosed = false;

  Future<void> closeDb() async {
    if (dbClosed) return;
    dbClosed = true;
    await db.close();
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dbClosed = false;
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(closeDb);

  /// 10 章书：3 章 mapDone、2 章 annotDone、llm_logs 两行（10+20 ×2 = 60），
  /// 阅读进度停在章 0 → 领先 2 章。
  Future<void> seedBook(
      {String status = 'IMPORTED', String? failedStage, AppDatabase? target}) async {
    final d = target ?? db;
    final meta = jsonEncode(const {
      'chapterCount': 10,
      'annotatedChapters': 2,
      'reading': {'chapterIdx': 0, 'scrollOffset': 0.0},
    });
    await d.into(d.projects).insert(ProjectsCompanion.insert(
          type: 'novel',
          title: '测试小说',
          sourcePath: '/book.txt',
          status: status,
          failedStage: Value(failedStage),
          metaJson: Value(meta),
        ));
    for (var i = 0; i < 10; i++) {
      await d.into(d.chapters).insert(ChaptersCompanion.insert(
            projectId: 1,
            idx: i,
            startPara: i * 2,
            endPara: i * 2 + 1,
            mapDone: Value(i < 3),
            annotDone: Value(i < 2),
            summary: Value(i < 3 ? '第$i章摘要' : null),
          ));
    }
    for (var i = 0; i < 2; i++) {
      await d.into(d.llmLogs).insert(LlmLogsCompanion.insert(
            projectId: const Value(1),
            purpose: 'novel_map',
            model: 'flash',
            promptTokens: const Value(10),
            completionTokens: const Value(20),
          ));
    }
  }

  Widget wrap(_StubPipelineController stub, {AppDatabase? database}) {
    final d = database ?? db;
    return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(d),
          settingsRepoProvider.overrideWithValue(
              SettingsRepository(d, const FlutterSecureStorage())),
          pipelineControllerProvider.overrideWith(() => stub),
        ],
        child: const MaterialApp(home: ProcessingPage(projectId: 1)),
      );
  }

  FilledButton reannotateButton(WidgetTester tester) =>
      tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, '重新批注此章'));

  testWidgets('双泳道按 DB 聚合渲染：地图/批注进度、领先徽章、token 花费', (tester) async {
    final stub = _StubPipelineController();
    await seedBook();
    await tester.pumpWidget(wrap(stub));
    await tester.pumpAndSettle();

    expect(find.text('地图 3/10 章'), findsOneWidget);
    expect(find.text('批注 2/10 章'), findsOneWidget);
    expect(find.text('领先阅读 2 章'), findsOneWidget);
    expect(find.text('本书已耗 token 60'), findsOneWidget);

    final bars = tester
        .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator))
        .toList();
    expect(bars, hasLength(2));
    expect(bars[0].value, closeTo(0.3, 1e-6));
    expect(bars[1].value, closeTo(0.2, 1e-6));
    await closeDb();
  });

  testWidgets('运行中：重批按钮禁用；空闲后可用并触发 controller.reannotateChapter',
      (tester) async {
    final stub = _StubPipelineController();
    await seedBook();
    await tester.pumpWidget(wrap(stub));
    await tester.pumpAndSettle();

    // 运行中（busy）——顶部有无限转圈动画，用 pump 推进而非 pumpAndSettle
    stub.push(1, const PipelineState(stage: 'novel', detail: '地图 3/10 章'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(reannotateButton(tester).onPressed, isNull);

    // 已取消/空闲（busy=false）：detail 以次要文字显示在泳道卡内
    stub.push(
        1,
        const PipelineState(
            stage: 'novel', busy: false, detail: '已取消（进度已保存，可继续）'));
    await tester.pump();
    await tester.pump();
    expect(find.text('已取消（进度已保存，可继续）'), findsOneWidget);

    // 非法章号禁用
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(reannotateButton(tester).onPressed, isNull);

    // 合法章号：按钮可用，点击触发单章重批
    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();
    expect(reannotateButton(tester).onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, '重新批注此章'));
    await tester.pump();
    expect(stub.reannotated, [
      (1, 2)
    ]);
    await closeDb();
  });

  testWidgets('FAILED：新 failed_stage 标签（地图/摘要快照/批注）+ 重试触发 controller.retry',
      (tester) async {
    final stub = _StubPipelineController();
    await seedBook(status: 'FAILED', failedStage: 'digest');
    await tester.pumpWidget(wrap(stub));
    await tester.pumpAndSettle();

    expect(find.text('重试「摘要快照」'), findsOneWidget);
    await tester.tap(find.text('重试「摘要快照」'));
    await tester.pump();
    expect(stub.retried, [1]);
    await closeDb();
  });

  testWidgets('FAILED 地图阶段：标签为「地图」', (tester) async {
    final stub = _StubPipelineController();
    await seedBook(status: 'FAILED', failedStage: 'map');
    await tester.pumpWidget(wrap(stub));
    await tester.pumpAndSettle();
    expect(find.text('重试「地图」'), findsOneWidget);
    await closeDb();
  });

  testWidgets('FAILED 批注阶段：标签为「批注」', (tester) async {
    final stub = _StubPipelineController();
    await seedBook(status: 'FAILED', failedStage: 'annotate');
    await tester.pumpWidget(wrap(stub));
    await tester.pumpAndSettle();
    expect(find.text('重试「批注」'), findsOneWidget);
    await closeDb();
  });

  testWidgets('重批进行中：按钮禁用防双击穿透，完成后恢复可用', (tester) async {
    final stub = _StubPipelineController();
    await seedBook();
    await tester.pumpWidget(wrap(stub));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();
    expect(reannotateButton(tester).onPressed, isNotNull);

    // 第一次点击：重批挂起进行中
    stub.hang = Completer<void>();
    await tester.tap(find.widgetWithText(FilledButton, '重新批注此章'));
    await tester.pump();
    await tester.pump();
    expect(stub.reannotated, [(1, 2)]);
    expect(reannotateButton(tester).onPressed, isNull, reason: '重批进行中禁用');

    // 进行中再点不再入队（双击穿透防护）
    await tester.tap(find.widgetWithText(FilledButton, '重新批注此章'));
    await tester.pump();
    expect(stub.reannotated, hasLength(1));

    // 完成（含完成后重载）→ 按钮恢复
    stub.hang!.complete();
    await tester.pumpAndSettle();
    expect(reannotateButton(tester).onPressed, isNotNull);
    expect(stub.reannotated, hasLength(1));
    await closeDb();
  });

  testWidgets('章号超界禁用：0 起编号，n 必须 < 总章数', (tester) async {
    final stub = _StubPipelineController();
    await seedBook(); // 10 章（idx 0..9）
    await tester.pumpWidget(wrap(stub));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '10');
    await tester.pump();
    expect(reannotateButton(tester).onPressed, isNull, reason: 'n=10 越界');

    await tester.enterText(find.byType(TextField), '9');
    await tester.pump();
    expect(reannotateButton(tester).onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();
    expect(reannotateButton(tester).onPressed, isNotNull);
    await closeDb();
  });

  testWidgets('_reload 并发守卫：慢查询返回的旧快照不回写（seq 丢弃）', (tester) async {
    await closeDb(); // 本测试用闸门库，先关掉默认库避免双库并存的 drift 警告
    final gate = _LlmLogGate();
    final gdb = AppDatabase(NativeDatabase.memory().interceptWith(gate));
    addTearDown(gdb.close);
    final stub = _StubPipelineController();
    await seedBook(target: gdb);
    await tester.pumpWidget(wrap(stub, database: gdb));
    await tester.pump();
    await tester.pump();
    expect(gate.queue, hasLength(1), reason: '首次重载停在 llm_logs 查询');

    // 旧快照停摆期间：token 涨了 30，并触发第二次重载
    await gdb.into(gdb.llmLogs).insert(LlmLogsCompanion.insert(
          projectId: const Value(1),
          purpose: 'novel_annotate',
          model: 'deep',
          promptTokens: const Value(30),
          completionTokens: const Value(0),
        ));
    stub.push(1, const PipelineState(stage: 'novel', busy: false, detail: '刷新'));
    await tester.pump();
    await tester.pump();
    expect(gate.queue, hasLength(2));

    gate.queue[1].complete(); // 新查询先回 → 显示 90
    await tester.pump();
    gate.queue[0].complete(); // 旧查询后回 → 应被 seq 守卫丢弃
    await tester.pump();
    await tester.pump();

    expect(find.text('本书已耗 token 90'), findsOneWidget,
        reason: '旧重载不得用过期计数覆盖新数据');
  });
}
