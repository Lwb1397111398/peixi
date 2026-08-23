import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/settings/settings_repository.dart';

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
