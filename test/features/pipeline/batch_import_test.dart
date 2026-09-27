import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/api_config.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/pipeline/pipeline_queue.dart';
import 'package:peixi/providers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import '../../fakes/fake_ffmpeg_service.dart';

class FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async => '/tmp/peixi-support';
}

class _NoWakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
  @override
  Future<bool> get enabled async => false;
}

void main() {
  setUpAll(() {
    // 控制器在管线事件里切换亮屏锁，测试环境用假实现
    wakelockPlusPlatformInstance = _NoWakelock();
  });

  group('PipelineQueue 串行队列', () {
    test('按入队顺序串行执行', () async {
      final q = PipelineQueue();
      final ran = <int>[];
      q.add(1, () async {
        ran.add(1);
        // 任务未完成时下一个不应开始
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      q.add(2, () async => ran.add(2));
      q.add(3, () async => ran.add(3));
      await q.waitIdle();
      expect(ran, [1, 2, 3]);
      expect(q.isIdle, isTrue);
    });

    test('cancelPending 跳过尚未开始的任务', () async {
      final q = PipelineQueue();
      final ran = <int>[];
      q.add(1, () async => ran.add(1));
      q.add(2, () async => ran.add(2));
      q.cancelPending(2);
      await q.waitIdle();
      expect(ran, [1]);
    });

    test('任务抛异常不中断后续任务', () async {
      final q = PipelineQueue();
      final ran = <int>[];
      q.add(1, () async => throw StateError('管线内部失败应已落盘'));
      q.add(2, () async => ran.add(2));
      await q.waitIdle();
      expect(ran, [2]);
    });
  });

  group('批量导入', () {
    late AppDatabase db;
    late Directory videoDir;
    late FakeFFmpegService fakeFfmpeg;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      FlutterSecureStorage.setMockInitialValues({});
      PathProviderPlatform.instance = FakePathProvider();
      videoDir = Directory.systemTemp.createTempSync('peixi_batch');
      fakeFfmpeg = FakeFFmpegService();
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        settingsRepoProvider.overrideWithValue(
            SettingsRepository(db, const FlutterSecureStorage())),
        ffmpegServiceProvider.overrideWithValue(fakeFfmpeg),
      ]);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
      videoDir.deleteSync(recursive: true);
    });

    Future<void> seedLlmConfig() async {
      // 渠道化后 _precheck 校验"存在可用渠道"；直接落一条渠道
      await container.read(settingsRepoProvider).addChannel(
          name: '测试渠道',
          baseUrl: 'https://llm.example/v1',
          apiKey: 'sk-test');
      // 本地识别模式：绕开云端所需的 OSS 配置校验
      await container
          .read(settingsRepoProvider)
          .saveAsrMode(AsrMode.local);
    }

    test('未配置 LLM Key 时直接返回配置错误，不创建项目', () async {
      final controller =
          container.read(pipelineControllerProvider.notifier);
      final res =
          await controller.importVideos(paths: ['${videoDir.path}/a.mkv']);
      expect(res.configError, isNotNull);
      expect(res.okIds, isEmpty);
      expect((await db.select(db.projects).get()), isEmpty);
    });

    test('多文件导入逐个入库，单个 probe 失败不中断批次', () async {
      await seedLlmConfig();
      final good = File('${videoDir.path}/潜伏.S01E01.mkv')
        ..writeAsBytesSync(List.filled(16, 1));
      final bad = File('${videoDir.path}/损坏.S01E02.mkv')
        ..writeAsBytesSync(List.filled(16, 2));
      fakeFfmpeg.onProbe =
          (p) => p == bad.path ? Exception('probe failed') : null;

      final controller =
          container.read(pipelineControllerProvider.notifier);
      final res = await controller.importVideos(paths: [good.path, bad.path]);

      expect(res.configError, isNull);
      expect(res.okIds.length, 1);
      expect(res.failures.length, 1);
      expect(res.failures.single.file, '损坏.S01E02.mkv');
      expect(res.failures.single.error, contains('无法读取视频'));

      final rows = await db.select(db.projects).get();
      expect(rows.length, 1);
      expect(rows.single.type, 'video');
      await controller.waitPipelineIdle();
    });

    test('一次导入多集时各自建档并保留集数', () async {
      await seedLlmConfig();
      final paths = <String>[];
      for (var i = 1; i <= 3; i++) {
        final f = File('${videoDir.path}/剧名.S01E0$i.mkv')
          ..writeAsBytesSync(List.filled(8, i));
        paths.add(f.path);
      }
      final controller =
          container.read(pipelineControllerProvider.notifier);
      final res = await controller.importVideos(paths: paths);
      expect(res.okIds.length, 3);
      expect(res.failures, isEmpty);

      final rows = await db.select(db.projects).get();
      expect(rows.length, 3);
      final episodes = rows
          .map((r) =>
              RegExp(r'"episode":(\d+)').firstMatch(r.metaJson!)!.group(1))
          .toSet();
      expect(episodes.length, 3);
      await controller.waitPipelineIdle();
    });

    test('小说批量导入：有效文件入库，空文件记录失败', () async {
      await seedLlmConfig();
      final good = File('${videoDir.path}/好小说.txt')
        ..writeAsStringSync('第一章 开始\n\n这是正文段落。\n\n第二章 继续\n\n另一段。\n');
      final empty = File('${videoDir.path}/空.txt')..writeAsStringSync('');

      final controller =
          container.read(pipelineControllerProvider.notifier);
      final res =
          await controller.importNovels(paths: [good.path, empty.path]);

      expect(res.okIds.length, 1);
      expect(res.failures.single.file, '空.txt');
      final rows = await db.select(db.projects).get();
      expect(rows.single.type, 'novel');
      expect(rows.single.title, '好小说');
      await controller.waitPipelineIdle();
    });
  });
}
