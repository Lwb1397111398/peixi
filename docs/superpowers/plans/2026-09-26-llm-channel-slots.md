# LLM 渠道与槽位系统 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 多渠道 OpenAI 兼容模型管理（KEY+URL+拉取模型）+ 按功能槽位绑定模型，`LlmService` 槽位化解析，并附全局并发/频控闸门。

**Architecture:** 新增 `RoutingTable`（渠道列表 + 槽位绑定）作为 LlmService 解析唯一依据；渠道存 `llm_channels` 表（KEY 走 secure storage）；旧单配置首启自动迁移为"默认渠道 + 三槽位"。并发信号量与 429 冷却内置于 LlmService。

**Tech Stack:** Flutter + Riverpod + Drift（sqlite）+ Dio。测试：flutter_test + `NativeDatabase.memory()` + 可编程 FakeAdapter（见 `test/core/llm/llm_service_test.dart` 既有模式）。

**Spec:** `docs/superpowers/specs/2026-09-26-novel-two-pass-pipeline-design.md` 第 3/4 节（参数 `llm.concurrency`、`llm.minRequestIntervalMs`）。

**注意:** 本计划是子系统一；子系统二（小说两遍式管线）在本计划落地后另行编写，将引用本计划产出的 `LlmSlot`/`RoutingTable` 真实接口。

---

### Task 1: 路由类型 `LlmSlot` / `ChannelRoute` / `RoutingTable`

**Files:**
- Create: `lib/core/llm/llm_routing.dart`
- Test: `test/core/llm/llm_routing_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/core/llm/llm_routing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/llm/llm_routing.dart';

void main() {
  test('显式绑定命中：返回绑定渠道与模型', () {
    final t = RoutingTable(
      channels: [
        ChannelRoute(id: 1, name: 'A', baseUrl: 'https://a/v1', apiKey: 'k1', enabled: true),
        ChannelRoute(id: 2, name: 'B', baseUrl: 'https://b/v1', apiKey: 'k2', enabled: true),
      ],
      slots: {LlmSlot.analysis: SlotBinding(channelId: 2, model: 'deepseek-v3')},
    );
    final r = t.resolve(LlmSlot.analysis)!;
    expect(r.channel.id, 2);
    expect(r.model, 'deepseek-v3');
  });

  test('未绑定槽位回落首个可用渠道 + 默认模型；embedding 不回落返回 null', () {
    final t = RoutingTable(
      channels: [
        ChannelRoute(id: 1, name: 'A', baseUrl: 'https://a/v1', apiKey: 'k1', enabled: false),
        ChannelRoute(id: 2, name: 'B', baseUrl: 'https://b/v1', apiKey: '', enabled: true),
        ChannelRoute(id: 3, name: 'C', baseUrl: 'https://c/v1', apiKey: 'k3', enabled: true),
      ],
      slots: {},
    );
    expect(t.resolve(LlmSlot.summary)!.channel.id, 3);
    expect(t.resolve(LlmSlot.summary)!.model, 'qwen-flash');
    expect(t.resolve(LlmSlot.analysis)!.model, 'qwen-plus');
    expect(t.resolve(LlmSlot.embedding), isNull);
  });

  test('绑定指向不存在/禁用渠道时按未绑定处理', () {
    final t = RoutingTable(
      channels: [ChannelRoute(id: 9, name: 'X', baseUrl: 'https://x/v1', apiKey: 'k', enabled: false)],
      slots: {LlmSlot.analysis: SlotBinding(channelId: 9, model: 'm')},
    );
    expect(t.resolve(LlmSlot.analysis), isNull);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/llm/llm_routing_test.dart`
Expected: FAIL（`llm_routing.dart` 不存在）

- [ ] **Step 3: 实现**

```dart
// lib/core/llm/llm_routing.dart
/// 功能槽位：管线各环节使用哪条渠道的哪个模型。
/// summary=轻量整理（地图/摘要/知识卡）analysis=深层分析（批注/解说）
/// vision=视觉理解 embedding=语义向量（仅语义回忆模块）
enum LlmSlot { summary, analysis, vision, embedding }

/// 单条渠道的路由信息（api_key 由调用方从 secure storage 读出注入）。
class ChannelRoute {
  const ChannelRoute({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.enabled,
  });
  final int id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final bool enabled;

  bool get usable => enabled && baseUrl.isNotEmpty && apiKey.isNotEmpty;
}

/// 槽位 → (渠道 id, 模型名)。
class SlotBinding {
  const SlotBinding({required this.channelId, required this.model});
  final int channelId;
  final String model;
}

/// 渠道 + 槽位整体路由表；LlmService 解析请求的唯一依据。
class RoutingTable {
  const RoutingTable({required this.channels, required this.slots});
  final List<ChannelRoute> channels;
  final Map<LlmSlot, SlotBinding> slots;

  static const _fallbackModel = {
    LlmSlot.summary: 'qwen-flash',
    LlmSlot.analysis: 'qwen-plus',
    LlmSlot.vision: 'qwen-vl-plus',
  };

  ChannelRoute? _byId(int id) {
    for (final c in channels) {
      if (c.id == id) return c;
    }
    return null;
  }

  ChannelRoute? _firstUsable() {
    for (final c in channels) {
      if (c.usable) return c;
    }
    return null;
  }

  /// 解析槽位 → (渠道, 模型)。显式绑定优先；未绑定时 summary/analysis/vision
  /// 回落到首个可用渠道 + 默认模型；embedding 必须显式绑定（不回落）。
  ({ChannelRoute channel, String model})? resolve(LlmSlot slot) {
    final bind = slots[slot];
    if (bind != null) {
      final c = _byId(bind.channelId);
      if (c != null && c.usable) return (channel: c, model: bind.model);
    }
    if (slot == LlmSlot.embedding) return null;
    final c = _firstUsable();
    if (c == null) return null;
    return (channel: c, model: _fallbackModel[slot]!);
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/core/llm/llm_routing_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/core/llm/llm_routing.dart test/core/llm/llm_routing_test.dart
git commit -m "feat(llm): 路由类型 LlmSlot/ChannelRoute/RoutingTable——渠道+槽位解析"
```

---

### Task 2: `llm_channels` 表（schema v4）

**Files:**
- Modify: `lib/core/database/app_database.dart`（表定义追加 + `@DriftDatabase(tables:[...])` + `schemaVersion` + `onUpgrade`）
- Test: `test/core/database/schema_v4_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/core/database/schema_v4_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';

void main() {
  test('llm_channels 表可写读，渠道 CRUD 字段齐全', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final id = await db.into(db.llmChannels).insert(
        LlmChannelsCompanion.insert(name: '中转站A', baseUrl: 'https://a/v1'));
    final row = await (db.select(db.llmChannels)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    expect(row.name, '中转站A');
    expect(row.enabled, true); // 默认启用
    await db.close();
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/database/schema_v4_test.dart`
Expected: FAIL（`llmChannels` getter 不存在，编译错误）

- [ ] **Step 3: 实现**——`app_database.dart` 三处修改：

① 在 `LlmCache` 表类之后追加：

```dart
/// LLM 渠道（OpenAI 兼容中转站）。api_key 存 secure storage（键 llm.channel.<id>.api_key）。
class LlmChannels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

② `@DriftDatabase(tables: [...])` 列表末尾加 `LlmChannels,`

③ `schemaVersion` 改为 `4`；`onUpgrade` 末尾追加：

```dart
          if (from < 4) {
            // v3→v4：LLM 渠道表（渠道化模型管理，api_key 在 secure storage）
            await m.createTable(llmChannels);
          }
```

- [ ] **Step 4: 生成 drift 代码**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `app_database.g.dart` 重新生成，无错误

- [ ] **Step 5: 运行确认通过**

Run: `flutter test test/core/database/schema_v4_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/app_database.dart lib/core/database/app_database.g.dart test/core/database/schema_v4_test.dart
git commit -m "feat(db): llm_channels 渠道表（schema v4）"
```

---

### Task 3: SettingsRepository 渠道 CRUD + 槽位持久化 + 旧配置迁移

**Files:**
- Modify: `lib/core/settings/settings_repository.dart`
- Test: `test/core/settings/settings_channels_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/core/settings/settings_channels_test.dart
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
  });

  test('从未配置过：loadRouting 返回空表不建渠道', () async {
    final r = await repo.loadRouting();
    expect(r.channels, isEmpty);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/settings/settings_channels_test.dart`
Expected: FAIL（`addChannel` 等方法不存在）

- [ ] **Step 3: 实现**——`settings_repository.dart` 追加（import 区加 `package:peixi/core/llm/llm_routing.dart`）：

```dart
  // ---- 渠道与槽位 ----
  static String _channelKey(int id) => 'llm.channel.$id.api_key';

  Future<int> addChannel(
      {required String name,
      required String baseUrl,
      required String apiKey,
      bool enabled = true}) async {
    final id = await _db.into(_db.llmChannels).insert(LlmChannelsCompanion.insert(
        name: name, baseUrl: baseUrl, enabled: Value(enabled)));
    await _secure.write(key: _channelKey(id), value: apiKey);
    return id;
  }

  Future<void> updateChannel(int id,
      {required String name,
      required String baseUrl,
      required String apiKey,
      required bool enabled}) async {
    await (_db.update(_db.llmChannels)..where((t) => t.id.equals(id))).write(
        LlmChannelsCompanion(
            name: Value(name),
            baseUrl: Value(baseUrl),
            enabled: Value(enabled)));
    await _secure.write(key: _channelKey(id), value: apiKey);
  }

  Future<void> deleteChannel(int id) async {
    await (_db.delete(_db.llmChannels)..where((t) => t.id.equals(id))).go();
    await _secure.delete(key: _channelKey(id));
    // 清掉指向该渠道的槽位绑定（槽位回落默认渠道）
    for (final s in LlmSlot.values) {
      final b = await loadSlot(s);
      if (b?.channelId == id) {
        await (_db.delete(_db.settings)
              ..where((t) => t.key.equals('llm.slot.${s.name}')))
            .go();
      }
    }
  }

  Future<void> saveSlot(LlmSlot slot,
      {required int channelId, required String model}) =>
      _set('llm.slot.${slot.name}', '$channelId:$model');

  Future<({int channelId, String model})?> loadSlot(LlmSlot slot) async {
    final raw = await _get('llm.slot.${slot.name}');
    if (raw == null) return null;
    final i = raw.indexOf(':');
    if (i <= 0) return null;
    final cid = int.tryParse(raw.substring(0, i));
    final model = raw.substring(i + 1);
    if (cid == null || model.isEmpty) return null;
    return (channelId: cid, model: model);
  }

  /// 组装路由表。首次调用时把旧单配置（llm.base_url/api_key/三模型）迁移为
  /// "默认渠道 + 三槽位"；从未配置过则返回空表。
  Future<RoutingTable> loadRouting() async {
    await _migrateLegacyConfigIfNeeded();
    final channels = <ChannelRoute>[];
    for (final row in await loadChannels()) {
      final key = await _secure.read(key: _channelKey(row.id)) ?? '';
      channels.add(ChannelRoute(
          id: row.id,
          name: row.name,
          baseUrl: row.baseUrl,
          apiKey: key,
          enabled: row.enabled));
    }
    final slots = <LlmSlot, SlotBinding>{};
    for (final s in LlmSlot.values) {
      final b = await loadSlot(s);
      if (b != null) slots[s] = SlotBinding(channelId: b.channelId, model: b.model);
    }
    return RoutingTable(channels: channels, slots: slots);
  }

  Future<void> _migrateLegacyConfigIfNeeded() async {
    if ((await loadChannels()).isNotEmpty) return;
    final baseUrl = await _get(_kBaseUrl);
    final apiKey = await _secure.read(key: _sApiKey);
    if ((baseUrl == null || baseUrl.isEmpty) &&
        (apiKey == null || apiKey.isEmpty)) {
      return;
    }
    final id = await addChannel(
        name: '默认渠道',
        baseUrl: baseUrl ?? ApiConfig.bailianBaseUrl,
        apiKey: apiKey ?? '');
    for (final (slot, key) in [
      (LlmSlot.summary, _kModelCheap),
      (LlmSlot.analysis, _kModelStandard),
      (LlmSlot.vision, _kModelVision),
    ]) {
      final model = await _get(key);
      if (model != null && model.isNotEmpty) {
        await saveSlot(slot, channelId: id, model: model);
      }
    }
  }
```

（`drift` 的 `Value` 已由现有 import 提供；若缺，import 行加 `package:drift/drift.dart`。）

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/core/settings/settings_channels_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/core/settings/settings_repository.dart test/core/settings/settings_channels_test.dart
git commit -m "feat(settings): 渠道CRUD/槽位持久化/旧单配置自动迁移"
```

---

### Task 4: LlmService 槽位化解析 + 缓存键含渠道 + 兼容垫片

**Files:**
- Modify: `lib/core/llm/llm_service.dart`
- Test: `test/core/llm/llm_service_test.dart`（既有文件，改 `updateConfig` 调用处不必动——Task 4 保留垫片；新增用例放同文件）

- [ ] **Step 1: 写失败测试**——追加到 `llm_service_test.dart` 的 `main()` 内：

```dart
  test('槽位解析：请求发到绑定渠道的 baseUrl/模型/key', () async {
    final (dio, adapter) = dioWith([TestResp(200, chatBody('ok'))]);
    final svc = LlmService(dio: dio, db: db)
      ..updateRouting(const RoutingTable(
        channels: [
          ChannelRoute(id: 1, name: 'B', baseUrl: 'https://b/v1', apiKey: 'sk-b', enabled: true),
        ],
        slots: {LlmSlot.analysis: SlotBinding(channelId: 1, model: 'deepseek-v3')},
      ));
    await svc.chat(const [
      {'role': 'user', 'content': 'hi'}
    ], slot: LlmSlot.analysis);
    expect(adapter.requests.single.path, 'https://b/v1/chat/completions');
    expect((adapter.requests.single.data as Map)['model'], 'deepseek-v3');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer sk-b');
  });

  test('槽位解析失败：抛可读异常', () async {
    final svc = LlmService(dio: Dio(), db: db);
    await expectLater(
        svc.chat(const [
          {'role': 'user', 'content': 'hi'}
        ], slot: LlmSlot.analysis),
        throwsA(isA<LlmException>()));
  });
```

（文件头 import 追加 `package:peixi/core/llm/llm_routing.dart`。）

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/llm/llm_service_test.dart`
Expected: FAIL（`updateRouting`/`slot` 参数不存在）

- [ ] **Step 3: 实现**——`llm_service.dart` 修改：

① import 追加 `package:peixi/core/llm/llm_routing.dart`；字段与替换：

```dart
  RoutingTable? _routing;

  /// 管线代码入口：启动与设置变更时注入最新路由表。
  void updateRouting(RoutingTable routing) => _routing = routing;

  /// 当前槽位解析出的模型名（评论落库 model 字段用；未配置返回 null）。
  String? modelOf(LlmSlot slot) => _routing?.resolve(slot)?.model;

  /// 兼容垫片：旧单配置 → 单渠道路由表（仅旧测试/迁移期使用）。
  @Deprecated('用 updateRouting')
  void updateConfig(ApiConfig config) => updateRouting(RoutingTable(
        channels: [
          ChannelRoute(
              id: 0,
              name: 'legacy',
              baseUrl: config.baseUrl,
              apiKey: config.apiKey,
              enabled: true),
        ],
        slots: {
          LlmSlot.summary: SlotBinding(channelId: 0, model: config.modelCheap),
          LlmSlot.analysis:
              SlotBinding(channelId: 0, model: config.modelStandard),
          LlmSlot.vision: SlotBinding(channelId: 0, model: config.modelVision),
        },
      ));

  /// 并发/频控闸门（Task 5 实现，此处先接最简版避免编译断裂——见下）
  final LlmGate gate = LlmGate();
```

② `chat` / `chatJson` / `chatVision` 签名：`{LlmTier tier = LlmTier.standard, ...}` → `{LlmSlot slot = LlmSlot.analysis, ...}`（`chatVision` 传 `slot: LlmSlot.vision`，删除其 `modelOverride` 逻辑）。

③ `_send` 重写解析段（`cfg == null` 判断替换为）：

```dart
    final r = _routing?.resolve(slot);
    if (r == null) {
      throw LlmException('未配置 LLM 渠道或槽位（设置页 → 模型渠道）');
    }
    final model = r.model;
    final baseUrl = r.channel.baseUrl;
```

请求行改为 `dio.post('$baseUrl/chat/completions', ...)`，头 `'Authorization': 'Bearer ${r.channel.apiKey}'`；`body` 中 `'model': model`。

④ 缓存键含渠道（防不同中转站同名模型串缓存）：

```dart
  String _cacheKey(String model, List<dynamic> messages, String baseUrl) =>
      sha256.convert(utf8.encode(jsonEncode([baseUrl, model, messages]))).toString();
```

`chatJson` 内：`final r = _routing?.resolve(slot); if (r == null) throw LlmException('未配置 LLM 渠道或槽位（设置页 → 模型渠道）');`，用 `r.channel.baseUrl` / `r.model` 算键；缓存命中直接返回（不经 gate/预算，语义同旧"缓存命中不记日志"）。

⑤ 删除 `ApiConfig? get config`（Task 7 会修掉唯一调用点）；删除 `LlmTier` 引用（`api_config.dart` 中枚举留待 Task 7 一并清除）。

⑥ 文件末尾追加闸门最简版（Task 5 再补全为可测版本，此处先满足编译）：

```dart
/// 全局并发/频控闸门：所有 LLM 调用共用，防止压垮限速中转站。
class LlmGate {
  int maxConcurrent = 2;
  Duration minInterval = Duration.zero;
  DateTime _cooldownUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastDispatch = DateTime.fromMillisecondsSinceEpoch(0);
  int _inFlight = 0;

  void updateLimits({int? maxConcurrent, Duration? minInterval}) {
    if (maxConcurrent != null && maxConcurrent >= 1) {
      this.maxConcurrent = maxConcurrent;
    }
    if (minInterval != null) this.minInterval = minInterval;
  }

  /// 429 等限流信号：全局冷却（在途请求不受影响，新请求延后）。
  void cooldown(Duration d) {
    final until = DateTime.now().add(d);
    if (until.isAfter(_cooldownUntil)) _cooldownUntil = until;
  }

  Future<void> acquire() async {
    while (true) {
      final now = DateTime.now();
      if (_inFlight < maxConcurrent && !now.isBefore(_cooldownUntil)) {
        final earliest = _lastDispatch.add(minInterval);
        if (now.isBefore(earliest)) {
          await Future.delayed(earliest.difference(now));
          continue;
        }
        _inFlight++;
        _lastDispatch = DateTime.now();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  void release() => _inFlight--;
}
```

`_send` 的调用段改为：预算检查后 `await gate.acquire(); try { ...原重试循环... } finally { gate.release(); }`；重试循环内 429 分支加 `gate.cooldown(Duration(seconds: 5 + attempt * 5));`（在 `lastError = ...; continue;` 之前）。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/core/llm/`
Expected: 全部 PASS（旧用例走 `updateConfig` 垫片继续绿）

- [ ] **Step 5: Commit**

```bash
git add lib/core/llm/llm_service.dart test/core/llm/llm_service_test.dart
git commit -m "feat(llm): LlmService 槽位化解析+缓存键含渠道+并发闸门雏形"
```

---

### Task 5: 闸门行为测试（并发上限 / 最小间隔 / 429 冷却）

**Files:**
- Test: `test/core/llm/llm_gate_test.dart`

- [ ] **Step 1: 写测试**（闸门已在 Task 4 实现，本任务补行为验证）：

```dart
// test/core/llm/llm_gate_test.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';

class SlowAdapter implements HttpClientAdapter {
  SlowAdapter(this.status);
  final int status;
  int inflight = 0;
  int maxInflight = 0;
  final stops = <DateTime>[];

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? s, Future? f) async {
    inflight++;
    if (inflight > maxInflight) maxInflight = inflight;
    await Future.delayed(const Duration(milliseconds: 60));
    stops.add(DateTime.now());
    inflight--;
    return ResponseBody.fromString(
        '{"choices":[{"message":{"content":"ok"}}],"usage":{}}', status,
        headers: {
          'content-type': ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

RoutingTable routing() => const RoutingTable(
      channels: [
        ChannelRoute(id: 1, name: 'A', baseUrl: 'https://a/v1', apiKey: 'k', enabled: true)
      ],
      slots: {},
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('并发上限：8 路并发请求，峰值在途 ≤ maxConcurrent', () async {
    final adapter = SlowAdapter(200);
    final svc = LlmService(dio: Dio()..httpClientAdapter = adapter, db: db)
      ..updateRouting(routing())
      ..gate.updateLimits(maxConcurrent: 3);
    await Future.wait([
      for (var i = 0; i < 8; i++)
        svc.chat(const [
          {'role': 'user', 'content': 'hi'}
        ])
    ]);
    expect(adapter.maxInflight, lessThanOrEqualTo(3));
  });

  test('最小间隔：相邻请求发出时刻间隔 ≥ minInterval', () async {
    final adapter = SlowAdapter(200);
    final svc = LlmService(dio: Dio()..httpClientAdapter = adapter, db: db)
      ..updateRouting(routing())
      ..gate.updateLimits(maxConcurrent: 8, minInterval: const Duration(milliseconds: 80));
    await Future.wait([
      for (var i = 0; i < 3; i++)
        svc.chat(const [
          {'role': 'user', 'content': 'hi'}
        ])
    ]);
    final t = adapter.stops..sort();
    for (var i = 1; i < t.length; i++) {
      expect(t[i].difference(t[i - 1]).inMilliseconds, greaterThanOrEqualTo(70));
    }
  });

  test('429 冷却：首个 429 后下一请求被延后（重试成功，共 2 次 HTTP）', () async {
    var calls = 0;
    final adapter = SlowAdapter(200);
    final svc = LlmService(
        dio: Dio()..httpClientAdapter = _Flaky429(adapter, () => calls++),
        db: db,
        backoffBase: const Duration(milliseconds: 10))
      ..updateRouting(routing());
    final out = await svc.chat(const [
      {'role': 'user', 'content': 'hi'}
    ]);
    expect(out, 'ok');
    expect(calls, 2);
  });
}

/// 第一次返回 429，其余透传 SlowAdapter
class _Flaky429 implements HttpClientAdapter {
  _Flaky429(this.inner, this.onCall);
  final SlowAdapter inner;
  final void Function() onCall;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? s, Future? f) async {
    if (onCall() == 0) {
      return ResponseBody.fromString('{"error":{"message":"rate"}}', 429);
    }
    return inner.fetch(o, s, f);
  }

  @override
  void close({bool force = false}) {}
}
```

- [ ] **Step 2: 运行确认通过**

Run: `flutter test test/core/llm/llm_gate_test.dart`
Expected: PASS (3 tests)——若"最小间隔"用例偶发抖动，把 70ms 容差放宽到 60ms（间隔本身 80ms）。

- [ ] **Step 3: Commit**

```bash
git add test/core/llm/llm_gate_test.dart
git commit -m "test(llm): 闸门行为——并发上限/最小间隔/429 冷却"
```

---

### Task 6: `embed()` 与 `fetchModels()`

**Files:**
- Modify: `lib/core/llm/llm_service.dart`
- Test: `test/core/llm/llm_service_test.dart`（追加）

- [ ] **Step 1: 写失败测试**——追加到 `main()`：

```dart
  test('embed：POST /embeddings 返回向量矩阵；未绑定槽位抛可读异常', () async {
    final (dio, adapter) = dioWith([
      TestResp(
          200,
          '{"data":[{"embedding":[0.1,0.2]},{"embedding":[0.3,0.4]}],"usage":{}}'),
    ]);
    final svc = LlmService(dio: dio, db: db)
      ..updateRouting(const RoutingTable(
        channels: [
          ChannelRoute(id: 1, name: 'A', baseUrl: 'https://a/v1', apiKey: 'k', enabled: true)
        ],
        slots: {LlmSlot.embedding: SlotBinding(channelId: 1, model: 'text-embedding-3')},
      ));
    final vs = await svc.embed(['一', '二']);
    expect(vs.length, 2);
    expect(vs[1], [0.3, 0.4]);
    expect(adapter.requests.single.path, 'https://a/v1/embeddings');
    expect((adapter.requests.single.data as Map)['model'], 'text-embedding-3');

    final bare = LlmService(dio: Dio(), db: db);
    await expectLater(bare.embed(['x']), throwsA(isA<LlmException>()));
  });

  test('fetchModels：GET /models 返回模型 id 列表', () async {
    final (dio, adapter) = dioWith([
      TestResp(200, '{"data":[{"id":"m1"},{"id":"m2"}]}'),
    ]);
    final svc = LlmService(dio: dio, db: db);
    final models = await svc.fetchModels(const ChannelRoute(
        id: 1, name: 'A', baseUrl: 'https://a/v1', apiKey: 'k', enabled: true));
    expect(models, ['m1', 'm2']);
    expect(adapter.requests.single.path, 'https://a/v1/models');
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/llm/llm_service_test.dart`
Expected: FAIL（`embed`/`fetchModels` 不存在）

- [ ] **Step 3: 实现**——`llm_service.dart` 追加方法：

```dart
  /// 语义向量（OpenAI 兼容 /embeddings）。语义回忆模块专用；未绑定 embedding
  /// 槽位时抛 LlmException（调用方捕获后静默跳过回忆层）。
  Future<List<List<double>>> embed(List<String> inputs,
      {String purpose = 'embed', int? projectId}) async {
    final r = _routing?.resolve(LlmSlot.embedding);
    if (r == null) {
      throw LlmException('未配置 embedding 模型（设置页 → 功能槽位）');
    }
    await _checkBudget();
    final resp = await dio.post('${r.channel.baseUrl}/embeddings',
        data: {'model': r.model, 'input': inputs},
        options: Options(
          validateStatus: (_) => true,
          headers: {'Authorization': 'Bearer ${r.channel.apiKey}'},
        ));
    if (resp.statusCode != 200) {
      throw LlmException(
          _extractErrorMessage(resp.data) ?? 'HTTP ${resp.statusCode}',
          statusCode: resp.statusCode);
    }
    final data = (resp.data as Map)['data'] as List;
    return [
      for (final d in data)
        [for (final v in (d['embedding'] as List)) (v as num).toDouble()]
    ];
  }

  /// 拉取渠道模型列表（设置页「测试连接/抓取模型」共用）。
  Future<List<String>> fetchModels(ChannelRoute channel) async {
    final resp = await dio.get('${channel.baseUrl}/models',
        options: Options(
          validateStatus: (_) => true,
          headers: {'Authorization': 'Bearer ${channel.apiKey}'},
        ));
    if (resp.statusCode != 200) {
      throw LlmException('HTTP ${resp.statusCode}', statusCode: resp.statusCode);
    }
    return [
      for (final m in ((resp.data as Map)['data'] as List))
        ((m as Map)['id'] ?? '').toString()
    ]..removeWhere((s) => s.isEmpty);
  }
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/core/llm/`
Expected: 全部 PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/llm/llm_service.dart test/core/llm/llm_service_test.dart
git commit -m "feat(llm): embed 向量接口 + fetchModels 渠道模型拉取"
```

---

### Task 7: 调用点迁移（tier→slot）+ 清除 LlmTier

**Files:**
- Modify: `lib/features/pipeline/novel_pipeline.dart:208`
- Modify: `lib/features/pipeline/novel_commentary_generator.dart:120,229`
- Modify: `lib/features/pipeline/character_mapper.dart:47`
- Modify: `lib/features/pipeline/commentary_generator.dart:19,26,74,94,145,153,211`
- Modify: `lib/features/pipeline/pipeline_controller.dart:106,113`
- Modify: `lib/core/settings/api_config.dart`（删 `LlmTier`）
- Modify: `lib/core/llm/llm_service.dart`（删 `ApiConfig` import 若不再用）

- [ ] **Step 1: 全局替换调用点**（import 区把 `LlmTier` 换成 `LlmSlot`，来自 `llm_routing.dart`）：

| 文件:行 | 旧 | 新 |
|---|---|---|
| novel_pipeline.dart:208 | `tier: LlmTier.cheap, purpose: 'novel_cast'` | `slot: LlmSlot.summary, purpose: 'novel_cast'` |
| novel_commentary_generator.dart:120 | `tier: LlmTier.standard, purpose: 'novel_annotate'` | `slot: LlmSlot.analysis, purpose: 'novel_annotate'` |
| novel_commentary_generator.dart:229 | `tier: LlmTier.cheap, purpose: 'novel_digest'` | `slot: LlmSlot.summary, purpose: 'novel_digest'` |
| character_mapper.dart:47 | `tier: LlmTier.cheap,` | `slot: LlmSlot.summary,` |
| commentary_generator.dart:94 | `tier: LlmTier.cheap,` | `slot: LlmSlot.summary,` |
| commentary_generator.dart:145 | `tier: LlmTier.standard,` | `slot: LlmSlot.analysis,` |
| commentary_generator.dart:211 | `tier: LlmTier.standard,` | `slot: LlmSlot.analysis,` |

- [ ] **Step 2: commentary_generator 去 ApiConfig 依赖**——构造函数 `required this.apiConfig` / `final ApiConfig Function() apiConfig` 改为：

```dart
    required this.modelStandard,
  ...
  /// 深层分析槽位当前模型名（落库 commentaries.model；测试可注入固定值）
  final String Function() modelStandard;
```

两处 `apiConfig().modelStandard`（74、153 行）改为 `modelStandard()`。

`pipeline_controller.dart` 装配处（106、113 行）改为：

```dart
    e.attachCollaborators(
      map: (id) => CharacterMapper(db: db, llm: llm).map(id),
      segment: (id) => SceneWriter(db).writeScenes(id),
      commentary: (id) => CommentaryGenerator(
        db: db,
        llm: llm,
        modelStandard: () => llm.modelOf(LlmSlot.analysis) ?? 'qwen-plus',
        isCancelled: () => e.isCancelled(id),
        onProgress: (done, total) => _onEvent(PipelineEvent(
            projectId: id,
            stage: 'commentary',
            status: ProjectStatus.segmented,
            progress: total == 0 ? 0 : done / total)),
      ).generate(id),
    );
```

（删除 `final fallback = await ref.read(settingsRepoProvider).loadApiConfig();` 与 `apiConfig: () => llm.config ?? fallback,`；同时文件头若 `api_config.dart` import 仅为此处保留则删除。）

- [ ] **Step 3: 清除 LlmTier**——`api_config.dart` 删除 `enum LlmTier`；全局搜索确认无残留引用。

Run: `grep -rn "LlmTier" lib test`
Expected: 无输出

- [ ] **Step 4: 全量验证**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全量测试 PASS

- [ ] **Step 5: Commit**

```bash
git add -A lib test
git commit -m "refactor(llm): 全部调用点 tier→slot 迁移，移除 LlmTier 与 ApiConfig 直依赖"
```

---

### Task 8: providers 装配 + 并发/频控设置项

**Files:**
- Modify: `lib/providers.dart:22-30`
- Modify: `lib/core/settings/settings_repository.dart`（追加两个键的读写）

- [ ] **Step 1: SettingsRepository 追加**（键区加 `static const _kLlmConcurrency = 'llm.concurrency';` 与 `static const _kLlmMinInterval = 'llm.min_request_interval_ms';`）：

```dart
  /// 并发/频控：并发数默认 2（1~8），请求最小间隔默认 0ms。
  Future<(int, int)> loadLlmLimits() async => (
        int.tryParse(await _get(_kLlmConcurrency) ?? '') ?? 2,
        int.tryParse(await _get(_kLlmMinInterval) ?? '') ?? 0,
      );

  Future<void> saveLlmLimits({required int concurrency, required int minIntervalMs}) async {
    await _set(_kLlmConcurrency, concurrency.clamp(1, 8).toString());
    await _set(_kLlmMinInterval, minIntervalMs.clamp(0, 10000).toString());
  }
```

- [ ] **Step 2: providers.dart 的 llmServiceProvider 改为**：

```dart
final llmServiceProvider = Provider<LlmService>((ref) {
  final svc = LlmService(db: ref.watch(databaseProvider));
  // 启动时武装路由表与并发闸门；设置页保存渠道/槽位/限流后会再次调用
  Future(() async {
    final repo = ref.read(settingsRepoProvider);
    svc.updateRouting(await repo.loadRouting());
    final (conc, minMs) = await repo.loadLlmLimits();
    svc.gate.updateLimits(
        maxConcurrent: conc, minInterval: Duration(milliseconds: minMs));
  });
  return svc;
});
```

- [ ] **Step 3: 全量验证**

Run: `flutter analyze && flutter test`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/providers.dart lib/core/settings/settings_repository.dart
git commit -m "feat(providers): 启动装配路由表与并发闸门；并发/频控设置键"
```

---

### Task 9: 设置页「模型渠道」「功能槽位」「并发频控」区块

**Files:**
- Create: `lib/features/settings/llm_channels_section.dart`
- Modify: `lib/features/settings/settings_page.dart`
- Test: `test/features/settings/llm_channels_section_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/features/settings/llm_channels_section_test.dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/settings/llm_channels_section.dart';
import 'package:peixi/providers.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  testWidgets('空态提示 + 添加渠道对话框落库后列表刷新', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsRepoProvider.overrideWithValue(
            SettingsRepository(db, const FlutterSecureStorage())),
      ],
      child: const MaterialApp(home: Scaffold(body: LlmChannelsSection())),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('尚未添加'), findsOneWidget);

    await tester.tap(find.text('添加渠道'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-name')), '中转站A');
    await tester.enterText(
        find.byKey(const Key('field-baseurl')), 'https://a/v1');
    await tester.enterText(find.byKey(const Key('field-apikey')), 'sk-a');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('中转站A'), findsOneWidget);
    expect(find.text('https://a/v1'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/features/settings/llm_channels_section_test.dart`
Expected: FAIL（组件不存在）

- [ ] **Step 3: 实现组件**——完整新文件：

```dart
// lib/features/settings/llm_channels_section.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/ui/widgets/section_card.dart';
import 'package:peixi/providers.dart';

/// 渠道：OpenAI 兼容中转站（KEY+URL+拉模型）。槽位：功能 → 渠道+模型绑定。
/// 并发/频控：llm.concurrency / llm.min_request_interval_ms。
class LlmChannelsSection extends ConsumerStatefulWidget {
  const LlmChannelsSection({super.key});
  @override
  ConsumerState<LlmChannelsSection> createState() => _LlmChannelsSectionState();
}

class _LlmChannelsSectionState extends ConsumerState<LlmChannelsSection> {
  List<ChannelRoute> _channels = [];
  final Map<LlmSlot, ({int channelId, String model})?> _slots = {};
  final Map<int, List<String>> _models = {}; // 渠道 id → 已拉取模型列表
  int _concurrency = 2;
  int _minIntervalMs = 0;
  bool _loaded = false;

  static const _slotLabels = {
    LlmSlot.summary: '轻量整理（地图/摘要/知识卡）',
    LlmSlot.analysis: '深层分析（批注/解说）',
    LlmSlot.vision: '视觉理解（关键帧）',
    LlmSlot.embedding: '语义向量（可选，前文回忆）',
  };

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final repo = ref.read(settingsRepoProvider);
    final routing = await repo.loadRouting();
    final (conc, minMs) = await repo.loadLlmLimits();
    if (!mounted) return;
    setState(() {
      _channels = routing.channels;
      for (final s in LlmSlot.values) {
        _slots[s] = routing.slots[s] == null
            ? null
            : (channelId: routing.slots[s]!.channelId,
                model: routing.slots[s]!.model);
      }
      _concurrency = conc;
      _minIntervalMs = minMs;
      _loaded = true;
    });
  }

  Future<void> _openChannelDialog([ChannelRoute? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final baseUrl = TextEditingController(text: existing?.baseUrl ?? '');
    final apiKey = TextEditingController(text: existing?.apiKey ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? '添加渠道' : '编辑渠道'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              key: const Key('field-name'),
              controller: name,
              decoration: const InputDecoration(labelText: '名称')),
          const SizedBox(height: Space.s),
          TextField(
              key: const Key('field-baseurl'),
              controller: baseUrl,
              decoration: const InputDecoration(
                  labelText: 'BASE_URL（OpenAI 兼容，含 /v1）')),
          const SizedBox(height: Space.s),
          TextField(
              key: const Key('field-apikey'),
              controller: apiKey,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'API KEY')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final repo = ref.read(settingsRepoProvider);
    final int id;
    if (existing == null) {
      id = await repo.addChannel(
          name: name.text.trim(),
          baseUrl: baseUrl.text.trim(),
          apiKey: apiKey.text.trim());
    } else {
      id = existing.id;
      await repo.updateChannel(existing.id,
          name: name.text.trim(),
          baseUrl: baseUrl.text.trim(),
          apiKey: apiKey.text.trim(),
          enabled: existing.enabled);
    }
    await _applyRouting();
    unawaited(_pullModels(id, baseUrl.text.trim(), apiKey.text.trim()));
  }

  /// 保存后重读路由表并注入 LlmService——运行中的管线立即生效。
  Future<void> _applyRouting() async {
    final routing = await ref.read(settingsRepoProvider).loadRouting();
    ref.read(llmServiceProvider).updateRouting(routing);
  }

  Future<void> _pullModels(int channelId, String baseUrl, String apiKey) async {
    try {
      final models = await ref.read(llmServiceProvider).fetchModels(
          ChannelRoute(
              id: channelId,
              name: '',
              baseUrl: baseUrl,
              apiKey: apiKey,
              enabled: true));
      if (!mounted) return;
      setState(() => _models[channelId] = models);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接成功，拉取到 ${models.length} 个模型')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('拉取失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      SectionCard(
        title: '模型渠道',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_channels.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.m),
                child: Text('尚未添加渠道。填写中转站的 BASE_URL 与 KEY，即可拉取模型列表。',
                    style: tt.bodySmall)),
          for (final c in _channels)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.name),
              subtitle: Text(c.baseUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                    onPressed: () => _pullModels(c.id, c.baseUrl, c.apiKey),
                    child: const Text('测试/拉模型')),
                IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _openChannelDialog(c)),
              ]),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
                onPressed: () => _openChannelDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加渠道')),
          ),
        ]),
      ),
      const SizedBox(height: Space.l),
      SectionCard(
        title: '功能槽位',
        child: Column(children: [
          for (final s in LlmSlot.values)
            _SlotRow(
              label: _slotLabels[s]!,
              channels: _channels,
              binding: _slots[s],
              models: _slots[s] == null ? null : _models[_slots[s]!.channelId],
              onChanged: (channelId, model) async {
                if (model.isEmpty) {
                  // 只切了渠道、还没选模型：不落库，等用户从拉取列表里选模型后一起保存
                  return;
                }
                await ref
                    .read(settingsRepoProvider)
                    .saveSlot(s, channelId: channelId, model: model);
                await _applyRouting();
                await _reload();
              },
            ),
        ]),
      ),
      const SizedBox(height: Space.l),
      SectionCard(
        title: '并发与频控',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('并发数'),
            Expanded(
              child: Slider(
                value: _concurrency.toDouble(),
                min: 1,
                max: 8,
                divisions: 7,
                label: '$_concurrency',
                onChanged: (v) => setState(() => _concurrency = v.round()),
              ),
            ),
            Text('$_concurrency 路'),
          ]),
          Row(children: [
            const Text('请求最小间隔'),
            Expanded(
              child: Slider(
                value: _minIntervalMs.toDouble(),
                min: 0,
                max: 2000,
                divisions: 20,
                label: '${_minIntervalMs}ms',
                onChanged: (v) => setState(() => _minIntervalMs = v.round()),
              ),
            ),
            Text('${_minIntervalMs}ms'),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
                onPressed: () async {
                  await ref.read(settingsRepoProvider).saveLlmLimits(
                      concurrency: _concurrency, minIntervalMs: _minIntervalMs);
                  ref.read(llmServiceProvider).gate.updateLimits(
                      maxConcurrent: _concurrency,
                      minInterval: Duration(milliseconds: _minIntervalMs));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('并发与频控已保存')));
                  }
                },
                child: const Text('保存')),
          ),
        ]),
      ),
    ]);
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.label,
    required this.channels,
    required this.binding,
    required this.models,
    required this.onChanged,
  });
  final String label;
  final List<ChannelRoute> channels;
  final ({int channelId, String model})? binding;
  final List<String>? models;
  final void Function(int channelId, String model) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(children: [
        SizedBox(width: 190, child: Text(label, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: Space.s),
        Expanded(
          child: DropdownButton<int>(
            isExpanded: true,
            hint: const Text('渠道'),
            value: binding?.channelId,
            items: [
              for (final c in channels)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: binding == null && channels.isEmpty
                ? null
                : (cid) {
                    if (cid == null) return;
                    onChanged(cid, binding?.model ?? '');
                  },
          ),
        ),
        const SizedBox(width: Space.s),
        Expanded(
          child: PopupMenuButton<String>(
            isExpanded: true,
            initialValue: binding?.model,
            enabled: binding != null,
            itemBuilder: (ctx) => [
              if (models == null || models!.isEmpty)
                const PopupMenuItem(enabled: false, child: Text('先在该渠道「测试/拉模型」')),
              for (final m in models ?? const <String>[])
                PopupMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)),
            ],
            onSelected: (m) => onChanged(binding!.channelId, m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xs),
              decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(binding?.model ?? '模型',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ]),
    );
  }
}
```

**实现要点：** 渠道/槽位每次保存后都调用 `_applyRouting()`（`loadRouting` → `updateRouting`），运行中的管线无需重启即生效；槽位行"只切渠道未选模型"时不落库（模型必须来自该渠道拉取到的列表，防止手滑填出空模型）。`SectionCard` 的真实签名为 `{required title, required child, subtitle, leading, trailing, padding}`（见 `lib/ui/widgets/section_card.dart`），上文代码与之匹配。

- [ ] **Step 4: 设置页装配**——`settings_page.dart`：删除「LLM API」SectionCard 块（以 `_baseUrl`/`_apiKey`/`_modelCheap`/`_modelStandard`/`_modelVision` 控制器与"测试连接"按钮构成的那一组 SectionCard），原位置插入：

```dart
              const LlmChannelsSection(),
```

文件头 import 加 `package:peixi/features/settings/llm_channels_section.dart`；`_init()` 中删除加载旧 LLM 字段与 `_preset` 相关行（保留 `_totalTokens/_monthTokens/_budget` 及其展示块）；删除 `_testing` 与旧测试连接方法（若有）。被删控制器字段一并移除。

- [ ] **Step 5: 运行确认通过**

Run: `flutter test test/features/settings/ && flutter analyze`
Expected: PASS / 无 error

- [ ] **Step 6: 全量回归 + Commit**

```bash
flutter test
git add lib/features/settings test/features/settings lib/core/llm/llm_service.dart
git commit -m "feat(settings): 模型渠道/功能槽位/并发频控三区块，替换旧 LLM API 表单"
```

---

### Task 10: 手动冒烟（真渠道）

- [ ] **Step 1: 启动应用**（`flutter run -d windows`），确认旧单配置自动出现在「模型渠道」为"默认渠道"。
- [ ] **Step 2:** 「测试/拉模型」成功列出模型；把「深层分析」绑到另一渠道模型后，导入一个视频跑解说，`llm_logs.model` 为新模型。
- [ ] **Step 3:** 并发滑杆设为 1，最小间隔 500ms，批量导入 2 个小说，观察请求节奏明显放缓、无 429 雪崩。
- [ ] **Step 4: Commit（如有微调）**

```bash
git add -A && git commit -m "chore(settings): 渠道冒烟反馈微调"
```

---

## 自查记录

- Spec 覆盖：spec 第 4 节全部行为（渠道 CRUD/拉模型/槽位绑定/迁移/并发频控/视频顺迁）↔ Task 1-9；`embed` 为 spec 第 3.x 回忆层前置 ↔ Task 6。
- 类型一致性：`LlmSlot/ChannelRoute/RoutingTable` 在 Task 1 定义，Task 3/4/6/8/9 引用同名同签名；`modelOf(LlmSlot)` Task 4 定义、Task 7 使用。
- 已知留白：设置页旧 LLM 表单的精确删除行号依赖 Task 9 Step 4 的锚点说明（控制器名唯一，可安全定位）。
