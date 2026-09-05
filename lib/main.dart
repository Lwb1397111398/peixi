import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:peixi/app.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/logging/crash_log.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/core/window/window_bounds.dart';
import 'package:peixi/providers.dart';

Future<void> main() async {
  // 全局错误边界：UI/平台/未捕获三类异常都落 crash.log（release 包此前不可观测）
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized(); // 播放器与校准试听共用
    final dir = await getApplicationSupportDirectory();
    await CrashLog.init(dir);
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      CrashLog.write('FLUTTER', details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (e, st) {
      CrashLog.write('PLATFORM', e, st);
      return true; // 已记录，不再让进程直接终止
    };
    final db = AppDatabase(NativeDatabase.createInBackground(
        File(p.join(dir.path, 'peixi.sqlite'))));
    final repo = SettingsRepository(db, FlutterSecureStorage());
    // 启动清理：90 天前的 LLM 调用日志与响应缓存只占空间不再有用
    await LlmService(db: db).pruneOldEntries();
    // 桌面端窗口尺寸/位置记忆（失败不阻塞启动）
    if (WindowBoundsStore.supported) {
      try {
        await WindowBoundsStore(repo).init();
      } catch (e, st) {
        CrashLog.write('window-init', e, st);
      }
    }
    runApp(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsRepoProvider.overrideWithValue(repo),
      ],
      child: const PeixiApp(),
    ));
  }, (e, st) => CrashLog.write('UNCAUGHT', e, st));
}
