import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/window/titlebar_brightness.dart';
import 'package:peixi/providers.dart';

/// 主题模式控制器：main() 启动时从设置库读出初值并 override 注入
///（避免启动闪变），设置页切换即写库。
class ThemeModeController extends Notifier<ThemeMode> {
  ThemeModeController([this._initial = ThemeMode.light]);
  final ThemeMode _initial;

  @override
  ThemeMode build() {
    Future.microtask(() => TitleBarBrightness.setDark(_isDark(state)));
    return _initial;
  }

  void set(ThemeMode mode) {
    if (mode == state) return;
    state = mode;
    TitleBarBrightness.setDark(_isDark(mode));
    final repo = ref.read(settingsRepoProvider);
    Future(() => repo.saveThemeModeRaw(mode.name));
  }

  bool _isDark(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          WidgetsBinding
              .instance.platformDispatcher.platformBrightness ==
              Brightness.dark,
      };
}

/// main() 里 overrideWith(() => ThemeModeController(初值)) 注入；
/// 测试等未覆写场景默认浅色。
final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// 设置库存的是字符串（'system' | 'light' | 'dark'），core 层不依赖 material
ThemeMode themeModeFromName(String raw) => ThemeMode.values
    .firstWhere((m) => m.name == raw, orElse: () => ThemeMode.light);
