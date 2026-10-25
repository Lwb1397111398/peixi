import 'package:peixi/core/settings/app_prefs.dart';

/// 播放器用的轻量场景视图（含该场景的 L4 问题）。
class QuizScene {
  const QuizScene({
    required this.sceneId,
    required this.idx,
    required this.startMs,
    required this.endMs,
    required this.importance,
    required this.hasQuestion,
  });
  final int sceneId;
  final int idx;
  final int startMs;
  final int endMs;
  final String importance;
  final bool hasQuestion;

  bool get quizCandidate => importance == 'high' && hasQuestion;
}

/// 二分查找：pos 所在场景下标（scenes 按 startMs 升序）。
/// 场景间的静默期归前景（解说卡在新场景开始时才切换）；
/// pos 早于首场景返回 0，晚于末场景返回 length-1，空表返回 -1。
int sceneAt(List<QuizScene> scenes, int posMs) {
  if (scenes.isEmpty) return -1;
  var lo = 0, hi = scenes.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (scenes[mid].startMs <= posMs) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo;
}

class QuizTrigger {
  const QuizTrigger({required this.scene, required this.atMs});
  final QuizScene scene;
  final int atMs;
}

/// L4 弹幕提问触发引擎（设计稿 8.2）：
/// 进入 high 场景的 triggerRatio 处触发；频率限制：每集最多 maxPerEpisode、
/// 两次间隔 ≥ minGapMinutes（按播放位置差，非墙钟）；已触发的场景不再触发。
class QuizEngine {
  QuizEngine({
    required this.prefs,
    required this.scenes,
  });

  final PlayPrefs prefs;
  final List<QuizScene> scenes;
  final Set<int> _fired = {};
  int? _lastPosMs;

  int get askedCount => _fired.length;
  int? lastAskPosMs;

  /// 单次位置事件的自然步长上限；超过即视为 seek（键盘快进等不经 onSeek 的路径）。
  static const _maxNaturalStepMs = 3000;

  double _triggerAtMs(QuizScene sc) =>
      sc.startMs + (sc.endMs - sc.startMs) * prefs.triggerRatio;

  /// 用户拖动/跳转（onSeek 通知）：落点若已越过所在场景的触发点，
  /// 本题按已触发处理（跳过即视为放弃）。逐帧拖动会产生多次小步 seek，
  /// 步长启发式覆盖不到，必须由 UI 显式通知。
  void notifySeek(int toMs) {
    final i = sceneAt(scenes, toMs);
    if (i >= 0) {
      final sc = scenes[i];
      if (sc.quizCandidate &&
          !_fired.contains(sc.sceneId) &&
          toMs >= _triggerAtMs(sc)) {
        _fired.add(sc.sceneId);
      }
    }
    _lastPosMs = toMs;
  }

  /// 播放位置推进时调用；返回应触发的提问（无则 null）。
  QuizTrigger? shouldTrigger(int posMs) {
    if (!prefs.quizEnabled) return null;
    if (_fired.length >= prefs.maxPerEpisode) return null;
    final i = sceneAt(scenes, posMs);
    if (i < 0) return null;
    final sc = scenes[i];
    final last = _lastPosMs;
    _lastPosMs = posMs;
    if (last != null && (posMs < last - 1500 || posMs - last > _maxNaturalStepMs)) {
      // 落点越过触发点的 seek：放弃该题，也不在落点立即弹题
      if (sc.quizCandidate &&
          !_fired.contains(sc.sceneId) &&
          posMs >= _triggerAtMs(sc)) {
        _fired.add(sc.sceneId);
      }
      return null;
    }
    if (!sc.quizCandidate || _fired.contains(sc.sceneId)) return null;

    final at = _triggerAtMs(sc);
    if (posMs < at) return null;
    if (lastAskPosMs != null &&
        posMs - lastAskPosMs! < prefs.minGapMinutes * 60000) {
      return null;
    }
    _fired.add(sc.sceneId);
    lastAskPosMs = posMs;
    return QuizTrigger(scene: sc, atMs: at.toInt());
  }

  /// 跳过/作答后由 UI 记账（qa_records 写库由页面负责）。
  void markAnswered(QuizScene scene, {bool skipped = false}) {
    _fired.add(scene.sceneId);
    lastAskPosMs ??= scene.startMs;
  }

  /// 场景含 L4 问题的进度条标记点（播放器橙色圆点）。
  List<({int posMs, int sceneIdx})> markerPoints() => [
        for (final s in scenes.where((s) => s.hasQuestion))
          (posMs: s.startMs, sceneIdx: s.idx),
      ];

  /// 场景边界刻度（进度条细刻度）。
  List<int> boundaryPoints() => [for (final s in scenes) s.startMs];
}
