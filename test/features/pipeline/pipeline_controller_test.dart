import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/novel/novel_parser.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/providers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// 单可用渠道路由表（单章重批走 analysis 槽位）。
const _route = ChannelRoute(
    id: 0, name: 'legacy', baseUrl: 'https://x/v1', apiKey: 'k', enabled: true);

/// 恒定返回第 0 章单条 L1 批注的假适配器。gate 非空时 fetch 挂起，
/// 用于把第一次重批停在 LLM 调用中间，制造"重批进行中"的窗口。
class _ScriptedAdapter implements HttpClientAdapter {
  Completer<void>? gate;
  final _entered = Completer<void>();

  /// 第一次 fetch 被调用（重批已进入 LLM 调用，互斥标志已置位）
  Future<void> get entered => _entered.future;

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    if (!_entered.isCompleted) _entered.complete();
    if (gate != null) await gate!.future;
    final body = '{"chapters":[{"idx":0,"annotations":'
        '[{"para_idx":0,"type":"L1","content":"重批注"}]}]}';
    return ResponseBody.fromString(
        '{"choices":[{"message":{"role":"assistant","content":${jsonEncode(body)}}}],'
        '"usage":{"prompt_tokens":10,"completion_tokens":20}}',
        200,
        headers: {
          'content-type': ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

class _NoWakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
  @override
  Future<bool> get enabled async => false;
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late _ScriptedAdapter adapter;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
    // 控制器在管线事件里切换亮屏锁，测试环境用假实现
    wakelockPlusPlatformInstance = _NoWakelock();
    adapter = _ScriptedAdapter();
    final llm = LlmService(
        db: db,
        dio: Dio()..httpClientAdapter = adapter,
        backoffBase: const Duration(milliseconds: 1))
      ..updateRouting(const RoutingTable(
        channels: [_route],
        slots: {
          LlmSlot.summary: SlotBinding(channelId: 0, model: 'flash'),
          LlmSlot.analysis: SlotBinding(channelId: 0, model: 'deep'),
        },
      ));
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      settingsRepoProvider.overrideWithValue(
          SettingsRepository(db, const FlutterSecureStorage())),
      llmServiceProvider.overrideWithValue(llm),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('PipelineController 单章重批', () {
    test('完成事件带项目当前真实状态：READY 项目重批后卡片不挂"处理中"', () async {
      final id = await NovelImporter(db: db).import(
          title: '书',
          sourcePath: '/book.txt',
          doc: const NovelDoc(chapters: [
            NovelChapter(idx: 0, title: '第一章', paragraphs: ['段落甲。', '段落乙。']),
          ]));
      // 已批注章（mapDone+annotDone+快照）的可重批形态；项目已完结 READY
      await (db.update(db.chapters)..where((t) => t.projectId.equals(id)))
          .write(const ChaptersCompanion(
              mapDone: Value(true),
              summary: Value('旧摘要'),
              annotDone: Value(true),
              digestBefore: Value('旧全书摘要')));
      await (db.update(db.projects)..where((t) => t.id.equals(id)))
          .write(const ProjectsCompanion(status: Value('READY')));

      final controller = container.read(pipelineControllerProvider.notifier);
      await controller.reannotateChapter(id, 0);

      // 修复前：完成事件固定发 imported → _onEvent 判 busy=true 且再无事件解锁
      final st = container.read(pipelineControllerProvider)[id]!;
      expect(st.busy, isFalse, reason: '重批完成后库卡片不得停留"处理中"');
      expect(st.stage, 'novel');
      expect(st.detail, contains('已重批第 0 章'));
      // 重批真的落库（幂等清旧写新后仍 1 条）
      final anns = await db.select(db.annotations).get();
      expect(anns, hasLength(1));
    });

    /// 已就绪可重批的书：n 章、全部 mapDone+annotDone+快照、项目 READY。
    Future<int> importReadyBook(
        {int chapters = 1, Map<String, dynamic>? meta}) async {
      final id = await NovelImporter(db: db).import(
          title: '书',
          sourcePath: '/book.txt',
          doc: NovelDoc(chapters: [
            for (var i = 0; i < chapters; i++)
              NovelChapter(
                  idx: i, title: '第${i + 1}章', paragraphs: ['第${i + 1}章正文。']),
          ]));
      await (db.update(db.chapters)..where((t) => t.projectId.equals(id)))
          .write(const ChaptersCompanion(
              mapDone: Value(true),
              summary: Value('旧摘要'),
              annotDone: Value(true),
              digestBefore: Value('旧全书摘要')));
      await (db.update(db.projects)..where((t) => t.id.equals(id)))
          .write(ProjectsCompanion(
              status: const Value('READY'),
              metaJson:
                  meta == null ? const Value(null) : Value(jsonEncode(meta))));
      return id;
    }

    test('重批进行中重复调用被拒：双击穿透不会并发重批（双倍 token）', () async {
      final id = await importReadyBook();
      adapter.gate = Completer<void>(); // 第一次重批停在 LLM 调用上
      final controller = container.read(pipelineControllerProvider.notifier);
      final first = controller.reannotateChapter(id, 0);
      await adapter.entered; // 第一发已进入 LLM 调用，互斥标志已置位

      await expectLater(
          controller.reannotateChapter(id, 0),
          throwsA(predicate((e) =>
              e is Exception && e.toString().contains('正在重批'))));

      adapter.gate!.complete();
      await first; // 第一发正常完成
      final st = container.read(pipelineControllerProvider)[id]!;
      expect(st.detail, contains('已重批第 0 章'));
      // 只发生了一次 LLM 调用（幂等清旧写新后仍 1 条批注）
      final anns = await db.select(db.annotations).get();
      expect(anns, hasLength(1));
    });

    test('重批完成后重算 meta.annotatedChapters 写回（JSON 级合并不丢无关键）', () async {
      // 两章均已批注，但徽章计数滞后（1/2）——模拟重批前库页/处理页分叉
      final id = await importReadyBook(chapters: 2, meta: const {
        'chapterCount': 2,
        'annotatedChapters': 1,
        'reading': {'chapterIdx': 1, 'scrollOffset': 12.0},
      });

      final controller = container.read(pipelineControllerProvider.notifier);
      await controller.reannotateChapter(id, 0);

      final p = await (db.select(db.projects)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      final meta = jsonDecode(p.metaJson!) as Map<String, dynamic>;
      expect(meta['annotatedChapters'], 2,
          reason: '重批完成后按 annot_done 重算写回');
      expect(meta['chapterCount'], 2);
      expect(meta['reading'], isNotNull,
          reason: '在 JSON map 层只改徽章键，阅读进度等无关键不得丢失');
    });
  });
}
