import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/api_config.dart';
import 'package:peixi/core/settings/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  late AppDatabase db;
  late SettingsRepository repo;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepository(db, FlutterSecureStorage());
  });
  tearDown(() async => db.close());

  test('ApiConfig 持久化往返：密钥入 secure、其余入 settings 表', () async {
    await repo.saveApiConfig(const ApiConfig(
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      apiKey: 'sk-test-123',
      modelCheap: 'qwen-flash',
      modelStandard: 'qwen-plus',
    ));
    // 密钥绝不能出现在 settings 表
    final rows = await db.select(db.settings).get();
    final joined = rows.map((r) => '${r.key}=${r.value}').join(';');
    expect(joined.contains('sk-test-123'), isFalse);
    final cfg = await repo.loadApiConfig();
    expect(cfg.apiKey, 'sk-test-123');
    expect(cfg.baseUrl, ApiConfig.bailianBaseUrl);
    expect(cfg.modelOf(LlmTier.cheap), 'qwen-flash');
    expect(cfg.modelOf(LlmTier.standard), 'qwen-plus');
  });

  test('空配置返回默认值', () async {
    final cfg = await repo.loadApiConfig();
    expect(cfg.baseUrl, ApiConfig.bailianBaseUrl);
    expect(cfg.apiKey, '');
    expect(cfg.isComplete, isFalse);
  });

  test('OssConfig 与播放偏好持久化', () async {
    await repo.saveOssConfig(const OssConfig(
        bucket: 'b',
        endpoint: 'oss-cn-beijing.aliyuncs.com',
        accessKeyId: 'ak',
        accessKeySecret: 'sk'));
    final oss = await repo.loadOssConfig();
    expect(oss?.bucket, 'b');
    final prefs = await repo.loadPlayPrefs();
    expect(prefs.quizEnabled, isTrue); // 设计稿 8.2 默认开启
    expect(prefs.maxPerEpisode, 5);
    expect(prefs.minGapMinutes, 4);
    expect(prefs.triggerRatio, 0.3);
  });
}
