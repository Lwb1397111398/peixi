import 'package:drift/drift.dart' show Value;
import 'package:peixi/core/database/app_database.dart';

/// 场景切分结果（idx 连续；firstSeg/lastSeg 指向 segments.idx 区间）。
class SceneSlice {
  const SceneSlice({
    required this.startMs,
    required this.endMs,
    required this.firstSegIdx,
    required this.lastSegIdx,
  });
  final int startMs;
  final int endMs;
  final int firstSegIdx;
  final int lastSegIdx;
}

/// S8 场景切分（设计稿规则）：
/// ① 相邻对白间隔 > 3s 切开；② 单场景 > 120s 在 120s 边界硬切
/// （①之后内部间隔均 ≤3s，无"最大间隔"可选）；③ 不足 15s 并入前景
/// （无前景并入后景）。
List<SceneSlice> segmentScenes(List<({int startMs, int endMs})> segs) {
  if (segs.isEmpty) return const [];
  const gapSplit = 3000;
  const maxScene = 120000;
  const minScene = 15000;

  // ① 间隔切分
  var groups = <List<int>>[
    [0]
  ];
  for (var i = 1; i < segs.length; i++) {
    if (segs[i].startMs - segs[i - 1].endMs > gapSplit) {
      groups.add([i]);
    } else {
      groups.last.add(i);
    }
  }

  // ② 超长强切
  final split = <List<int>>[];
  for (final g in groups) {
    split.addAll(_splitLong(g, segs, maxScene));
  }
  groups = split;

  // ③ 短景合并（迭代到稳定：合并后仍可能产生新短景边界情况）
  var merged = _mergeShort(groups, segs, minScene);
  while (merged.length != groups.length) {
    groups = merged;
    merged = _mergeShort(groups, segs, minScene);
  }

  return [
    for (var i = 0; i < merged.length; i++)
      SceneSlice(
        startMs: segs[merged[i].first].startMs,
        endMs: segs[merged[i].last].endMs,
        firstSegIdx: merged[i].first,
        lastSegIdx: merged[i].last,
      ),
  ];
}

List<List<int>> _splitLong(
    List<int> g, List<({int startMs, int endMs})> segs, int maxScene) {
  final dur = segs[g.last].endMs - segs[g.first].startMs;
  if (dur <= maxScene || g.length == 1) return [g];
  // 硬切：组起点 +120s 后的第一个完整句子处
  final deadline = segs[g.first].startMs + maxScene;
  var cut = 1;
  while (cut < g.length - 1 && segs[g[cut]].endMs < deadline) {
    cut++;
  }
  return [
    ..._splitLong(g.sublist(0, cut), segs, maxScene),
    ..._splitLong(g.sublist(cut), segs, maxScene),
  ];
}

List<List<int>> _mergeShort(
    List<List<int>> groups, List<({int startMs, int endMs})> segs, int minScene) {
  if (groups.length <= 1) return groups;
  final out = <List<int>>[groups.first];
  for (var i = 1; i < groups.length; i++) {
    final cur = groups[i];
    final curDur = segs[cur.last].endMs - segs[cur.first].startMs;
    final prev = out.last;
    final prevDur = segs[prev.last].endMs - segs[prev.first].startMs;
    if (curDur < minScene || prevDur < minScene) {
      // 短景（当前或前一景）→ 并入对方
      out[out.length - 1] = [...prev, ...cur];
    } else {
      out.add(cur);
    }
  }
  // 末景孤立短景：并回前一景
  if (out.length > 1) {
    final last = out.last;
    final lastDur = segs[last.last].endMs - segs[last.first].startMs;
    if (lastDur < minScene) {
      final prev = out[out.length - 2];
      out.removeLast();
      out[out.length - 1] = [...prev, ...last];
    }
  }
  return out;
}

/// S8 落库：segments → scenes（幂等：先清旧 scenes，级联清 commentaries/questions 引用）。
class SceneWriter {
  SceneWriter(this.db);
  final AppDatabase db;

  Future<void> writeScenes(int projectId) async {
    final segs = await (db.select(db.segments)
          ..where((t) => t.projectId.equals(projectId)))
        .get()
      ..sort((a, b) => a.idx.compareTo(b.idx));
    final slices = segmentScenes(
        [for (final s in segs) (startMs: s.startMs, endMs: s.endMs)]);

    // 先清旧（commentaries 随 scenes 级联删除；questions 显式清理）
    await (db.delete(db.questions)
          ..where((t) => t.projectId.equals(projectId)))
        .go();
    await (db.delete(db.scenes)..where((t) => t.projectId.equals(projectId)))
        .go();
    final batch = <Future<int>>[];
    for (var i = 0; i < slices.length; i++) {
      final sc = slices[i];
      batch.add(db.into(db.scenes).insert(ScenesCompanion.insert(
          projectId: projectId,
          idx: i,
          startMs: sc.startMs,
          endMs: sc.endMs)));
    }
    await Future.wait(batch);
    if (slices.isEmpty) {
      throw Exception('没有对白可切分场景');
    }
  }
}
