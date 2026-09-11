import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Windows 深浅色标题栏（DWMWA_USE_IMMERSIVE_DARK_MODE = 20）。
/// 跟随应用主题切换；非 Windows 或任何失败均静默跳过（锦上添花项）。
abstract final class TitleBarBrightness {
  static const _dwmaUseImmersiveDarkMode = 20;

  static void setDark(bool dark) {
    if (!Platform.isWindows) return;
    Pointer<Uint16>? title;
    Pointer<Int32>? value;
    try {
      final dwm = DynamicLibrary.open('dwmapi.dll');
      final setAttribute = dwm.lookupFunction<
          Int32 Function(Pointer<Void>, Int32, Pointer<Int32>, Int32),
          int Function(
              Pointer<Void>, int, Pointer<Int32>, int)>('DwmSetWindowAttribute');
      final user32 = DynamicLibrary.open('user32.dll');
      final findWindowW = user32.lookupFunction<
          Pointer<Void> Function(Pointer<Uint16>, Pointer<Uint16>),
          Pointer<Void> Function(
              Pointer<Uint16>, Pointer<Uint16>)>('FindWindowW');
      final units = '陪析'.codeUnits;
      title = calloc<Uint16>(units.length + 1);
      for (var i = 0; i < units.length; i++) {
        title[i] = units[i];
      }
      title[units.length] = 0;
      final hwnd = findWindowW(nullptr, title);
      if (hwnd == nullptr) return;
      value = calloc<Int32>()..value = dark ? 1 : 0;
      // 20 为 Win10 20H1+ 的正式属性号，旧版本退回 19；都失败则静默放弃
      if (setAttribute(hwnd, _dwmaUseImmersiveDarkMode, value, 4) != 0) {
        setAttribute(hwnd, 19, value, 4);
      }
    } catch (_) {
      // 忽略：标题栏颜色不影响功能
    } finally {
      if (title != null) calloc.free(title);
      if (value != null) calloc.free(value);
    }
  }
}
