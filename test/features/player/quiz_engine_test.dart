import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/settings/api_config.dart';
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
    final t = e.shouldTrigger(31000);
    expect(t, isNotNull);
    expect(t!.scene.sceneId, 0);
    expect(e.shouldTrigger(40000), isNull, reason: '同场景不重复触发');
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
    // 20s 后 = 40000ms，与上次 20000 相差 20000ms < 4 分钟 → 不触发
    expect(e.shouldTrigger(80000), isNull);
    // 5 分钟后（320000ms 位置）恢复可触发
    final e2 = QuizEngine(prefs: prefs(gap: 4), scenes: [
      sc(0, 0, 60000, high: true),
      sc(1, 300000, 400000, high: true),
    ]);
    expect(e2.shouldTrigger(20000), isNotNull);
    expect(e2.shouldTrigger(330000), isNotNull, reason: '间隔 310s ≥ 4min');
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
}
