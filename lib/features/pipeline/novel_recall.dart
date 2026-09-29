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

  final AppDatabase _db;
  final LlmService _llm;
  final int topK;
  final double minScore;

  @override
  Future<void> ensureIndexed(int projectId) async {
    try {
      final done = await (_db.select(_db.chapterEmbeddings)
            ..where((t) => t.projectId.equals(projectId)))
          .get();
      final indexed = done.map((e) => e.chapterId).toSet();
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
      // 批量 embed：一次请求补齐全部缺向量的章（章序即向量序，查询已按 idx 排序）
      final vectors = await _llm.embed(
          [for (final ch in pending) ch.summary!],
          purpose: 'novel_recall', projectId: projectId);
      for (var i = 0; i < pending.length && i < vectors.length; i++) {
        await _db.into(_db.chapterEmbeddings).insert(
            ChapterEmbeddingsCompanion.insert(
                projectId: projectId,
                chapterId: pending[i].id,
                dim: vectors[i].length,
                vectorJson: jsonEncode(vectors[i])));
      }
    } on LlmException {
      return; // 整层静默降级（§8：索引下次补建）
    }
  }

  @override
  Future<String> recallContext(int projectId,
      {required int beforeChapterIdx, required String query}) async {
    try {
      final rows = await (_db.select(_db.chapterEmbeddings)
            ..where((t) => t.projectId.equals(projectId)))
          .get();
      if (rows.isEmpty) return ''; // 无索引：不浪费一次查询向量调用
      final qv = (await _llm.embed([query],
              purpose: 'novel_recall', projectId: projectId))
          .first;
      final chapterRows = await (_db.select(_db.chapters)
            ..where((t) => t.projectId.equals(projectId)))
          .get();
      final byId = {for (final c in chapterRows) c.id: c};
      final scored = <(double, Chapter)>[];
      for (final r in rows) {
        final ch = byId[r.chapterId];
        if (ch == null || ch.idx >= beforeChapterIdx) continue; // 只回忆前文
        final vec = [
          for (final v in (jsonDecode(r.vectorJson) as List))
            (v as num).toDouble(),
        ];
        scored.add((cosineSimilarity(qv, vec), ch));
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
    } on LlmException {
      return '';
    }
  }
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
