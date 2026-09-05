import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect, Size;

import 'package:window_manager/window_manager.dart';
import 'package:peixi/core/logging/crash_log.dart';
import 'package:peixi/core/settings/settings_repository.dart';

/// 桌面窗口尺寸/位置记忆：启动恢复、关闭与移动/缩放（防抖）落库。
/// 仅桌面端使用；Android/iOS 不调用 init()。
class WindowBoundsStore with WindowListener {
  WindowBoundsStore(this._repo);
  final SettingsRepository _repo;

  Timer? _debounce;
  bool _saving = false;

  /// 首次启动用默认 1280×720 居中；否则恢复上次边界。
  /// windows/runner/main.cpp 里的初始 1280×720(10,10) 只是闪屏前的占位，
  /// 真实边界以这里的恢复为准。
  Future<void> init() async {
    await windowManager.ensureInitialized();
    final saved = await _repo.loadWindowBounds();
    final options = WindowOptions(
      size: Size(saved?.width ?? 1280, saved?.height ?? 720),
      minimumSize: const Size(900, 560),
      center: saved == null,
      title: '陪析',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (saved != null) {
        await windowManager.setBounds(
            Rect.fromLTWH(saved.left, saved.top, saved.width, saved.height));
      }
      await windowManager.show();
      await windowManager.setPreventClose(true);
      windowManager.addListener(this);
    });
  }

  Future<void> saveNow() async {
    if (_saving) return;
    _saving = true;
    try {
      final b = await windowManager.getBounds();
      await _repo.saveWindowBounds(
          b.left, b.top, b.width, b.height);
    } catch (e, st) {
      CrashLog.write('window-save', e, st);
    } finally {
      _saving = false;
    }
  }

  void _saveDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      unawaited(saveNow());
    });
  }

  @override
  void onWindowMove() => _saveDebounced();

  @override
  void onWindowResize() => _saveDebounced();

  @override
  void onWindowClose() async {
    _debounce?.cancel();
    await saveNow();
    await windowManager.destroy();
  }

  /// Android/iOS/无窗口环境下不可调用 window_manager。
  static bool get supported =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}
