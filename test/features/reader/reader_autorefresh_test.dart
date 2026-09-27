import 'dart:convert';

import 'package:drift/drift.dart' show Value;
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

  Widget wrap(_StubPipelineController stub) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsRepoProvider.overrideWithValue(
              SettingsRepository(db, const FlutterSecureStorage())),
          pipelineControllerProvider.overrideWith(() => stub),
        ],
        child: const MaterialApp(home: ReaderPage(projectId: 1)),
      );

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
}
