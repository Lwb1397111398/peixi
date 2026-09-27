# Plan 2：小说两遍式管线（三趟流水线 + 调度器 + 导入即读）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development（`.zcode/skills/subagent-driven-development/SKILL.md`）执行本计划。每个 Task 由独立子代理实现，完成后必须经过独立 spec 合规审查 + 代码质量审查并修复，才可进入下一 Task。设计依据：`docs/superpowers/specs/2026-09-26-novel-two-pass-pipeline-design.md`（下称"设计文档"，章节号 §N 均指它）。

## Goal

把小说管线从"逐章逐块 ~3000 次串行调用、跑完全书才能读"重构为三趟流水线（地图 → 快照 → 批注，~760 次）+ 调度器（首屏冲刺 + 跟随模式），实现：导入即读、批注永远领先阅读、批注上下文含"故事至今 + 人物事件线"从而能写预示式/呼应式批注且不剧透。可选向量语义回忆（默认关，关闭零影响）。

## Architecture

```
N1 导入（不变）→ 立即可进阅读器
   ↓
NovelMapPass（summary 槽位）      每 5 章一调用，产出章摘要/出场名单/人物事件/人物增量
   ↓ 通过 chapters.map_done / cast_ids / character_events / characters.major 衔接
NovelDigestPass（summary 槽位）   每 10 章一调用，滚动摘要快照写各章 digest_before
   ↓ 通过 chapters.digest_before 衔接
NovelAnnotatePass（analysis 槽位）每 3 章一调用，上下文 = [故事至今][出场人物][相关前文回忆(可选)][前文摘要][本章正文]
   ↓ 写 annotations / knowledge_cards，annot_done 按章落库
NovelScheduler   首屏冲刺（前 10 章 map→digest→annotate）→ 跟随模式双泳道（地图泳道保领先 20 章；主泳道 digest 追赶 + annotate 按书序）
```

- 三层之间**只经数据库衔接**，上层不感知下层实现；任一层缺失自动降级（annotate 对缺 map/快照的章返回 0 等待）。
- 所有 LLM 调用走 `LlmService`（槽位解析 + 响应缓存 + 全局 `LlmGate` 并发/频控/429 收敛）。
- 批边界由**章节完成状态静态推导**（首个未完成章起连续 N 章）：崩溃续跑边界一致、响应缓存命中。
- JSON 解析失败自适应降批（减半 → 单章兜底 → 阶段失败）；摘要合成失败拼接截断兜底。
- 小说不再占用 `PipelineQueue` 串行车道（视频管线不受影响）；多本小说并发挂调度器，靠全局信号量交错。

## Tech stack

Flutter + Riverpod + Drift(sqlite) + Dio；Dart 3（switch 表达式/records 可用）。

## 基线与执行纪律

- 基线 commit `5755db4`，235 个测试全绿，`dart analyze` 干净。
- Flutter：`/c/Users/jingyue/AndroidTools/flutter/bin/flutter test <路径>`；分析：`/c/Users/jingyue/AndroidTools/flutter/bin/dart analyze`。
- **git 仓库根是 `C:/AIWorkSpace` 单体仓**：提交只允许显式 `git add <具体文件>`，**严禁 `git add -A` / `git add .`**。
- 每个 Task：先写测试（红）→ 实现（绿）→ `dart analyze` 干净 → 按给定 message 提交。
- 每个 Task 结束时全量测试必须保持通过（数量只增不减，除非本 Task 明确删除旧测试）。

---

# Group A：数据层与基础件

## Task 1：Schema v5（新列/新表）+ NovelMeta 扩展 + 旧项目回填

**改动文件**：`lib/core/database/app_database.dart`、`lib/features/pipeline/novel_importer.dart`、新增 `lib/features/pipeline/novel_backfill.dart`；新增测试 `test/core/database/schema_v5_test.dart`。

### 步骤

1. **写测试（红）** `test/core/database/schema_v5_test.dart`（沿用 `test/core/database/schema_v4_test.dart` 的 NativeDatabase.memory() 模式）：
   - 新建库：chapters 行含 `mapDone=false / annotDone=false / castIds='[]' / digestBefore=null`；characters 行含 `major=false`。
   - 迁移测试：手工建 v4 库（`PRAGMA user_version = 4` + v4 表结构，参考 `migration_v3_test.dart` 的做法），插入旧小说项目（summary 非空章、meta.annotatedPara=某章 end_para、meta.digest='旧摘要'），open 后断言：①summary 非空章 mapDone=true；②annotatedPara ≥ end_para 的章 annotDone=true；③第一个未批注章 digestBefore='旧摘要'；④annotations/characters/knowledgeCards 行数不变；⑤meta 中 chapterCount/annotatedChapters 已回填。
2. **实现**：
   - `app_database.dart`：`Chapters` 加列 `BoolColumn get mapDone => boolean().withDefault(const Constant(false))();`、`BoolColumn get annotDone => boolean().withDefault(const Constant(false))();`、`TextColumn get castIds => text().withDefault(const Constant('[]'))();`（SQL 列名 cast_ids）、`TextColumn get digestBefore => text().nullable()();`；`Characters` 加 `BoolColumn get major => boolean().withDefault(const Constant(false))();`；新增表：
     ```dart
     @TableIndex(name: 'idx_character_events_project', columns: {#projectId})
     @TableIndex(name: 'idx_character_events_character', columns: {#characterId})
     class CharacterEvents extends Table {
       IntColumn get id => integer().autoIncrement()();
       IntColumn get projectId =>
           integer().references(Projects, #id, onDelete: KeyAction.cascade)();
       IntColumn get characterId =>
           integer().references(Characters, #id, onDelete: KeyAction.cascade)();
       IntColumn get chapterIdx => integer()();
       TextColumn get event => text()();
     }

     class ChapterEmbeddings extends Table {
       IntColumn get id => integer().autoIncrement()();
       IntColumn get projectId =>
           integer().references(Projects, #id, onDelete: KeyAction.cascade)();
       IntColumn get chapterId =>
           integer().references(Chapters, #id, onDelete: KeyAction.cascade)();
       IntColumn get dim => integer()();
       TextColumn get vectorJson => text()(); // JSON List<double>
       @override
       List<Set<Column>> get uniqueKeys => [{chapterId}];
     }
     ```
     两表加入 `@DriftDatabase(tables: [...])`；`schemaVersion => 5`；onUpgrade 加：
     ```dart
     if (from < 5) {
       // v4→v5：两遍式管线的章级断点列 + 人物事件线 + 语义回忆索引（设计文档 §5）
       await m.addColumn(chapters, chapters.mapDone);
       await m.addColumn(chapters, chapters.annotDone);
       await m.addColumn(chapters, chapters.castIds);
       await m.addColumn(chapters, chapters.digestBefore);
       await m.addColumn(characters, characters.major);
       await m.createTable(characterEvents);
       await m.createTable(chapterEmbeddings);
       await backfillNovelV5(this);
     }
     ```
   - 新文件 `novel_backfill.dart`（设计文档 §5 五条规则的 Dart 实现，独立函数便于测试）：
     ```dart
     import 'package:drift/drift.dart';
     import 'package:peixi/core/database/app_database.dart';
     import 'package:peixi/features/pipeline/novel_importer.dart';

     /// v4→v5 旧项目回填（设计文档 §5）：
     /// ①summary 非空 → map_done=1；②meta.annotatedPara ≥ end_para → annot_done=1；
     /// ③旧 meta.digest → 首个未批注章的 digest_before（旧断点的"故事至今"）；
     /// ④批注/人物/知识卡原样保留（不触碰）；⑤annotatedPara 保留不再使用。
     Future<void> backfillNovelV5(AppDatabase db) async {
       final novels = await (db.select(db.projects)
             ..where((t) => t.type.equals('novel')))
           .get();
       for (final p in novels) {
         final meta = NovelMeta.fromJson(p.metaJson);
         final chapters = await (db.select(db.chapters)
               ..where((t) => t.projectId.equals(p.id))
               ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
             .get();
         if (chapters.isEmpty) continue;
         var annotCount = 0;
         Chapter? firstUnannot;
         for (final ch in chapters) {
           final mapDone = ch.summary != null && ch.summary!.isNotEmpty;
           final annotDone = meta.annotatedPara >= ch.endPara;
           if (annotDone) annotCount++;
           if (!annotDone && firstUnannot == null) firstUnannot = ch;
           if (!mapDone && !annotDone) continue;
           await (db.update(db.chapters)..where((t) => t.id.equals(ch.id))).write(
               ChaptersCompanion(
                   mapDone: Value(mapDone), annotDone: Value(annotDone)));
         }
         final digest = meta.digest;
         if (digest != null && digest.isNotEmpty && firstUnannot != null) {
           await (db.update(db.chapters)
                 ..where((t) => t.id.equals(firstUnannot.id)))
               .write(ChaptersCompanion(digestBefore: Value(digest)));
         }
         meta
           ..chapterCount = chapters.length
           ..annotatedChapters = annotCount;
         await (db.update(db.projects)..where((t) => t.id.equals(p.id))).write(
             ProjectsCompanion(metaJson: Value(meta.encode())));
       }
     }
     ```
   - `novel_importer.dart`：`NovelMeta` 加字段 `int chapterCount = 0;` 与 `int annotatedChapters = 0;`（toJson/fromJson 同步加，fromJson 容错缺 key）；`NovelImporter.import` 创建 meta 时 `chapterCount` 记 `doc.chapters.length`。
3. **生成与验证**：`flutter pub run build_runner build --delete-conflicting-outputs`（或项目既有的 codegen 命令）；新测试绿；全量测试绿；`dart analyze` 干净。
4. **提交**：
   ```bash
   git add lib/core/database/app_database.dart lib/core/database/app_database.g.dart \
     lib/features/pipeline/novel_importer.dart lib/features/pipeline/novel_backfill.dart \
     test/core/database/schema_v5_test.dart
   git commit -m "feat(db): schema v5——章级 map/annot 断点列、人物事件线、向量索引表 + 旧项目回填"
   ```

## Task 2：NovelParams 设置项

**改动文件**：`lib/core/settings/settings_repository.dart`；新增测试 `test/core/settings/settings_novel_params_test.dart`。

### 步骤

1. **写测试（红）**：空库 → `loadNovelParams()` 返回默认 `{mapBatch:5, digestBatch:10, annotateBatch:3, burst:10, mapLead:20, vectorRecall:false}`；写入越界值（mapBatch=99、mapLead=0）→ 读取被钳制（mapBatch∈[1,10]、mapLead≥1）；`saveNovelParams` 后 roundtrip 一致。
2. **实现**（风格镜像现有 `loadLlmLimits/saveLlmLimits`，若仓库内部有私有读写帮助方法则沿用）：
   ```dart
   /// 小说两遍式管线参数（设计文档 §3；mapLead 下限 1，为 0 会让地图/批注双泳道互等死锁）。
   class NovelParams {
     const NovelParams({
       this.mapBatchChapters = 5,
       this.digestBatchChapters = 10,
       this.annotateBatchChapters = 3,
       this.initialBurstChapters = 10,
       this.mapLeadChapters = 20,
       this.vectorRecall = false,
     });
     final int mapBatchChapters;
     final int digestBatchChapters;
     final int annotateBatchChapters;
     final int initialBurstChapters;
     final int mapLeadChapters;
     final bool vectorRecall;
   }
   ```
   `SettingsRepository` 加：
   ```dart
   static const _novelKeys = {
     'mapBatch': 'novel.mapBatchChapters',
     'digestBatch': 'novel.digestBatchChapters',
     'annotateBatch': 'novel.annotateBatchChapters',
     'burst': 'novel.initialBurstChapters',
     'mapLead': 'novel.mapLeadChapters',
     'vectorRecall': 'novel.vectorRecall',
   };

   Future<NovelParams> loadNovelParams() async {
     Future<int?> readInt(String key) async { /* 镜像 loadLlmLimits 的读法 */ }
     final mapBatch = (await readInt(_novelKeys['mapBatch']!) ?? 5).clamp(1, 10);
     final digestBatch = (await readInt(_novelKeys['digestBatch']!) ?? 10).clamp(1, 50);
     final annotateBatch = (await readInt(_novelKeys['annotateBatch']!) ?? 3).clamp(1, 10);
     final burst = (await readInt(_novelKeys['burst']!) ?? 10).clamp(1, 200);
     final mapLead = (await readInt(_novelKeys['mapLead']!) ?? 20).clamp(1, 500);
     final recallRow = await (db.select(settings)..where((t) => t.key.equals(_novelKeys['vectorRecall']!))).getSingleOrNull();
     return NovelParams(
         mapBatchChapters: mapBatch, digestBatchChapters: digestBatch,
         annotateBatchChapters: annotateBatch, initialBurstChapters: burst,
         mapLeadChapters: mapLead,
         vectorRecall: recallRow?.value == 'true');
   }

   Future<void> saveNovelParams(NovelParams p) async {
     /* 逐 key into(settings).insertOnConflictUpdate(SettingsCompanion.insert(key: ..., value: ...)) */
   }
   ```
3. 测试绿 + 全量绿 + analyze 干净。
4. **提交**：`git add lib/core/settings/settings_repository.dart test/core/settings/settings_novel_params_test.dart` → `feat(settings): 小说管线参数 novel.*（批大小/首屏/领先/回忆开关）`

## Task 3：三个新 Prompt 模板

**改动文件**：`lib/core/llm/prompts.dart`；新增测试 `test/core/llm/prompts_novel_v2_test.dart`。

### 步骤

1. **写测试（红）**：断言三个模板包含关键锚点——`novelMap` 含 `[已知人物名单]`、`"chapters"` 输出结构、`禁止编造`；`digestMerge` 含 `400字`、`未回收伏笔`、`{"digest"`；`novelAnnotateV2` 含 `[故事至今]`、`[出场人物]`、`[前文摘要]`、`[本章正文`、三条硬规则原文（`绝不透露后文走向与结局`、`在酝酿什么`、`具体事实`）、`宁缺毋滥`；且 recall 为空串时**不出现** `[相关前文回忆]`。
2. **实现**——`Prompts` 类追加（旧 `novelCast`/`novelAnnotation` 本 Task 保留不动，Task 8 随旧引擎一起删）：
   ```dart
   /// Prompt N2v2（地图趟，设计文档 §7.1；summary 槽位）
   static String novelMap({
     required String roster,
     required List<String> chapterBlocks,
   }) =>
       '你是小说地图整理助手。以下是截至上一批为止的已知人物名单（仅主要与近期活跃人物），'
       '以及连续多章正文，请逐章整理。\n'
       '[已知人物名单]\n$roster\n'
       '[正文]\n${chapterBlocks.join('\n\n')}\n'
       '任务：\n'
       '①为每一章写 150~300 字摘要：概括本章情节、转折与人物关系变化。\n'
       '②列出每章出场人物（cast，用名单或正文中的名字）。\n'
       '③记录人物关键事件：只记对后文可能有意义的事（立誓、结怨、获物、别离、身份揭晓等），'
       '主要人物每章至多 2 条，龙套不记。\n'
       '④维护人物名单：新出现的重要人物给一句话人设（身份/性格/立场）；'
       '名单中已有人物若人设变化则更新其 profile；贯穿全书的重要人物 major=true。\n'
       '输出：{"chapters":[{"idx":0,"summary":"...","cast":["人物名"],'
       '"events":[{"name":"人物名","event":"一句"}],'
       '"characters":[{"name":"新人物或更新人物","profile":"一句话人设","major":false}]}]}\n'
       '要求：idx 必须与正文标注的章号一致；只依据文本，禁止编造；无名龙套不收录。';

   /// Prompt N3v2（故事地图趟，设计文档 §7.2；summary 槽位）
   static String digestMerge({
     required String oldDigest,
     required List<String> chapterSummaries,
   }) =>
       '将旧摘要与新章节摘要合并为不超过400字的"故事至今"摘要。\n'
       '必须保留：人物关系与立场、当前悬念、未回收伏笔（逐条短语列出）。\n'
       '[旧摘要]$oldDigest\n'
       '[新章摘要]\n${chapterSummaries.map((s) => '- $s').join('\n')}\n'
       '输出：{"digest":"..."}';

   /// Prompt N4v2（批注趟，设计文档 §7.3；analysis 槽位。人设=陪读老友）
   static String novelAnnotateV2({
     required String digest,
     required String cast,
     required String recall,
     required String recentSummaries,
     required String chaptersText,
     required int chapterStart,
     required int chapterEnd,
   }) =>
       '你是用户的陪读老友，陪用户读小说、提升情商与思维。只依据"故事至今"与本章前文发言。\n'
       '[故事至今]$digest\n'
       '[出场人物]\n$cast\n'
       '${recall.isEmpty ? '' : '[相关前文回忆]\n$recall\n'}'
       '[前文摘要]${recentSummaries.isEmpty ? '（本章即故事开头）' : recentSummaries}\n'
       '[本章正文（第$chapterStart~$chapterEnd章，每行开头 [n] 是段落编号 para_idx，批注必须锚定到它）]\n$chaptersText\n'
       '三条硬规则：\n'
       '1. 只基于"故事至今"与本章前文，绝不透露后文走向与结局；\n'
       '2. 可以点破"在酝酿什么"（如"他心里开始犯嘀咕，总觉得这事没完"），但不点名后果；\n'
       '3. 引用前文必须用[出场人物]与[前文摘要]里的具体事实，不许空泛。\n'
       '输出：\n'
       '{"chapters":[\n'
       ' {"idx":$chapterStart,"annotations":[\n'
       '  {"para_idx":0,"type":"L1","content":"潜台词解读，2~4句解释性叙述"},\n'
       '  {"para_idx":0,"type":"L2","content":"心理分析：动机/性格/情绪，2~4句"},\n'
       '  {"para_idx":0,"type":"L3","content":{"term":"名词","text":"150字内知识","uncertain":false}},\n'
       '  {"para_idx":0,"type":"L4","content":{"question":"抛给用户的开放性问题，逼其代入思考","perspectives":["参考角度1","参考角度2","参考角度3"]}}\n'
       ' ]}\n'
       ']}\n'
       '要求：每章 3~8 条为基准、可上下浮动，只标有分析价值的段落，宁缺毋滥；'
       '禁止"此处埋下伏笔"式标签短语；para_idx 必须取自正文出现过的编号；'
       'idx 必须取自本次送审的章号；type 只能是 L1/L2/L3/L4；'
       'L1/L2 的 content 为字符串，L3/L4 的 content 为对象。';
   ```
3. 测试绿 + analyze 干净。
4. **提交**：`git add lib/core/llm/prompts.dart test/core/llm/prompts_novel_v2_test.dart` → `feat(prompts): 地图/快照/批注 v2 三模板——陪读老友人设与三条硬规则`

---

# Group B：三趟引擎

**测试基建（三个 Task 共用）**：沿用 `test/features/pipeline/novel_pipeline_test.dart` 的模式——`ScriptedAdapter implements HttpClientAdapter`（按请求序返回预置响应、记录 `requests`）、`ChannelRoute` 种子路由 + `LlmService(db: db, dio: Dio()..httpClientAdapter = adapter, backoffBase: Duration(milliseconds: 1))..updateRouting(RoutingTable(channels: [_route], slots: {LlmSlot.summary: SlotBinding(channelId: 0, model: 'flash'), LlmSlot.analysis: SlotBinding(channelId: 0, model: 'deep')}))`。造书用 `NovelImporter.import` + `NovelDoc/NovelChapter`。注意：`chatJson` 每次尝试最多产生 2 个 HTTP 请求（正文 + 修复链）。

## Task 4：NovelMapPass（地图趟）

**新文件**：`lib/features/pipeline/novel_map_pass.dart`；测试 `test/features/pipeline/novel_map_pass_test.dart`。

### 步骤

1. **写测试（红）**，覆盖：
   - **批量与落库**：5 章书、batchChapters=2 → 首次 step 处理第 0-1 章（断言请求正文含 `[章0`、`[章1`，不含 `[章2`）；响应含 summary/cast/events/characters → 断言 chapters.mapDone/summary/castIds 落库、characters 新建（含 profile/major）、character_events 行写入（chapter_idx 对应）；再次 step 处理 2-3 章，最后 step 处理第 4 章；全书完成后 step 返回 0。
   - **名单窗口**：给第 0 章造 castIds=[idA]，第 9 章（窗口外）造 castIds=[idB]；处理第 10 章起（rosterWindowChapters=5）时请求中的 `[已知人物名单]` 含 A 不含 B；major 人物（idB 设 major=true）则含。
   - **续跑确定性**：第 0-4 章已 mapDone → step 直接从第 5 章开始（边界 = 首个未完成章）。
   - **自适应降批**：batchChapters=2，脚本第 1 响应为非法 JSON（后续合法）→ step 内部降半重试成功；`onDegraded` 被调用；两章均落库。单章批解析两次失败（正文+修复均坏）→ rethrow `LlmJsonException`。
   - **取消**：isCancelled=true → step 抛 `PipelineCancelled`。
   - **返回值 = 新完成章数**：模型响应漏掉某章 idx → 该章不计入（不置 map_done），返回值相应减少。
2. **实现**（完整代码如下；`PipelineCancelled` 来自 `pipeline_engine.dart`）：
   ```dart
   import 'dart:convert';
   import 'dart:math' as math;

   import 'package:drift/drift.dart';
   import 'package:peixi/core/database/app_database.dart';
   import 'package:peixi/core/llm/llm_service.dart';
   import 'package:peixi/core/llm/prompts.dart';
   import 'package:peixi/features/pipeline/pipeline_engine.dart';

   /// 地图趟（设计文档 §3/§7.1，summary 槽位）：每批连续 N 章一次调用，
   /// 产出章摘要/出场名单/人物事件/人物增量；名单按 major + 50 章窗口快照，防 O(n²)。
   /// 批边界 = 首个未 map_done 章起连续 N 章（静态可重放，缓存命中）；
   /// 解析失败自适应降批（减半 → 单章兜底）。返回值 = 本批新完成章数（模型漏章不计）。
   class NovelMapPass {
     NovelMapPass({
       required AppDatabase db,
       required LlmService llm,
       this.batchChapters = 5,
       this.rosterWindowChapters = 50,
       this.maxChapterChars = 6000,
       this.onProgress,
       this.onDegraded,
       this.isCancelled,
     })  : _db = db,
           _llm = llm;

     final AppDatabase _db;
     final LlmService _llm;
     final int batchChapters;
     final int rosterWindowChapters;
     final int maxChapterChars;
     final void Function(int done, int total)? onProgress;
     final void Function(String detail)? onDegraded;
     final bool Function()? isCancelled;

     /// 推进一批；返回新完成章数（0 = 全书地图已完成）。
     Future<int> step(int projectId) async {
       final chapters = await _chapters(projectId);
       final first = chapters.indexWhere((c) => !c.mapDone);
       if (first < 0) return 0;
       final end = math.min(first + batchChapters, chapters.length);
       return _processBatch(projectId, chapters.sublist(first, end), chapters.length);
     }

     Future<int> _processBatch(
         int projectId, List<Chapter> batch, int total) async {
       if (isCancelled?.call() ?? false) throw const PipelineCancelled();
       final rosterText = await _roster(projectId, beforeIdx: batch.first.idx);
       final blocks = <String>[];
       for (final ch in batch) {
         final paras = await (_db.select(_db.paragraphs)
               ..where((t) => t.chapterId.equals(ch.id))
               ..orderBy([(p) => OrderingTerm.asc(p.idx)]))
             .get();
         blocks.add(_chapterBlock(ch, paras));
       }
       try {
         final result = await _llm.chatJson([
           {'role': 'user', 'content': Prompts.novelMap(roster: rosterText, chapterBlocks: blocks)},
         ], slot: LlmSlot.summary, purpose: 'novel_map', projectId: projectId);
         final doneCount = await _apply(projectId, batch, result);
         onProgress?.call(await _doneCount(projectId), total);
         return doneCount;
       } on LlmJsonException {
         if (batch.length == 1) rethrow;
         final mid = batch.length ~/ 2;
         onDegraded?.call('地图批解析失败，降批：${batch.length} → $mid + ${batch.length - mid}');
         return await _processBatch(projectId, batch.sublist(0, mid), total) +
             await _processBatch(projectId, batch.sublist(mid), total);
       }
     }

     String _chapterBlock(Chapter ch, List<Paragraph> paras) {
       var text = paras.map((p) => p.content).join('\n');
       if (text.length > maxChapterChars) {
         text =
             '${text.substring(0, maxChapterChars)}\n……（本章其余内容截断，仅供地图参考）';
       }
       return '[章${ch.idx} ${ch.title ?? '第${ch.idx + 1}部分'}]\n$text';
     }

     /// 名单摘录：major 全量 + 最近 rosterWindow 章出场者，合并去重，≤80 行。
     Future<String> _roster(int projectId, {required int beforeIdx}) async {
       final windowStart = beforeIdx - rosterWindowChapters;
       final windowChapters = await (_db.select(_db.chapters)
             ..where((t) => t.projectId.equals(projectId) &
                 t.idx.isBiggerOrEqualValue(windowStart) &
                 t.idx.isSmallerThanValue(beforeIdx)))
           .get();
       final recentIds = <int>{
         for (final ch in windowChapters)
           ...((jsonDecode(ch.castIds) as List? ?? []).cast<int>()),
       };
       final rows = await (_db.select(_db.characters)
             ..where((t) => t.projectId.equals(projectId)))
           .get();
       final picked = [
         for (final r in rows)
           if (r.major || recentIds.contains(r.id)) r,
       ]..sort((a, b) => (b.major ? 1 : 0).compareTo(a.major ? 1 : 0));
       if (picked.isEmpty) return '（尚无，本批为开头）';
       return [
         for (final r in picked.take(80))
           '${r.name}：${r.aliasesJson.isEmpty ? '（暂无人设）' : r.aliasesJson}${r.major ? '【主要】' : ''}',
       ].join('\n');
     }

     /// 落库（单事务）：人物增量 → cast 解析 → 事件 → 章行（summary/map_done/cast_ids）。
     /// 返回实际完成章数（响应缺章/摘要为空的不计）。
     Future<int> _apply(int projectId, List<Chapter> batch,
         Map<String, dynamic> result) async {
       final entries = <int, Map>{
         for (final e in (result['chapters'] as List? ?? []).cast<Map>())
           if (e['idx'] is num) (e['idx'] as num).toInt(): e,
       };
       final rows = await (_db.select(_db.characters)
             ..where((t) => t.projectId.equals(projectId)))
           .get();
       final idByName = {for (final r in rows) r.name: r.id};
       var done = 0;
       await _db.transaction(() async {
         for (final ch in batch) {
           final e = entries[ch.idx];
           if (e == null) continue;
           final summary = (e['summary'] ?? '').toString().trim();
           if (summary.isEmpty) continue;
           for (final c in (e['characters'] as List? ?? []).cast<Map>()) {
             final name = (c['name'] ?? '').toString().trim();
             if (name.isEmpty) continue;
             final profile = (c['profile'] ?? '').toString().trim();
             final major = c['major'] == true;
             final existingId = idByName[name];
             if (existingId == null) {
               idByName[name] = await _db.into(_db.characters).insert(
                   CharactersCompanion.insert(
                       projectId: projectId, name: name,
                       aliasesJson: Value(profile), major: Value(major)));
             } else if (profile.isNotEmpty || major) {
               await (_db.update(_db.characters)
                     ..where((t) => t.id.equals(existingId)))
                   .write(CharactersCompanion(
                       aliasesJson: profile.isNotEmpty
                           ? Value(profile)
                           : const Value.absent(),
                       major: major ? const Value(true) : const Value.absent()));
             }
           }
           final castIds = <int>[];
           for (final n in (e['cast'] as List? ?? [])) {
             final name = n.toString().trim();
             if (name.isEmpty) continue;
             var cid = idByName[name];
             if (cid == null) {
               cid = await _db.into(_db.characters).insert(
                   CharactersCompanion.insert(projectId: projectId, name: name));
               idByName[name] = cid;
             }
             castIds.add(cid);
           }
           for (final ev in (e['events'] as List? ?? []).cast<Map>()) {
             final name = (ev['name'] ?? '').toString().trim();
             final event = (ev['event'] ?? '').toString().trim();
             final cid = idByName[name];
             if (cid == null || event.isEmpty) continue;
             await _db.into(_db.characterEvents).insert(
                 CharacterEventsCompanion.insert(
                     projectId: projectId, characterId: cid,
                     chapterIdx: ch.idx, event: event));
           }
           await (_db.update(_db.chapters)..where((t) => t.id.equals(ch.id)))
               .write(ChaptersCompanion(
                   summary: Value(summary),
                   mapDone: const Value(true),
                   castIds: Value(jsonEncode(castIds))));
           done++;
         }
       });
       return done;
     }

     Future<List<Chapter>> _chapters(int projectId) async =>
         await (_db.select(_db.chapters)
               ..where((t) => t.projectId.equals(projectId))
               ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
             .get();

     Future<int> _doneCount(int projectId) async {
       final rows = await _chapters(projectId);
       return rows.where((c) => c.mapDone).length;
     }
   }
   ```

3. 测试绿 + 全量绿 + analyze 干净。
4. **提交**：`git add lib/features/pipeline/novel_map_pass.dart test/features/pipeline/novel_map_pass_test.dart` → `feat(novel): 地图趟——批量摘要/人物事件线/窗口名单 + 自适应降批`

## Task 5：NovelDigestPass（快照趟）

**新文件**：`lib/features/pipeline/novel_digest_pass.dart`；测试 `test/features/pipeline/novel_digest_pass_test.dart`。

### 步骤

1. **写测试（红）**：
   - 10 章书（均已 mapDone，summary='第i章摘要'）、digestBatchChapters=10 → step：请求含旧摘要占位与 10 条 `- 第i章摘要`；响应 `{"digest":"新摘要"}` → 断言批内每章 digestBefore == '（故事刚开始）'（批前快照；批内细粒度由批注趟[前文摘要]补足——这是设计决策，写进代码注释）、meta.digest == '新摘要'。
   - 第二次 step（再造 10 章）→ 请求含 meta.digest 的旧值；批内 digestBefore == 上一批产出。
   - **批在地图前沿截断**：digestBatch=5 但第 3 章 mapDone=false → 批只含第 0-2 章（防止批超界吃进未映射章导致冲刺阶段互等）。
   - **上游未就绪**：首个无快照章本身 mapDone=false → 截断后批为空 → step 返回 0 且不发起调用。
   - **续跑**：前 5 章 digestBefore 非空 → 批从第 5 章起（边界 = 首个无快照章）。
   - **兜底**：响应非法 JSON → `onDegraded` 调用，meta.digest == 拼接截断（含旧摘要与各章摘要，长度 ≤400）。
   - 取消 → `PipelineCancelled`。
2. **实现**：
   ```dart
   import 'dart:math' as math;

   import 'package:drift/drift.dart';
   import 'package:peixi/core/database/app_database.dart';
   import 'package:peixi/core/llm/llm_service.dart';
   import 'package:peixi/core/llm/prompts.dart';
   import 'package:peixi/features/pipeline/novel_importer.dart';
   import 'package:peixi/features/pipeline/pipeline_engine.dart';

   /// 快照趟（设计文档 §3/§7.2，summary 槽位）：每批 10 章一次合成调用；
   /// 批内每章 digest_before = 批前滚动摘要（运行摘要持久化在 meta.digest，与
   /// 快照同事务落库；崩溃续跑一致）。章内细粒度由批注趟的[前文摘要]（前一两章
   /// 章摘要）补足。合成失败 → 拼接截断兜底，不阻塞批注主线。
   class NovelDigestPass {
     NovelDigestPass({
       required AppDatabase db,
       required LlmService llm,
       this.batchChapters = 10,
       this.onProgress,
       this.onDegraded,
       this.isCancelled,
     })  : _db = db,
           _llm = llm;

     final AppDatabase _db;
     final LlmService _llm;
     final int batchChapters;
     final void Function(int done, int total)? onProgress;
     final void Function(String detail)? onDegraded;
     final bool Function()? isCancelled;

     /// 推进一批；返回章数（0 = 上游地图未就绪或全书快照已完成）。
     /// 批 = 首个无快照章起连续 N 章，且在地图前沿截断（不吃进未映射章，
     /// 否则首屏冲刺阶段 digest 与 map 互等死锁）。
     Future<int> step(int projectId) async {
       if (isCancelled?.call() ?? false) throw const PipelineCancelled();
       final chapters = await (_db.select(_db.chapters)
             ..where((t) => t.projectId.equals(projectId))
             ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
           .get();
       final first = chapters.indexWhere((c) => c.digestBefore == null);
       if (first < 0) return 0;
       final limit = math.min(first + batchChapters, chapters.length);
       final batch = <Chapter>[];
       for (var i = first; i < limit; i++) {
         final ch = chapters[i];
         if (!ch.mapDone || (ch.summary?.isEmpty ?? true)) break;
         batch.add(ch);
       }
       if (batch.isEmpty) return 0; // 地图先行（调度器保证领先；防御性等待）

       final project = await (_db.select(_db.projects)
             ..where((t) => t.id.equals(projectId)))
           .getSingle();
       final meta = NovelMeta.fromJson(project.metaJson);
       final oldDigest =
           (meta.digest ?? '').isEmpty ? '（故事刚开始）' : meta.digest!;
       final newDigest = await _merge(projectId, oldDigest, batch);
       await _db.transaction(() async {
         for (final ch in batch) {
           await (_db.update(_db.chapters)..where((t) => t.id.equals(ch.id)))
               .write(ChaptersCompanion(digestBefore: Value(oldDigest)));
         }
         meta.digest = newDigest;
         await (_db.update(_db.projects)..where((t) => t.id.equals(projectId)))
             .write(ProjectsCompanion(metaJson: Value(meta.encode())));
       });
       onProgress?.call(chapters.where((c) => c.digestBefore != null).length,
           chapters.length);
       return batch.length;
     }

     Future<String> _merge(
         int projectId, String oldDigest, List<Chapter> batch) async {
       try {
         final r = await _llm.chatJson([
           {
             'role': 'user',
             'content': Prompts.digestMerge(
                 oldDigest: oldDigest,
                 chapterSummaries: [
                   for (final ch in batch) '第${ch.idx}章 ${ch.summary}',
                 ]),
           }
         ], slot: LlmSlot.summary, purpose: 'novel_digest', projectId: projectId);
         final d = (r['digest'] ?? '').toString().trim();
         return d.isEmpty ? _fallback(oldDigest, batch) : d;
       } on LlmException {
         onDegraded?.call('摘要合成失败，拼接兜底（第${batch.first.idx}章起）');
         return _fallback(oldDigest, batch);
       }
     }

     String _fallback(String oldDigest, List<Chapter> batch) {
       final merged =
           '$oldDigest\n${batch.map((c) => c.summary).join('\n')}'.trim();
       return merged.length > 400 ? merged.substring(merged.length - 400) : merged;
     }
   }
   ```
3. 测试绿 + 全量绿 + analyze 干净。
4. **提交**：`git add lib/features/pipeline/novel_digest_pass.dart test/features/pipeline/novel_digest_pass_test.dart` → `feat(novel): 快照趟——10章合成滚动摘要 + digest_before 按章快照`

## Task 6：NovelAnnotatePass（批注趟）

**新文件**：`lib/features/pipeline/novel_annotate_pass.dart`；测试 `test/features/pipeline/novel_annotate_pass_test.dart`。

### 步骤

1. **写测试（红）**：
   - **上下文装配**：3 章批，造好 mapDone/summary/castIds/digestBefore → 请求正文依次含 `[故事至今]`（=首章 digestBefore）、`[出场人物]`（含人设 + 该章之前的事件线 ≤3 条；**不含**本章及之后的事件）、`[前文摘要]`（前两章 summary）、`[本章正文`，段落行 `[n] 正文` 全局 idx；recall=null → 无 `[相关前文回忆]`。
   - **落库**：响应 chapters[idx].annotations（L1/L2 字符串、L3 对象、L4 对象、越界 para_idx 丢弃、未知 type 丢弃）→ annotations 行、knowledgeCards L3 去重 upsert、annotDone=true；重复跑同一章（先造旧批注）→ 旧批注被清除（幂等重批）。
   - **批在上游前沿截断**：annotateBatch=3，第 2 章 digestBefore=null → 批只含第 0-1 章；首个未批注章本身未就绪 → 返回 0 不调用。
   - **降批**：batchChapters=3 首响应非法 JSON → 减半重试成功；onDegraded 调用；单章连续失败 → rethrow `LlmJsonException`。
   - **模型漏章**：响应缺某章 → 该章 annotDone 不置位、返回值不计。
   - **单章重批**：`reannotateChapter(projectId, idx)` 只发一次调用且只影响该章。
   - 取消 → `PipelineCancelled`。
2. **实现**：
   ```dart
   import 'dart:convert';
   import 'dart:math' as math;

   import 'package:drift/drift.dart';
   import 'package:peixi/core/database/app_database.dart';
   import 'package:peixi/core/llm/llm_service.dart';
   import 'package:peixi/core/llm/prompts.dart';
   import 'package:peixi/features/pipeline/novel_recall.dart';
   import 'package:peixi/features/pipeline/pipeline_engine.dart';

   /// 批注趟（设计文档 §3/§7.3，analysis 槽位）：每批连续 N 章一次调用。
   /// 上下文逐层拼装：[故事至今]=批首章 digest_before → [出场人物]=cast 人设+批前
   /// 事件线(≤3条/人) → [相关前文回忆](可选注入) → [前文摘要]=前一两章摘要 →
   /// [本章正文]。L1-L4 content 结构与旧版完全一致（阅读器/知识卡/SRS 依赖）。
   /// 按章分组校验落库：模型漏章不计 annot_done，下一轮重试；解析失败自适应降批。
   class NovelAnnotatePass {
     NovelAnnotatePass({
       required AppDatabase db,
       required LlmService llm,
       this.batchChapters = 3,
       this.recall,
       this.onProgress,
       this.onDegraded,
       this.isCancelled,
     })  : _db = db,
           _llm = llm;

     final AppDatabase _db;
     final LlmService _llm;
     final int batchChapters;
     final NovelRecallProvider? recall;
     final void Function(int done, int total)? onProgress;
     final void Function(String detail)? onDegraded;
     final bool Function()? isCancelled;

     /// 推进一批；返回新完成章数（0 = 上游未就绪或全书批注已完成）。
     /// 批 = 首个未批注章起连续 N 章，且在地图/快照前沿截断（同 DigestPass，
     /// 防止首屏冲刺阶段互等）。
     Future<int> step(int projectId) async {
       final chapters = await _chapters(projectId);
       final first = chapters.indexWhere((c) => !c.annotDone);
       if (first < 0) return 0;
       final limit = math.min(first + batchChapters, chapters.length);
       final batch = <Chapter>[];
       for (var i = first; i < limit; i++) {
         final ch = chapters[i];
         if (!ch.mapDone || ch.digestBefore == null) break;
         batch.add(ch);
       }
       if (batch.isEmpty) return 0;
       return _processBatch(projectId, batch, chapters.length);
     }

     /// 单章重批（处理页按钮；调用方须保证调度器空闲）。
     Future<void> reannotateChapter(int projectId, int chapterIdx) async {
       final chapters = await _chapters(projectId);
       final idx = chapters.indexWhere((c) => c.idx == chapterIdx);
       if (idx < 0) throw PipelineException('章不存在: $chapterIdx');
       final ch = chapters[idx];
       if (!ch.mapDone || ch.digestBefore == null) {
         throw PipelineException('该章的地图或摘要尚未就绪');
       }
       await _processBatch(projectId, [ch], chapters.length);
     }

     Future<int> _processBatch(
         int projectId, List<Chapter> batch, int total) async {
       if (isCancelled?.call() ?? false) throw const PipelineCancelled();
       final prompt = await _buildPrompt(projectId, batch);
       try {
         final result = await _llm.chatJson([
           {'role': 'user', 'content': prompt},
         ], slot: LlmSlot.analysis, purpose: 'novel_annotate', projectId: projectId);
         final done = await _apply(projectId, batch, result);
         onProgress?.call(await _doneCount(projectId), total);
         return done;
       } on LlmJsonException {
         if (batch.length == 1) rethrow;
         final mid = batch.length ~/ 2;
         onDegraded?.call('批注批解析失败，降批：${batch.length} → $mid + ${batch.length - mid}');
         return await _processBatch(projectId, batch.sublist(0, mid), total) +
             await _processBatch(projectId, batch.sublist(mid), total);
       }
     }

     Future<String> _buildPrompt(int projectId, List<Chapter> batch) async {
       final paras = await (_db.select(_db.paragraphs)
             ..where((t) => t.chapterId.isIn([for (final c in batch) c.id]))
             ..orderBy([(p) => OrderingTerm.asc(p.idx)]))
           .get();
       final byChapter = <int, List<Paragraph>>{};
       for (final p in paras) {
         if (p.chapterId == null) continue;
         (byChapter[p.chapterId!] ??= []).add(p);
       }
       final digest = batch.first.digestBefore!;
       final castIds = <int>{
         for (final ch in batch)
           ...((jsonDecode(ch.castIds) as List? ?? []).cast<int>()),
       };
       final cast = await _castSection(projectId,
           beforeIdx: batch.first.idx, ids: castIds);
       final recallText = await recall?.recallContext(projectId,
               beforeChapterIdx: batch.first.idx, query: digest) ??
           '';
       final prev = await (_db.select(_db.chapters)
             ..where((t) => t.projectId.equals(projectId) &
                 t.idx.isBiggerOrEqualValue(batch.first.idx - 2) &
                 t.idx.isSmallerThanValue(batch.first.idx))
             ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
           .get();
       final recent = [
         for (final c in prev)
           if ((c.summary ?? '').isNotEmpty) '第${c.idx}章：${c.summary}',
       ].join('\n');
       final blocks = [
         for (final ch in batch)
           '[第${ch.idx}章 ${ch.title ?? ''}]\n'
               '${(byChapter[ch.id] ?? const []).map((p) => '[${p.idx}] ${p.content}').join('\n')}',
       ];
       return Prompts.novelAnnotateV2(
           digest: digest,
           cast: cast,
           recall: recallText,
           recentSummaries: recent,
           chaptersText: blocks.join('\n\n'),
           chapterStart: batch.first.idx,
           chapterEnd: batch.last.idx);
     }

     /// [出场人物]：cast 并集 → 人设 + 批前事件线（每人物最近 3 条，时间正序），
     /// major 优先，≤30 行。
     Future<String> _castSection(int projectId,
         {required int beforeIdx, required Set<int> ids}) async {
       if (ids.isEmpty) return '（本章暂无已知出场人物）';
       final rows = await (_db.select(_db.characters)
             ..where((t) => t.projectId.equals(projectId) & t.id.isIn(ids.toList())))
           .get()
         ..sort((a, b) => (b.major ? 1 : 0).compareTo(a.major ? 1 : 0));
       final events = await (_db.select(_db.characterEvents)
             ..where((t) => t.projectId.equals(projectId) &
                 t.characterId.isIn(ids.toList()) &
                 t.chapterIdx.isSmallerThanValue(beforeIdx))
             ..orderBy([(e) => OrderingTerm.desc(e.chapterIdx)]))
           .get();
       final byChar = <int, List<CharacterEvents>>{};
       for (final e in events) {
         (byChar[e.characterId] ??= []).add(e);
       }
       final lines = <String>[];
       for (final r in rows.take(30)) {
         final evs = [
           for (final e in (byChar[r.id] ?? const []).reversed.take(3)) e.event,
         ];
         lines.add('${r.name}${r.major ? '【主要人物】' : ''}：'
             '${r.aliasesJson.isEmpty ? '（暂无人设）' : r.aliasesJson}'
             '${evs.isEmpty ? '' : '；前文：${evs.join('；')}'}');
       }
       return lines.isEmpty ? '（本章暂无已知出场人物）' : lines.join('\n');
     }

     Future<int> _apply(int projectId, List<Chapter> batch,
         Map<String, dynamic> result) async {
       final entries = <int, Map>{
         for (final e in (result['chapters'] as List? ?? []).cast<Map>())
           if (e['idx'] is num) (e['idx'] as num).toInt(): e,
       };
       final paras = await (_db.select(_db.paragraphs)
             ..where((t) => t.chapterId.isIn([for (final c in batch) c.id])))
           .get();
       final byChapter = <int, List<Paragraph>>{};
       for (final p in paras) {
         if (p.chapterId == null) continue;
         (byChapter[p.chapterId!] ??= []).add(p);
       }
       var done = 0;
       await _db.transaction(() async {
         for (final ch in batch) {
           final e = entries[ch.idx];
           if (e == null) continue; // 模型漏章：不置 annot_done，下轮重试
           final chapterParas = byChapter[ch.id] ?? const <Paragraph>[];
           if (chapterParas.isEmpty) continue;
           final paraByIdx = {for (final p in chapterParas) p.idx: p};
           final inserts = <(Paragraph, String, Map<String, dynamic>)>[];
           for (final a in (e['annotations'] as List? ?? []).cast<Map>()) {
             final idx = (a['para_idx'] as num?)?.toInt();
             final type = (a['type'] ?? '').toString().trim();
             final para = idx == null ? null : paraByIdx[idx];
             if (para == null) continue;
             final content = normalizeAnnotationContent(type, a['content']);
             if (content == null) continue;
             inserts.add((para, type, content));
           }
           // 幂等重批：先清本章旧批注再写入（锚定 paraId）
           await (_db.delete(_db.annotations)
                 ..where((t) => t.paraId.isIn(chapterParas.map((p) => p.id).toList())))
               .go();
           for (final (para, type, content) in inserts) {
             await _db.into(_db.annotations).insert(AnnotationsCompanion.insert(
                 paraId: para.id, type: type, contentJson: jsonEncode(content)));
             if (type == 'L3' && content['term'] != null) {
               await _upsertKnowledgeCard(projectId, content);
             }
           }
           await (_db.update(_db.chapters)..where((t) => t.id.equals(ch.id)))
               .write(ChaptersCompanion(annotDone: const Value(true)));
           done++;
         }
       });
       return done;
     }

     Future<void> _upsertKnowledgeCard(
         int projectId, Map<String, dynamic> l3) async {
       final term = (l3['term'] ?? '').toString();
       final existing = await (_db.select(_db.knowledgeCards)
             ..where((t) => Expression.and(
                 [t.projectId.equals(projectId), t.term.equals(term)])))
           .getSingleOrNull();
       if (existing != null) return;
       await _db.into(_db.knowledgeCards).insert(KnowledgeCardsCompanion.insert(
             projectId: projectId,
             term: term,
             title: term,
             content: (l3['text'] ?? '').toString(),
             uncertain: Value(l3['uncertain'] == true),
           ));
     }

     Future<List<Chapter>> _chapters(int projectId) async =>
         await (_db.select(_db.chapters)
               ..where((t) => t.projectId.equals(projectId))
               ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
             .get();

     Future<int> _doneCount(int projectId) async {
       final rows = await _chapters(projectId);
       return rows.where((c) => c.annotDone).length;
     }
   }

   /// 归一化各类型批注 content（L1/L2 字符串 → {"text"}；L3 → {term,text,uncertain}；
   /// L4 → {question,perspectives}）。结构自旧版原样保留（阅读器/SRS 兼容）。
   Map<String, dynamic>? normalizeAnnotationContent(String type, dynamic content) {
     switch (type) {
       case 'L1':
       case 'L2':
         final text = content is String ? content.trim() : '';
         return text.isEmpty ? null : {'text': text};
       case 'L3':
         if (content is! Map) return null;
         final term = (content['term'] ?? '').toString().trim();
         final text = (content['text'] ?? '').toString().trim();
         if (term.isEmpty || text.isEmpty) return null;
         return {
           'term': term,
           'text': text,
           'uncertain': content['uncertain'] == true,
         };
       case 'L4':
         if (content is! Map) return null;
         final question = (content['question'] ?? '').toString().trim();
         final perspectives = [
           for (final p in (content['perspectives'] as List? ?? [])) p.toString(),
         ];
         if (question.isEmpty) return null;
         return {'question': question, 'perspectives': perspectives};
       default:
         return null;
     }
   }
   ```
   > Dart records `(Paragraph, String, Map<String, dynamic>)` 与解构 `for (final (a, b, c) in ...)` 需要 Dart 3（项目已在用 switch 表达式，可用）。
3. 测试绿 + 全量绿 + analyze 干净。
4. **提交**：`git add lib/features/pipeline/novel_annotate_pass.dart test/features/pipeline/novel_annotate_pass_test.dart` → `feat(novel): 批注趟 v2——整章批量、上下文五层拼装、按章幂等落库`

---

# Group C：调度与接线

## Task 7：NovelScheduler（首屏冲刺 + 双泳道跟随）

**新文件**：`lib/features/pipeline/novel_scheduler.dart`；测试 `test/features/pipeline/novel_scheduler_test.dart`。**同时**在 `lib/features/pipeline/pipeline_engine.dart` 增加：

```dart
/// 阶段级失败（调度器抛出）：引擎按 stage 落 FAILED + failed_stage。
class PipelineStageException implements Exception {
  PipelineStageException(this.stage, this.cause);
  final String stage;
  final Object cause;
  @override
  String toString() => '阶段 $stage 失败：$cause';
}
```

### 步骤

1. **写测试（红）**，10 章书（每章 2 段）、burst=4、mapBatch=2、digestBatch=3、annotateBatch=2、mapLead=3：
   - **首屏冲刺顺序**：脚本 2 map + 2 digest + 2 annotate 响应；跑完 run 前 4 章 map→digest→annotate 各就位（断言 chapters 状态 + llmLogs 的 purpose 顺序 = map,map,digest,digest,annotate,annotate）+ `onEvent` 收到 kind='burst'。
   - **跟随推进到全书完成**：补足剩余响应脚本 → run 完成：全书 mapDone/annotDone、meta.digest 非空、status 经 MAPPED → COMMENTARY_DONE → READY（llmLogs/事件可验）+ meta.annotatedChapters==10。
   - **地图领先保活**（观察请求序）：annotateBatch=2、mapLead=3、10 章全脚本 → 请求 purpose 序列中第 k 个 annotate 前 map 调用覆盖章数 ≥ 该 annotate 已完成章数 + 3（断言 llmLogs 序列满足约束即可，不必逐条推导——写成"map 的最后一个请求发生在 annotDone 达到 total 之前"级别的粗断言 + 明确的顺序断言：首屏后第一个请求是 map）。
   - **地图泳道失败传导**：脚本在跟随阶段 map 批返回坏 JSON 直至单章仍失败 → run 抛 `PipelineStageException('map', ...)`（等待 mapLane 错误浮出）。
   - **批注持续零进度失败**：annotate 永远漏章（响应只含已完成章）→ 连续 3 批 0 进度 → `PipelineStageException('annotate', ...)`。
   - **取消**：isCancelled 在首个 map 批完成后置 true → run 抛 `PipelineCancelled`，已落库部分保留、status 不变（IMPORTED）。
   - **里程碑只升不降**：预先把 status 设为 MAPPED → run 完成后不会回写 IMPORTED。
   - **模型漏章自愈**：首个 map 批响应缺第 1 章（其余正常）→ 后续批从第 1 章起重试，最终全书 mapDone；期间批注零进度不熔断（上游有进展）。
2. **实现**：
   ```dart
   import 'dart:async';
   import 'dart:math' as math;

   import 'package:drift/drift.dart';
   import 'package:peixi/core/database/app_database.dart';
   import 'package:peixi/core/llm/llm_service.dart';
   import 'package:peixi/core/settings/settings_repository.dart';
   import 'package:peixi/features/pipeline/novel_annotate_pass.dart';
   import 'package:peixi/features/pipeline/novel_digest_pass.dart';
   import 'package:peixi/features/pipeline/novel_importer.dart';
   import 'package:peixi/features/pipeline/novel_map_pass.dart';
   import 'package:peixi/features/pipeline/novel_recall.dart';
   import 'package:peixi/features/pipeline/pipeline_engine.dart';
   import 'package:peixi/features/pipeline/project_status.dart';

   /// 调度器事件：controller 转 PipelineEvent；UI 依赖 detail 文案 + 自行复算 DB。
   class NovelSchedulerEvent {
     NovelSchedulerEvent(this.kind, this.detail, {this.status});
     final String kind; // progress | burst | degraded | milestone
     final String detail;
     final ProjectStatus? status; // milestone 事件携带目标状态
   }

   typedef _Counts = ({int mapDone, int digestReady, int annotDone, int total});

   /// 小说调度器（设计文档 §6）：①首屏冲刺（前 burst 章 map→digest→annotate，
   /// 批注尽快就绪可读）②跟随模式双泳道：地图泳道保持 mapDone ≥ annotDone +
   /// mapLead（领先保活）；主泳道 digest 追赶（就绪 ≥ 批注完成 + 1）+ annotate
   /// 按书序推进。全部调用经 LlmService（全局信号量交错），取消/失败在批边界
   /// 优雅退出；里程碑 mapped/commentaryDone/ready 只升不降。
   class NovelScheduler {
     NovelScheduler({
       required AppDatabase db,
       required LlmService llm,
       required bool Function() isCancelled,
       NovelParams params = const NovelParams(),
       NovelRecallProvider? recall,
       void Function(NovelSchedulerEvent event)? onEvent,
     })  : _db = db,
           _isCancelled = isCancelled,
           _params = params,
           _recall = recall,
           _onEvent = onEvent {
       _mapPass = NovelMapPass(
           db: db, llm: llm, batchChapters: _params.mapBatchChapters,
           isCancelled: _isCancelled,
           onDegraded: (d) => _onEvent?.call(NovelSchedulerEvent('degraded', d)),
           onProgress: (done, total) => _onEvent
               ?.call(NovelSchedulerEvent('progress', '地图 $done/$total 章')));
       _digestPass = NovelDigestPass(
           db: db, llm: llm, batchChapters: _params.digestBatchChapters,
           isCancelled: _isCancelled,
           onDegraded: (d) => _onEvent?.call(NovelSchedulerEvent('degraded', d)));
       _annotatePass = NovelAnnotatePass(
           db: db, llm: llm, batchChapters: _params.annotateBatchChapters,
           recall: recall, isCancelled: _isCancelled,
           onDegraded: (d) => _onEvent?.call(NovelSchedulerEvent('degraded', d)),
           onProgress: (done, total) {
             _onEvent?.call(NovelSchedulerEvent('progress', '批注 $done/$total 章'));
             final pid = _currentProjectId;
             if (pid != null) unawaited(_updateBadge(pid, done));
           });
     }

     static const _pollInterval = Duration(milliseconds: 100);

     late final NovelMapPass _mapPass;
     late final NovelDigestPass _digestPass;
     late final NovelAnnotatePass _annotatePass;
     final AppDatabase _db;
     final bool Function() _isCancelled;
     final NovelParams _params;
     final NovelRecallProvider? _recall;
     final void Function(NovelSchedulerEvent event)? _onEvent;
     int? _currentProjectId;
     bool _stopped = false; // 主泳道退出后置位，地图泳道据此收尾

     Future<void> run(int projectId) async {
       _currentProjectId = projectId;
       final total = await _chapterCount(projectId);
       if (total == 0) {
         await _finish(projectId);
         return;
       }
       final burstEnd = math.min(_params.initialBurstChapters, total);
       // ① 首屏冲刺
       await _advanceTo(projectId, 'map', _mapPass.step, burstEnd);
       await _recall?.ensureIndexed(projectId); // 摘要就绪即向量化（可选层）
       await _advanceTo(projectId, 'digest', _digestPass.step, burstEnd);
       await _advanceTo(projectId, 'annotate', _annotatePass.step, burstEnd);
       _onEvent?.call(NovelSchedulerEvent('burst', '前 $burstEnd 章批注已就绪，可以开始阅读'));
       // ② 跟随模式：地图泳道 + 主泳道并发（LLM 调用经全局信号量交错）
       final mapLaneError = <Object?>[];
       final mapLane = _mapLane(projectId, total)
           .catchError((Object e) => mapLaneError.add(e));
       try {
         await _followLane(projectId, total, mapLaneError);
       } catch (_) {
         _stopped = true; // 主泳道失败/取消 → 停掉地图泳道，别让它继续消耗调用
         rethrow;
       }
       await mapLane;
       if (mapLaneError.isNotEmpty) throw mapLaneError.first; // 末尾竞态取消不吞掉
       await _finish(projectId);
     }

     Future<void> _advanceTo(int projectId, String stage,
         Future<int> Function(int) step, int target) async {
       try {
         var zeroStreak = 0;
         while (true) {
           if (_isCancelled()) throw const PipelineCancelled();
           if (await _targetDone(projectId, stage, target)) return;
           final n = await step(projectId);
           if (n == 0) {
             // 冲刺阶段上游已就绪，0 只能是持续无进展（如模型恒漏同一章）→ 熔断
             zeroStreak++;
             if (zeroStreak >= 10) {
               throw PipelineStageException(stage, '连续 10 批无法推进');
             }
             await Future.delayed(_pollInterval);
             continue;
           }
           zeroStreak = 0;
         }
       } on PipelineCancelled {
         rethrow;
       } on PipelineStageException {
         rethrow;
       } catch (e) {
         throw PipelineStageException(stage, e); // LlmException 等按当前阶段落盘
       }
     }

     /// 目标判定用"第 target-1 章的完成标志"而非计数——计数会被批超界/模型
     /// 漏章形成的"洞"骗过（count 够但窗口内有洞 → 假就绪）。
     Future<bool> _targetDone(int projectId, String stage, int target) async {
       final ch = await (_db.select(_db.chapters)
             ..where((t) => t.projectId.equals(projectId) &
                 t.idx.equals(target - 1)))
           .getSingleOrNull();
       if (ch == null) return true; // 书比 target 短
       return switch (stage) {
         'map' => ch.mapDone,
         'digest' => ch.digestBefore != null,
         _ => ch.annotDone,
       };
     }

     Future<void> _mapLane(int projectId, int total) async {
       try {
         while (true) {
           if (_isCancelled() || _stopped) {
             throw const PipelineCancelled();
           }
           final firstUnmapped = await _firstIdx(projectId, (c) => !c.mapDone);
           if (firstUnmapped == null) break; // 全书地图完成
           final c = await _counts(projectId);
           if (firstUnmapped >= math.min(c.annotDone + _params.mapLeadChapters, total)) {
             await Future.delayed(_pollInterval); // 领先足够，让路给批注
             continue;
           }
           final n = await _mapPass.step(projectId);
           if (n == 0) {
             throw PipelineStageException('map', '地图趟推进返回 0（全书未完成）');
           }
           await _recall?.ensureIndexed(projectId); // 新摘要随到随向量化
         }
         await _setMilestone(
             projectId, ProjectStatus.mapped, detail: '地图趟全书完成');
       } on PipelineCancelled {
         rethrow;
       } on PipelineStageException {
         rethrow;
       } catch (e) {
         throw PipelineStageException('map', e);
       }
     }

     Future<void> _followLane(
         int projectId, int total, List<Object?> mapLaneError) async {
       try {
         var zeroStreak = 0;
         var lastUpstream = (mapDone: 0, digestReady: 0);
         while (true) {
           if (mapLaneError.isNotEmpty) throw mapLaneError.first;
           if (_isCancelled()) throw const PipelineCancelled();
           final c = await _counts(projectId);
           if (c.annotDone >= total) return;
           if (c.digestReady < c.annotDone + 1) {
             try {
               await _digestPass.step(projectId); // 快照追赶（就绪 ≥ 批注完成 + 1）
             } on PipelineCancelled {
               rethrow;
             } on PipelineStageException {
               rethrow;
             } catch (e) {
               throw PipelineStageException('digest', e);
             }
             continue;
           }
           final n = await _annotatePass.step(projectId);
           if (n == 0) {
             // 上游（地图泳道）有进展时不计零进度——批注只是在等洞被补上
             if (c.mapDone == lastUpstream.mapDone &&
                 c.digestReady == lastUpstream.digestReady) {
               zeroStreak++;
               if (zeroStreak >= 3) {
                 throw PipelineStageException('annotate', '连续 3 批未能产出批注且上游停滞');
               }
             } else {
               zeroStreak = 0;
             }
             lastUpstream = (mapDone: c.mapDone, digestReady: c.digestReady);
             await Future.delayed(_pollInterval);
             continue;
           }
           zeroStreak = 0;
         }
       } on PipelineCancelled {
         rethrow;
       } on PipelineStageException {
         rethrow;
       } catch (e) {
         throw PipelineStageException('annotate', e);
       }
     }

     /// 首个满足谓词的章号（null = 无）。
     Future<int?> _firstIdx(
         int projectId, bool Function(Chapter) predicate) async {
       final rows = await (_db.select(_db.chapters)
             ..where((t) => t.projectId.equals(projectId))
             ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
           .get();
       for (final r in rows) {
         if (predicate(r)) return r.idx;
       }
       return null;
     }

     Future<void> _finish(int projectId) async {
       await _setMilestone(projectId, ProjectStatus.commentaryDone, detail: '批注全部完成');
       await _setMilestone(projectId, ProjectStatus.ready, detail: '全书就绪');
     }

     /// 里程碑只升不降；FAILED 视为重跑恢复，允许直接写目标状态。
     Future<void> _setMilestone(int projectId, ProjectStatus target,
         {String? detail}) async {
       final p = await (_db.select(_db.projects)
             ..where((t) => t.id.equals(projectId)))
           .getSingleOrNull();
       if (p == null) return;
       final cur = ProjectStatus.fromDb(p.status);
       const order = [
         ProjectStatus.imported,
         ProjectStatus.mapped,
         ProjectStatus.commentaryDone,
         ProjectStatus.ready,
       ];
       final upgrade =
           cur == ProjectStatus.failed || order.indexOf(cur) < order.indexOf(target);
       if (!upgrade) return;
       await (_db.update(_db.projects)..where((t) => t.id.equals(projectId)))
           .write(ProjectsCompanion(
               status: Value(target.db),
               failedStage: const Value(null),
               updatedAt: Value(DateTime.now())));
       _onEvent?.call(NovelSchedulerEvent('milestone', detail ?? target.db, status: target));
     }

     /// 库页徽章计数（denormalized 到 meta，避免列表页逐卡查库）。
     Future<void> _updateBadge(int projectId, int annotatedChapters) async {
       try {
         final p = await (_db.select(_db.projects)
               ..where((t) => t.id.equals(projectId)))
             .getSingleOrNull();
         if (p == null) return;
         final meta = NovelMeta.fromJson(p.metaJson);
         if (meta.annotatedChapters == annotatedChapters) return;
         meta.annotatedChapters = annotatedChapters;
         await (_db.update(_db.projects)..where((t) => t.id.equals(projectId)))
             .write(ProjectsCompanion(metaJson: Value(meta.encode())));
       } catch (_) {
         // 徽章计数失败不影响主线
       }
     }

     Future<int> _chapterCount(int projectId) async =>
         (await _counts(projectId)).total;

     Future<_Counts> _counts(int projectId) async {
       final rows = await (_db.select(_db.chapters)
             ..where((t) => t.projectId.equals(projectId)))
           .get();
       return (
         mapDone: rows.where((c) => c.mapDone).length,
         digestReady: rows.where((c) => c.digestBefore != null).length,
         annotDone: rows.where((c) => c.annotDone).length,
         total: rows.length,
       );
     }
   }
   ```
   > 注意：①`_advanceTo` 传方法 tear-off，`step` 参数类型 `Future<int> Function(int)`；②非取消/非阶段异常一律包装成 `PipelineStageException(<当前阶段>)` 抛出（HTTP/JSON 失败由此落对 failedStage，引擎的兜底 catch 不再猜阶段）；③地图泳道经 `catchError` 捕获进 `mapLaneError`，`_followLane` 每轮先转发它；主泳道退出时置 `_stopped` 让地图泳道收尾，`run` 末尾再转发一次 `mapLaneError`（吞掉末尾竞态取消的情况不存在——最终统一 rethrow 给引擎）；④`unawaited` 需要 `dart:async`（已 import）；⑤目标判定用"第 target-1 章完成标志"而非计数——模型漏章会在章序中留"洞"，计数会误判就绪；⑥批注零进度熔断只在上游（地图/快照计数）也停滞时累计，地图泳道补洞期间不误杀。
3. 测试绿 + 全量绿 + analyze 干净。
4. **提交**：`git add lib/features/pipeline/novel_scheduler.dart lib/features/pipeline/pipeline_engine.dart test/features/pipeline/novel_scheduler_test.dart` → `feat(novel): 调度器——首屏冲刺 + 双泳道跟随 + 里程碑只升不降`

## Task 8：引擎/控制器接线 + 旧代码删除

**改动文件**：`lib/features/pipeline/novel_pipeline.dart`（重写引擎、删 `NovelCharacterExtractor`）、删除 `lib/features/pipeline/novel_commentary_generator.dart`、`lib/core/llm/prompts.dart`（删 `novelCast`/`novelAnnotation`）、`lib/features/pipeline/project_status.dart`（删 `novelEntryStatusOfStage`）、`lib/features/pipeline/pipeline_controller.dart`。

### 步骤

1. **重写 `novel_pipeline.dart`**：保留 `_events`/`_busy`/`_cancelRequested`/`requestCancel`/`isCancelled`/`_project`/`_setStatus`/`_emit`，新增 `bool isBusy(int projectId) => _busy.contains(projectId);`；`attachCollaborators` 换成：
   ```dart
   Future<void> Function(int projectId)? _runFn;

   /// 调度器注入点（推进/里程碑/取消检查都在调度器内；引擎只管语义外壳）
   void attachRun(Future<void> Function(int projectId) run) => _runFn = run;
   ```
   `run` 重写为：
   ```dart
   Future<void> run(int projectId) async {
     if (!_busy.add(projectId)) return;
     try {
       final p = await _project(projectId);
       final st = ProjectStatus.fromDb(p.status);
       _emit(projectId, 'novel',
           st == ProjectStatus.failed ? ProjectStatus.imported : st);
       await _runFn?.call(projectId);
     } on PipelineCancelled {
       final p = await _project(projectId);
       _emit(projectId, 'novel', ProjectStatus.fromDb(p.status),
           detail: '已取消（进度已保存，可继续）', cancelled: true);
     } on PipelineStageException catch (e) {
       await _setStatus(projectId, ProjectStatus.failed, failedStage: e.stage);
       _emit(projectId, 'novel', ProjectStatus.failed, detail: '$e');
     } catch (e) {
       await _setStatus(projectId, ProjectStatus.failed, failedStage: 'map');
       _emit(projectId, 'novel', ProjectStatus.failed, detail: '$e');
     } finally {
       _busy.remove(projectId);
     }
   }

   Future<void> retry(int projectId) => run(projectId);
   ```
   整个 `NovelCharacterExtractor` 类删除。文件头注释更新为两遍式架构说明。
2. **删除** `novel_commentary_generator.dart`（其 `_normalizeContent`/`_upsertKnowledgeCard` 已移入 Task 6 的 annotate pass）；`prompts.dart` 删 `novelCast`、`novelAnnotation` 及其注释行；`project_status.dart` 删 `novelEntryStatusOfStage`（`stageLabel` 加 `'novel' => '处理中',`）。
3. **`pipeline_controller.dart`**：
   - `novelEngine()` 改为：
     ```dart
     /// 小说管线（两遍式）：调度器驱动，不占 PipelineQueue 串行车道（§6.2）。
     Future<NovelPipelineEngine> novelEngine() async {
       if (_novelEngine != null) return _novelEngine!;
       final e = NovelPipelineEngine(db: ref.read(databaseProvider));
       final llm = ref.read(llmServiceProvider);
       final db = ref.read(databaseProvider);
       final repo = ref.read(settingsRepoProvider);
       e.attachRun((id) async {
         final params = await repo.loadNovelParams();
         final recall = null; // Task 13 接入：vectorRecall && embedding 槽位已绑定时 → NovelRecallService(db: db, llm: llm)
         final scheduler = NovelScheduler(
             db: db, llm: llm, params: params, recall: recall,
             isCancelled: () => e.isCancelled(id),
             onEvent: (ev) => _onSchedulerEvent(id, ev));
         await scheduler.run(id);
       });
       e.events.listen(_onEvent);
       _novelEngine = e;
       return e;
     }

     void _onSchedulerEvent(int projectId, NovelSchedulerEvent ev) {
       _onEvent(PipelineEvent(
           projectId: projectId,
           stage: 'novel',
           status: ev.status ?? ProjectStatus.imported,
           detail: ev.detail));
     }
     ```
     > Task 8 时刻 `NovelRecallService` 尚未存在——本 Task 先以 `recall: null` 接线（占位注释 `// Task 13 接入语义回忆`），Task 13 再改这 3 行。
   - `_startRun` 拆分：novel 不再走 `_queue`：
     ```dart
     void _startRun(String type, int projectId) {
       if (type == 'novel') {
         unawaited(_startNovel(projectId));
         return;
       }
       _queue.add(projectId, () async => (await engine()).run(projectId));
     }

     Future<void> _startNovel(int projectId) async {
       final e = await novelEngine();
       await e.run(projectId);
     }
     ```
     `import 'dart:async'` 补 `unawaited`（如已有则免）。grep `_startRun('novel'` 的调用点（importNovels 与 `_resumeAll`）确认语义不变——`_startRun` 内部已分流，调用点无需改动。
   - 暴露小说事件流与单章重批（供处理页/阅读器）：
     ```dart
     /// 小说引擎原始事件流（阅读器自动刷新订阅用）
     Stream<PipelineEvent> get novelEvents =>
         _novelEngine?.events ?? const Stream.empty();

     /// 单章重批（处理页按钮；调度器运行中拒绝）。
     Future<void> reannotateChapter(int projectId, int chapterIdx) async {
       final e = await novelEngine();
       if (e.isBusy(projectId)) {
         throw Exception('管线运行中，请先停止再重批单章');
       }
       final pass = NovelAnnotatePass(
           db: ref.read(databaseProvider), llm: ref.read(llmServiceProvider));
       await pass.reannotateChapter(projectId, chapterIdx);
       _onEvent(PipelineEvent(
           projectId: projectId, stage: 'novel',
           status: ProjectStatus.imported, detail: '已重批第 $chapterIdx 章'));
     }
     ```
   - `cancelProcessing`（找到现方法）确认对小说项目也调 `novelEngine().requestCancel`；`_resumeAll` 小说分支不变（状态过滤仍按 imported/mapped/commentaryDone，FAILED 项目由用户手动重试）。
4. **旧测试处理**：
   - `test/features/pipeline/novel_pipeline_test.dart`：删 `NovelCharacterExtractor` 的 group，保留 `NovelImporter` group；新增引擎外壳测试（attachRun 抛 `PipelineStageException` → status=FAILED+failedStage、emit failed 事件；抛 `PipelineCancelled` → cancelled 事件、状态不变；isBusy 语义）。
   - 删除 `test/features/pipeline/novel_commentary_generator_test.dart`。
   - `integration_test/real_pipeline_test.dart` 中引用 `NovelCharacterExtractor`/`NovelCommentaryGenerator` 的段落改为 `NovelMapPass`/`NovelAnnotatePass` 等价调用（该文件若仅手工跑可保编译通过即可）。
   - 全量测试回归：修复所有引用旧类的编译错误（grep `NovelCharacterExtractor|NovelCommentaryGenerator|novelEntryStatusOfStage|novelCast|novelAnnotation`）。
5. 测试绿 + analyze 干净。
6. **提交**：
   ```bash
   git add lib/features/pipeline/novel_pipeline.dart lib/features/pipeline/pipeline_controller.dart \
     lib/features/pipeline/project_status.dart lib/core/llm/prompts.dart \
     test/features/pipeline/novel_pipeline_test.dart integration_test/real_pipeline_test.dart
   git rm lib/features/pipeline/novel_commentary_generator.dart test/features/pipeline/novel_commentary_generator_test.dart
   git commit -m "refactor(novel): 引擎接线调度器、小说脱离串行队列，删除单章旧引擎（extractor/旧批注生成器）"
   ```

---

# Group D：UI 层（库页 / 处理页 / 阅读器）

## Task 9：库页——导入即读 + 批注徽章

**改动文件**：`lib/features/library/library_page.dart`；测试 `test/features/library/library_entry_test.dart`（新增）。

### 步骤

1. **写测试（红）**：novel 项目 status=IMPORTED（meta.chapterCount=10, annotatedChapters=3）→ 卡片主按钮文案「开始阅读」且点击进 ReaderPage（不进 ProcessingPage）；徽章显示「批注 3/10 章」；status=FAILED → 不放行（进处理页/重试路径）；video 项目行为不变（READY 才进 PlayerPage）。
2. **实现**（`library_page.dart`）：
   - 放行闸门（~line 519）：
     ```dart
     final isNovel = project.type == 'novel';
     if (isNovel && status != ProjectStatus.failed) {
       // 两遍式管线：导入即可读，批注随到随显（§6.3）
       → ReaderPage(projectId: project.id)
     } else if (status == ProjectStatus.ready) {
       → video PlayerPage
     } else {
       → ProcessingPage
     }
     ```
   - 卡片按钮文案：novel 非 failed 显示「开始阅读」（含处理中状态）；按钮/onTap 走同一闸门。
   - 徽章：novel 且 `meta.chapterCount > 0` 时显示 `批注 ${meta.annotatedChapters}/${meta.chapterCount} 章`（meta 从 `NovelMeta.fromJson(project.metaJson)` 取；放在状态文本旁，样式沿用现有 AppBadge）。
   - `statusLabel` 小说中态文案微调：`imported => '处理中 · 可阅读'`、`mapped => '地图完成 · 批注进行中 · 可阅读'`。
3. 测试绿 + 全量绿 + analyze 干净。
4. **提交**：`git add lib/features/library/library_page.dart test/features/library/library_entry_test.dart` → `feat(library): 小说导入即可读 + 批注进度徽章`

## Task 10：处理页——双泳道 + 领先徽章 + token + 单章重批

**改动文件**：`lib/features/processing/processing_page.dart`；测试 `test/features/processing/processing_novel_test.dart`（新增）。

### 步骤

1. **设计**：novel 处理卡片改为 **DB 为真相源**（事件流只触发重建）：页面加载与每次 controller state 变化时重查——章总数、mapDone 数、annotDone 数、meta.readingProgress、token 花费（`llm_logs` 按 projectId 汇总 prompt+completion）。
2. **写测试（红）**：造 10 章 novel（3 章 mapDone、2 章 annotDone、llm_logs 两行）→ 页面显示「地图 3/10 章」「批注 2/10 章」、LinearProgressIndicator 进度值正确、显示「本书已耗 token 60」（10+20 ×2行=60）、「领先阅读 N 章」（readingProgress.chapterIdx=0 → N=2）；运行中（state busy）显示 TextField+「重新批注此章」按钮为禁用；空闲时可用。
3. **实现**（`processing_page.dart` novel 分支重写；视频分支不动）：
   - `_novelStages` 常量删除；novel 卡片改用新 widget `_NovelSwimlanes`（ConsumerStatefulWidget）：
     ```dart
     class _NovelSwimlanes extends ConsumerStatefulWidget {
       const _NovelSwimlanes({required this.project});
       final Project project;
       ...
     }
     ```
     - `initState`/`ref.listen(pipelineControllerProvider, ...)` 触发 `_reload()`：查 chapters 全列（或 count 表达式）、projects.metaJson、llm_logs 汇总：
       ```dart
       final tokenSum = await (db.selectOnly(db.llmLogs)
             ..addColumns([db.llmLogs.promptTokens.sum(), db.llmLogs.completionTokens.sum()])
             ..where(db.llmLogs.projectId.equals(widget.project.id)))
           .getSingle();
       ```
     - 泳道行（沿用 `_stageRow` 的视觉风格或新建轻量行）：
       - 「地图 X/Y 章」+ LinearProgressIndicator(value: x/y)
       - 「批注 A/B 章」+ 进度条
       - `领先阅读 N 章` 徽章（N = annotDone − readingProgress.chapterIdx，>0 才显示；AppBadge 样式）
       - 「本书已耗 token T」（T = 两列 sum 之和）
       - 降批/取消提示行：controller state.detail 非空时以次要文字显示（含「已取消（进度已保存）」）
     - 单章重批区：`TextField(章号)` + `FilledButton('重新批注此章')`，busy 或 TextField 非法数字时禁用；onPressed → `ref.read(pipelineControllerProvider.notifier).reannotateChapter(id, n)`，异常用 ScaffoldMessenger snackbar 展示，成功后 `_reload()`。
     - 重试按钮（FAILED 项目）沿用现有重试路径（`retry` → engine.run）。
   - `stageLabel`/'novel' 分支（project_status.dart 已加）不再被 novel 卡片依赖。
4. 测试绿 + 全量绿 + analyze 干净。
5. **提交**：`git add lib/features/processing/processing_page.dart test/features/processing/processing_novel_test.dart` → `feat(processing): 小说双泳道进度 + 领先徽章 + token 花费 + 单章重批`

## Task 11：阅读器——批注自动刷新 + 生成中提示

**改动文件**：`lib/features/reader/reader_page.dart`；测试 `test/features/reader/reader_autorefresh_test.dart`（新增）。

### 步骤

1. **写测试（红）**：
   - 当前章 annotDone=false 且该项目 state.busy=true →AppBar 下方出现「本章批注生成中」轻提示（细条/角标）。
   - 管线事件到达（controller state 变化）且批注已落库 → 无需重进页面，段落气泡出现（`_anns` 重载）。
   - 提示在 annotDone=true 后消失。
2. **实现**（`reader_page.dart`）：
   - `_ReaderPageState` 增加防抖重载：
     ```dart
     Timer? _reloadDebounce;

     @override
     Widget build(BuildContext context) {
       // 管线批注随到随显：该项目状态变化（含批注进度/重批事件）→ 防抖重载当前章批注
       ref.listen(pipelineControllerProvider, (prev, next) {
         final s = next[widget.projectId];
         if (s == null) return;
         if (prev?[widget.projectId] == s) return;
         _reloadDebounce?.cancel();
         _reloadDebounce = Timer(const Duration(milliseconds: 800), () {
           if (mounted) _reloadAnnotations();
         });
       });
       ...
     }
     ```
     - 抽取 `_reloadAnnotations()`：重查当前章 `annotDone` 标志 + `annotationsByParaId(当前章段落 ids)` 并 setState（复用现有加载逻辑，勿重复查正文）。
     - `dispose` 取消 `_reloadDebounce`。
   - 生成中提示：当前章行 `annotDone == false` 且 `ref.watch(pipelineControllerProvider)[projectId]?.busy == true` 时，在正文列表顶部（或 AppBar 底部）渲染细提示条：
     ```dart
     if (_showGeneratingHint)
       const Material(
         child: SizedBox(
           width: double.infinity,
           child: Padding(
             padding: EdgeInsets.symmetric(vertical: 4),
             child: Center(child: Text('本章批注生成中…',
                 style: TextStyle(fontSize: 12)))),
         ),
       )
     ```
     `_showGeneratingHint` 由 `_reloadAnnotations` 与 busy 状态共同推导（正文加载时也求值一次）。
3. 测试绿 + 全量绿 + analyze 干净。
4. **提交**：`git add lib/features/reader/reader_page.dart test/features/reader/reader_autorefresh_test.dart` → `feat(reader): 批注随到随显——事件防抖刷新 + 本章生成中提示`

---

# Group E：集成验证

## Task 12：集成测试（全链路 / 续跑 / 取消 / 失败语义）

**新文件**：`test/features/pipeline/novel_two_pass_integration_test.dart`。全部用 ScriptedAdapter 假 LLM（模式同 Task 4 基建），10 章书（每章 2 段）。

### 用例

1. **全链路**：params 默认（burst=10、map=5、digest=10、annotate=3）。脚本 2 map + 1 digest + 4 annotate 响应（map 响应用 helper 构造 5 章 entries，含人物 林川(major=true)/事件/新人物；annotate 响应给 L1+L3）→ `scheduler.run(id)` 完成后断言：
   - 全书 mapDone/annotDone、summary 非空、castIds 解析正确、character_events 有行；
   - digestBefore 全部非空（第 0-9 章一致 = '（故事刚开始）'）；
   - annotations 落库且 L3 进 knowledgeCards；
   - llmLogs purpose 序列 = `[novel_map, novel_map, novel_digest, novel_annotate×4]`；
   - project.status == 'READY'，meta.annotatedChapters == 10。
2. **中途崩溃续跑**：adapter 先返回 2 map + 1 digest 后全部返回 HTTP 500（`backoffBase: 1ms`）→ run 抛 `PipelineStageException('annotate', ...)`（map/digest 已完成、无 annotDone）；换新 adapter 补足 annotate 响应再 run → 全书完成；断言 annotations 无重复（每 paraId 每类型至多 1 行）、characters 无重名、续跑只发 4 个 annotate 请求（map/digest 阶段因章节已完成直接跳过，不发任何请求）。
3. **取消**：`var cancelAfter = 2;` 包装 isCancelled（第 2 次 map step 后 true）→ run 抛 `PipelineCancelled`；断言 status 仍 'IMPORTED'、已完成的 map 章保留；再 run（不取消）可继续完成。
4. **失败语义（引擎外壳）**：`NovelPipelineEngine` + `attachRun(scheduler.run)`，annotate 脚本恒坏 JSON → `engine.run` 返回后 status='FAILED'、failedStage='annotate'、事件含 failed；`engine.retry` 前先修 adapter 为合法 → 恢复到 READY。
5. **里程碑只升不降**：把 status 预置 'MAPPED' → 完整 run → 终态 READY 且过程中无回写 IMPORTED（以 _setMilestone 顺序断言 + 终态为准）。

### 步骤

1. 写测试（红——部分断言依赖 Task 7/8 已落地，应直接绿；若有红先修实现）。
2. 全量测试 + analyze。
3. **提交**：`git add test/features/pipeline/novel_two_pass_integration_test.dart` → `test(novel): 两遍式全链路/续跑/取消/失败语义集成`

## Task 13：语义回忆模块（可选层，默认关）

**新文件**：`lib/features/pipeline/novel_recall.dart`；测试 `test/features/pipeline/novel_recall_test.dart`。

### 步骤

1. **写测试（红）**：
   - `cosineSimilarity([1,0],[0,1])==0`、`([1,1],[1,1])==1`（容差 1e-9）、零向量 → 0。
   - `recallContext`：3 章已有向量（脚本：embeddings 端点按请求返回不同向量）→ 命中 top1/top2 ≥ 阈值输出 `- 第{i}章摘要：{summary}` 行、排除 `chapterIdx >= beforeChapterIdx`、无命中/低于阈值返回 ''。
   - `ensureIndexed`：2 章摘要就绪无向量 → 调 embed 落 chapter_embeddings（dim/vectorJson 正确）；重复调用不重复落；embed 抛 LlmException → 静默返回（不抛）。
   - **注入集成**：`NovelAnnotatePass(recall: fakeProvider)` → 请求含 `[相关前文回忆]` 节与 fake 文本；`recall` 返回 '' → 节整体缺席。
   - **调度器三态**：recall=null → 无 embed 调用；recall 非 null → 每批地图完成（冲刺后 + 跟随泳道每步）后发生 ensureIndexed 的 embed 请求（摘要就绪即向量化）。
2. **实现**：
   ```dart
   import 'dart:convert';
   import 'dart:math' as math;

   import 'package:drift/drift.dart';
   import 'package:peixi/core/database/app_database.dart';
   import 'package:peixi/core/llm/llm_service.dart';

   /// 语义回忆提供者（批注趟可选上下文层；null = 整层跳过，零影响）。
   abstract class NovelRecallProvider {
     /// 为摘要就绪但无向量的章补建索引（幂等；失败静默）。
     Future<void> ensureIndexed(int projectId);

     /// [相关前文回忆] 文本：cos top3 前文章摘要；无命中/失败 → 空串。
     Future<String> recallContext(int projectId,
         {required int beforeChapterIdx, required String query});
   }

   /// 默认实现（设计文档 §3 回忆索引层）：章摘要向量入 chapter_embeddings，
   /// cos 相似度 Dart 侧计算（1200 章规模无需 sqlite 扩展）。embedding 槽位未绑定
   /// 或调用失败 → 整层静默降级，绝不阻塞批注主线。
   class NovelRecallService implements NovelRecallProvider {
     NovelRecallService({
       required AppDatabase db,
       required LlmService llm,
       this.topK = 3,
       this.minScore = 0.35,
     })  : _db = db,
           _llm = llm;

     final AppDatabase _db;
     final LlmService _llm;
     final int topK;
     final double minScore;

     @override
     Future<void> ensureIndexed(int projectId) async {
       try {
         final done = await (_db.select(_db.chapterEmbeddings)
               ..where((t) => t.projectId.equals(projectId)))
             .get();
         final indexed = done.map((e) => e.chapterId).toSet();
         final chapters = await (_db.select(_db.chapters)
               ..where((t) => t.projectId.equals(projectId) &
                   t.mapDone.equals(true)))
             .get();
         final pending = [
           for (final ch in chapters)
             if (!indexed.contains(ch.id) && (ch.summary ?? '').isNotEmpty) ch,
         ];
         if (pending.isEmpty) return;
         final vectors = await _llm.embed(
             [for (final ch in pending) ch.summary!],
             purpose: 'novel_recall', projectId: projectId);
         for (var i = 0; i < pending.length && i < vectors.length; i++) {
           await _db.into(_db.chapterEmbeddings).insert(
               ChapterEmbeddingsCompanion.insert(
                   projectId: projectId,
                   chapterId: pending[i].id,
                   dim: vectors[i].length,
                   vectorJson: jsonEncode(vectors[i])));
         }
       } on LlmException {
         return; // 整层静默降级（§8：索引下次补建）
       }
     }

     @override
     Future<String> recallContext(int projectId,
         {required int beforeChapterIdx, required String query}) async {
       try {
         final rows = await (_db.select(_db.chapterEmbeddings)
               ..where((t) => t.projectId.equals(projectId)))
             .get();
         if (rows.isEmpty) return '';
         final qv = (await _llm.embed([query],
                 purpose: 'novel_recall', projectId: projectId))
             .first;
         final chapterRows = await (_db.select(_db.chapters)
               ..where((t) => t.projectId.equals(projectId)))
             .get();
         final byId = {for (final c in chapterRows) c.id: c};
         final scored = <(double, Chapter)>[];
         for (final r in rows) {
           final ch = byId[r.chapterId];
           if (ch == null || ch.idx >= beforeChapterIdx) continue;
           final vec = [
             for (final v in (jsonDecode(r.vectorJson) as List)) (v as num).toDouble(),
           ];
           scored.add((cosineSimilarity(qv, vec), ch));
         }
         scored.sort((a, b) => b.$1.compareTo(a.$1));
         final hits = [
           for (final (score, ch) in scored)
             if (score >= minScore) ch,
         ].take(topK).toList();
         if (hits.isEmpty) return '';
         return [
           for (final ch in hits) '- 第${ch.idx}章摘要：${ch.summary}',
         ].join('\n');
       } on LlmException {
         return '';
       }
     }
   }

   double cosineSimilarity(List<double> a, List<double> b) {
     if (a.isEmpty || a.length != b.length) return 0;
     var dot = 0.0, na = 0.0, nb = 0.0;
     for (var i = 0; i < a.length; i++) {
       dot += a[i] * b[i];
       na += a[i] * a[i];
       nb += b[i] * b[i];
     }
     if (na == 0 || nb == 0) return 0;
     return dot / (math.sqrt(na) * math.sqrt(nb));
   }
   ```
   > 测试用 adapter 需区分端点：请求 path 含 `/embeddings` 返回 `{"data":[{"embedding":[...]}]}`，否则返回 chat choices 结构（写一个 `DualModeAdapter`）。
3. **接线（Task 8 留的占位）**：`pipeline_controller.dart` novelEngine 中：
   ```dart
   final recall = params.vectorRecall && llm.modelOf(LlmSlot.embedding) != null
       ? NovelRecallService(db: db, llm: llm)
       : null;
   ```
   删除占位注释。开关三态行为验证：关（null）零调用；中途开（下次 run 补建索引后生效）；中途关（向量留库、批注层跳过该节）——由调度器测试与本 Task 用例共同覆盖，无需额外代码。
4. 测试绿 + 全量绿 + analyze 干净。
5. **提交**：`git add lib/features/pipeline/novel_recall.dart lib/features/pipeline/pipeline_controller.dart test/features/pipeline/novel_recall_test.dart` → `feat(novel): 语义回忆可选层——摘要向量索引 + cos top3 注入，默认关零影响`

---

# 收尾

## Task 14：全量回归 + 冒烟准备 + 推送

1. `/c/Users/jingyue/AndroidTools/flutter/bin/dart analyze` 零问题。
2. `/c/Users/jingyue/AndroidTools/flutter/bin/flutter test` 全绿（记录最终数量，基线 235 + 本计划新增）。
3. grep 检查无残留：`NovelCharacterExtractor|NovelCommentaryGenerator|novelEntryStatusOfStage|novelCast|novelAnnotation` 应零命中（prompts_novel_v2_test 等新测试除外）。
4. `git status` 核对本计划文件全部已提交；`git push origin master`。
5. 输出冒烟清单给用户（真渠道手工验证）：导入长篇网文 → 1-2 分钟内可进阅读器且前 10 章有批注 → 边读边出现新批注 → 处理页双泳道/领先徽章/token → 设置页开启 `novel.vectorRecall` 并绑定 embedding 槽位 → 重启 app 续跑无损。

## Self-review 清单（执行前对照）

- [ ] 覆盖设计文档 §5 全部数据变更与 5 条回填规则（Task 1）
- [ ] §7 三个 prompt 措辞与 JSON 结构一致；L1-L4 content 结构与旧版完全一致（Task 3/6）
- [ ] §6 调度：冲刺顺序 map→digest→annotate、领先保活、digest ≥ 批注+1、优先级（批注让地图让路通过 poll 间隔体现）、取消/失败批边界退出（Task 7）
- [ ] §8 错误表：降批（map/annotate）、摘要兜底、429 由既有 gate 处理、崩溃续跑（静态批边界 + 缓存）、embedding 失败静默（Task 4/5/6/13）
- [ ] §9 UI 全项：库页入口+徽章、处理页双泳道+领先+token+单章重批、阅读器自动刷新+生成中提示（Task 9/10/11）
- [ ] §11 落地顺序：渠道（Plan 1 已完成）→ 迁移 → 三趟 → 调度+UI → 集成 → 回忆（本计划 Task 顺序一致）
- [ ] 每个任务都有红-绿 TDD 证据、analyze 干净、显式 git add（单体仓纪律）
- [ ] 无占位符/TODO 残留；所有新代码不直连 HTTP（一律走 LlmService 槽位）
