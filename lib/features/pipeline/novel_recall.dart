// ignore_for_file: prefer_initializing_formals
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';

/// 语义回忆提供者（批注趟可选上下文层；null = 整层跳过，零影响）。
abstract class NovelRecallProvider {
  /// 为摘要就绪但无向量的章补建索引（幂等；失败静默）。
  Future<void> ensureIndexed(int projectId);

  /// [相关前文回忆] 文本：cos top3 前文章摘要；无命中/失败 → 空串。
  Future<String> recallContext(int projectId,
      {required int beforeChapterIdx, required String query});
}

/// 默认实现（设计文档 §3 回忆索引层 / §10 向量召回）：章摘要向量入
/// chapter_embeddings，cos 相似度 Dart 侧计算（1200 章规模无需 sqlite 扩展）。
/// embedding 槽位未绑定或调用失败 → 整层静默降级，绝不阻塞批注主线。
class NovelRecallService implements NovelRecallProvider {
  NovelRecallService({
    required AppDatabase db,
    required LlmService llm,
    this.topK = 3,
    this.minScore = 0.35,
  })  : _db = db,
        _llm = llm;

  /// 单次 embed 请求的章数上限：老书中途开启回忆（如 1200 章）不再单请求
  /// 携全部缺向量章（易超中转站批量上限，失败即零进展且每 mapLane 步全量重试）。
  static const _embedBatch = 64;

  final AppDatabase _db;
  final LlmService _llm;
  final int topK;
  final double minScore;

  /// 章向量内存缓存（chapterId → 向量；chapterId 全局唯一，实例每 run 新建
  /// 天然隔离）。ensureIndexed 落库与 recallContext 缓存未命中解码时同步
  /// 填充：同一实例内重复召回免重复 jsonDecode（annotate ~400 批热路径）。
  final _vectorCache = <int, List<double>>{};

  @override
  Future<void> ensureIndexed(int projectId) async {
    try {
      // 已索引集合单列查询：整表拉回 vectorJson 只为取 chapterId 会把历史
      // 向量全量读进内存（1200 章书每步 ensureIndexed 数百 MB 级重复读）
      final ce = _db.chapterEmbeddings;
      final indexRows = await (_db.selectOnly(ce)
            ..where(ce.projectId.equals(projectId))
            ..addColumns([ce.chapterId]))
          .get();
      final indexed = {for (final r in indexRows) r.read(ce.chapterId)!};
      final chapters = await (_db.select(_db.chapters)
            ..where((t) => t.projectId.equals(projectId) &
                t.mapDone.equals(true))
            ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
          .get();
      final pending = [
        for (final ch in chapters)
          if (!indexed.contains(ch.id) && (ch.summary ?? '').isNotEmpty) ch,
      ];
      if (pending.isEmpty) return;
      // 按 64 条分批 embed，每批包事务落库：中途失败已落库批保留（幂等，
      // 下次续建只补剩余），不再"单请求全部章 → 失败零进展"。
      // 章序即向量序（embed 已按响应 index 对齐输入序，查询亦按 idx 排序）
      for (var off = 0; off < pending.length; off += _embedBatch) {
        final chunk =
            pending.sublist(off, math.min(off + _embedBatch, pending.length));
        final vectors = await _llm.embed([for (final ch in chunk) ch.summary!],
            purpose: 'novel_recall', projectId: projectId);
        await _db.transaction(() async {
          for (var i = 0; i < chunk.length && i < vectors.length; i++) {
            // insertOnConflictUpdate：幂等防唯一键(chapterId)冲突重试炸掉整批
            await _db.into(_db.chapterEmbeddings).insertOnConflictUpdate(
                ChapterEmbeddingsCompanion.insert(
                    projectId: projectId,
                    chapterId: chunk[i].id,
                    dim: vectors[i].length,
                    vectorJson: jsonEncode(vectors[i])));
            _vectorCache[chunk[i].id] = vectors[i];
          }
        });
      }
    } catch (_) {
      // 可选层任何异常（含非 LLM 异常）不得击穿批注主线：静默返回 = 索引
      // 下次补建。预算异常在此吞掉不遮蔽主线失败——主线 chatJson 会在
      // 自己的预算闸门处把 LlmBudgetException 透传为阶段 FAILED
      // （§8 用户可读失败，对照 c595d3f 先例）。
      return;
    }
  }

  @override
  Future<String> recallContext(int projectId,
      {required int beforeChapterIdx, required String query}) async {
    try {
      // 空查询（老项目回填批首章 digest 为 null）直接空串：不烧一次查询向量
      if (query.trim().isEmpty) return '';
      final ce = _db.chapterEmbeddings;
      final ch = _db.chapters;
      // SQL 侧 inner join chapters 并过滤未来章：只把前文候选行（含
      // vectorJson）读进内存解码，不再全书 embedding 全量拉回后 Dart 丢弃
      final candidates = await (_db.select(ce).join([
            innerJoin(ch, ch.id.equalsExp(ce.chapterId)),
          ])
            ..where(ce.projectId.equals(projectId) &
                ch.idx.isSmallerThanValue(beforeChapterIdx)))
          .get();
      if (candidates.isEmpty) return ''; // 无前文候选：不浪费查询向量调用
      final qv = (await _llm.embed([query],
              purpose: 'novel_recall', projectId: projectId))
          .first;
      final scored = <(double, Chapter)>[];
      for (final row in candidates) {
        final ceRow = row.readTable(ce);
        var vec = _vectorCache[ceRow.chapterId];
        if (vec == null) {
          vec = decodeVector(ceRow.vectorJson);
          _vectorCache[ceRow.chapterId] = vec;
        }
        scored.add((cosineSimilarity(qv, vec), row.readTable(ch)));
      }
      scored.sort((a, b) => b.$1.compareTo(a.$1));
      final hits = [
        for (final (score, ch) in scored)
          if (score >= minScore) ch,
      ].take(topK).toList();
      if (hits.isEmpty) return '';
      return [
        for (final ch in hits) '- 第${ch.idx}章摘要：${ch.summary}',
      ].join('\n');
    } catch (_) {
      // 可选层任何异常（含非 LLM 异常，如坏向量行解码失败）静默返回空串。
      // 预算异常在此吞掉不遮蔽主线失败——静默空串后主线 chatJson 仍会把
      // LlmBudgetException 透传为阶段 FAILED（对照 c595d3f 先例）。
      return '';
    }
  }

  /// vectorJson → 向量（缓存未命中时的解码点；测试覆写计数验证缓存命中）。
  List<double> decodeVector(String vectorJson) => [
        for (final v in (jsonDecode(vectorJson) as List)) (v as num).toDouble(),
      ];
}

/// 余弦相似度：零向量/维度不等 → 0（防御，不抛）。
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty || a.length != b.length) return 0;
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na == 0 || nb == 0) return 0;
  return dot / (math.sqrt(na) * math.sqrt(nb));
}
