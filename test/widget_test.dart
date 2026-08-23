import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/app.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/settings_repository.dart';
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
      ],
      child: const PeixiApp(),
    ));
    await tester.pump();
    expect(find.text('还没有项目'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    await db.close();
  });
}
