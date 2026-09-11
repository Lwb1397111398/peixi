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
  testWidgets('应用启动显示媒体库空态', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(
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
    ));
    await tester.pump();
    expect(find.text('还没有项目'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    await db.close();
  });
}
