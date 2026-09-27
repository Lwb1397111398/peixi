import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/features/settings/settings_page.dart';
import 'package:peixi/providers.dart';

class FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async => '/tmp/peixi-support';
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
    PathProviderPlatform.instance = FakePathProvider();
  });
  tearDown(() => db.close());

  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsRepoProvider
              .overrideWithValue(SettingsRepository(db, FlutterSecureStorage())),
        ],
        child: MaterialApp(home: child),
      );

  testWidgets('设置页装配：LLM 渠道区块就位，旧 base_url 首启迁移为默认渠道', (tester) async {
    await db.into(db.settings).insert(SettingsCompanion.insert(
        key: 'llm.base_url', value: 'https://x/v1'));
    await tester.pumpWidget(wrap(const SettingsPage()));
    await tester.pumpAndSettle();

    // 新三区块替代旧「LLM API」表单
    expect(find.text('模型渠道'), findsOneWidget);
    expect(find.text('功能槽位'), findsOneWidget);
    expect(find.text('并发与频控'), findsOneWidget);
    expect(find.text('供应商预设'), findsNothing);
    // 旧单配置键在首启时迁移为默认渠道
    expect(find.text('默认渠道'), findsOneWidget);
    // 用量与预算区块保留（页面变长后该块在懒加载 ListView 视口外，先滚动到位）
    await tester.scrollUntilVisible(
      find.text('月度 token 预算'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('月度 token 预算'), findsOneWidget);
  });

  testWidgets('播放偏好：开关与滑杆调整即时落库', (tester) async {
    await db.into(db.settings).insert(SettingsCompanion.insert(
        key: 'llm.base_url', value: 'https://x/v1'));
    await tester.pumpWidget(wrap(const SettingsPage()));
    await tester.pumpAndSettle();

    // 播放偏好区块在列表下方，滚动到位（ListView 懒加载）
    await tester.scrollUntilVisible(
      find.text('播放偏好'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('播放偏好'), findsOneWidget);

    // 关闭弹幕提问
    await tester.tap(find.text('弹幕提问打断（L4）'));
    await tester.pumpAndSettle();
    var row = await (db.select(db.settings)
          ..where((t) => t.key.equals('play.quiz_enabled')))
        .getSingle();
    expect(row.value, '0');

    // 每集上限滑到 10（+右侧末端）；不能全局取第一个 Slider——
    // 页面上方的「并发与频控」区块也有 Slider
    final sliderRow = find
        .ancestor(of: find.text('每集最多提问'), matching: find.byType(Row))
        .first;
    await tester.drag(
        find.descendant(of: sliderRow, matching: find.byType(Slider)),
        const Offset(400, 0));
    await tester.pumpAndSettle();
    row = await (db.select(db.settings)
          ..where((t) => t.key.equals('play.max_per_episode')))
        .getSingle();
    expect(int.parse(row.value), 10);

    // 关闭保留临时音频
    await tester.tap(find.text('保留临时音频'));
    await tester.pumpAndSettle();
    row = await (db.select(db.settings)
          ..where((t) => t.key.equals('play.keep_temp_audio')))
        .getSingle();
    expect(row.value, '0');
  });
}
