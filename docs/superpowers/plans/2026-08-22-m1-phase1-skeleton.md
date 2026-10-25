# 《陪析》M1 阶段一：环境与应用骨架 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭好 Flutter 双端工程（Windows 优先），交付带 drift 数据库、安全设置存储、LlmService（OpenAI 兼容 + JSON 兜底）和设置页的可运行应用骨架，为阶段二（S1-S5 流水线）打地基。

**Architecture:** 单一 Flutter 工程同时产出 Windows EXE 与 Android APK。lib/ 按 `core/`（database/settings/llm）与 `features/`（library/settings）分层，全局依赖经 Riverpod Provider 注入。数据库一次性建齐设计稿全部 12 张表（避免后期迁移），小说相关表本阶段只建不用。

**Tech Stack:** Flutter 3.47.1 / Dart 3.13.1，flutter_riverpod 3.4.2，drift 2.34.3（不再需要已废弃的 sqlite3_flutter_libs），dio 5.11.0，flutter_secure_storage 11.0.0。

**计划序列（本文件是第 1 份）：**
1. **本计划**：环境 + 骨架 + 数据层 + LlmService + 设置页
2. 阶段二：S1-S5（导入探测→字幕尝试→抽音频→OSS 上传→ASR），含技术验证 spike
3. 阶段三：S6-S10 + 校准页（角色映射→校准闸门→场景切分→解说生成）
4. 阶段四：视频播放器页 + 解说卡联动 + M1 Windows 验收
5. 阶段五：Android 适配 + 双端验收

后续计划在前一阶段完成后编写（依赖实际运行中学到的 API 行为），不要现在预写。

---

## 前置状态（执行本计划前必须成立的事实）

| 项 | 状态 | 位置/值 |
|---|---|---|
| Android SDK | ✅ 就绪 | `C:\Users\<user>\AndroidTools\sdk`（platform-35、build-tools 35、licenses 已接受） |
| JDK 17 | ✅ 就绪 | `C:\Users\<user>\AndroidTools\jdk\jdk-17.0.20.1+1` |
| Gradle 8.11.1 本地包 | ✅ 可参照 | `C:\Users\<user>\AndroidTools\gradle\gradle-8.11.1` |
| Flutter SDK zip | ⏳ 由主会话后台下载中 | `C:\Users\<user>\AndroidTools\dl\flutter_3.47.1-stable.zip`（1,929,093,631 字节） |
| Git 仓库 | ✅ 仓库根为 `C:\AI WorkSpace`，本项目在 `陪析/` 子目录 | 不建嵌套仓库 |
| 镜变参照项目 | ✅ 本机验证过 Android 构建 | AGP 8.7.3 + Kotlin 2.0.21 + compileSdk 35 + JVM 17 |

**每个 shell 会话开始前导出（后续所有命令默认含此环境）：**

```bash
export JAVA_HOME="C:/Users/<user>/AndroidTools/jdk/jdk-17.0.20.1+1"
export ANDROID_HOME="C:/Users/<user>/AndroidTools/sdk"
export PATH="/c/Users/<user>/AndroidTools/flutter/bin:$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
```

---

## 文件结构（本计划结束时）

```
陪析/
├── pubspec.yaml
├── analysis_options.yaml
├── android/                          # Flutter 模板生成后仅改镜像与必要配置
├── windows/                          # Flutter 模板生成，不动
├── docs/                             # 已有设计稿与 spec
├── lib/
│   ├── main.dart                     # 入口：初始化 DB、MediaKit 占位、ProviderScope
│   ├── app.dart                      # MaterialApp + 暗色主题 + 两页导航壳
│   ├── providers.dart                # 全局 Provider：db / settingsRepo / llmService
│   ├── core/
│   │   ├── database/
│   │   │   ├── app_database.dart     # 全部表定义 + AppDatabase
│   │   │   └── app_database.g.dart   # build_runner 生成
│   │   ├── settings/
│   │   │   ├── api_config.dart       # ApiConfig 模型 + LlmTier
│   │   │   └── settings_repository.dart  # secure storage(密钥) + settings表(偏好)
│   │   └── llm/
│   │       └── llm_service.dart      # chat/chatJson/testConnection + 兜底链 + llm_logs
│   └── features/
│       ├── library/library_page.dart # M1-P1 空态媒体库
│       └── settings/settings_page.dart
└── test/
    ├── core/database/app_database_test.dart
    └── core/llm/llm_service_test.dart
```

---

### Task 0: 安装 Flutter SDK 并通过 doctor

**Files:** 无代码文件（纯环境）

- [ ] **Step 0.1: 确认 zip 完整性**

Run: `ls -la "C:/Users/<user>/AndroidTools/dl/flutter_3.47.1-stable.zip"`
Expected: 大小恰为 `1929093631`。若文件不存在或更小，说明主会话下载未完成——等待而非重下。

- [ ] **Step 0.2: 解压到 AndroidTools/flutter**

```bash
cd "C:/Users/<user>/AndroidTools" && tar -xf dl/flutter_3.47.1-stable.zip
```
Expected: 出现 `C:/Users/<user>/AndroidTools/flutter/bin/flutter`（约需 2-5 分钟）。

- [ ] **Step 0.3: 关闭分析上报并验证版本**

```bash
"C:/Users/<user>/AndroidTools/flutter/bin/flutter" config --no-analytics
flutter --version
```
Expected: 输出 `Flutter 3.47.1 • channel stable`。

- [ ] **Step 0.4: flutter doctor 体检**

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
flutter doctor
```
Expected（关键三项）：
- `[✓] Android toolchain`（若报 licenses，运行 `flutter doctor --android-licenses` 全 y）
- `[✓] Windows desktop develop`（Visual Studio 含 C++ 工作负载）
- Chrome/Android Studio 条目可忽略

**分支处理：**
- 若 pub 镜像 `pub.flutter-io.cn` 连接失败（`flutter doctor -v` 或后续 `pub get` 报超时）：`unset PUB_HOSTED_URL` 直连 pub.dev（本机 Google 源可达，已验证）。
- 若 Windows desktop 条目为 `[✗]`（无 Visual Studio）：需安装 VS Build Tools——`winget install Microsoft.VisualStudio.2022.BuildTools --override "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive"`（约 2-4GB，耗时 20-60 分钟；winget 不可用则从 https://visualstudio.microsoft.com/downloads/ 手动下载）。安装完重跑 doctor。**这是本计划最大不确定项，越早发现越好。**

- [ ] **Step 0.5: Commit（记录环境快照到项目 docs）**

```bash
cd "C:/AI WorkSpace/陪析" && flutter doctor -v > docs/flutter-doctor-snapshot.txt 2>&1
cd "C:/AI WorkSpace" && git add "陪析/docs/flutter-doctor-snapshot.txt" && git commit -m "chore(peixi): Flutter 3.47.1 环境就绪快照"
```

---

### Task 1: 创建工程、锁依赖、配 Android 镜像、Windows 冒烟

**Files:**
- Create: `陪析/pubspec.yaml`（flutter create 后整体替换）
- Modify: `陪析/android/gradle/wrapper/gradle-wrapper.properties`
- Modify: `陪析/android/gradle.properties`

- [ ] **Step 1.1: flutter create**

```bash
cd "C:/AI WorkSpace/陪析"
flutter create --project-name peixi --org com.<user> --platforms windows,android .
```
Expected: `All done!`，生成 `android/`、`windows/`、`lib/main.dart`、`test/widget_test.dart` 等。

- [ ] **Step 1.2: 整体替换 pubspec.yaml**

```yaml
name: peixi
description: 陪析——观影读小说时的 AI 陪练教练（个人自用）
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ^3.13.0

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.4.2
  drift: ^2.34.3
  dio: ^5.11.0
  flutter_secure_storage: ^11.0.0
  path_provider: ^2.1.6
  path: ^1.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  drift_dev: ^2.34.5
  build_runner: ^2.16.0

flutter:
  uses-material-design: true
```

说明：media_kit / ffmpeg / OSS / just_audio / file_picker / wakelock 等按阶段在各自计划中加入（YAGNI）。**不添加 sqlite3_flutter_libs**（已 EOL，drift 2.34 + sqlite3 3.x 内置处理）。

- [ ] **Step 1.3: gradle wrapper 换腾讯镜像**

编辑 `android/gradle/wrapper/gradle-wrapper.properties`，将 `distributionUrl` 行替换为模板要求版本对应的腾讯镜像（保持模板的 Gradle 版本号不变，只换域名）：

```properties
distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-X.Y-bin.zip
```
（X.Y = 模板原值，镜像路径模式与镜变项目一致：`mirrors.cloud.tencent.com/gradle/gradle-X.Y-bin.zip`）

- [ ] **Step 1.4: gradle.properties 增加 JVM 内存与编码**

在 `android/gradle.properties` 追加（已有键则改值）：

```properties
org.gradle.jvmargs=-Xmx3072m -Dfile.encoding=UTF-8
android.useAndroidX=true
```

- [ ] **Step 1.5: 依赖解析**

```bash
flutter pub get
```
Expected: `Got dependencies!`。若 pub.flutter-io.cn 超时则 unset 后直连重试。

- [ ] **Step 1.6: Windows 冒烟运行**

```bash
flutter run -d windows
```
Expected: 弹出模板计数器窗口。确认后 `q` 退出。若编译报 Visual Studio 组件缺失，回到 Task 0.4 分支处理。

- [ ] **Step 1.7: .gitignore 校验与 Commit**

确认模板 `.gitignore` 已含 `*.g.dart` 排除则**删除该行**（drift 生成文件建议入库，保证任何人 clone 后无需 build_runner 即可编译；若团队习惯不入库则保留排除并在下文每次 commit 前先跑 build_runner）。

```bash
cd "C:/AI WorkSpace" && git add 陪析/ && git commit -m "feat(peixi): Flutter 工程初始化（Win+Android 双端模板与依赖锁定）"
```

---

### Task 2: drift 数据库——全部 12 张表（TDD）

**Files:**
- Create: `lib/core/database/app_database.dart`
- Create: `lib/core/database/app_database.g.dart`（build_runner 生成）
- Test: `test/core/database/app_database_test.dart`

设计稿第三节 SQL → drift 表。状态枚举直接存 TEXT。

- [ ] **Step 2.1: 写失败测试**

```dart
// test/core/database/app_database_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  test('projects 全生命周期字段与状态写入读出', () async {
    final id = await db.into(db.projects).insert(ProjectsCompanion.insert(
          type: 'video',
          title: '潜伏 S01E03',
          sourcePath: 'D:/tv/qianfeng.mkv',
          status: 'IMPORTED',
        ));
    final row = await db.select(db.projects).getSingle();
    expect(row.id, id);
    expect(row.status, 'IMPORTED');
    expect(row.createdAt, isNotNull);
    expect(row.updatedAt, isNotNull);
    await (db.update(db.projects)..where((t) => t.id.equals(id)))
        .write(const ProjectsCompanion(status: Value('FAILED'), failedStage: Value('S5_ASR')));
    expect((await db.select(db.projects).getSingle()).failedStage, 'S5_ASR');
  });

  test('scenes/commentaries/questions 级联删除与唯一约束', () async {
    final pid = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'video', title: 't', sourcePath: 'p', status: 'READY'));
    final sid = await db.into(db.scenes).insert(ScenesCompanion.insert(
        projectId: pid, idx: 0, startMs: 0, endMs: 1000));
    final cid = await db.into(db.commentaries).insert(CommentariesCompanion.insert(
        sceneId: sid, l1Subtext: '潜台词'));
    final qid = await db.into(db.questions).insert(QuestionsCompanion.insert(
        projectId: pid, sceneId: sid, question: 'q', perspectivesJson: '[]'));
    await db.into(db.qaRecords).insert(QaRecordsCompanion.insert(
        questionId: qid, userAnswer: 'a'));

    // commentaries.sceneId 唯一：重复插入应冲突
    expect(
      () => db.into(db.commentaries).insert(
          CommentariesCompanion.insert(sceneId: sid, l1Subtext: 'x')),
      throwsA(isA<Exception>()),
    );

    // 删除 project 级联清掉全部子表
    await (db.delete(db.projects)..where((t) => t.id.equals(pid))).go();
    expect(await db.select(db.scenes).get(), isEmpty);
    expect(await db.select(db.commentaries).get(), isEmpty);
    expect(await db.select(db.questions).get(), isEmpty);
    expect(await db.select(db.qaRecords).get(), isEmpty);
    expect(cid, greaterThan(0));
  });

  test('novel 三表（chapters/paragraphs/annotations）建表可用', () async {
    final pid = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'novel', title: 'n', sourcePath: 'p', status: 'READY'));
    final chid = await db.into(db.chapters)
        .insert(ChaptersCompanion.insert(projectId: pid, idx: 0, startPara: 0, endPara: 10));
    final paid = await db.into(db.paragraphs).insert(
        ParagraphsCompanion.insert(projectId: pid, chapterId: chid, idx: 0, text: '正文'));
    await db.into(db.annotations).insert(
        AnnotationsCompanion.insert(paraId: paid, type: 'L1', contentJson: '{}'));
    expect(await db.select(db.chapters).get(), hasLength(1));
  });

  test('settings 键值与 llm_logs 计数', () async {
    await db.into(db.settings).insert(SettingsCompanion.insert(key: 'k', value: 'v'));
    await db.customStatement(
        "INSERT INTO llm_logs(project_id,purpose,model,prompt_tokens,completion_tokens,created_at) VALUES(1,'解说','qwen-plus',100,200,0)");
    final sum = await db.customSelect(
        'SELECT SUM(prompt_tokens+completion_tokens) AS t FROM llm_logs').getSingle();
    expect(sum.read<int>('t'), 300);
  });
}
```

- [ ] **Step 2.2: 运行确认失败**

Run: `flutter test test/core/database/app_database_test.dart`
Expected: FAIL，报 `package:peixi/core/database/app_database.dart` 不存在。

- [ ] **Step 2.3: 实现表定义**

```dart
// lib/core/database/app_database.dart
import 'package:drift/drift.dart';
import 'package:peixi/main.dart' show appDatabasePath; // 若循环依赖则改为构造注入

/// 设计稿第三节全部 12 张表。状态一律 TEXT 存枚举字面量。
/// *_json 字段按原文存 TEXT（JSON 字符串），由业务层编解码。

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // 'video' | 'novel'
  TextColumn get title => text()();
  TextColumn get sourcePath => text()();
  // IMPORTED/AUDIO_READY/UPLOADED/ASR_DONE/MAPPED/WAIT_CALIBRATION/
  // SEGMENTED/COMMENTARY_DONE/READY/FAILED（校准后置 CALIBRATED）
  TextColumn get status => text()();
  TextColumn get failedStage => text().nullable()();
  TextColumn get metaJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Characters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get aliasesJson => text().withDefault(const Constant('[]'))();
  TextColumn get speakerKey => text().nullable()(); // SPEAKER_00 等
  RealColumn get confidence => real().nullable()();
  TextColumn get source => text().withDefault(const Constant('auto'))(); // auto|manual
  TextColumn get color => text().nullable()();
}

class Segments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get idx => integer()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  IntColumn get speakerCharId => integer().nullable()();
  TextColumn get text => text()();
}

class Scenes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get idx => integer()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  TextColumn get summary => text().nullable()();
  TextColumn get importance => text().withDefault(const Constant('normal'))();
}

class Commentaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sceneId => integer().references(Scenes, #id, onDelete: KeyAction.cascade)();
  TextColumn get l1Subtext => text()();
  TextColumn get l2PsychologyJson => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('done'))();
  TextColumn get model => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  List<Set<Column>> get uniqueKeys => [
        {sceneId}
      ];
}

class KnowledgeCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get term => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  IntColumn get firstSceneIdx => integer().nullable()();
  BoolColumn get uncertain => bool().withDefault(const Constant(false))();
  @override
  List<Set<Column>> get uniqueKeys => [
        {projectId, term}
      ];
}

class Questions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get sceneId => integer().nullable()();
  TextColumn get question => text()();
  TextColumn get perspectivesJson => text().withDefault(const Constant('[]'))();
}

class QaRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questionId => integer().references(Questions, #id, onDelete: KeyAction.cascade)();
  TextColumn get userAnswer => text()();
  DateTimeColumn get answeredAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get skipped => bool().withDefault(const Constant(false))();
}

class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get idx => integer()();
  TextColumn get title => text().nullable()();
  IntColumn get startPara => integer()();
  IntColumn get endPara => integer()();
  TextColumn get summary => text().nullable()();
}

class Paragraphs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterId => integer().nullable()();
  IntColumn get idx => integer()();
  TextColumn get text => text()();
}

class Annotations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get paraId => integer().references(Paragraphs, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()(); // L1|L2|L3|L4
  TextColumn get contentJson => text()();
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class LlmLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().nullable()();
  TextColumn get purpose => text()();
  TextColumn get model => text()();
  IntColumn get promptTokens => integer().withDefault(const Constant(0))();
  IntColumn get completionTokens => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [
  Projects, Characters, Segments, Scenes, Commentaries, KnowledgeCards,
  Questions, QaRecords, Chapters, Paragraphs, Annotations, Settings, LlmLogs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;
}
```

注意：删除文件顶部 `import 'package:peixi/main.dart'...` 那行——数据库不依赖 main，路径由使用方传入（测试传 `NativeDatabase.memory()`）。

- [ ] **Step 2.4: 生成代码并跑测试**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/database/app_database_test.dart
```
Expected: `All tests passed!`（4 个用例）。生成 `app_database.g.dart`。

- [ ] **Step 2.5: Commit**

```bash
cd "C:/AI WorkSpace" && git add 陪析/lib 陪析/test && git commit -m "feat(peixi): drift 数据库 12 表全量 schema（设计稿第三节）+ DAO 测试"
```

---

### Task 3: ApiConfig 模型 + SettingsRepository（密钥分离存储）

**Files:**
- Create: `lib/core/settings/api_config.dart`
- Create: `lib/core/settings/settings_repository.dart`
- Test: `test/core/settings/settings_repository_test.dart`

设计稿 8.6/九.3：API Key、OSS AK/SK 只进 flutter_secure_storage；偏好类进 settings 表。

- [ ] **Step 3.1: 写失败测试**

```dart
// test/core/settings/settings_repository_test.dart
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
        bucket: 'b', endpoint: 'oss-cn-beijing.aliyuncs.com', accessKeyId: 'ak', accessKeySecret: 'sk'));
    final oss = await repo.loadOssConfig();
    expect(oss?.bucket, 'b');
    final prefs = await repo.loadPlayPrefs();
    expect(prefs.quizEnabled, isTrue); // 设计稿 8.2 默认开启
    expect(prefs.maxPerEpisode, 5);
    expect(prefs.minGapMinutes, 4);
    expect(prefs.triggerRatio, 0.3);
  });
}
```

- [ ] **Step 3.2: 运行确认失败**

Run: `flutter test test/core/settings/settings_repository_test.dart`
Expected: FAIL，包不存在。

- [ ] **Step 3.3: 实现 ApiConfig**

```dart
// lib/core/settings/api_config.dart

/// LLM 分层（设计稿第六节）：cheap→摘要/映射/人物提取；standard→解说/批注/知识卡
enum LlmTier { cheap, standard }

class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.apiKey,
    this.modelCheap = 'qwen-flash',
    this.modelStandard = 'qwen-plus',
  });

  static const bailianBaseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1';

  final String baseUrl;
  final String apiKey;
  final String modelCheap;
  final String modelStandard;

  String modelOf(LlmTier tier) =>
      tier == LlmTier.cheap ? modelCheap : modelStandard;
  bool get isComplete => baseUrl.isNotEmpty && apiKey.isNotEmpty;
}

class OssConfig {
  const OssConfig({
    required this.bucket,
    required this.endpoint,
    required this.accessKeyId,
    required this.accessKeySecret,
  });
  final String bucket;
  final String endpoint; // 形如 oss-cn-beijing.aliyuncs.com
  final String accessKeyId;
  final String accessKeySecret;
  bool get isComplete =>
      bucket.isNotEmpty && endpoint.isNotEmpty && accessKeyId.isNotEmpty && accessKeySecret.isNotEmpty;
}

/// 弹幕提问偏好（设计稿 8.2/8.6 默认值）
class PlayPrefs {
  const PlayPrefs({
    this.quizEnabled = true,
    this.maxPerEpisode = 5,
    this.minGapMinutes = 4,
    this.triggerRatio = 0.3,
    this.keepTempAudio = true,
  });
  final bool quizEnabled;
  final int maxPerEpisode;
  final int minGapMinutes;
  final double triggerRatio;
  final bool keepTempAudio;
}
```

- [ ] **Step 3.4: 实现 SettingsRepository**

```dart
// lib/core/settings/settings_repository.dart
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/api_config.dart';

/// 明文偏好（settings 表）与机密（secure storage）的统一读写入口。
class SettingsRepository {
  SettingsRepository(this._db, this._secure);
  final AppDatabase _db;
  final FlutterSecureStorage _secure;

  // settings 表键
  static const _kBaseUrl = 'llm.base_url';
  static const _kModelCheap = 'llm.model_cheap';
  static const _kModelStandard = 'llm.model_standard';
  static const _kOssBucket = 'oss.bucket';
  static const _kOssEndpoint = 'oss.endpoint';
  // secure storage 键
  static const _sApiKey = 'llm.api_key';
  static const _sOssAk = 'oss.access_key_id';
  static const _sOssSk = 'oss.access_key_secret';
  // 播放偏好键
  static const _kQuizEnabled = 'play.quiz_enabled';
  static const _kMaxPerEpisode = 'play.max_per_episode';
  static const _kMinGap = 'play.min_gap_minutes';
  static const _kTriggerRatio = 'play.trigger_ratio';
  static const _kKeepTempAudio = 'play.keep_temp_audio';

  Future<String?> _get(String key) async =>
      await (_db.select(_db.settings)..where((t) => t.key.equals(key)))
          .getSingleOrNull()
          ?.value;

  Future<void> _set(String key, String value) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: value));
  }

  Future<ApiConfig> loadApiConfig() async => ApiConfig(
        baseUrl: await _get(_kBaseUrl) ?? ApiConfig.bailianBaseUrl,
        apiKey: await _secure.read(key: _sApiKey) ?? '',
        modelCheap: await _get(_kModelCheap) ?? 'qwen-flash',
        modelStandard: await _get(_kModelStandard) ?? 'qwen-plus',
      );

  Future<void> saveApiConfig(ApiConfig c) async {
    await _set(_kBaseUrl, c.baseUrl);
    await _set(_kModelCheap, c.modelCheap);
    await _set(_kModelStandard, c.modelStandard);
    await _secure.write(key: _sApiKey, value: c.apiKey);
  }

  Future<OssConfig?> loadOssConfig() async {
    final bucket = await _get(_kOssBucket);
    final endpoint = await _get(_kOssEndpoint);
    final ak = await _secure.read(key: _sOssAk);
    final sk = await _secure.read(key: _sOssSk);
    if (bucket == null || endpoint == null || ak == null || sk == null) return null;
    return OssConfig(bucket: bucket, endpoint: endpoint, accessKeyId: ak, accessKeySecret: sk);
  }

  Future<void> saveOssConfig(OssConfig c) async {
    await _set(_kOssBucket, c.bucket);
    await _set(_kOssEndpoint, c.endpoint);
    await _secure.write(key: _sOssAk, value: c.accessKeyId);
    await _secure.write(key: _sOssSk, value: c.accessKeySecret);
  }

  Future<PlayPrefs> loadPlayPrefs() async => PlayPrefs(
        quizEnabled: (await _get(_kQuizEnabled) ?? '1') == '1',
        maxPerEpisode: int.tryParse(await _get(_kMaxPerEpisode) ?? '') ?? 5,
        minGapMinutes: int.tryParse(await _get(_kMinGap) ?? '') ?? 4,
        triggerRatio: double.tryParse(await _get(_kTriggerRatio) ?? '') ?? 0.3,
        keepTempAudio: (await _get(_kKeepTempAudio) ?? '1') == '1',
      );

  Future<void> savePlayPrefs(PlayPrefs p) async {
    await _set(_kQuizEnabled, p.quizEnabled ? '1' : '0');
    await _set(_kMaxPerEpisode, p.maxPerEpisode.toString());
    await _set(_kMinGap, p.minGapMinutes.toString());
    await _set(_kTriggerRatio, p.triggerRatio.toString());
    await _set(_kKeepTempAudio, p.keepTempAudio ? '1' : '0');
  }
}
```

- [ ] **Step 3.5: 运行测试通过并 Commit**

Run: `flutter test test/core/settings/settings_repository_test.dart`
Expected: 3 个用例 PASS。

```bash
cd "C:/AI WorkSpace" && git add 陪析/lib 陪析/test && git commit -m "feat(peixi): 设置仓库（secure storage 密钥分离 + settings 表偏好）"
```

---

### Task 4: LlmService——OpenAI 兼容协议唯一出口（TDD）

**Files:**
- Create: `lib/core/llm/llm_service.dart`
- Test: `test/core/llm/llm_service_test.dart`

设计稿第六节全部 5 条要求在此实现：唯一出口、模型分层、JSON 兜底链、结果落 llm_logs、成本统计基础。ASR 不走此类（spec 偏离决策 #2）。

- [ ] **Step 4.1: 写失败测试（含假 HTTP 适配器）**

```dart
// test/core/llm/llm_service_test.dart
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/settings/api_config.dart';

/// 可编程假适配器：按顺序消费预设响应
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.responses);
  final List<_Resp> responses;
  int calls = 0;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    requests.add(options);
    final r = responses[calls++];
    if (r.delay != null) await Future.delayed(r.delay!);
    if (r.error != null) throw r.error!;
    return ResponseBody.fromString(r.body!, r.status,
        headers: ResponseBodyHeaders.fromMap({
          'content-type': ['application/json']
        }));
  }

  @override
  void close({bool force = false}) {}
}

class _Resp {
  _Resp(this.status, this.body, {this.delay, this.error});
  final int status;
  final String? body;
  final Duration? delay;
  final Object? error;
}

String chatBody(String content, {int pt = 10, int ct = 20}) =>
    '{"choices":[{"message":{"role":"assistant","content":${jsonEncode(content)}}],'
    '"usage":{"prompt_tokens":$pt,"completion_tokens":$ct}}';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  ApiConfig cfg() => const ApiConfig(
      baseUrl: 'https://example.com/v1',
      apiKey: 'sk-x',
      modelCheap: 'qwen-flash',
      modelStandard: 'qwen-plus');

  Dio dioWith(List<_Resp> rs) {
    final adapter = FakeAdapter(rs);
    return Dio(BaseOptions())
      ..httpClientAdapter = adapter
      ..options.validateStatus = (_) => true; // 让服务层自己处理状态码
  }

  test('chat 成功：Bearer 头、模型分层、usage 落 llm_logs', () async {
    final dio = dioWith([_Resp(200, chatBody('你好'))]);
    final svc = LlmService(dio: dio, db: db)..updateConfig(cfg());
    final out = await svc.chat(const [
      {'role': 'user', 'content': 'hi'}
    ], purpose: '测试');
    expect(out, '你好');
    final req = (dio.httpClientAdapter as FakeAdapter).requests.single;
    expect(req.path, 'https://example.com/v1/chat/completions');
    expect(req.headers['Authorization'].first, 'Bearer sk-x');
    final log = await db.select(db.llmLogs).getSingle();
    expect(log.model, 'qwen-plus');
    expect(log.promptTokens, 10);
    expect(log.completionTokens, 20);
    expect(log.purpose, '测试');
  });

  test('cheap 分层用 qwen-flash，jsonMode 带 response_format', () async {
    final dio = dioWith([_Resp(200, chatBody('{}'))]);
    final svc = LlmService(dio: dio, db: db)..updateConfig(cfg());
    await svc.chatJson(const [
      {'role': 'user', 'content': '输出 json'}
    ], tier: LlmTier.cheap, purpose: '映射');
    final req = (dio.httpClientAdapter as FakeAdapter).requests.single;
    expect((req.data as Map)['model'], 'qwen-flash');
    expect((req.data as Map)['response_format'], {'type': 'json_object'});
  });

  test('429 退避重试后成功', () async {
    final dio = dioWith([_Resp(429, '{"error":"rate"}'), _Resp(200, chatBody('ok'))]);
    final svc = LlmService(dio: dio, db: db, backoffBase: Duration.zero)..updateConfig(cfg());
    expect(await svc.chat(const [{'role': 'user', 'content': 'x'}], purpose: 't'), 'ok');
  });

  test('非重试错误直接抛 LlmException', () async {
    final dio = dioWith([_Resp(401, '{"error":{"message":"bad key"}}')]);
    final svc = LlmService(dio: dio, db: db, backoffBase: Duration.zero)..updateConfig(cfg());
    await expectLater(
        svc.chat(const [{'role': 'user', 'content': 'x'}], purpose: 't'),
        throwsA(isA<LlmException>().having((e) => e.message, 'message', contains('bad key'))));
  });

  test('chatJson 兜底链：剥围栏→截取大括号→LLM 修复', () async {
    // 第一次返回带围栏+前后杂质的 JSON，无需修复即可解析
    final dio = dioWith([
      _Resp(200, chatBody('好的，结果如下：\n```json\n{"a":1}\n```\n完毕'))
    ]);
    final svc = LlmService(dio: dio, db: db)..updateConfig(cfg());
    expect(await svc.chatJson(const [{'role': 'user', 'content': 'x'}], purpose: 't'), {'a': 1});
  });

  test('chatJson 修复链：坏 JSON 回传 LLM 修复一次后成功', () async {
    final dio = dioWith([
      _Resp(200, chatBody('{"a": ')),          // 截断的 JSON，本地无法解析
      _Resp(200, chatBody('{"a": 1}')),        // 修复后的合法 JSON
    ]);
    final svc = LlmService(dio: dio, db: db, backoffBase: Duration.zero)..updateConfig(cfg());
    expect(await svc.chatJson(const [{'role': 'user', 'content': 'x'}], purpose: 't'), {'a': 1});
    expect((dio.httpClientAdapter as FakeAdapter).calls, 2);
  });

  test('修复后仍失败 → 抛 LlmJsonException', () async {
    final dio = dioWith([
      _Resp(200, chatBody('not-json')),
      _Resp(200, chatBody('still-not-json')),
    ]);
    final svc = LlmService(dio: dio, db: db, backoffBase: Duration.zero)..updateConfig(cfg());
    await expectLater(svc.chatJson(const [{'role': 'user', 'content': 'x'}], purpose: 't'),
        throwsA(isA<LlmJsonException>()));
  });

  test('testConnection 走 GET /models', () async {
    final dio = dioWith([_Resp(200, '{"data":[{"id":"qwen-plus"}]}')]);
    final svc = LlmService(dio: dio, db: db)..updateConfig(cfg());
    expect(await svc.testConnection(), contains('qwen-plus'));
  });
}
```

注意：文件顶部还需 `import 'dart:convert';`（jsonEncode 用）。

- [ ] **Step 4.2: 运行确认失败**

Run: `flutter test test/core/llm/llm_service_test.dart`
Expected: FAIL，`llm_service.dart` 不存在。

- [ ] **Step 4.3: 实现 LlmService**

```dart
// lib/core/llm/llm_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/api_config.dart';

class LlmException implements Exception {
  LlmException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'LlmException($statusCode): $message';
}

class LlmJsonException implements Exception {
  LlmJsonException(this.message);
  final String message;
  @override
  String toString() => 'LlmJsonException: $message';
}

/// LLM 调用唯一出口（设计稿 6.1）。业务代码禁止直连任何厂商 SDK。
class LlmService {
  LlmService({Dio? dio, required this.db, this.backoffBase = const Duration(seconds: 1)})
      : dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 5),
            ));

  final Dio dio;
  final AppDatabase db;
  final Duration backoffBase;
  ApiConfig? _config;

  void updateConfig(ApiConfig config) => _config = config;

  static const jsonSystemPrefix =
      '只输出 json（JSON），不要 markdown 代码块，不要解释。'
      '不确定的信息明确说不确定，严禁编造剧情和设定。';
  // 注：前缀同时含中英文 "json/JSON" 字样，满足百炼 json_object 模式对提示词的硬性要求（spec 3.2）。

  /// 普通 chat。messages 形如 [{"role":"system","content":...},...]。
  Future<String> chat(
    List<Map<String, String>> messages, {
    LlmTier tier = LlmTier.standard,
    bool jsonMode = false,
    String purpose = '',
    int? projectId,
  }) async {
    final cfg = _config;
    if (cfg == null || !cfg.isComplete) {
      throw LlmException('未配置 API（设置页填写 base_url 与 api_key）');
    }
    final body = <String, dynamic>{
      'model': cfg.modelOf(tier),
      'messages': messages,
      if (jsonMode) 'response_format': {'type': 'json_object'},
    };

    const maxAttempts = 4; // 1 次原始 + 3 次重试（设计稿 S9/6）
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(backoffBase * (1 << (attempt - 1))); // 指数退避 1s/2s/4s
      }
      try {
        final resp = await dio.post('${cfg.baseUrl}/chat/completions',
            data: body,
            options: Options(
              validateStatus: (_) => true,
              headers: {'Authorization': 'Bearer ${cfg.apiKey}'},
            ));
        if (resp.statusCode == 200) {
          final data = resp.data as Map<String, dynamic>;
          final usage = (data['usage'] as Map<String, dynamic>?) ?? {};
          await db.into(db.llmLogs).insert(LlmLogsCompanion.insert(
                projectId: Value(projectId),
                purpose: purpose,
                model: cfg.modelOf(tier),
                promptTokens: Value((usage['prompt_tokens'] as int?) ?? 0),
                completionTokens: Value((usage['completion_tokens'] as int?) ?? 0),
              ));
          final choices = data['choices'] as List;
          return ((choices[0] as Map)['message'] as Map)['content'] as String;
        }
        final msg = _extractErrorMessage(resp.data) ?? 'HTTP ${resp.statusCode}';
        if (_retryable(resp.statusCode)) {
          lastError = LlmException(msg, statusCode: resp.statusCode);
          continue;
        }
        throw LlmException(msg, statusCode: resp.statusCode);
      } on DioException catch (e) {
        lastError = LlmException('网络错误: ${e.message}');
        continue; // 网络类错误一律重试（设计稿 9.1）
      }
    }
    throw lastError ?? LlmException('重试次数耗尽');
  }

  bool _retryable(int? status) =>
      status == null || status == 429 || (status != null && status >= 500);

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final err = data['error'];
      if (err is Map && err['message'] is String) return err['message'] as String;
      if (err is String) return err;
    }
    return null;
  }

  /// JSON 模式调用 + 兜底解析链（设计稿 6.3）：
  /// 直接解析 → 剥围栏 → 首尾大括号截取 → LLM 修复一次 → 抛 LlmJsonException
  Future<Map<String, dynamic>> chatJson(
    List<Map<String, String>> messages, {
    LlmTier tier = LlmTier.standard,
    String purpose = '',
    int? projectId,
  }) async {
    final msgs = [
      {'role': 'system', 'content': jsonSystemPrefix},
      ...messages,
    ];
    var raw = await chat(msgs, tier: tier, jsonMode: true, purpose: purpose, projectId: projectId);
    dynamic? parsed = _tryParse(raw);
    if (parsed is Map<String, dynamic>) return parsed;

    // 修复链（最多 1 次）
    raw = await chat([
      ...msgs,
      {'role': 'assistant', 'content': raw},
      {'role': 'user',
       'content': '上面的输出不是合法 json。请只输出修复后的合法 json，不要任何其他文字。'},
    ], tier: tier, jsonMode: true, purpose: '$purpose(修复)', projectId: projectId);
    parsed = _tryParse(raw);
    if (parsed is Map<String, dynamic>) return parsed;
    throw LlmJsonException('解析失败，最后输出: ${raw.length > 200 ? raw.substring(0, 200) : raw}');
  }

  dynamic _tryParse(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {}
    // 剥 markdown 围栏
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(raw);
    if (fence != null) {
      try {
        return jsonDecode(fence.group(1)!);
      } catch (_) {}
    }
    // 首尾大括号截取
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        return jsonDecode(raw.substring(start, end + 1));
      } catch (_) {}
    }
    return null;
  }

  /// 设置页〔测试连接〕：GET /models
  Future<String> testConnection() async {
    final cfg = _config;
    if (cfg == null || !cfg.isComplete) throw LlmException('未配置 API');
    final resp = await dio.get('${cfg.baseUrl}/models',
        options: Options(
          validateStatus: (_) => true,
          headers: {'Authorization': 'Bearer ${cfg.apiKey}'},
        ));
    if (resp.statusCode != 200) {
      throw LlmException('HTTP ${resp.statusCode}', statusCode: resp.statusCode);
    }
    final data = (resp.data as Map)['data'] as List;
    return '连接成功，可用模型 ${data.length} 个';
  }
}
```

- [ ] **Step 4.4: 运行测试通过**

Run: `flutter test test/core/llm/llm_service_test.dart`
Expected: 8 个用例全部 PASS。

- [ ] **Step 4.5: Commit**

```bash
cd "C:/AI WorkSpace" && git add 陪析/lib 陪析/test && git commit -m "feat(peixi): LlmService 唯一出口（分层/重试退避/JSON 兜底链/llm_logs 计量）"
```

---

### Task 5: 应用壳——入口、Provider、媒体库空态页

**Files:**
- Create: `lib/main.dart`（替换模板）
- Create: `lib/app.dart`
- Create: `lib/providers.dart`
- Create: `lib/features/library/library_page.dart`
- Modify: `test/widget_test.dart`（替换模板计数器测试）

- [ ] **Step 5.1: 全局 Provider**

```dart
// lib/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/settings/settings_repository.dart';

/// main() 里完成异步初始化后 overrideWithValue 注入
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());
final settingsRepoProvider = Provider<SettingsRepository>((ref) => throw UnimplementedError());

final llmServiceProvider = Provider<LlmService>((ref) {
  final svc = LlmService(db: ref.watch(databaseProvider));
  ref.listenSelf((_, __) {});
  // 启动时用已存配置武装 LLM；设置页保存后会再次 updateConfig
  ref.onDispose(() {});
  Future(() async {
    final cfg = await ref.read(settingsRepoProvider).loadApiConfig();
    svc.updateConfig(cfg);
  });
  return svc;
});
```

- [ ] **Step 5.2: 入口**

```dart
// lib/main.dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:peixi/app.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:peixi/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  final db = AppDatabase(NativeDatabase.createInBackground(
      File(p.join(dir.path, 'peixi.sqlite'))));
  final repo = SettingsRepository(db, FlutterSecureStorage());
  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      settingsRepoProvider.overrideWithValue(repo),
    ],
    child: const PeixiApp(),
  ));
}
```

- [ ] **Step 5.3: App 与主题**

```dart
// lib/app.dart
import 'package:flutter/material.dart';

class PeixiApp extends StatelessWidget {
  const PeixiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '陪析',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: const LibraryPage(),
      );
}

import 'package:peixi/features/library/library_page.dart';
```
（import 移到文件顶部。）

- [ ] **Step 5.4: 媒体库空态页**

```dart
// lib/features/library/library_page.dart
import 'package:flutter/material.dart';
import 'package:peixi/features/settings/settings_page.dart';

/// M1-P1：仅空态与设置入口。项目卡片网格在阶段二接入真实数据。
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('陪析 · 媒体库'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '设置',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsPage())),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_filter_outlined,
                  size: 72, color: Colors.grey.shade600),
              const SizedBox(height: 12),
              Text('还没有项目', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('视频导入与处理流水线将在阶段二上线',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}
```

- [ ] **Step 5.5: 替换模板 widget_test.dart 为冒烟测试**

```dart
// test/widget_test.dart
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/app.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/providers.dart';

void main() {
  testWidgets('应用启动显示媒体库空态', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsRepoProvider.overrideWithValue(SettingsRepository(db, FlutterSecureStorage())),
      ],
      child: const PeixiApp(),
    ));
    await tester.pump();
    expect(find.text('还没有项目'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    await db.close();
  });
}
```

注意：测试需在 `setUp` 加 `FlutterSecureStorage.setMockInitialValues({});`（或文件顶部 main 内第一行）。

- [ ] **Step 5.6: 全量测试 + Windows 运行**

```bash
flutter test
flutter run -d windows
```
Expected: 全部测试 PASS；窗口显示"还没有项目"空态，右上角设置图标可点击（设置页在 Task 6 前 push 会失败——本步骤只验证图标存在即可，或把 Task 6 完成后再跑此步）。

- [ ] **Step 5.7: Commit**

```bash
cd "C:/AI WorkSpace" && git add 陪析/lib 陪析/test && git commit -m "feat(peixi): 应用壳（入口/Provider/暗色主题/媒体库空态）"
```

---

### Task 6: 设置页——API 配置 + OSS + 测试连接 + 成本统计

**Files:**
- Create: `lib/features/settings/settings_page.dart`

设计稿 8.6 的 M1 子集：供应商预设（默认阿里云百炼）、自定义 base_url/api_key/model 两档、〔测试连接〕、OSS 四项、token 成本统计。播放偏好开关本页先不做（阶段四播放器时随弹幕引擎一起做）。

- [ ] **Step 6.1: 实现页面**

```dart
// lib/features/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/settings/api_config.dart';
import 'package:peixi/providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _modelCheap = TextEditingController();
  final _modelStandard = TextEditingController();
  final _ossBucket = TextEditingController();
  final _ossEndpoint = TextEditingController();
  final _ossAk = TextEditingController();
  final _ossSk = TextEditingController();
  String _preset = '阿里云百炼';
  int? _totalTokens;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final repo = ref.read(settingsRepoProvider);
    final cfg = await repo.loadApiConfig();
    _baseUrl.text = cfg.baseUrl;
    _apiKey.text = cfg.apiKey;
    _modelCheap.text = cfg.modelCheap;
    _modelStandard.text = cfg.modelStandard;
    final oss = await repo.loadOssConfig();
    if (oss != null) {
      _ossBucket.text = oss.bucket;
      _ossEndpoint.text = oss.endpoint;
      _ossAk.text = oss.accessKeyId;
      _ossSk.text = oss.accessKeySecret;
    }
    _totalTokens = await ref.read(databaseProvider).customSelect(
        'SELECT COALESCE(SUM(prompt_tokens+completion_tokens),0) AS t FROM llm_logs')
        .getSingle()
        .then((r) => r.read<int>('t'));
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_baseUrl, _apiKey, _modelCheap, _modelStandard,
        _ossBucket, _ossEndpoint, _ossAk, _ossSk]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('LLM API', style: Theme.of(context).textTheme.titleMedium),
              DropdownButtonFormField<String>(
                initialValue: _preset,
                decoration: const InputDecoration(labelText: '供应商预设'),
                items: const [
                  DropdownMenuItem(value: '阿里云百炼', child: Text('阿里云百炼（推荐）')),
                  DropdownMenuItem(value: '自定义', child: Text('自定义')),
                ],
                onChanged: (v) => setState(() {
                  _preset = v!;
                  if (v == '阿里云百炼') {
                    _baseUrl.text = ApiConfig.bailianBaseUrl;
                  }
                }),
              ),
              TextFormField(
                controller: _baseUrl,
                enabled: _preset == '自定义',
                decoration: const InputDecoration(labelText: 'Base URL'),
              ),
              TextFormField(
                controller: _apiKey,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'API Key', hintText: '百炼控制台 → API-KEY 创建'),
              ),
              TextFormField(
                controller: _modelCheap,
                decoration: const InputDecoration(
                    labelText: '轻量模型（映射/摘要/人物）', suffixText: 'cheap'),
              ),
              TextFormField(
                controller: _modelStandard,
                decoration: const InputDecoration(
                    labelText: '主力模型（解说/批注/知识卡）', suffixText: 'standard'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_tethering),
                label: Text(_testing ? '测试中…' : '测试连接'),
              ),
              const Divider(height: 32),
              Text('阿里云 OSS（语音识别中转）',
                  style: Theme.of(context).textTheme.titleMedium),
              TextFormField(
                  controller: _ossBucket, decoration: const InputDecoration(labelText: 'Bucket')),
              TextFormField(
                  controller: _ossEndpoint,
                  decoration: const InputDecoration(
                      labelText: 'Endpoint', hintText: 'oss-cn-beijing.aliyuncs.com')),
              TextFormField(
                  controller: _ossAk,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'AccessKeyId')),
              TextFormField(
                  controller: _ossSk,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'AccessKeySecret')),
              const Divider(height: 32),
              Row(children: [
                const Icon(Icons.coin_outlined, size: 18),
                const SizedBox(width: 8),
                Text('本项目累计 LLM 消耗：${_totalTokens ?? 0} tokens'),
              ]),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存全部'),
              ),
            ],
          ),
        ),
      );

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 用表单当前值临时构造配置测试，未保存也能测
      ref.read(llmServiceProvider).updateConfig(ApiConfig(
          baseUrl: _baseUrl.text.trim(),
          apiKey: _apiKey.text.trim(),
          modelCheap: _modelCheap.text.trim(),
          modelStandard: _modelStandard.text.trim()));
      final msg = await ref.read(llmServiceProvider).testConnection();
      messenger.showSnackBar(SnackBar(content: Text('✅ $msg')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('❌ $e')));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final repo = ref.read(settingsRepoProvider);
    await repo.saveApiConfig(ApiConfig(
        baseUrl: _baseUrl.text.trim(),
        apiKey: _apiKey.text.trim(),
        modelCheap: _modelCheap.text.trim(),
        modelStandard: _modelStandard.text.trim()));
    await repo.saveOssConfig(OssConfig(
        bucket: _ossBucket.text.trim(),
        endpoint: _ossEndpoint.text.trim(),
        accessKeyId: _ossAk.text.trim(),
        accessKeySecret: _ossSk.text.trim()));
    ref.read(llmServiceProvider).updateConfig(await repo.loadApiConfig());
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
    }
  }
}
```

注意：Riverpod 3.x 中 `ConsumerStatefulWidget`/`ConsumerState` 用法与 2.x 相同；若 `DropdownButtonFormField.initialValue` 参数名不同（新版为 `value`），按编译器提示改。

- [ ] **Step 6.2: 手动验证（真实验收需要用户的 Key）**

```bash
flutter run -d windows
```
Expected: 设置页打开无红屏；无 Key 时点〔测试连接〕→ SnackBar 显示"❌ 未配置 API…"（LlmException 文案）；填入真实百炼 Key 后点测试 → "✅ 连接成功，可用模型 N 个"。**没有真实 Key 时到此为止即可**（真实 Key 由用户提供后补测，不阻塞本任务）。

- [ ] **Step 6.3: Commit**

```bash
cd "C:/AI WorkSpace" && git add 陪析/lib && git commit -m "feat(peixi): 设置页（预设/自定义/测试连接/OSS/成本统计）"
```

---

### Task 7: 阶段一收尾验收

- [ ] **Step 7.1: 静态分析零告警**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7.2: 全量测试**

Run: `flutter test`
Expected: 全部 PASS（DB 4 + Settings 3 + LLM 8 + 冒烟 1 = 16 个用例左右）。

- [ ] **Step 7.3: Windows Release 构建冒烟**

Run: `flutter build windows --release`
Expected: `√ Built build\windows\x64\runner\Release\peixi.exe`。双击 exe 可启动。

- [ ] **Step 7.4: Android Debug 构建冒烟（可选但建议现在做，尽早暴露 Android 构建问题）**

```bash
export JAVA_HOME="C:/Users/<user>/AndroidTools/jdk/jdk-17.0.20.1+1"
export ANDROID_HOME="C:/Users/<user>/AndroidTools/sdk"
flutter build apk --debug
```
Expected: `√ Built build\app\outputs\flutter-apk\app-debug.apk`。首次 Gradle 下载较慢（走腾讯镜像）。

- [ ] **Step 7.5: Commit 与交付说明**

```bash
cd "C:/AI WorkSpace" && git add 陪析/ && git commit -m "chore(peixi): M1 阶段一收尾（analyze/test/双端构建冒烟通过）"
```

在 `docs/交付说明-M1阶段一.md` 写：已交付内容、已知问题清单（如测试连接未经真实 Key 验证、Visual Studio 依赖项的实际状态）、与设计稿偏离无新增。

---

## Self-Review 记录（计划编写者已执行）

1. **Spec 覆盖**：spec §5 运行时验证清单中 pub 镜像（Task 0.4 分支）、sqlite 原生库（Task 2.4 测试即验证）已覆盖；OSS/ffmpeg/ASR/json_object 四项验证属阶段二 spike，不在本计划范围（已在"计划序列"注明）。依赖版本与 spec §3.5 一致。
2. **占位符扫描**：无 TBD/TODO；Task 6.2 的真实 Key 测试明确标注"由用户提供后补测，不阻塞"。
3. **类型一致性**：`ApiConfig.modelOf(LlmTier)` 在 Task 3 定义、Task 4 使用一致；`LlmService.chat/chatJson/testConnection` 签名在 Task 4 测试与实现一致；`SettingsRepository` 方法名 Task 3 内自洽、Task 6 使用一致。Task 5.3 app.dart 的 import 位置笔误已就地注明修正方式。

