import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/settings/api_config.dart';
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
    await repo.saveApiConfig(const ApiConfig(
        baseUrl: 'https://old/v1',
        apiKey: 'sk-old',
        modelCheap: 'flash-x',
        modelStandard: 'plus-x',
        modelVision: 'vl-x'));
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
}
