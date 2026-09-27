import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/settings/llm_channels_section.dart';
import 'package:peixi/providers.dart';

/// fetchModels 不触网：返回固定模型列表，避免测试内真实 HTTP 与挂起定时器。
class FakeLlmService extends LlmService {
  FakeLlmService({required super.db});
  @override
  Future<List<String>> fetchModels(ChannelRoute channel) async =>
      const ['fake-model-1', 'fake-model-2'];
}

void main() {
  late AppDatabase db;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsRepoProvider.overrideWithValue(
              SettingsRepository(db, const FlutterSecureStorage())),
          llmServiceProvider.overrideWithValue(FakeLlmService(db: db)),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );

  Widget section() => const SingleChildScrollView(child: LlmChannelsSection());

  Future<SettingsRepository> seededRepo() async {
    final repo = SettingsRepository(db, const FlutterSecureStorage());
    return repo;
  }

  /// SnackBar 自动收起依赖定时器：推进假时钟并等退场动画结束。
  Future<void> dismissSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('空态提示 + 添加渠道对话框落库后列表刷新', (tester) async {
    await tester.pumpWidget(wrap(section()));
    await tester.pumpAndSettle();
    expect(find.textContaining('尚未添加'), findsOneWidget);

    await tester.tap(find.text('添加渠道'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-name')), '中转站A');
    await tester.enterText(
        find.byKey(const Key('field-baseurl')), 'https://a/v1');
    await tester.enterText(find.byKey(const Key('field-apikey')), 'sk-a');
    // 页面上「并发与频控」卡片也有一个「保存」按钮，须限定对话框内
    await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('保存')));
    await tester.pumpAndSettle();
    expect(find.text('中转站A'), findsOneWidget);
    expect(find.text('https://a/v1'), findsOneWidget);
    expect(find.textContaining('尚未添加'), findsNothing);
  });

  testWidgets('编辑渠道：对话框预填，改名保存后列表刷新', (tester) async {
    final repo = await seededRepo();
    await repo.addChannel(name: '旧站', baseUrl: 'https://old/v1', apiKey: 'sk-old');
    await tester.pumpWidget(wrap(section()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('编辑渠道'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('field-name')), '新站');
    await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('保存')));
    await tester.pumpAndSettle();
    expect(find.text('新站'), findsOneWidget);
    expect(find.text('旧站'), findsNothing);
  });

  testWidgets('功能槽位：四个槽位标签渲染；已绑定未拉模型时弹层提示先拉模型', (tester) async {
    final repo = await seededRepo();
    final id =
        await repo.addChannel(name: '测试站', baseUrl: 'https://t/v1', apiKey: 'sk-t');
    await repo.saveSlot(LlmSlot.analysis, channelId: id, model: 'deepseek-v3');
    await tester.pumpWidget(wrap(section()));
    await tester.pumpAndSettle();

    expect(find.textContaining('轻量整理'), findsOneWidget);
    expect(find.textContaining('深层分析'), findsOneWidget);
    expect(find.textContaining('视觉理解'), findsOneWidget);
    expect(find.textContaining('语义向量'), findsOneWidget);
    // 渠道名出现两次：模型渠道列表 + analysis 槽位下拉选中项
    expect(find.text('测试站'), findsNWidgets(2));

    // 该渠道从未拉取过模型 → 模型弹层只有禁用提示项
    await tester.tap(find.text('deepseek-v3'));
    await tester.pumpAndSettle();
    expect(find.text('先在该渠道「测试/拉模型」'), findsOneWidget);
  });

  testWidgets('槽位绑定指向不存在的渠道：下拉回退为占位提示，不崩溃', (tester) async {
    // 模拟"渠道被外部删除但槽位串残留"的脏数据
    await db.into(db.settings).insert(
        SettingsCompanion.insert(key: 'llm.slot.analysis', value: '999:deepseek-v3'));
    await tester.pumpWidget(wrap(section()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('渠道'), findsWidgets);
  });

  testWidgets('删除渠道：确认对话框后落库并回到空态', (tester) async {
    final repo = await seededRepo();
    final id =
        await repo.addChannel(name: '待删站', baseUrl: 'https://d/v1', apiKey: 'sk-d');
    await tester.pumpWidget(wrap(section()));
    await tester.pumpAndSettle();
    expect(find.text('待删站'), findsOneWidget);

    await tester.tap(find.byKey(Key('del-channel-$id')));
    await tester.pumpAndSettle();
    expect(find.textContaining('其槽位绑定将一并清除'), findsOneWidget);
    await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('删除')));
    await tester.pumpAndSettle();
    expect(find.textContaining('尚未添加'), findsOneWidget);
    expect(find.text('待删站'), findsNothing);
  });

  testWidgets('新增渠道后可通过 UI 创建槽位绑定：选渠道→模型弹层选模型→落库', (tester) async {
    final repo = await seededRepo();
    final cid =
        await repo.addChannel(name: '新站', baseUrl: 'https://n/v1', apiKey: 'sk-n');
    await tester.pumpWidget(wrap(section()));
    await tester.pumpAndSettle();

    // 拉取模型列表（FakeLlmService 不触网）
    await tester.tap(find.text('测试/拉模型'));
    await tester.pumpAndSettle();
    expect(find.textContaining('连接成功'), findsOneWidget);
    await dismissSnackBar(tester);

    // 深层分析槽位：打开渠道下拉并选择「新站」（此前无绑定时选择无法持久化）
    await tester.tap(find.byKey(const Key('slot-channel-analysis')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新站').last);
    await tester.pumpAndSettle();

    // 模型弹层此时必须可用（无绑定时也不禁用）
    await tester.tap(find.byKey(const Key('slot-model-analysis')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('fake-model-1').last);
    await tester.pumpAndSettle();

    final b = await repo.loadSlot(LlmSlot.analysis);
    expect(b, isNotNull, reason: '选择模型后必须落库（此前 UI 流程走不通）');
    expect(b!.channelId, cid);
    expect(b.model, 'fake-model-1');
    expect(find.text('fake-model-1'), findsOneWidget);
  });

  testWidgets('已绑定槽位切换渠道后选模型：保存新渠道 id 而非旧渠道', (tester) async {
    final repo = await seededRepo();
    final idA =
        await repo.addChannel(name: '甲站', baseUrl: 'https://a/v1', apiKey: 'sk-a');
    await repo.saveSlot(LlmSlot.analysis, channelId: idA, model: 'm-a');
    await tester.pumpWidget(wrap(section()));
    await tester.pumpAndSettle();

    // 通过对话框新增「乙站」：保存后自动拉模型
    await tester.tap(find.text('添加渠道'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-name')), '乙站');
    await tester.enterText(find.byKey(const Key('field-baseurl')), 'https://b/v1');
    await tester.enterText(find.byKey(const Key('field-apikey')), 'sk-b');
    await tester.tap(find
        .descendant(of: find.byType(AlertDialog), matching: find.text('保存')));
    await tester.pumpAndSettle();
    await dismissSnackBar(tester);

    // analysis 槽位：渠道切到乙站 → 模型弹层选 fake-model-2
    await tester.tap(find.byKey(const Key('slot-channel-analysis')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('乙站').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('slot-model-analysis')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('fake-model-2').last);
    await tester.pumpAndSettle();

    final channels = await repo.loadChannels();
    final idB = channels.firstWhere((c) => c.name == '乙站').id;
    final b = (await repo.loadSlot(LlmSlot.analysis))!;
    expect(b.channelId, idB, reason: '必须保存下拉当前选中的渠道，而非旧绑定渠道');
    expect(b.model, 'fake-model-2');
  });

  testWidgets('渠道对话框校验：空字段报错不关闭；BASE_URL 非 http(s) 拦截；填写完整后保存', (tester) async {
    final repo = await seededRepo();
    await tester.pumpWidget(wrap(section()));
    await tester.pumpAndSettle();

    Future<void> tapDialogSave() async {
      await tester.tap(find
          .descendant(of: find.byType(AlertDialog), matching: find.text('保存')));
      await tester.pump();
    }

    await tester.tap(find.text('添加渠道'));
    await tester.pumpAndSettle();

    // 全空：报错且对话框不关闭
    await tapDialogSave();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('请填写名称'), findsOneWidget);
    expect(find.text('请填写 BASE_URL'), findsOneWidget);
    expect(find.text('请填写 API KEY'), findsOneWidget);

    // BASE_URL 非 http(s)：拦截
    await tester.enterText(find.byKey(const Key('field-name')), '站点B');
    await tester.enterText(find.byKey(const Key('field-baseurl')), 'ftp://x');
    await tester.enterText(find.byKey(const Key('field-apikey')), 'sk-b');
    await tapDialogSave();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('需以 http:// 或 https:// 开头'), findsOneWidget);

    // 填写完整：保存落库
    await tester.enterText(find.byKey(const Key('field-baseurl')), 'https://ok/v1');
    await tapDialogSave();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('站点B'), findsOneWidget);
    expect(find.text('https://ok/v1'), findsOneWidget);
    final channels = await repo.loadChannels();
    expect(channels.map((c) => c.name), contains('站点B'));
  });
}
