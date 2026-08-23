import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/calibration/calibration_page.dart';
import 'package:peixi/providers.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => db.close());

  Future<int> seed() async {
    final id = await db.into(db.projects).insert(ProjectsCompanion.insert(
        type: 'video', title: '潜伏', sourcePath: '/x.mkv', status: 'WAIT_CALIBRATION'));
    final c1 = await db.into(db.characters).insert(CharactersCompanion.insert(
        projectId: id,
        name: '余则成',
        speakerKey: const Value('SPEAKER_00'),
        confidence: const Value(0.9)));
    final c2 = await db.into(db.characters).insert(CharactersCompanion.insert(
        projectId: id,
        name: '未知·声音1',
        speakerKey: const Value('SPEAKER_01'),
        confidence: const Value(0.3)));
    await db.into(db.segments).insert(SegmentsCompanion.insert(
        projectId: id,
        idx: 0,
        startMs: 1000,
        endMs: 3000,
        content: '站长，这件事恐怕没那么简单，得从长计议',
        speakerCharId: Value(c1)));
    await db.into(db.segments).insert(SegmentsCompanion.insert(
        projectId: id,
        idx: 1,
        startMs: 4000,
        endMs: 4500,
        content: '好',
        speakerCharId: Value(c2)));
    return id;
  }

  Future<void> pumpPage(WidgetTester tester, int id,
      void Function(Map<int, String>) onConfirm) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: CalibrationPage(
          projectId: id,
          audioPath: '/nonexistent.mp3',
          onConfirm: (m) async => onConfirm(m),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('按台词量降序、低置信度高亮、代表台词与句数', (tester) async {
    final id = await seed();
    await pumpPage(tester, id, (_) {});

    // 余则成（1 句长台词）在前，未知·声音1（1 句"好"）在后 —— 同为 1 句按插入序
    expect(find.textContaining('余则成（0.90）'), findsOneWidget);
    expect(find.textContaining('未知·声音1（0.30）'), findsOneWidget);
    expect(find.textContaining('待确认'), findsOneWidget, reason: '低置信度标记');
    expect(find.text('站长，这件事恐怕没那么简单，得从长计议'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsNWidgets(2));
    expect(find.text('全部采纳建议'), findsOneWidget);
  });

  testWidgets('改名提交回调携带修正名', (tester) async {
    final id = await seed();
    Map<int, String>? submitted;
    await pumpPage(tester, id, (m) => submitted = m);

    // 第二簇（未知·声音1）改名
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '李涯');
    await tester.tap(find.text('确认，继续生成'));
    await tester.pump();

    expect(submitted, isNotNull);
    expect(submitted!.values.toSet(), {'余则成', '李涯'});
  });
}
