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

/// 恒定返回第 0 章单条 L1 批注的假适配器。
class _ScriptedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future? cancelFuture) async {
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

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
    // 控制器在管线事件里切换亮屏锁，测试环境用假实现
    wakelockPlusPlatformInstance = _NoWakelock();
    final llm = LlmService(
        db: db,
        dio: Dio()..httpClientAdapter = _ScriptedAdapter(),
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
  });
}
