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
import 'package:peixi/features/reader/reader_page.dart';
import 'package:peixi/providers.dart';

/// 阅读器批注随到随显（Plan 2 Task 11）：管线事件防抖 800ms 重载当前章批注；
/// 当前章 annotDone=false 且引擎运行中 → 「本章批注生成中」轻提示。
class _StubPipelineController extends PipelineController {
  @override
  Map<int, PipelineState> build() => const {};

  void push(int projectId, PipelineState s) => state = {...state, projectId: s};
}

/// 按条件闸住 SELECT：命中谓词的查询停到 release() 为止，
/// 用于把 _reloadAnnotations 停在"按旧章 paraId 查批注"的中间，制造切章竞态。
class _ArgGateInterceptor extends QueryInterceptor {
  Completer<void>? _gate;
  final parked = Completer<void>();

  void arm(bool Function(String statement, List<Object?> args) when) {
    _gate = Completer<void>();
    _when = when;
  }

  bool Function(String statement, List<Object?> args)? _when;

  void release() => _gate?.complete();

  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor executor,
      String statement, List<Object?> args) async {
    final gate = _gate;
    if (gate != null && !gate.isCompleted && _when != null && _when!(statement, args)) {
      if (!parked.isCompleted) parked.complete();
      await gate.future;
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

  Future<void> seed() async {
    // 当前章（idx 0）尚未批注完成
    await db.into(db.projects).insert(ProjectsCompanion.insert(
          type: 'novel',
          title: '测试小说',
          sourcePath: '/book.txt',
          status: 'IMPORTED',
        ));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        projectId: 1, idx: 0, startPara: 0, endPara: 1));
    await db.into(db.paragraphs).insert(ParagraphsCompanion.insert(
        projectId: 1, chapterId: const Value(1), idx: 0, content: '少年背剑而行。'));
    await db.into(db.paragraphs).insert(ParagraphsCompanion.insert(
        projectId: 1, chapterId: const Value(1), idx: 1, content: '风起于青萍之末。'));
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
        child: const MaterialApp(home: ReaderPage(projectId: 1)),
      );
  }

  /// 两章各一段、各带一条 L1：ch0/para1(L1-A)、ch1/para2(L1-B)。
  Future<void> seedTwoChapters(AppDatabase d) async {
    await d.into(d.projects).insert(ProjectsCompanion.insert(
          type: 'novel',
          title: '测试小说',
          sourcePath: '/book.txt',
          status: 'IMPORTED',
        ));
    await d.into(d.chapters).insert(ChaptersCompanion.insert(
        projectId: 1, idx: 0, title: const Value('第一章'), startPara: 0, endPara: 0));
    await d.into(d.chapters).insert(ChaptersCompanion.insert(
        projectId: 1, idx: 1, title: const Value('第二章'), startPara: 1, endPara: 1));
    await d.into(d.paragraphs).insert(ParagraphsCompanion.insert(
        projectId: 1, chapterId: const Value(1), idx: 0, content: '第一章正文。'));
    await d.into(d.paragraphs).insert(ParagraphsCompanion.insert(
        projectId: 1, chapterId: const Value(2), idx: 1, content: '第二章正文。'));
    await d.into(d.annotations).insert(AnnotationsCompanion.insert(
        paraId: 1, type: 'L1', contentJson: jsonEncode({'text': '旧章批注'})));
    await d.into(d.annotations).insert(AnnotationsCompanion.insert(
        paraId: 2, type: 'L1', contentJson: jsonEncode({'text': '新章批注'})));
  }

  testWidgets('生成中提示显隐：busy 且当前章未批注时出现，annotDone 翻位后消失',
      (tester) async {
    final stub = _StubPipelineController();
    await seed();
    // get 语法不能用于函数局部声明，故在测试体内局部定义 Finder
    final hint = find.textContaining('本章批注生成中');
    await tester.pumpWidget(wrap(stub));
    await tester.pumpAndSettle();

    // 空闲（无管线事件）不提示
    expect(hint, findsNothing);

    // 引擎开始运行 → 轻提示出现
    stub.push(1, const PipelineState(stage: 'novel', detail: '地图 1/1 章'));
    await tester.pump();
    expect(hint, findsOneWidget);

    // 引擎停止（busy=false，如已取消）→ 提示消失（本章仍未批注）
    stub.push(
        1,
        const PipelineState(
            stage: 'novel', busy: false, detail: '已取消（进度已保存，可继续）'));
    await tester.pump();
    expect(hint, findsNothing);

    // 防抖 Timer 结束后再收尾，避免悬挂定时器
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    await closeDb();
  });

  testWidgets('管线事件到达 → 防抖 800ms 内不刷新，之后批注气泡出现（无需重进页面）',
      (tester) async {
    final stub = _StubPipelineController();
    await seed();
    final hint = find.textContaining('本章批注生成中');
    await tester.pumpWidget(wrap(stub));
    await tester.pumpAndSettle();

    stub.push(1, const PipelineState(stage: 'novel', detail: '地图 1/1 章'));
    await tester.pump();
    expect(hint, findsOneWidget);

    // 批注落库 + annotDone 翻位，随后进度事件到达
    await (db.update(db.chapters)..where((t) => t.id.equals(1)))
        .write(const ChaptersCompanion(annotDone: Value(true)));
    await db.into(db.annotations).insert(AnnotationsCompanion.insert(
        paraId: 1,
        type: 'L1',
        contentJson: jsonEncode({'text': '少年表面平静，实则剑意已动'})));
    stub.push(1, const PipelineState(stage: 'novel', detail: '批注 1/1 章'));

    // 防抖：事件到达 800ms 内不重载
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('L1'), findsNothing);
    expect(hint, findsOneWidget);

    // 越过防抖窗口 → 批注出现、提示消失
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('L1'), findsOneWidget);
    expect(find.textContaining('本章批注生成中'), findsNothing);
    await closeDb();
  });

  testWidgets('事件持续高频到达：maxWait 2s 兜底强制刷新（防饥饿）', (tester) async {
    final stub = _StubPipelineController();
    await seed();
    await tester.pumpWidget(wrap(stub));
    await tester.pumpAndSettle();
    expect(find.text('L1'), findsNothing);

    // 批注落库，随后事件每 500ms 一个，防抖窗口不断被重置
    await db.into(db.annotations).insert(AnnotationsCompanion.insert(
        paraId: 1, type: 'L1', contentJson: jsonEncode({'text': '迟到批注'})));
    stub.push(1, const PipelineState(stage: 'novel', detail: '批注 0'));
    await tester.pump();
    for (var i = 1; i <= 3; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      stub.push(1, PipelineState(stage: 'novel', detail: '批注 $i'));
    }
    // t≈1.5s：仍被防抖推迟（无 maxWait 时会一直饥饿）
    expect(find.text('L1'), findsNothing);

    // t=2.0s：距首个未处理事件满 2s → 强制刷新
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('L1'), findsOneWidget);
    await closeDb();
  });

  testWidgets('切章竞态：旧章批注重载返回时不写回新章视图（首 paraId 守卫）', (tester) async {
    // 默认库换成本测试专用的闸门库（先关默认库，避免双库并存的 drift 警告；
    // tearDown 仍会关掉替换后的 db）
    await db.close();
    final gate = _ArgGateInterceptor();
    final gdb = AppDatabase(NativeDatabase.memory().interceptWith(gate));
    db = gdb;
    final stub = _StubPipelineController();
    await seedTwoChapters(gdb);
    await tester.pumpWidget(wrap(stub, database: gdb));
    await tester.pumpAndSettle();
    expect(find.text('L1'), findsOneWidget); // 第 0 章的 L1-A

    // 事件到达 → 防抖 800ms 后重载；闸住"按 para1 查批注"的查询
    gate.arm((s, a) => s.contains('annotations') && a.contains(1));
    stub.push(1, const PipelineState(stage: 'novel', detail: '批注进行中'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(gate.parked.isCompleted, isTrue, reason: '旧章批注查询已停摆');

    // 停摆期间用户切到第二章（其批注查询 args=[2]，不受闸影响）
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第二章'));
    await tester.pumpAndSettle();
    expect(find.text('L1'), findsOneWidget, reason: '第二章自己的 L1-B');

    // 释放闸口：旧章重载返回。守卫按首 paraId 识别已切章，整体丢弃写回
    gate.release();
    await tester.pump();
    await tester.pump();
    expect(find.text('L1'), findsOneWidget,
        reason: '无守卫时旧章 _anns 会冲掉第二章刚显示的批注');
    await closeDb();
  });
}
