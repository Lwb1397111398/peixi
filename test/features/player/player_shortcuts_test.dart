import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/features/player/player_shortcuts.dart';

void main() {
  test('空格/媒体键 → 播放暂停切换', () {
    expect(resolvePlayerKey(LogicalKeyboardKey.space, editing: false),
        PlayerKeyAction.toggle);
    expect(resolvePlayerKey(LogicalKeyboardKey.mediaPlayPause, editing: false),
        PlayerKeyAction.toggle);
  });

  test('方向键：左右 seek、上下音量', () {
    expect(resolvePlayerKey(LogicalKeyboardKey.arrowLeft, editing: false),
        PlayerKeyAction.seekBack);
    expect(resolvePlayerKey(LogicalKeyboardKey.arrowRight, editing: false),
        PlayerKeyAction.seekForward);
    expect(resolvePlayerKey(LogicalKeyboardKey.arrowUp, editing: false),
        PlayerKeyAction.volumeUp);
    expect(resolvePlayerKey(LogicalKeyboardKey.arrowDown, editing: false),
        PlayerKeyAction.volumeDown);
  });

  test('编辑框聚焦时一切按键让位（答题框可正常输入空格）', () {
    for (final key in [
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowUp,
    ]) {
      expect(resolvePlayerKey(key, editing: true), PlayerKeyAction.none,
          reason: '$key 在编辑态应被忽略');
    }
  });

  test('其他键不消费', () {
    expect(resolvePlayerKey(LogicalKeyboardKey.keyA, editing: false),
        PlayerKeyAction.none);
  });

  test('seek 落点夹取', () {
    expect(clampSeekMs(5000, -10000), 0, reason: '不越出开头');
    expect(clampSeekMs(5000, 10000), 15000);
    expect(clampSeekMs(99000, 10000, maxMs: 100000), 100000, reason: '不越出结尾');
    expect(clampSeekMs(99000, 10000), 109000, reason: '时长未知时不设上限');
  });
}
