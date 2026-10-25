import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/library/library_page.dart';
import 'package:peixi/features/pipeline/pipeline_controller.dart';
import 'package:peixi/features/pipeline/project_status.dart';
import 'package:peixi/features/player/player_page.dart';
import 'package:peixi/features/processing/processing_page.dart';
import 'package:peixi/features/reader/reader_page.dart';
import 'package:peixi/providers.dart';

/// 库页入口闸门（Plan 2 Task 9）：小说导入即可读 + 批注进度徽章。
/// 桩控制器：不自动续跑、不产生管线事件，卡片渲染纯按 DB 状态。
class _StubPipelineController extends PipelineController {
  @override
  Map<int, PipelineState> build() => const {};
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
  // 树卸载时 drift 流缓存会调度零延时 Timer，须在 widget 测试体内先关库
  // （同 widget_test.dart 约定）；tearDown 兜底纯 db 测试。
  tearDown(closeDb);

  Future<int> seedNovel(
      {required String status,
      String? failedStage,
      Map<String, dynamic> metaExtra = const {}}) async {
    final meta = jsonEncode({
      'paraCount': 3,
      'charCount': 120,
      'chapterCount': 10,
      'annotatedChapters': 3,
      ...metaExtra,
    });
    final id = await db.into(db.projects).insert(ProjectsCompanion.insert(
          type: 'novel',
          title: '测试小说',
          sourcePath: '/book.txt',
          status: status,
          failedStage: Value(failedStage),
          metaJson: Value(meta),
        ));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        projectId: id, idx: 0, startPara: 0, endPara: 0));
    await db.into(db.paragraphs).insert(ParagraphsCompanion.insert(
        projectId: id, chapterId: Value(id), idx: 0, content: '少年背剑而行。'));
    return id;
  }

  Future<int> seedVideo(String status) => db.into(db.projects).insert(
        ProjectsCompanion.insert(
            type: 'video', title: '剧集', sourcePath: '/v.mp4', status: status),
      );

  Future<Project> projectRow(int id) => (db.select(db.projects)
        ..where((t) => t.id.equals(id)))
      .getSingle();

  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsRepoProvider.overrideWithValue(
              SettingsRepository(db, const FlutterSecureStorage())),
          pipelineControllerProvider.overrideWith(_StubPipelineController.new),
        ],
        child: MaterialApp(home: child),
      );

  testWidgets('小说 IMPORTED：「开始阅读」+ 批注徽章，点按钮进阅读器', (tester) async {
    await seedNovel(status: 'IMPORTED');
    await tester.pumpWidget(wrap(const LibraryPage()));
    await tester.pumpAndSettle();

    expect(find.text('开始阅读'), findsOneWidget);
    expect(find.text('批注 3/10 章'), findsOneWidget);
    expect(find.text('处理中 · 可阅读'), findsOneWidget);

    // 导入即读：不进处理页，直接进阅读器（§6.3）
    await tester.tap(find.text('开始阅读'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderPage), findsOneWidget);
    expect(find.text('少年背剑而行。'), findsOneWidget);
    expect(find.byType(ProcessingPage), findsNothing);
    await closeDb();
  });

  testWidgets('小说 IMPORTED：点卡片本体走同一闸门进阅读器', (tester) async {
    await seedNovel(status: 'IMPORTED');
    await tester.pumpWidget(wrap(const LibraryPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('测试小说'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderPage), findsOneWidget);
    expect(find.byType(ProcessingPage), findsNothing);
    await closeDb();
  });

  testWidgets('小说 FAILED：不放行，进处理页走重试路径', (tester) async {
    await seedNovel(status: 'FAILED', failedStage: 'map');
    await tester.pumpWidget(wrap(const LibraryPage()));
    await tester.pumpAndSettle();

    expect(find.text('开始阅读'), findsNothing);
    expect(find.text('处理失败'), findsOneWidget);
    expect(find.textContaining('失败：'), findsOneWidget);

    await tester.tap(find.text('测试小说'));
    await tester.pumpAndSettle();
    expect(find.byType(ProcessingPage), findsOneWidget);
    expect(find.byType(ReaderPage), findsNothing);
    await closeDb();
  });

  test('小说闸门：非 failed 一律放行进阅读器，failed 进处理页', () async {
    for (final status in ['IMPORTED', 'MAPPED', 'COMMENTARY_DONE', 'READY']) {
      final id = await seedNovel(status: status);
      expect(
          libraryEntryGate(
              await projectRow(id), ProjectStatus.fromDb(status)),
          isA<ReaderPage>(),
          reason: 'novel $status 应导入即可读');
      await (db.delete(db.projects)..where((t) => t.id.equals(id))).go();
    }
    final failed = await seedNovel(status: 'FAILED', failedStage: 'digest');
    expect(
        libraryEntryGate(
            await projectRow(failed), ProjectStatus.fromDb('FAILED')),
        isA<ProcessingPage>());
  });

  test('video 闸门不变：READY 进播放器，中间态/失败进处理页', () async {
    final ready = await seedVideo('READY');
    expect(
        libraryEntryGate(
            await projectRow(ready), ProjectStatus.fromDb('READY')),
        isA<PlayerPage>());
    final segmented = await seedVideo('SEGMENTED');
    expect(
        libraryEntryGate(
            await projectRow(segmented), ProjectStatus.fromDb('SEGMENTED')),
        isA<ProcessingPage>());
    final failed = await seedVideo('FAILED');
    expect(
        libraryEntryGate(
            await projectRow(failed), ProjectStatus.fromDb('FAILED')),
        isA<ProcessingPage>());
  });
  testWidgets('小说卡片显示已读百分比（v6 progressPercent）', (tester) async {
    await seedNovel(status: 'IMPORTED', metaExtra: const {
      'reading': {'chapterIdx': 2, 'scrollOffset': 0.0, 'progressPercent': 0.45},
    });
    await tester.pumpWidget(wrap(const LibraryPage()));
    await tester.pumpAndSettle();

    expect(find.textContaining('已读 45%'), findsOneWidget);
    await closeDb();
  });
}
