import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';

void main() {
  test('llm_channels 表可写读，渠道 CRUD 字段齐全', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final id = await db.into(db.llmChannels).insert(
        LlmChannelsCompanion.insert(name: '中转站A', baseUrl: 'https://a/v1'));
    final row = await (db.select(db.llmChannels)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    expect(row.name, '中转站A');
    expect(row.enabled, true); // 默认启用
    await db.close();
  });
}
