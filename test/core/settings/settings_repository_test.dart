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

  test('ASR 模式默认 cloud，可切 local 再切回', () async {
    expect(await repo.loadAsrMode(), AsrMode.cloud);
    await repo.saveAsrMode(AsrMode.local);
    expect(await repo.loadAsrMode(), AsrMode.local);
    await repo.saveAsrMode(AsrMode.cloud);
    expect(await repo.loadAsrMode(), AsrMode.cloud);
  });

  test('阅读偏好持久化往返', () async {
    final p = await repo.loadReaderPrefs();
    expect(p.fontSize, 17);
    expect(p.lineHeight, 1.7);
    expect(p.theme, ReaderTheme.paper);
    await repo.saveReaderPrefs(const ReaderPrefs(
        fontSize: 20, lineHeight: 2.0, theme: ReaderTheme.night));
    final r = await repo.loadReaderPrefs();
    expect(r.fontSize, 20);
    expect(r.lineHeight, 2.0);
    expect(r.theme, ReaderTheme.night);
  });
}
