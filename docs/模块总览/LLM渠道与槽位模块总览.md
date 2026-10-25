# LLM 渠道与槽位模块总览

## 模块职责

管理用户自定义的 LLM 渠道（BASE_URL + API KEY）与功能槽位绑定（轻量/主力/视觉/向量四个角色各用哪条渠道的哪个模型），并提供全应用唯一的 LLM 调用出口（含并发频控、月度预算、响应缓存、重试退避）。**没有内置默认渠道与默认模型**——不配置就调不通，绝无隐藏的阿里云百炼。

## 运作流程

1. **渠道从哪来**：设置页「模型渠道」区块（`llm_channels_section.dart`）由用户手动添加，每条渠道填名称、BASE_URL（任意 OpenAI 兼容接口，中转站/官方 API 均可）、API KEY。渠道行存 drift 的 `llm_channels` 表（`app_database.dart`），API KEY 存 flutter_secure_storage（键 `llm.channel.<id>.api_key`），可添加任意多条。
2. **渠道怎么验证**：点「测试/拉模型」→ `LlmService.fetchModels()` GET `{BASE_URL}/models`，成功即弹出模型列表并缓存在页面 state（`_models`），供槽位绑定时选择。
3. **槽位怎么绑**：设置页「功能槽位」区块把四个角色（`LlmSlot.summary` 轻量模型=地图/摘要/知识卡、`LlmSlot.analysis` 主力模型=批注/解说、`LlmSlot.vision` 视觉模型=关键帧、`LlmSlot.embedding` 向量模型=前文回忆）各自绑定到「某渠道 + 该渠道拉到的某个模型」。绑定串 `channelId:model` 存 settings 表键 `llm.slot.<slotName>`。同一渠道可绑多个角色。
4. **调用时怎么解析**：管线代码统一调 `LlmService.chat/chatJson/chatVision/embed`（`llm_service.dart`）→ `RoutingTable.resolve(slot)`（`llm_routing.dart`）只认显式绑定且渠道可用，未绑定返回 null → 抛 `LlmException('尚未绑定「××模型」槽位')`。唯一例外：轻量槽位未绑定时 `_resolveFor` 自动降级用主力槽位（地图/摘要这类轻活依附于主力功能，静默跳过会退化；这是代码里写明的策略，不是隐藏默认模型）。
5. **请求怎么发**：POST `{BASE_URL}/chat/completions`（embed 走 `/embeddings`），带 `Authorization: Bearer <渠道 KEY>`；429/5xx 按 1s/2s/4s 退避重试 3 次，429 触发闸门冷却。每次成功调用按 usage 落 `llm_logs` 表（token 统计与月度预算依据）。
6. **闸门与预算**：`LlmGate` 限并发（默认 2 路，设置页「并发与频控」可调 1~8）+ 请求最小间隔；月度 token 预算超限抛 `LlmBudgetException` 暂停管线。
7. **响应缓存**：`chatJson` 的成功解析结果按 sha256(渠道 baseUrl+模型+全部消息) 存 `llm_cache` 表，同请求重跑零花费；解析失败不入缓存（保证「重跑覆盖 failed 占位」机制可用）。
8. **闭环**：设置页改动 → `_persistAndRefresh()` 重读路由表 → `LlmService.updateRouting()` 注入，运行中的管线立即生效，无需重启。

## 入口文件清单

- `lib/core/llm/llm_service.dart` —— 调用唯一出口（chat/chatJson/chatVision/embed/fetchModels/预算/缓存/重试）
- `lib/core/llm/llm_routing.dart` —— LlmSlot/ChannelRoute/SlotBinding/RoutingTable（解析规则：只认显式绑定）
- `lib/core/llm/llm_gate.dart` —— 并发/频控闸门
- `lib/core/llm/prompts.dart` —— 各管线环节的提示词模板
- `lib/features/settings/llm_channels_section.dart` —— 设置页渠道+槽位+并发 UI
- `lib/core/settings/settings_repository.dart` —— 渠道行/KEY/槽位串/并发频控的持久化

## 对外接口 / 被谁调用

- 视频/小说管线全部协作器（CharacterMapper、CommentaryGenerator、NovelScheduler 及各 pass、NovelRecallService、VisualAssistant）都通过 `llmServiceProvider` 调用。
- `providers.dart` 的 `llmServiceProvider` 在启动时装配路由表；设置页保存后再次注入。

## 依赖的上游模块

- 数据库（settings/llm_channels/llm_logs/llm_cache 表）
- 设置存储（secure storage 存 KEY）

## 关键数据结构

- `LlmSlot` 枚举：summary/analysis/vision/embedding
- `ChannelRoute`：id/name/baseUrl/apiKey/enabled（`usable` = enabled 且 baseUrl、KEY 非空）
- `RoutingTable`：channels 列表 + slots 映射，`resolve()` 是唯一解析入口
- settings 键：`llm.slot.<name>`（`channelId:model`）、`llm.concurrency`、`llm.min_request_interval_ms`、`llm.monthly_budget_tokens`

## 已知坑与约束

- **绑定指向已删渠道**：deleteChannel 事务内级联清绑定；脏数据（渠道被外部改库删掉）时 resolve 返回 null 报「未绑定」，UI 下拉回退占位提示。
- **轻量→主力降级**是有意设计：轻量槽位未绑定≠功能不可用，而是落到主力模型（稍贵但正确）。
- **无说话人分离的视觉依赖**：vision 槽位仅供 M3 实验性视觉辅助（关键帧判断谁在说话），未绑定时报错但不阻塞主线。
- **业务代码禁止直连厂商 SDK**：所有调用必须走 LlmService（设计稿 6.1 红线）。
- 2026-10-25 起：移除百炼默认回落（旧 `fallbackModelFor`/首可用渠道兜底）与旧单配置首启迁移；升级前若还停留在「旧单配置」未渠道化的安装，需在设置页重新添加渠道。

## 最后更新

- 2026-10-25：去掉默认阿里云百炼（路由零回落 + 删迁移逻辑），槽位文案角色化（轻量/主力/视觉/向量），新增轻量→主力降级策略与对应测试；本总览首次成文。
