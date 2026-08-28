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

    // 每集上限滑到 10（+右侧末端）
    final maxSlider = find.byType(Slider).first;
    await tester.drag(maxSlider, const Offset(400, 0));
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
