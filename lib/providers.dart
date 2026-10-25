import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/media/ffmpeg_service.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/core/update/update_service.dart';
import 'package:peixi/features/pipeline/pipeline_controller.dart';

/// 共享 Dio（ASR 等客户端复用）
final dioProvider = Provider<Dio>((ref) => Dio());

/// ffmpeg 门面（导入探测/抽音频/抽字幕）；测试用 Fake 覆写
final ffmpegServiceProvider =
    Provider<FFmpegService>((ref) => FFmpegKitService());

/// main() 里完成异步初始化后 overrideWithValue 注入
final databaseProvider =
    Provider<AppDatabase>((ref) => throw UnimplementedError());
final settingsRepoProvider =
    Provider<SettingsRepository>((ref) => throw UnimplementedError());

final llmServiceProvider = Provider<LlmService>((ref) {
  final svc = LlmService(db: ref.watch(databaseProvider));
  // 启动时武装路由表与并发闸门；设置页保存渠道/槽位/限流后会再次调用
  Future(() async {
    try {
      final repo = ref.read(settingsRepoProvider);
      svc.updateRouting(await repo.loadRouting());
      final (conc, minMs) = await repo.loadLlmLimits();
      svc.gate.updateLimits(
          maxConcurrent: conc, minInterval: Duration(milliseconds: minMs));
    } catch (e) {
      // secure storage 等在 Windows 上可能抛错；吞掉会让 LLM 报出难排查的
      // "未配置"，这里至少留一条日志。
      debugPrint('LLM 启动装配失败: $e');
    }
  });
  return svc;
});

/// 管线后台控制器：进度状态按 projectId 广播
final pipelineControllerProvider = NotifierProvider<PipelineController,
    Map<int, PipelineState>>(PipelineController.new);

/// 应用自更新：检查（GitHub Releases）/ 下载（断点续传+镜像兜底）/ 替换重启
final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());
