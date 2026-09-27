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
}
