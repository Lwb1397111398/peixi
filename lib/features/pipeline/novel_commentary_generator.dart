// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/llm/prompts.dart';
import 'package:peixi/core/settings/api_config.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';

/// N3 批注生成（设计稿第五节 N3 + Prompt D）：
/// 按章内段落块（~2000 字）全局顺序调用，上下文 = 前情滚动摘要 + 本章已读
/// 概要 + 当前块全文；批注锚定段落全局 idx，类型 L1-L4 写 annotations 表。
/// 每块完成即与 meta.annotated_para 同事务落库（崩溃续跑）；防剧透：块 n
/// 的提示词只含块 ≤n 的信息。
class NovelCommentaryGenerator {
  NovelCommentaryGenerator({
    required AppDatabase db,
    required LlmService llm,
    this.blockChars = 2000,
    this.onProgress,
    this.isCancelled,
  })  : _db = db,
        _llm = llm;

  final AppDatabase _db;
  final LlmService _llm;
  final int blockChars;
  final void Function(int done, int total)? onProgress;

  /// 返回 true 时抛 [PipelineCancelled] 中断循环（已完成块已落库，可续跑）
  final bool Function()? isCancelled;

  /// 一块 = [startPara, endPara] 的段落行（含段落 id 与全局 idx）
  Future<void> generate(int projectId) async {
    final project = await (_db.select(_db.projects)
          ..where((t) => t.id.equals(projectId)))
        .getSingle();
    final meta = NovelMeta.fromJson(project.metaJson);

    final chapters = await (_db.select(_db.chapters)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
        .get();

    // 先算总块数（进度条用），块按 全书段落顺序 排列
    final chapterBlocks = <List<List<Paragraph>>>[];
    var totalBlocks = 0;
    for (final ch in chapters) {
      final paras = await (_db.select(_db.paragraphs)
            ..where((t) => t.chapterId.equals(ch.id))
            ..orderBy([(p) => OrderingTerm.asc(p.idx)]))
          .get();
      final blocks = _splitBlocks(paras);
      chapterBlocks.add(blocks);
      totalBlocks += blocks.length;
    }

    var done = 0;
    var recentSummaries = <String>[]; // 本章已读块概要（最近 2 块）
    for (final blocks in chapterBlocks) {
      for (final block in blocks) {
        if (isCancelled?.call() ?? false) throw const PipelineCancelled();
        final startPara = block.first.idx;
        final endPara = block.last.idx;
        if (endPara <= meta.annotatedPara) {
          done++; // 续跑：该块已完成
          onProgress?.call(done, totalBlocks);
          continue;
        }
        final blockSummary = await _generateOne(
            projectId, meta, block, startPara, endPara,
            recentContext: recentSummaries.isEmpty
                ? '（本章刚开始）'
                : recentSummaries.join('\n'));
        recentSummaries.add(blockSummary);
        if (recentSummaries.length > 2) recentSummaries.removeAt(0);
        done++;
        onProgress?.call(done, totalBlocks);
      }
      recentSummaries = []; // 换章清空"本章已读"
    }
  }

  List<List<Paragraph>> _splitBlocks(List<Paragraph> paras) {
    final blocks = <List<Paragraph>>[];
    var buf = <Paragraph>[];
    var bufChars = 0;
    for (final p in paras) {
      buf.add(p);
      bufChars += p.content.length;
      if (bufChars >= blockChars) {
        blocks.add(buf);
        buf = <Paragraph>[];
        bufChars = 0;
      }
    }
    if (buf.isNotEmpty) blocks.add(buf);
    return blocks;
  }

  Future<String> _generateOne(int projectId, NovelMeta meta,
      List<Paragraph> block, int startPara, int endPara,
      {required String recentContext}) async {
    final blockText = block.map((p) => '[${p.idx}] ${p.content}').join('\n');

    final result = await _llm.chatJson([
      {
        'role': 'user',
        'content': Prompts.novelAnnotation(
          digest: meta.digest ?? '（故事刚开始）',
          recentContext: recentContext,
          blockText: blockText,
          paraStart: startPara,
          paraEnd: endPara,
        ),
      }
    ], tier: LlmTier.standard, purpose: 'novel_annotate', projectId: projectId);

    final annotations =
        (result['annotations'] as List? ?? []).cast<Map>();
    final blockSummary = (result['block_summary'] ?? '').toString();

    await _db.transaction(() async {
      // 幂等重跑：先清本块旧批注（annotations 锚定 paraId）
      final paraIds = block.map((p) => p.id).toList();
      await (_db.delete(_db.annotations)
            ..where((t) => t.paraId.isIn(paraIds)))
          .go();

      for (final a in annotations) {
        final idx = (a['para_idx'] as num?)?.toInt();
        final type = (a['type'] ?? '').toString().trim();
        if (idx == null || idx < startPara || idx > endPara) continue;
        final para = block.firstWhere((p) => p.idx == idx,
            orElse: () => block.first);
        final content = a['content'];
        if (content == null) continue;
        final contentJson = _normalizeContent(type, content);
        if (contentJson == null) continue;
        await _db.into(_db.annotations).insert(AnnotationsCompanion.insert(
              paraId: para.id,
              type: type,
              contentJson: jsonEncode(contentJson),
            ));
        // L3 知识卡同时进卡片集（按 projectId+term 去重）
        if (type == 'L3' && contentJson['term'] != null) {
          await _upsertKnowledgeCard(projectId, contentJson);
        }
      }

      // 滚动前情摘要（Prompt E，cheap 层；失败不阻塞主线）
      meta.digest = await _mergeDigest(meta.digest, blockSummary, annotations);

      // 断点凭据与批注同事务落库
      meta.annotatedPara = endPara;
      await (_db.update(_db.projects)..where((t) => t.id.equals(projectId)))
          .write(ProjectsCompanion(metaJson: Value(meta.encode())));
    });
    return blockSummary;
  }

  /// 归一化各类型批注内容 → 统一对象存 contentJson。
  /// L1/L2: {"text": "..."}；L3: {"term","text","uncertain"}；L4: {"question","perspectives"}。
  Map<String, dynamic>? _normalizeContent(String type, dynamic content) {
    switch (type) {
      case 'L1':
      case 'L2':
        final text = content is String ? content.trim() : '';
        return text.isEmpty ? null : {'text': text};
      case 'L3':
        if (content is! Map) return null;
        final term = (content['term'] ?? '').toString().trim();
        final text = (content['text'] ?? '').toString().trim();
        if (term.isEmpty || text.isEmpty) return null;
        return {
          'term': term,
          'text': text,
          'uncertain': content['uncertain'] == true,
        };
      case 'L4':
        if (content is! Map) return null;
        final question = (content['question'] ?? '').toString().trim();
        final perspectives = [
          for (final p in (content['perspectives'] as List? ?? []))
            p.toString()
        ];
        if (question.isEmpty) return null;
        return {'question': question, 'perspectives': perspectives};
      default:
        return null; // 未知类型丢弃
    }
  }

  Future<void> _upsertKnowledgeCard(
      int projectId, Map<String, dynamic> l3) async {
    final term = (l3['term'] ?? '').toString();
    final existing = await (_db.select(_db.knowledgeCards)
          ..where((t) =>
              Expression.and([t.projectId.equals(projectId), t.term.equals(term)])))
        .getSingleOrNull();
    if (existing != null) return;
    await _db.into(_db.knowledgeCards).insert(KnowledgeCardsCompanion.insert(
          projectId: projectId,
          term: term,
          title: term,
          content: (l3['text'] ?? '').toString(),
          uncertain: Value(l3['uncertain'] == true),
        ));
  }

  Future<String?> _mergeDigest(
      String? oldDigest, String blockSummary, List<Map> annotations) async {
    final highlights = [
      for (final a in annotations)
        if ((a['type'] ?? '') == 'L1' && a['content'] is String)
          (a['content'] as String),
    ].take(3).join('；');
    final newScene = '$blockSummary${highlights.isEmpty ? '' : '。$highlights'}';
    try {
      final r = await _llm.chatJson([
        {
          'role': 'user',
          'content': Prompts.rollingDigest(
              oldDigest: oldDigest ?? '（无）', newScene: newScene),
        }
      ], tier: LlmTier.cheap, purpose: 'novel_digest');
      return (r['digest'] ?? '').toString();
    } catch (_) {
      // 摘要失败不影响批注主线：直接拼接旧摘要（截断防膨胀）
      final merged = '${oldDigest ?? ''}\n$newScene'.trim();
      return merged.length > 300 ? merged.substring(merged.length - 300) : merged;
    }
  }
}
