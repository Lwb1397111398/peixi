import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/app_prefs.dart';
import 'package:peixi/core/settings/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  late AppDatabase db;
  late SettingsRepository repo;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepository(db, FlutterSecureStorage());
  });
  tearDown(() async => db.close());

  test('播放偏好持久化', () async {
    final prefs = await repo.loadPlayPrefs();
    expect(prefs.quizEnabled, isTrue); // 设计稿 8.2 默认开启
    expect(prefs.maxPerEpisode, 5);
    expect(prefs.minGapMinutes, 4);
    expect(prefs.triggerRatio, 0.3);
    await repo.savePlayPrefs(prefs.copyWith(maxPerEpisode: 8, quizEnabled: false));
    final saved = await repo.loadPlayPrefs();
    expect(saved.quizEnabled, isFalse);
    expect(saved.maxPerEpisode, 8);
  });

  test('阅读偏好持久化往返', () async {
    final p = await repo.loadReaderPrefs();
    expect(p.fontSize, 17);
    expect(p.lineHeight, 1.7);
    expect(p.theme, ReaderTheme.paper);
    await repo.saveReaderPrefs(const ReaderPrefs(
        fontSize: 20, lineHeight: 2.0, theme: ReaderTheme.night));
    final r = await repo.loadReaderPrefs();
    expect(r.fontSize, 20);
    expect(r.lineHeight, 2.0);
    expect(r.theme, ReaderTheme.night);
  });
}
