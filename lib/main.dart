import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:peixi/app.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/settings_repository.dart';
import 'package:peixi/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // 播放器与校准试听共用
  final dir = await getApplicationSupportDirectory();
  final db = AppDatabase(NativeDatabase.createInBackground(
      File(p.join(dir.path, 'peixi.sqlite'))));
  final repo = SettingsRepository(db, FlutterSecureStorage());
  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      settingsRepoProvider.overrideWithValue(repo),
    ],
    child: const PeixiApp(),
  ));
}
