import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/settings_repository.dart';

/// 小说两遍式管线参数（设计文档 §3）：默认值、读取侧钳制脏值、roundtrip。
void main() {
  late AppDatabase db;
  late SettingsRepository repo;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepository(db, const FlutterSecureStorage());
  });
  tearDown(() async => db.close());

  /// 直写 settings 原始键，模拟外部/手改产生的越界脏值。
  Future<void> putRaw(String key, String value) =>
      db.into(db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: value));

  test('空库读取返回全部默认值', () async {
    final p = await repo.loadNovelParams();
    expect(p.mapBatchChapters, 5);
    expect(p.digestBatchChapters, 10);
    expect(p.annotateBatchChapters, 3);
    expect(p.initialBurstChapters, 10);
    expect(p.mapLeadChapters, 20);
    expect(p.vectorRecall, isFalse, reason: '向量语义回忆默认关');
  });

  test('读取侧钳制越界脏值（mapBatch=99→10、mapLead=0→1）', () async {
    await putRaw('novel.mapBatchChapters', '99');
    await putRaw('novel.mapLeadChapters', '0');
    await putRaw('novel.digestBatchChapters', '-3');
    await putRaw('novel.annotateBatchChapters', '0');
    await putRaw('novel.initialBurstChapters', '99999');
    final p = await repo.loadNovelParams();
    expect(p.mapBatchChapters, inInclusiveRange(1, 10));
    expect(p.mapLeadChapters, greaterThanOrEqualTo(1),
        reason: 'mapLead 为 0 会让地图/批注双泳道互等死锁');
    expect(p.digestBatchChapters, inInclusiveRange(1, 50));
    expect(p.annotateBatchChapters, inInclusiveRange(1, 10));
    expect(p.initialBurstChapters, inInclusiveRange(1, 200));
  });

  test('saveNovelParams 后 roundtrip 一致（含 vectorRecall 开）', () async {
    const p = NovelParams(
        mapBatchChapters: 7,
        digestBatchChapters: 15,
        annotateBatchChapters: 4,
        initialBurstChapters: 12,
        mapLeadChapters: 30,
        vectorRecall: true);
    await repo.saveNovelParams(p);
    final loaded = await repo.loadNovelParams();
    expect(loaded.mapBatchChapters, 7);
    expect(loaded.digestBatchChapters, 15);
    expect(loaded.annotateBatchChapters, 4);
    expect(loaded.initialBurstChapters, 12);
    expect(loaded.mapLeadChapters, 30);
    expect(loaded.vectorRecall, isTrue);
  });

  test('非整数值按默认值处理，不抛异常', () async {
    await putRaw('novel.mapBatchChapters', 'abc');
    final p = await repo.loadNovelParams();
    expect(p.mapBatchChapters, 5);
  });
}
