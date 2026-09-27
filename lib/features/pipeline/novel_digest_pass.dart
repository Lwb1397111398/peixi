// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/llm/prompts.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';

/// 快照趟（设计文档 §3/§7.2，summary 槽位）：每批 10 章一次合成调用；
/// 批内每章 digest_before = 批前滚动摘要（运行摘要持久化在 meta.digest，与
/// 快照同事务落库；崩溃续跑一致）。章内细粒度由批注趟的[前文摘要]（前一两章
/// 章摘要）补足。合成失败 → 拼接截断兜底，不阻塞批注主线。
class NovelDigestPass {
  NovelDigestPass({
    required AppDatabase db,
    required LlmService llm,
    this.batchChapters = 10,
    this.onProgress,
    this.onDegraded,
    this.isCancelled,
  })  : _db = db,
        _llm = llm;

  final AppDatabase _db;
  final LlmService _llm;
  final int batchChapters;
  final void Function(int done, int total)? onProgress;
  final void Function(String detail)? onDegraded;
  final bool Function()? isCancelled;

  /// 推进一批；返回章数（0 = 上游地图未就绪或全书快照已完成）。
  /// 批 = 首个无快照章起连续 N 章，且在地图前沿截断（不吃进未映射章，
  /// 否则首屏冲刺阶段 digest 与 map 互等死锁）。
  Future<int> step(int projectId) async {
    if (isCancelled?.call() ?? false) throw const PipelineCancelled();
    final chapters = await (_db.select(_db.chapters)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
        .get();
    // 选批条件带 !annotDone：老项目回填态（0..k-1 章 annotDone=1 而 digest_before
    // 为 null，旧断点快照挂在第 k 章）不得从第 0 章重启快照链——否则「已含
    // 0..k 内容的 oldDigest」会与章摘要双计，且把含后文剧情的快照写进前段章
    // digest_before（reannotate 剧透）。新项目零影响：被批注章必有快照。
    final first =
        chapters.indexWhere((c) => c.digestBefore == null && !c.annotDone);
    if (first < 0) return 0;
    final limit = math.min(first + batchChapters, chapters.length);
    final batch = <Chapter>[];
    for (var i = first; i < limit; i++) {
      final ch = chapters[i];
      if (!ch.mapDone || (ch.summary?.isEmpty ?? true)) break;
      batch.add(ch);
    }
    if (batch.isEmpty) return 0; // 地图先行（调度器保证领先；防御性等待）

    final project = await (_db.select(_db.projects)
          ..where((t) => t.id.equals(projectId)))
        .getSingle();
    final meta = NovelMeta.fromJson(project.metaJson);
    final oldDigest =
        (meta.digest ?? '').isEmpty ? '（故事刚开始）' : meta.digest!;
    final newDigest = await _merge(projectId, oldDigest, batch);
    await _db.transaction(() async {
      for (final ch in batch) {
        await (_db.update(_db.chapters)..where((t) => t.id.equals(ch.id)))
            .write(ChaptersCompanion(digestBefore: Value(oldDigest)));
      }
      meta.digest = newDigest;
      await (_db.update(_db.projects)..where((t) => t.id.equals(projectId)))
          .write(ProjectsCompanion(metaJson: Value(meta.encode())));
    });
    // 进度按提交后的最新章状态计（与 map/annotate 趟的 onProgress 语义一致）
    final fresh = await (_db.select(_db.chapters)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    onProgress?.call(fresh.where((c) => c.digestBefore != null).length,
        fresh.length);
    return batch.length;
  }

  Future<String> _merge(
      int projectId, String oldDigest, List<Chapter> batch) async {
    try {
      final r = await _llm.chatJson([
        {
          'role': 'user',
          'content': Prompts.digestMerge(
              oldDigest: oldDigest,
              chapterSummaries: [
                for (final ch in batch) '第${ch.idx}章 ${ch.summary}',
              ]),
        }
      ], slot: LlmSlot.summary, purpose: 'novel_digest', projectId: projectId);
      final d = (r['digest'] ?? '').toString().trim();
      return d.isEmpty ? _fallback(oldDigest, batch) : d;
    } on LlmJsonException {
      return _degraded(oldDigest, batch);
    } on LlmBudgetException {
      // 预算用尽须原样落阶段失败（§8：用户可读懂的失败提示），
      // 不得被拼接兜底静默吞掉——否则全书 digest 用垃圾拼接落库且管线不报错
      rethrow;
    } on LlmException {
      return _degraded(oldDigest, batch);
    }
  }

  /// 合成失败兜底：旧摘要 + 各章摘要拼接，保留末尾 ≤400 字（§8，不阻塞批注主线）。
  String _degraded(String oldDigest, List<Chapter> batch) {
    onDegraded?.call('摘要合成失败，拼接兜底（第${batch.first.idx}章起）');
    return _fallback(oldDigest, batch);
  }

  String _fallback(String oldDigest, List<Chapter> batch) {
    final merged =
        '$oldDigest\n${batch.map((c) => c.summary).join('\n')}'.trim();
    if (merged.length <= 400) return merged;
    // 保留末尾 400 字；UTF-16 截断点落在代理对中间时回退 1 个码元（不劈 emoji）
    var start = merged.length - 400;
    final u = merged.codeUnitAt(start);
    if (u >= 0xDC00 && u <= 0xDFFF) start--;
    return merged.substring(start);
  }
}
