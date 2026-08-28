# M2 实施计划：小说模式 N1-N4 + 阅读器 + sherpa-onnx 本地 ASR 双模式

> **For agentic workers:** REQUIRED SUB-SKILL: subagent-driven-development (recommended) / executing-plans. Steps use `- [ ]`.
> 前置：M1 已交付（65 测试全绿）。本计划在既有 drift 13 表 + 管线架构 上增量实现。

**Goal:** 完成小说模式 N1 导入→N2 人物提取→N3 顺序批注→N4 完成 + 阅读器（批注气泡/L4 段间卡片/章节抽屉/人物列表），并加入 sherpa-onnx 本地 ASR（cloud/local 可切换双模式）。

**说明**：Sherpa 本地 ASR 与小说管线无耦合，分两条并行线推进，各自独立可测。

---

## 小说管线线（N1-N4 + 阅读器）

### Task A1: 编码检测与切章（N1）
**Files:** `lib/core/novel/novel_parser.dart`（新）、`test/core/novel/novel_parser_test.dart`
```
class NovelDoc { List<NovelChapter> chapters; }
class NovelChapter { int idx; String title; List<String> paragraphs; }
NovelDoc parseNovel(String rawText)
```
- 编码：utf8 严格解码失败 → GB18030（`dangerouslyAllowCJK` 不存在；用 `utf8.decode(bytes, allowMalformed:false)` try → 失败则用 `gbk` 包或 `Latin1` 兜底）。测试注入中文 GBK bytes。
- 统一换行 `\n`；按 `^\s*第[〇零一二三四五六七八九十百千0-9]+[章回卷节]` 切；无匹配则按每 ~2000 字符在段落边界切块。
- 测试：标准章标题切分 / 无章标题按块切 / GBK 解码 / 空输入。

### Task A2: 小说导入（N1 入库）
**Files:** `lib/features/pipeline/pipeline_controller.dart`（加 `importNovel()`）、`lib/features/pipeline/novel_pipeline.dart`（新）
- `importNovel()`：file_picker 选 txt → `parseNovel` → 建 projects(type='novel') + chapters + paragraphs（一个事务）。
- `NovelPipelineEngine.run(projectId)`：N2→N3→N4（N2 人物提取复用 `LlmService`，N3 批注复用深度防剧透）。
- 测试：importNovel 建行数与段 idx；N2 假 LLM 输出 → characters/annotations 落库。

### Task A3: Prompt D 小说批注（N3）
**Files:** `lib/core/llm/prompts.dart`（加 `novelAnnotation()`）、`lib/features/pipeline/novel_commentary_generator.dart`（新）
- `novelAnnotation(chunkDigest, currentDigest, blockText, paraRange)`：结构同 B，锚定 `para_range`，加密度指令。
- 批注生成：按章内段落块 ~2000 字顺序调用；上下文 = 前文章节摘要 + 本章已读概要 + 当前块。锚定 para idx，类型 L1/L2/L3/L4，写 annotations 表；每块完成即落库（崩溃续跑）。
- 测试：防剧透（块1 不含块2 内容）；锚定 para_range；类型 L1-L4；续跑覆盖。

### Task A4: 阅读器 UI（游戏 8.4）
**Files:** `lib/features/reader/reader_page.dart`（新）、`lib/features/reader/reader.dart`（新）
- 正文纵向滚动；字号/行距/背景色（含夜间）可调（设置存 settings 表）。
- 批注呈现：段落尾部小气泡角标（颜色分 L1-L4），点击底部弹层；L4 为段间展开卡片，作答写 qa_records（复用 QuizOverlay 逻辑的简化版）。
- 顶部章节抽屉；右上本章人物列表（点击看人设）。
- 测试：气泡角标渲染；点开批注内容；字号调节；段落映射。

### Task A5: 媒体库 + 导航接入
- 库页加"导入小说"按钮（与导入视频并列）；`_open` 对 type='novel' 走阅读器；novel READY 才可进阅读器。
- `settings_repository` 加阅读偏好（fontSize/lineHeight/bg/夜间）。测试：偏好读写。

## 本地 ASR 线（sherpa-onnx）

### Task B1: sherpa_onnx 依赖 + 模型下载
- `pubspec.yaml` 加 `sherpa_onnx: ^1.13.6`；`flutter pub get`。
- `tool/download-sherpa-model.sh`（镜像 hf-mirror）：sherpa-onnx-paraformer-zh-2024-03-09 int8，解压到 `<appSupport>/models/asr/`。不做下载到仓库。
- 平台确认：sherpa_onnx 支持 Windows 与 Android（Android 用 onnxruntime AAR）。构建前需 gradle 配置 ndkVersion 等——见 B2。

### Task B2: 本地 ASR 客户端
**Files:** `lib/core/asr/local_asr_client.dart`（新）、`test/core/asr/local_asr_client_test.dart`
```
class LocalAsrResult { int durationMs; List<AsrSentence> sentences; }
class LocalAsrClient {
  Future<LocalAsrResult> recognize(String audioPath, {String? languageHint='zh'});
}
```
- 用 sherpa_onnx `OfflineRecognizer`（paraformer-zh，vocab.bpe）加载模型目录；`createStream`→`acceptWaveform(sampleRate, samples)`→`decode`→`GetResult`.
- 128ms 窗 / 16kHz 采样；无说话人分离（本地 paraformer 无 diarization），speaker 归一到 `SPEAKER_00`。
- 测试（纯逻辑）：sherpa 结果 → AsrSentence 序列化；空结果容错。

### Task B3: ASR 双模式切换
**Files:** `lib/core/settings/settings_repository.dart`（加 `asr_mode` 键）、`lib/core/settings/api_config.dart`（加 `AsrMode {cloud, local}`）、`pipeline_engine.dart`（`_runAsrTask` 按模式分叉）
- `_runAsrTask`：cloud→走 AsrClient；local→音频文件直接 `LocalAsrClient.recognize`（无需 OSS/任务轮询），产物 `metaJson.asrNormalized` 同结构，删除 OSS 对象逻辑跳过。
- 设置页加"识别模式"下拉（云端/本地）。测试：loadAsrMode / saveAsrMode；engine local 分支可跑。

### Task B4: 双模式 UI 与交付
- 设置页 ASR 模式切换 + 本地模型状态（已下载/未下载 + 下载中进度）。
- 更新 `docs/交付说明-M2.md`（本阶段全部偏离、sherpa 双模式限制：无说话人分离→speaker 全为 SPEAKER_00、本地精度略低、需下载模型）。

---

## 阶段验收
- 小说：导入 GBK 中文 txt → 切章 → 人物提取 → 顺序批注 → 阅读器显示气泡/L4 卡片 → 全部可离线测试。
- ASR：设置页可切换云端/本地；本地 recognize 产出与云端同构规范化结果；构建双端通过。

## 关键决策记录
1. 本地 paraformer 无 diarization → 全归 `SPEAKER_00`，校准页退化（角色名=单一"说话人"）。交付说明注明。
2. sherpa_onnx 模型不入库（~100MB），工具脚本下载到应用目录；首次使用需联网。
3. N3 批注不写 commentary 表（那是视频用的），写 `annotations`。
4. L4 阅读场景用段间卡片而非弹幕打断。
5. N2 人物提取每章一次，维护全局书单（避免跨章指代漂移）。
