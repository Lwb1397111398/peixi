import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/pipeline/pipeline_controller.dart';

/// 共享 Dio（ASR 等客户端复用）
final dioProvider = Provider<Dio>((ref) => Dio());

/// main() 里完成异步初始化后 overrideWithValue 注入
final databaseProvider =
    Provider<AppDatabase>((ref) => throw UnimplementedError());
final settingsRepoProvider =
    Provider<SettingsRepository>((ref) => throw UnimplementedError());

final llmServiceProvider = Provider<LlmService>((ref) {
  final svc = LlmService(db: ref.watch(databaseProvider));
  // 启动时用已存配置武装 LLM；设置页保存后会再次 updateConfig
  Future(() async {
    final cfg = await ref.read(settingsRepoProvider).loadApiConfig();
    svc.updateConfig(cfg);
  });
  return svc;
});

/// 管线后台控制器：进度状态按 projectId 广播
final pipelineControllerProvider = NotifierProvider<PipelineController,
    Map<int, PipelineState>>(PipelineController.new);
