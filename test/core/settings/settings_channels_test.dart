import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/settings/settings_repository.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepository(db, const FlutterSecureStorage());
  });
  tearDown(() async => db.close());

  /// 直写旧单配置原始键（_migrateLegacyConfigIfNeeded 的读取对象），
  /// 模拟渠道化之前的老用户存量数据。
  Future<void> seedLegacyConfig({
    String baseUrl = 'https://old/v1',
    String apiKey = 'sk-old',
    String cheap = 'flash-x',
    String standard = 'plus-x',
    String vision = 'vl-x',
  }) async {
    Future<void> put(String key, String value) => db
        .into(db.settings)
        .insert(SettingsCompanion.insert(key: key, value: value));
    if (baseUrl.isNotEmpty) await put('llm.base_url', baseUrl);
    await put('llm.model_cheap', cheap);
    await put('llm.model_standard', standard);
    await put('llm.model_vision', vision);
    await const FlutterSecureStorage().write(key: 'llm.api_key', value: apiKey);
  }

  test('渠道增改删 + KEY 落 secure storage', () async {
    final id = await repo.addChannel(
        name: 'A站', baseUrl: 'https://a/v1', apiKey: 'sk-a');
    expect((await repo.loadChannels()).single.id, id);
    await repo.updateChannel(id,
        name: 'A站2', baseUrl: 'https://a2/v1', apiKey: 'sk-a2', enabled: false);
    final ch = (await repo.loadChannels()).single;
    expect(ch.enabled, false);
    final routing = await repo.loadRouting();
    expect(routing.channels.single.apiKey, 'sk-a2');
    await repo.deleteChannel(id);
    expect(await repo.loadChannels(), isEmpty);
  });

  test('槽位绑定保存/读取；删除渠道时清掉指向它的槽位', () async {
    final id = await repo.addChannel(
        name: 'A', baseUrl: 'https://a/v1', apiKey: 'k');
    await repo.saveSlot(LlmSlot.analysis, channelId: id, model: 'deepseek-v3');
    var r = await repo.loadRouting();
    expect(r.slots[LlmSlot.analysis]!.model, 'deepseek-v3');
    await repo.deleteChannel(id);
    r = await repo.loadRouting();
    expect(r.slots.containsKey(LlmSlot.analysis), false);
  });

  test('旧单配置首启迁移为默认渠道+三槽位，且不重复迁移', () async {
    await seedLegacyConfig();
    var r = await repo.loadRouting();
    expect(r.channels.single.baseUrl, 'https://old/v1');
    expect(r.channels.single.apiKey, 'sk-old');
    expect(r.slots[LlmSlot.summary]!.model, 'flash-x');
    expect(r.slots[LlmSlot.analysis]!.model, 'plus-x');
    expect(r.slots[LlmSlot.vision]!.model, 'vl-x');
    // 第二次不再重复建渠道
    r = await repo.loadRouting();
    expect(r.channels.length, 1);
    // 删光渠道后不得"复活"默认渠道（迁移幂等由旗标保证，而非"表是否为空"）
    await repo.deleteChannel(r.channels.single.id);
    r = await repo.loadRouting();
    expect(r.channels, isEmpty);
    expect(r.slots, isEmpty);
  });

  test('迁移后经渠道 API 编辑：同步落库，重启不回退', () async {
    await seedLegacyConfig();
    await repo.loadRouting(); // 触发一次性迁移（此后旗标已置位）
    // 设置页编辑渠道与三槽位（updateChannel/saveSlot 路径）
    final id = (await repo.loadChannels()).single.id;
    await repo.updateChannel(id,
        name: '默认渠道',
        baseUrl: 'https://new/v1',
        apiKey: 'sk-new',
        enabled: true);
    await repo.saveSlot(LlmSlot.summary, channelId: id, model: 'flash-n');
    await repo.saveSlot(LlmSlot.analysis, channelId: id, model: 'plus-n');
    await repo.saveSlot(LlmSlot.vision, channelId: id, model: 'vl-n');
    // 模拟重启：repo 无内存状态，再次 loadRouting 等价重启后装配
    final r = await repo.loadRouting();
    expect(r.channels.single.baseUrl, 'https://new/v1');
    // apiKey 走 secure storage 路径（loadRouting 从 _channelKey 读出）
    expect(r.channels.single.apiKey, 'sk-new');
    expect(r.slots[LlmSlot.summary]!.model, 'flash-n');
    expect(r.slots[LlmSlot.analysis]!.model, 'plus-n');
    expect(r.slots[LlmSlot.vision]!.model, 'vl-n');
    // 槽位仍绑定到那条渠道，而不是悬空回落
    expect(r.slots[LlmSlot.analysis]!.channelId, r.channels.single.id);
  });

  test('损坏的槽位串被丢弃：loadRouting 不抛异常也不含该槽位', () async {
    await db.into(db.settings).insert(
        SettingsCompanion.insert(key: 'llm.slot.analysis', value: 'abc:'));
    final r = await repo.loadRouting();
    expect(r.slots.containsKey(LlmSlot.analysis), isFalse);
  });

  test('从未配置过：loadRouting 返回空表不建渠道', () async {
    final r = await repo.loadRouting();
    expect(r.channels, isEmpty);
  });

  test('并发/频控：未配置时返回默认 (2, 0)', () async {
    final (conc, minMs) = await repo.loadLlmLimits();
    expect(conc, 2);
    expect(minMs, 0);
  });

  test('并发/频控：保存后读回；越界值被钳制到 1~8 / 0~10000', () async {
    await repo.saveLlmLimits(concurrency: 0, minIntervalMs: 20000);
    expect(await repo.loadLlmLimits(), (1, 10000));
    await repo.saveLlmLimits(concurrency: 99, minIntervalMs: -5);
    expect(await repo.loadLlmLimits(), (8, 0));
  });

  test('并发/频控：外部直写越界脏值，读取侧同样钳制', () async {
    await db.into(db.settings).insert(
        SettingsCompanion.insert(key: 'llm.concurrency', value: '600000'));
    await db.into(db.settings).insert(SettingsCompanion.insert(
        key: 'llm.min_request_interval_ms', value: '-999'));
    expect(await repo.loadLlmLimits(), (8, 0));
    await db.into(db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: 'llm.concurrency', value: '0'));
    await db.into(db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(
            key: 'llm.min_request_interval_ms', value: '600000'));
    expect(await repo.loadLlmLimits(), (1, 10000));
  });
}
