import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/settings/app_prefs.dart';
import 'package:peixi/features/player/quiz_engine.dart';

QuizScene sc(int id, int start, int end, {bool high = false, bool q = true}) =>
    QuizScene(
        sceneId: id,
        idx: id,
        startMs: start,
        endMs: end,
        importance: high ? 'high' : 'normal',
        hasQuestion: q);

PlayPrefs prefs({
  bool enabled = true,
  int max = 5,
  int gap = 4,
  double ratio = 0.3,
}) =>
    PlayPrefs(
        quizEnabled: enabled, maxPerEpisode: max, minGapMinutes: gap, triggerRatio: ratio);

/// 模拟自然播放推进：以 2s 步长喂位置（远小于 seek 判定阈值 3s）。
/// 返回首次触发的提问（无则 null）。
QuizTrigger? playTo(QuizEngine e, int from, int to) {
  QuizTrigger? t;
  for (var pos = from; pos <= to; pos += 2000) {
    t = e.shouldTrigger(pos);
    if (t != null) return t;
  }
  return t;
}

void main() {
  test('sceneAt 二分定位', () {
    final scenes = [sc(0, 0, 60000), sc(1, 60000, 120000), sc(2, 180000, 240000)];
    expect(sceneAt(scenes, 500), 0);
    expect(sceneAt(scenes, 65000), 1);
    expect(sceneAt(scenes, 150000), 1, reason: '间隙期归前景');
    expect(sceneAt(scenes, 200000), 2);
    expect(sceneAt(scenes, 999999), 2, reason: '晚于末景归末景');
    expect(sceneAt([], 0), -1);
  });

  test('30% 触发点前不触发、过后触发一次', () {
    final e = QuizEngine(prefs: prefs(), scenes: [sc(0, 0, 100000, high: true)]);
    expect(e.shouldTrigger(10000), isNull, reason: '10% 未到 30%');
    final t = playTo(e, 12000, 40000);
    expect(t, isNotNull);
    expect(t!.scene.sceneId, 0);
    expect(playTo(e, 42000, 60000), isNull, reason: '同场景不重复触发');
  });

  test('非 high 或无问题的场景不触发', () {
    expect(
        QuizEngine(prefs: prefs(), scenes: [sc(0, 0, 100000)])
            .shouldTrigger(90000),
        isNull,
        reason: 'normal 重要性不触发');
    expect(
        QuizEngine(prefs: prefs(), scenes: [sc(0, 0, 100000, high: true, q: false)])
            .shouldTrigger(90000),
        isNull,
        reason: '无 L4 问题不触发');
  });

  test('每集上限', () {
    final scenes = [
      sc(0, 0, 60000, high: true),
      sc(1, 60000, 120000, high: true),
    ];
    final e = QuizEngine(prefs: prefs(max: 1, gap: 0), scenes: scenes);
    expect(e.shouldTrigger(20000), isNotNull);
    expect(e.shouldTrigger(80000), isNull, reason: '已达每集 1 次上限');
  });

  test('最小间隔（按播放位置差）', () {
    final scenes = [
      sc(0, 0, 60000, high: true),
      sc(1, 60000, 120000, high: true),
    ];
    final e = QuizEngine(prefs: prefs(gap: 4), scenes: scenes);
    expect(e.shouldTrigger(20000), isNotNull);
    // 自然播放推进到 80s：与上次相差 60s < 4 分钟 → 不触发
    expect(playTo(e, 22000, 80000), isNull);
    // 5 分钟后（330s 位置）恢复可触发
    final e2 = QuizEngine(prefs: prefs(gap: 4), scenes: [
      sc(0, 0, 60000, high: true),
      sc(1, 300000, 400000, high: true),
    ]);
    expect(e2.shouldTrigger(20000), isNotNull);
    final t2 = playTo(e2, 22000, 330000);
    expect(t2, isNotNull, reason: '间隔 310s ≥ 4min');
    expect(t2!.scene.sceneId, 1);
  });

  test('总开关关闭', () {
    final e = QuizEngine(
        prefs: prefs(enabled: false), scenes: [sc(0, 0, 100000, high: true)]);
    expect(e.shouldTrigger(50000), isNull);
  });

  test('进度条标记点', () {
    final scenes = [
      sc(0, 0, 60000, high: true),
      sc(1, 60000, 120000, q: false),
    ];
    final e = QuizEngine(prefs: prefs(), scenes: scenes);
    expect(e.markerPoints().length, 1, reason: '只有含问题场景有橙点');
    expect(e.boundaryPoints().length, 2);
  });

  test('大步长跳变越过触发点：不弹题且按已触发处理', () {
    final e = QuizEngine(prefs: prefs(), scenes: [sc(0, 0, 100000, high: true)]);
    expect(e.shouldTrigger(10000), isNull, reason: '自然播放预热');
    expect(e.shouldTrigger(60000), isNull, reason: '50s 跳变视为 seek，落点不弹');
    expect(e.shouldTrigger(61000), isNull, reason: '落点已过触发点，本题视为放弃');
  });

  test('notifySeek 落点越过触发点 → 放弃本题', () {
    final e = QuizEngine(prefs: prefs(), scenes: [sc(0, 0, 100000, high: true)]);
    e.notifySeek(90000);
    expect(e.shouldTrigger(90200), isNull, reason: '拖过 30% 后继续播放不再弹');
  });

  test('notifySeek 落点在触发点之前：自然播放到点仍弹题', () {
    final e = QuizEngine(prefs: prefs(), scenes: [sc(0, 0, 100000, high: true)]);
    e.notifySeek(10000);
    expect(e.shouldTrigger(10400), isNull, reason: 'seek 后第一步是自然步长');
    expect(playTo(e, 10400, 40000), isNotNull);
  });

  test('回退 seek（重看）不重复弹已答场景', () {
    final e = QuizEngine(prefs: prefs(), scenes: [sc(0, 0, 100000, high: true)]);
    expect(e.shouldTrigger(31000), isNotNull);
    e.notifySeek(5000);
    expect(playTo(e, 5200, 31500), isNull, reason: '同场景已触发过');
  });
}
