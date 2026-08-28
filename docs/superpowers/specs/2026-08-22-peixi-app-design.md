# 《陪析》实施规格说明书

> 日期：2026-08-22
> 状态：待用户确认
> 需求唯一来源：`docs/设计稿-原文-v1.0.md`（用户已锁定的最终版设计稿 v1.0）
> 本文档职责：记录环境事实、外部 API 核查结论、依赖选型与实现决策，作为实施计划的输入。与设计稿冲突时以设计稿为准，除非本文档明确标注"偏离决策"及理由。

---

## 1. 范围

按设计稿第十节里程碑执行：**M1 视频主链路（先 Windows 后 Android）→ M2 弹幕提问 + 小说模式 → M3 打磨**。本次实施从环境搭建与 M1 开始。

## 2. 环境与工具链（已核实）

| 项 | 事实 |
|---|---|
| Git 仓库 | 整个 `C:\AI WorkSpace` 是单一仓库，陪析作为子目录纳入，不建嵌套仓库 |
| Flutter | 3.47.1 stable（Dart 3.13.1），安装至 `C:\Users\jingyue\AndroidTools\flutter`（下载安装中） |
| JDK | Microsoft OpenJDK 17.0.20.1，位于 `C:\Users\jingyue\AndroidTools\jdk\jdk-17.0.20.1+1` |
| Android SDK | `C:\Users\jingyue\AndroidTools\sdk`：platforms/android-35、build-tools 35.0.0 与 34.0.0、platform-tools、emulator、system-images、cmdline-tools、licenses 均已就绪 |
| Gradle | 本地有 8.11.1（`AndroidTools\gradle`）；项目用 wrapper，distribution URL 采用腾讯镜像（参照镜变项目） |
| Android 构建参照 | 镜变项目在本机验证可用的组合：AGP 8.7.3 + Kotlin 2.0.21 + compileSdk 35 + minSdk 26 + JVM 17；`gradle.properties` 用 `-Xmx3072m -Dfile.encoding=UTF-8` |
| 打包 | Windows：`flutter build windows`；Android：`flutter build apk`（个人自用侧载，release 用 debug 签名即可，参照镜变做法） |
| 网络 | storage.flutter-io.cn 镜像已失效（401），Flutter SDK 从官方源多连接并行下载；pub 镜像 `pub.flutter-io.cn` 连通性在首次 `pub get` 时验证，失败则直连 pub.dev |

## 3. 外部 API 核查结论（设计稿 2.3 核对清单）

### 3.1 DashScope 录音文件识别（paraformer-v2）✅ 已核实

- **提交任务**：`POST https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription`
  - Headers：`Authorization: Bearer {API_KEY}`、`Content-Type: application/json`、**`X-DashScope-Async: enable`（必须，否则报错）**
  - Body：`{"model": "paraformer-v2", "input": {"file_urls": ["<URL编码后的公网URL>"]}, "parameters": {"language_hints": ["zh"], "diarization_enabled": true, "timestamp_alignment_enabled": true}}`
  - 返回 `output.task_id`、`output.task_status`（PENDING/RUNNING/SUCCEEDED/FAILED）
- **查询任务**：`POST https://dashscope.aliyuncs.com/api/v1/tasks/{task_id}`（Bearer 认证，body 为空）
  - SUCCEEDED 后从 `output.results[].transcription_url` **下载结果 JSON（有效期 24 小时）**；需检查 `results[].subtask_status` 是否 SUCCEED
- **结果结构**：`transcripts[].sentences[]`，每句含 `begin_time`/`end_time`（毫秒整数）、`text`、`speaker_id`（**整数，从 0 起**，仅 diarization 开启时有）、`words[]`；`properties.original_duration_in_milliseconds`
- **约束**：说话人分离**仅支持单声道**（设计稿 S3 产出 16kHz 单声道 MP3，满足）；说话人分离建议音频 <2 小时；`file_urls` 中的特殊字符必须 URL 编码；不支持本地文件/base64，必须公网 URL（OSS 中转方案成立）
- 来源：[Paraformer非实时语音识别RESTful API官方文档](https://help.aliyun.com/zh/model-studio/paraformer-recorded-speech-recognition-restful-api)

### 3.2 OpenAI 兼容模式（LLM）✅ 已核实

- `base_url = https://dashscope.aliyuncs.com/compatible-mode/v1` 仍然有效；认证 `Authorization: Bearer {API_KEY}`
- `response_format={"type":"json_object"}` 受 Qwen 大部分模型支持，**但要求 messages 中必须出现 "json" 字样**，否则报错 → 设计稿的通用系统前缀已含"只输出 JSON"，实现时再显式附加小写 "json" 字样兜底
- `GET /compatible-mode/v1/models` 可用，作为设置页〔测试连接〕的实现
- 来源：[OpenAI Chat接口兼容](https://help.aliyun.com/zh/model-studio/compatibility-of-openai-with-dashscope)、[结构化输出](https://help.aliyun.com/zh/model-studio/qwen-structured-output)

### 3.3 百炼免费额度 ✅ 已核实

新用户每模型约 100 万 token、有效期 90 天（自开通起），合计超 7000 万 token；部分模型免费额度限北京地域。个人自用充足。ASR 按时长计费（千炼 paraformer 录音文件识别约 0.288 元/小时量级，以官网为准）。
来源：[新人免费额度规则](https://help.aliyun.com/zh/model-studio/new-free-quota)、[模型调用价格](https://help.aliyun.com/zh/model-studio/model-pricing)

### 3.4 阿里云 OSS（Flutter 客户端直传）✅ 方案已定

- **选型**：pub 包 `dart_aliyun_oss`（v1.3.0，纯 Dart，支持上传/分片/签名 URL）为主选；备选 `alibabacloud_oss_sdk_dart` 或以 `crypto` 包自行实现签名
- **风险点（运行时验证）**：阿里云 2025-05 之后新建 Bucket 逐步禁用 V1 签名（HMAC-SHA1），若用户 bucket 为新建且 SDK 仅支持 V1 会失败 → 验证失败则切换自实现 V4 签名（HMAC-SHA256 链）
- 流程照设计稿 2.3：PutObject（私有）→ 限时签名 GET URL 交 ASR → 用完 DeleteObject
- 来源：[pub.dev/packages/dart_aliyun_oss](https://pub.dev/packages/dart_aliyun_oss)、[客户端直传OSS官方文档](https://help.aliyun.com/zh/oss/user-guide/uploading-objects-to-oss-directly-from-clients/)

### 3.5 Flutter 依赖选型 ✅ 已核实（pub.dev，2026-08-22）

| 包 | 版本 | 用途 | 备注 |
|---|---|---|---|
| flutter_riverpod | latest | 状态管理 | 设计稿指定 |
| media_kit / media_kit_video | 1.2.6 | 视频播放 | Win7+/Android5+ 全支持；`MediaKit.ensureInitialized()` |
| ffmpeg_kit_flutter_new | 4.6.2 | 抽音频/转码 | 社区维护 fork（原仓库已归档），FFmpeg 8.1.2，Android+Windows；优先 `_audio` 变体（更小），运行时验证 mkv 解封装+mp3 编码，不行退回 full 变体；GPL 对个人自用无碍 |
| drift + sqlite3_flutter_libs | latest | 数据库 | 设计稿指定 |
| dio | latest | 网络/重试/进度 | 设计稿指定 |
| just_audio + just_audio_windows | 0.2.3 | 校准页试听 | Windows 需补 `just_audio_windows`（2026-04 仍在维护） |
| flutter_secure_storage | latest | 密钥存储 | 设计稿指定 |
| file_picker | latest | 文件选择 | Win+Android 双端支持 |
| wakelock_plus | latest | 处理期间保持唤醒 | Android 需求（设计稿 9.4） |
| epubx | latest | EPUB（M3） | 后期再验 |

来源：[ffmpeg_kit_flutter_new](https://pub.dev/packages/ffmpeg_kit_flutter_new)、[media_kit](https://pub.dev/packages/media_kit)、[just_audio_windows](https://pub.dev/packages/just_audio_windows)

### 3.6 本地 ASR（用户 2026-08-23 新增需求）✅ 方案已核实

用户要求：**云端 API 与本地模型两种 ASR 模式可切换**（双端一致）。

- 选型：pub 包 **`sherpa_onnx` 1.13.6**（Apache-2.0，官方维护，4 天前仍发版）。联邦插件按平台分发：Windows 走 `sherpa_onnx_windows`，Android 走 `sherpa_onnx_android_arm64` 等四 ABI 包——与本项目双端完全匹配
- 中文识别模型：`sherpa-onnx-paraformer-zh-2024-03-09`（官方推荐的离线中文模型，中英混说+方言支持；int8 量化版体积约百 MB 量级，与用户预期一致）
- 说话人分离：sherpa-onnx 支持 offline speaker diarization（pyannote 分段模型 + 3D-Speaker 声纹模型组合），Dart API 具体类名与模型清单在阶段二 spike 中跑通确认
- 模型分发：**运行时下载到应用目录**（不打包进安装包，控制 APK/EXE 体积）；首次切到本地模式时引导下载
- 模式语义：设置页新增"语音识别模式：云端（DashScope paraformer-v2）| 本地（离线 paraformer）"；**默认云端**（识别质量与说话人分离更稳），无网络/无 Key 时可切本地
- 来源：[sherpa_onnx | Flutter package](https://pub.dev/packages/sherpa_onnx)、[sherpa-onnx Releases](https://github.com/k2-fsa/sherpa-onnx/releases)

### 3.7 应用图标（用户 2026-08-23 提供）

用户提供的 2048×2048 PNG（AI 生成，右下角带"豆包AI生成"水印）：已中央 75% 裁剪（去水印、构图居中合格，已视觉复核），母版与产物存于 `陪析/design/icon/`（`icon_master_1536.png`、`app_icon.ico` 多尺寸、`mipmap-mdpi..xxxhdpi/ic_launcher.png`）。工程创建后覆盖模板图标：Windows 替换 `windows/runner/resources/app_icon.ico`，Android 替换 `android/app/src/main/res/mipmap-*/ic_launcher.png`。

## 4. 偏离决策记录（与设计稿的差异及理由）

| # | 偏离 | 理由 |
|---|---|---|
| 1 | ASR 结果 `speaker_id` 为整数，规范化时映射为 `"SPEAKER_XX"` 字符串键 | 官方返回即整数；设计稿中间产物格式的字符串键更有可读性，映射在规范化层完成 |
| 2 | ASR 走独立的 `AsrService`（DashScope 原生异步任务 API），不经过 `LlmService` | 设计稿第六节"唯一出口"约束的是 chat 类调用（OpenAI 兼容）；ASR 是异构协议（异步任务+轮询+transcription_url 二次下载），强行统一反而复杂 |
| 3 | 通用系统前缀追加小写 "json" 字样 | 百炼 json_object 模式的硬性要求（messages 必须含 "json"） |
| 4 | OSS 用 `dart_aliyun_oss` 而非自研签名 | 减少签名版本兼容风险（V1/V4），签名逻辑交由 SDK；失败再自实现 |
| 5 | Android 构建配置采用镜变验证过的组合（AGP 8.7.3/Kotlin 2.0.21/compileSdk 35），gradle wrapper 用腾讯镜像 | 本机网络与 SDK 已验证该组合可用，降低构建期风险 |
| 6 | release APK 使用 debug 签名 | 个人自用侧载，与镜变做法一致，免去 keystore 管理 |
| 7 | ASR 双模式：云端（DashScope）+ 本地（sherpa-onnx paraformer int8）可切换，默认云端（2026-08-23 用户需求，原设计稿中本地仅为 Plan B） | 用户明确要求；本地模式零成本、无网可用，云端模式质量更稳，二者共存互补 |
| 8 | 应用图标采用用户提供的 AI 生成图，中央 75% 裁剪（去"豆包AI生成"水印）后生成双端全套图标 | 用户 2026-08-23 提供并要求先裁剪；裁剪结果已视觉复核合格 |

## 5. 运行时验证清单（实施计划的第一批任务，即"技术验证 spike"）

1. `flutter doctor` 全绿（Android toolchain / Visual Studio for Windows desktop）
2. `dart_aliyun_oss` 对用户 bucket 的 PutObject + 签名 GET + Delete 走通（验证 V1/V4）
3. `ffmpeg_kit_flutter_new_audio` 变体对真实 mkv 执行 `-i in.mkv -ac 1 -ar 16000 -b:a 48k out.mp3` 成功
4. qwen-plus `json_object` 实测返回合法 JSON
5. 用一小段真实音频走通 ASR 提交→轮询→transcription_url 解析全链路

> 上述任何一项失败都可能在实施中调整 3.4/3.5 的选型，属预期内。

## 6. 验收标准

照设计稿第十节 M1/M2/M3 原文执行，不再重复。

## 5. M1 完整实现新增偏离（2026-08-23，详见 交付说明-M1完整版.md）

10. OSS 客户端自实现 V1 签名（替代 dart_aliyun_oss），单次 PUT 替代分片。
11. 校准试听复用 media_kit AudioPlayer（不引入 just_audio）。
12. 抽音频编码器运行时探测（libmp3lame→aac→pcm），规避 ffmpeg-kit 变体差异。
13. Android 导入复制视频进应用目录（SAF 路径不可长期依赖）。
14. S2 字幕仅提取解析入库（交叉校对/角色名提升延至调优期）。
15. L4 最小间隔按播放位置差而非墙钟。
16. 构建期 GitHub 依赖（ffmpeg-kit zip / libmpv win+android / ANGLE）全部以
    镜像预取脚本固化：tool/fetch-windows-native-deps.sh、tool/fetch-android-native-deps.sh。
