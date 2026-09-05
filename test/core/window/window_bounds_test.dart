import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/settings_repository.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
    repo = SettingsRepository(db, const FlutterSecureStorage());
  });

  tearDown(() => db.close());

  test('窗口边界存取往返', () async {
    expect(await repo.loadWindowBounds(), isNull, reason: '首次启动无记录');

    await repo.saveWindowBounds(12.5, -3, 1600, 900);
    final b = await repo.loadWindowBounds();
    expect(b!.left, 12.5);
    expect(b.top, -3, reason: '多显示器场景 top 可为负');
    expect(b.width, 1600);
    expect(b.height, 900);

    // 二次保存覆盖
    await repo.saveWindowBounds(0, 0, 1280, 720);
    expect((await repo.loadWindowBounds())!.width, 1280);
  });

  test('损坏的边界记录返回 null（回退默认尺寸）', () async {
    await db.into(db.settings).insert(SettingsCompanion.insert(
        key: 'window.bounds', value: '10,20,not-a-number,400'));
    expect(await repo.loadWindowBounds(), isNull);

    await db
        .update(db.settings)
        .write(const SettingsCompanion(value: Value('1,2,3')));
    expect(await repo.loadWindowBounds(), isNull, reason: '字段不足');
  });
}
