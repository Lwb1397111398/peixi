import 'dart:io';

/// 崩溃/未捕获异常的本地文件日志（个人应用不上报云端）。
/// app_support/crash.log 追加写入，超过 512KB 时截掉前一半。
/// 在 main() 尽早 init；任何写入失败静默忽略（日志自身不能引发崩溃）。
class CrashLog {
  CrashLog._();

  static File? _file;
  static const _maxBytes = 512 * 1024;

  static Future<void> init(Directory supportDir) async {
    try {
      final f = File('${supportDir.path}/crash.log');
      if (await f.exists() && await f.length() > _maxBytes) {
        final bytes = await f.readAsBytes();
        final text = String.fromCharCodes(bytes);
        await f.writeAsString(text.substring(text.length ~/ 2), flush: true);
      }
      _file = f;
    } catch (_) {
      _file = null;
    }
  }

  static String get path => _file?.path ?? '';

  static void write(String scope, Object error, StackTrace? stack) {
    final f = _file;
    if (f == null) return;
    try {
      final ts = DateTime.now().toIso8601String();
      final buf = StringBuffer()
        ..writeln('[$ts][$scope] $error')
        ..writeln(stack ?? StackTrace.current);
      f.writeAsStringSync(buf.toString(), mode: FileMode.append);
    } catch (_) {}
  }
}
