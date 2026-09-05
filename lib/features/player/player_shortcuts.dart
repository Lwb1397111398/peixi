import 'package:flutter/services.dart';

/// 播放器键盘动作。
enum PlayerKeyAction { none, toggle, seekBack, seekForward, volumeUp, volumeDown }

/// 键盘路由：编辑框聚焦（答题框输入空格/方向键）时全部让位。
PlayerKeyAction resolvePlayerKey(LogicalKeyboardKey key,
    {required bool editing}) {
  if (editing) return PlayerKeyAction.none;
  return switch (key) {
    LogicalKeyboardKey.space ||
    LogicalKeyboardKey.mediaPlayPause ||
    LogicalKeyboardKey.mediaPlay ||
    LogicalKeyboardKey.mediaPause =>
      PlayerKeyAction.toggle,
    LogicalKeyboardKey.arrowLeft ||
    LogicalKeyboardKey.mediaRewind =>
      PlayerKeyAction.seekBack,
    LogicalKeyboardKey.arrowRight ||
    LogicalKeyboardKey.mediaFastForward =>
      PlayerKeyAction.seekForward,
    LogicalKeyboardKey.arrowUp => PlayerKeyAction.volumeUp,
    LogicalKeyboardKey.arrowDown => PlayerKeyAction.volumeDown,
    _ => PlayerKeyAction.none,
  };
}

/// seek 落点夹取：不小于 0，不超过 maxMs（maxMs <= 0 视为未知时长，只保下限）。
int clampSeekMs(int fromMs, int deltaMs, {int maxMs = -1}) {
  final v = fromMs + deltaMs;
  if (v < 0) return 0;
  if (maxMs > 0 && v > maxMs) return maxMs;
  return v;
}
