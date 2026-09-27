// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/llm/prompts.dart';
import 'package:peixi/features/pipeline/novel_recall.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';

/// 批注趟（设计文档 §3/§7.3，analysis 槽位）：每批连续 N 章一次调用。
/// 上下文逐层拼装：[故事至今]=批首章 digest_before → [出场人物]=cast 人设+批前
/// 事件线(≤3条/人) → [相关前文回忆](可选注入) → [前文摘要]=前一两章摘要 →
/// [本章正文]。L1-L4 content 结构与旧版完全一致（阅读器/知识卡/SRS 依赖）。
/// 按章分组校验落库：模型漏章不计 annot_done，下一轮重试；解析失败自适应降批。
class NovelAnnotatePass {
  NovelAnnotatePass({
    required AppDatabase db,
    required LlmService llm,
    this.batchChapters = 3,
    this.recall,
    this.onProgress,
    this.onDegraded,
    this.isCancelled,
  })  : _db = db,
        _llm = llm;

  final AppDatabase _db;
  final LlmService _llm;
  final int batchChapters;
  final NovelRecallProvider? recall;
  final void Function(int done, int total)? onProgress;
  final void Function(String detail)? onDegraded;
  final bool Function()? isCancelled;

  /// 推进一批；返回新完成章数（0 = 上游未就绪或全书批注已完成）。
  /// 批 = 首个未批注章起连续 N 章，且在地图/快照前沿截断（同 DigestPass，
  /// 防止首屏冲刺阶段互等）。
  Future<int> step(int projectId) async {
    final chapters = await _chapters(projectId);
    final first = chapters.indexWhere((c) => !c.annotDone);
    if (first < 0) return 0;
    final limit = math.min(first + batchChapters, chapters.length);
    final batch = <Chapter>[];
    for (var i = first; i < limit; i++) {
      final ch = chapters[i];
      if (!ch.mapDone || ch.digestBefore == null) break;
      batch.add(ch);
    }
    if (batch.isEmpty) return 0;
    return _processBatch(projectId, batch, chapters.length);
  }

  /// 单章重批（处理页按钮；调用方须保证调度器空闲）。
  Future<void> reannotateChapter(int projectId, int chapterIdx) async {
    if (isCancelled?.call() ?? false) throw const PipelineCancelled();
    final chapters = await _chapters(projectId);
    final idx = chapters.indexWhere((c) => c.idx == chapterIdx);
    if (idx < 0) throw PipelineException('章不存在: $chapterIdx');
    final ch = chapters[idx];
    if (!ch.mapDone) throw PipelineException('该章的地图尚未就绪');
    // digest_before 为空（老项目回填旧章）不阻断重批：prompt 省略[故事至今]节
    await _processBatch(projectId, [ch], chapters.length, skipAnnotated: false);
  }

  Future<int> _processBatch(
      int projectId, List<Chapter> batch, int total,
      {bool skipAnnotated = true}) async {
    if (isCancelled?.call() ?? false) throw const PipelineCancelled();
    final prompt = await _buildPrompt(projectId, batch);
    try {
      final result = await _llm.chatJson([
        {'role': 'user', 'content': prompt},
      ], slot: LlmSlot.analysis, purpose: 'novel_annotate', projectId: projectId);
      final done = await _apply(projectId, batch, result,
          skipAnnotated: skipAnnotated);
      onProgress?.call(await _doneCount(projectId), total);
      return done;
    } on LlmJsonException {
      if (batch.length == 1) rethrow;
      final mid = batch.length ~/ 2;
      onDegraded?.call('批注批解析失败，降批：${batch.length} → $mid + ${batch.length - mid}');
      return await _processBatch(projectId, batch.sublist(0, mid), total,
              skipAnnotated: skipAnnotated) +
          await _processBatch(projectId, batch.sublist(mid), total,
              skipAnnotated: skipAnnotated);
    }
  }

  Future<String> _buildPrompt(int projectId, List<Chapter> batch) async {
    final paras = await (_db.select(_db.paragraphs)
          ..where((t) => t.chapterId.isIn([for (final c in batch) c.id]))
          ..orderBy([(p) => OrderingTerm.asc(p.idx)]))
        .get();
    final byChapter = <int, List<Paragraph>>{};
    for (final p in paras) {
      if (p.chapterId == null) continue;
      (byChapter[p.chapterId!] ??= []).add(p);
    }
    // 近似取舍：整批统一用批首章的 digest_before——跨快照批边界时后段章拿到
    // 更旧的快照（偏保守、无剧透），逐章精确快照需拆批调用，不值得。
    // 老项目回填旧章可为 null：[故事至今] 节整体省略（下方剥除），其余层照常。
    final digest = batch.first.digestBefore;
    final castIds = <int>{
      for (final ch in batch)
        ...((jsonDecode(ch.castIds) as List? ?? []).cast<int>()),
    };
    final cast = await _castSection(projectId,
        beforeIdx: batch.first.idx, ids: castIds);
    final recallText = await recall?.recallContext(projectId,
            beforeChapterIdx: batch.first.idx, query: digest ?? '') ??
        '';
    final prev = await (_db.select(_db.chapters)
          ..where((t) => t.projectId.equals(projectId) &
              t.idx.isBiggerOrEqualValue(batch.first.idx - 2) &
              t.idx.isSmallerThanValue(batch.first.idx))
          ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
        .get();
    final recent = [
      for (final c in prev)
        if ((c.summary ?? '').isNotEmpty) '第${c.idx}章：${c.summary}',
    ].join('\n');
    // 无正文段落的章（如卷标题紧邻章标题切出的空章）不进正文块：无可锚定段落
    final blocks = [
      for (final ch in batch)
        if ((byChapter[ch.id] ?? const <Paragraph>[]).isNotEmpty)
          '[第${ch.idx}章 ${ch.title ?? ''}]\n'
              '${(byChapter[ch.id] ?? const []).map((p) => '[${p.idx}] ${p.content}').join('\n')}',
    ];
    var prompt = Prompts.novelAnnotateV2(
        digest: digest ?? '',
        cast: cast,
        recall: recallText,
        recentSummaries: recent,
        chaptersText: blocks.join('\n\n'),
        chapterStart: batch.first.idx,
        chapterEnd: batch.last.idx);
    if (digest == null || digest.isEmpty) {
      // 模板对 digest 是必填 String：按空串渲染后剥除空的 [故事至今] 节行
      prompt = prompt.replaceFirst('[故事至今]\n', '');
    }
    return prompt;
  }

  /// [出场人物]：cast 并集 → 人设 + 批前事件线（每人物最近 3 条，时间正序），
  /// major 优先，≤30 行。
  Future<String> _castSection(int projectId,
      {required int beforeIdx, required Set<int> ids}) async {
    if (ids.isEmpty) return '（本章暂无已知出场人物）';
    final rows = await (_db.select(_db.characters)
          ..where((t) => t.projectId.equals(projectId) & t.id.isIn(ids.toList())))
        .get()
      ..sort((a, b) {
        final byMajor = (b.major ? 1 : 0).compareTo(a.major ? 1 : 0);
        // id 次级排序键：List.sort 不稳定，同 major 时保证确定序（缓存键/降批重放一致）
        return byMajor != 0 ? byMajor : a.id.compareTo(b.id);
      });
    final events = await (_db.select(_db.characterEvents)
          ..where((t) => t.projectId.equals(projectId) &
              t.characterId.isIn(ids.toList()) &
              t.chapterIdx.isSmallerThanValue(beforeIdx))
          ..orderBy([(e) => OrderingTerm.desc(e.chapterIdx),
              (e) => OrderingTerm.asc(e.id)])) // 同章多条按 id 稳定次序
        .get();
    final byChar = <int, List<CharacterEvent>>{};
    for (final e in events) {
      (byChar[e.characterId] ??= []).add(e);
    }
    final lines = <String>[];
    for (final r in rows.take(30)) {
      final evs = [
        // 查询按章号倒序 → 取最近 3 条后反转回时间正序
        for (final e in (byChar[r.id] ?? const []).take(3).toList().reversed)
          e.event,
      ];
      lines.add('${r.name}${r.major ? '【主要人物】' : ''}：'
          '${r.aliasesJson.isEmpty ? '（暂无人设）' : r.aliasesJson}'
          '${evs.isEmpty ? '' : '；前文：${evs.join('；')}'}');
    }
    return lines.isEmpty ? '（本章暂无已知出场人物）' : lines.join('\n');
  }

  Future<int> _apply(int projectId, List<Chapter> batch,
      Map<String, dynamic> result,
      {bool skipAnnotated = true}) async {
    final entries = _parseResult(result); // 解析先行：失败走降批，不产生半途写库
    final paras = await (_db.select(_db.paragraphs)
          ..where((t) => t.chapterId.isIn([for (final c in batch) c.id])))
        .get();
    final byChapter = <int, List<Paragraph>>{};
    for (final p in paras) {
      if (p.chapterId == null) continue;
      (byChapter[p.chapterId!] ??= []).add(p);
    }
    var done = 0;
    await _db.transaction(() async {
      for (final ch in batch) {
        // 洞口续批包含已完成章（重试漏章的设计意图）：跳过不重写、done 不重复计数
        if (skipAnnotated && ch.annotDone) continue;
        final chapterParas = byChapter[ch.id] ?? const <Paragraph>[];
        if (chapterParas.isEmpty) {
          // 空章（卷标题紧邻章标题、行首章标题等切出的无正文章）：无可批注对象
          // 即视为完成——否则永远卡住批首，后续章被反复删除重写。宁缺毋滥不受影响。
          await (_db.update(_db.chapters)..where((t) => t.id.equals(ch.id)))
              .write(const ChaptersCompanion(annotDone: Value(true)));
          done++;
          continue;
        }
        final annotations = entries[ch.idx];
        if (annotations == null) continue; // 模型漏章：不置 annot_done，下轮重试
        final paraByIdx = {for (final p in chapterParas) p.idx: p};
        final inserts = <(Paragraph, String, Map<String, dynamic>)>[];
        for (final a in annotations) {
          final idx =
              a['para_idx'] is num ? (a['para_idx'] as num).toInt() : null;
          final type = (a['type'] ?? '').toString().trim();
          final para = idx == null ? null : paraByIdx[idx];
          if (para == null) continue;
          final content = normalizeAnnotationContent(type, a['content']);
          if (content == null) continue;
          inserts.add((para, type, content));
        }
        // 幂等重批：先清本章旧批注再写入（锚定 paraId）
        await (_db.delete(_db.annotations)
              ..where((t) => t.paraId.isIn(chapterParas.map((p) => p.id).toList())))
            .go();
        for (final (para, type, content) in inserts) {
          await _db.into(_db.annotations).insert(AnnotationsCompanion.insert(
              paraId: para.id, type: type, contentJson: jsonEncode(content)));
          if (type == 'L3' && content['term'] != null) {
            await _upsertKnowledgeCard(projectId, content);
          }
        }
        await (_db.update(_db.chapters)..where((t) => t.id.equals(ch.id)))
            .write(ChaptersCompanion(annotDone: const Value(true)));
        done++;
      }
    });
    return done;
  }

  Future<void> _upsertKnowledgeCard(
      int projectId, Map<String, dynamic> l3) async {
    final term = (l3['term'] ?? '').toString();
    final existing = await (_db.select(_db.knowledgeCards)
          ..where((t) => Expression.and(
              [t.projectId.equals(projectId), t.term.equals(term)])))
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

  Future<List<Chapter>> _chapters(int projectId) =>
      (_db.select(_db.chapters)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
          .get();

  Future<int> _doneCount(int projectId) async {
    final rows = await _chapters(projectId);
    return rows.where((c) => c.annotDone).length;
  }
}

/// 归一化各类型批注 content（L1/L2 字符串 → {"text"}；L3 → {term,text,uncertain}；
/// L4 → {question,perspectives}）。结构自旧版原样保留（阅读器/SRS 兼容）。
Map<String, dynamic>? normalizeAnnotationContent(String type, dynamic content) {
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
      // 非 List（如模型给了字符串）中性化为空列表，不抛 TypeError
      final raw = content['perspectives'];
      final perspectives = [
        if (raw is List) for (final p in raw) p.toString(),
      ];
      if (question.isEmpty) return null;
      return {'question': question, 'perspectives': perspectives};
    default:
      return null;
  }
}

/// 解析模型响应 → {章 idx: 批注条目}。只包解析、不包落库（落库 bug 不得被伪装成
/// 模型错误）：顶层 chapters 非数组等形状错误转 LlmJsonException 走既有降批路径；
/// 元素非 Map / annotations 非 List 就地跳过。catch 兜住 TypeError——惰性 cast
/// 绕过 on LlmJsonException 直冒 step、而毒响应已入缓存会导致重试永久失败。
Map<int, List<Map>> _parseResult(Map<String, dynamic> result) {
  try {
    final raw = result['chapters'];
    if (raw == null) return const <int, List<Map>>{};
    if (raw is! List) {
      throw LlmJsonException('批注响应 chapters 不是数组（${raw.runtimeType}）');
    }
    final entries = <int, List<Map>>{};
    for (final e in raw.whereType<Map>()) {
      if (e['idx'] is! num) continue;
      final anns = e['annotations'];
      entries[(e['idx'] as num).toInt()] = [
        if (anns is List) ...anns.whereType<Map>(),
      ];
    }
    return entries;
  } on TypeError catch (e) {
    throw LlmJsonException('批注响应结构异常: $e');
  }
}
