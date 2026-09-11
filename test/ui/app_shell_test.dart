import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/app.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/core/theme/theme_controller.dart';
import 'package:peixi/providers.dart';

void main() {
  FlutterSecureStorage.setMockInitialValues({});

  Widget wrap(AppDatabase db) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsRepoProvider.overrideWithValue(
              SettingsRepository(db, FlutterSecureStorage())),
          // AppShell 一次性挂载设置页会触发 llmServiceProvider 的启动
          // 异步武装（零延时 Timer，会卡住 fake_async 不变式），此处换裸实例
          llmServiceProvider.overrideWith((ref) => LlmService(db: db)),
          themeModeProvider
              .overrideWith(() => ThemeModeController(ThemeMode.light)),
        ],
        child: const PeixiApp(),
      );

  testWidgets('窄屏（<900）用底部 NavigationBar 导航且可切换目的地', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap(db));
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.tap(find.text('设置'));
    await tester.pump();
    expect(find.text('服务连接与学习偏好，全部即时生效'), findsOneWidget);

    await tester.tap(find.text('复盘'));
    await tester.pump();
    expect(find.text('还没有答题记录'), findsOneWidget);

    // 在测试体内关闭：drift 需要显式 close 才不会在树卸载时留流缓存 Timer
    await db.close();
  });

  testWidgets('宽屏（≥900）用左侧 NavigationRail 导航', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    tester.view.physicalSize = const Size(1100, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap(db));
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('陪析'), findsOneWidget); // rail 品牌位

    await db.close();
  });
}
