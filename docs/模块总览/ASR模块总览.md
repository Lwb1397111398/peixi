# ASR 模块总览

## 模块职责

视频管线的语音识别：只提供**本地 sherpa-onnx 离线转写**一种模式（云端 DashScope 录音文件识别及其 OSS 中转已于 2026-10-25 移除——成本高、无实用价值）。

## 运作流程

1. **模型从哪来**：sherpa-onnx 的 paraformer-zh-2024-03-09 int8 模型（约 200–300 MB）。设置页「语音识别（本地离线）」区块内点「下载模型」→ `AsrModelController.download()` → `AsrModelDownloader` 按 `files` 清单逐文件下载，国内优先走 hf-mirror 镜像、失败回落官方源，写 `.part` 临时文件、全部完成并校验大小后落位。
2. **模型放哪里**：`LocalAsrClient.defaultLocalModelDir()` 按序找：①`<应用支持目录>/models/asr` ②Windows 便携的 exe 同级 `models/asr`。桌面端也可手动运行 `tool/download-sherpa-model.sh`。
3. **识别怎么跑**：管线 S5 阶段（`pipeline_engine.dart` 的 `_runAsrTask`）把音频准备成 16k 单声道 wav（抽取阶段就固定产 wav；云端时代残留的 mp3/m4a 缓存会补转一份 wav）→ `PipelineController` 注入的 `localAsr` 回调缺模型时应用内自动补下载 → `LocalAsrClient.recognizeInBackground()` 在后台 isolate 里加载模型、按 30s 窗切块（窗边界吸附低能量点减少截词）、逐窗解码。
4. **结果怎么规范化**：token+时间戳经 `buildSentencesFromTokens()`（`local_asr_client.dart`）切句——标点结尾 > 静音间隙 0.6s > 30 token 上限；所有句子说话人归一为 `SPEAKER_00`（本地模型无说话人分离）。产物 `NormalizedAsr`（`asr_types.dart`）与字幕纠错、场景切分共用。
5. **结果去哪**：`_persistAsrResult` 写 meta_json 的 `asrNormalized` + segments 表逐行落库；有内嵌字幕时先经 `subtitle_aligner.dart` 交叉纠错（文本换字幕、时间轴/说话人保持 ASR 原值）。
6. **闭环**：识别失败 → 项目落 FAILED+failed_stage='asr'，重试从 audioReady 入口重跑；识别中取消 → 协作式退出、状态保留可续。

## 入口文件清单

- `lib/core/asr/asr_types.dart` —— 共享数据类型（NormalizedAsr/AsrSentence/AsrException）
- `lib/core/asr/local_asr_client.dart` —— 本地识别 + 切句纯逻辑
- `lib/core/asr/asr_model_downloader.dart` —— 模型下载（镜像兜底/断点校验）
- `lib/core/asr/asr_model_controller.dart` —— 模型状态 riverpod 状态机（ready/missing/downloading/failed）
- `lib/features/settings/settings_page.dart` —— 「语音识别（本地离线）」区块（模型状态行 + 下载入口）
- `lib/features/pipeline/pipeline_engine.dart` —— S5 调用方（wav 准备与结果落库）

## 对外接口 / 被谁调用

- `PipelineController.engine()` 构造引擎时注入 `localAsr` 回调（含自动补下载）。
- `asrModelStateProvider` 被设置页消费。
- 处理页时间线（`processing_page.dart`）展示 asr 阶段进度（已无上传阶段）。

## 依赖的上游模块

- 媒体（ffmpeg 抽 16k wav）、数据库（segments/meta_json）、处理管线（S5 阶段宿主）。

## 关键数据结构

- `NormalizedAsr { durationMs, sentences: List<AsrSentence> }`
- `AsrSentence { beginMs, endMs, text, speakerId }`（speakerId 恒 `SPEAKER_00`）
- meta_json 键：`audioFormat`（固定 wav）、`asrNormalized`

## 已知坑与约束

- **无说话人分离**：角色映射会把全部对白归成一个说话人（设置页有警示文案）。
- **无 VAD**：30s 窗切分边界可能截词，已做低能量点吸附缓解。
- **int8 量化**：精度略低于云端 paraformer-v2（原云端方案已删，不再可比）。
- FFI 绑定按 isolate 各自初始化；模型目录须主 isolate 解析后传入后台 isolate。
- 旧库残留状态 `UPLOADED`（云端上传阶段产物）仍会被引擎接受为 asr 入口并补转 wav 识别，保证老项目可继续。

## 最后更新

- 2026-10-25：删除云端 DashScope 转写与 OSS 中转全套（AsrClient/oss_client/OssConfig/AsrMode），语音识别收敛为本地单模式；共享类型抽到 asr_types.dart；本总览首次成文。
