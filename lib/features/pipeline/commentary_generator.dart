import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/llm/prompts.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';
import 'package:peixi/features/pipeline/project_meta.dart';

/// S9 逐场景解说生成（防剧透核心，设计稿 6.3/6.4/S9）：
/// 串行循环；上下文 = 前情滚动摘要 + 本场景对白，严禁后续内容；
/// 每场景完成即写库（崩溃可续跑）；knowledge_needed 查重后生成卡片；
/// l4_question 入 questions；单场景失败标 failed 占位并继续。
class CommentaryGenerator {
  CommentaryGenerator({
    required this.db,
    required this.llm,
    required this.modelStandard,
    this.onProgress,
    this.isCancelled,
  });

  final AppDatabase db;
  final LlmService llm;

  /// 深层分析槽位当前模型名（落库 commentaries.model；测试可注入固定值）
  final String Function() modelStandard;
  final void Function(int done, int total)? onProgress;

  /// 返回 true 时抛 [PipelineCancelled] 中断循环（已完成场景已落库，可续跑）
  final bool Function()? isCancelled;

  Future<void> generate(int projectId) async {
    final p = await (db.select(db.projects)
          ..where((t) => t.id.equals(projectId)))
        .getSingle();
    final meta = ProjectMeta.fromJson(p.metaJson);
    var digest = meta.digest ?? '';

    // 角色名表：speaker_key → 显示名
    final chars = await (db.select(db.characters)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    final nameBySpeaker = {
      for (final c in chars)
        if (c.speakerKey != null) c.speakerKey!: c.name,
    };
    final nameById = {for (final c in chars) c.id: c.name};

    final scenes = await (db.select(db.scenes)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.asc(t.idx)]))
        .get();

    for (var i = 0; i < scenes.length; i++) {
      if (isCancelled?.call() ?? false) throw const PipelineCancelled();
      final scene = scenes[i];

      // 续跑：已 done 的跳过
      final existing = await (db.select(db.commentaries)
            ..where((t) => t.sceneId.equals(scene.id)))
          .getSingleOrNull();
      if (existing != null && existing.status == 'done') continue;

      try {
        await _generateOne(projectId, p.title, scene, nameBySpeaker, nameById,
            digest, meta);
      } catch (_) {
        // 失败占位（保证重跑可识别、不阻塞后续场景）
        if (existing == null) {
          await db.into(db.commentaries).insert(CommentariesCompanion.insert(
                sceneId: scene.id,
                l1Subtext: '',
                status: const Value('failed'),
                model: modelStandard(),
              ));
        }
      }

      // 更新摘要（失败则沿用旧摘要）
      try {
        final sc = await (db.select(db.commentaries)
              ..where((t) => t.sceneId.equals(scene.id)))
            .getSingle();
        if (sc.status == 'done' && sc.l1Subtext.isNotEmpty) {
          final r = await llm.chatJson(
            [
              {
                'role': 'user',
                'content': Prompts.rollingDigest(
                    oldDigest: digest.isEmpty ? '（无）' : digest,
                    newScene: sc.l1Subtext),
              },
            ],
            slot: LlmSlot.summary,
            purpose: 'digest',
            projectId: projectId,
          );
          final d = (r['digest'] ?? '').toString().trim();
          if (d.isNotEmpty) digest = d.length > 300 ? d.substring(0, 300) : d;
        }
      } catch (_) {}

      meta.digest = digest;
      await (db.update(db.projects)..where((t) => t.id.equals(projectId)))
          .write(ProjectsCompanion(metaJson: Value(meta.encode())));
      onProgress?.call(i + 1, scenes.length);
    }
  }

  Future<void> _generateOne(
    int projectId,
    String title,
    Scene scene,
    Map<String, String> nameBySpeaker,
    Map<int, String> nameById,
    String digest,
    ProjectMeta meta,
  ) async {
    // 本场景对白（带角色名与时间戳）——只取 startMs..endMs 区间，天然防剧透
    final segs = await (db.select(db.segments)
          ..where((t) => Expression.and([
                t.projectId.equals(projectId),
                t.startMs.isBiggerOrEqualValue(scene.startMs),
                t.endMs.isSmallerOrEqualValue(scene.endMs),
              ]))
          ..orderBy([(t) => OrderingTerm.asc(t.idx)]))
        .get();
    final charRows = await (db.select(db.characters)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    final speakerOf = {for (final c in charRows) c.id: c.speakerKey};
    final dialogue = segs
        .map((sg) =>
            '[${nameById[sg.speakerCharId] ?? speakerOf[sg.speakerCharId] ?? '?'}]'
            '[${formatTimestamp(sg.startMs)}]${sg.content}')
        .join('\n');

    final result = await llm.chatJson(
      [
        {
          'role': 'user',
          'content': Prompts.sceneCommentary(digest: digest, dialogues: dialogue),
        },
      ],
      slot: LlmSlot.analysis,
      purpose: 'commentary',
      projectId: projectId,
    );

    final l1 = (result['l1_subtext'] ?? '').toString();
    final importance = (result['importance'] ?? 'normal').toString();
    final summary = (result['scene_summary'] ?? '').toString();
    final model = modelStandard();

    await db.transaction(() async {
      // commentaries 覆盖写（含 failed 占位升级）
      final existing = await (db.select(db.commentaries)
            ..where((t) => t.sceneId.equals(scene.id)))
          .getSingleOrNull();
      final companion = CommentariesCompanion.insert(
        sceneId: scene.id,
        l1Subtext: l1,
        l2PsychologyJson:
            Value(jsonEncode(result['l2_psychology'] ?? [])),
        status: const Value('done'),
        model: model,
      );
      if (existing == null) {
        await db.into(db.commentaries).insert(companion);
      } else {
        await (db.update(db.commentaries)
              ..where((t) => t.id.equals(existing.id)))
            .write(companion);
      }

      await (db.update(db.scenes)..where((t) => t.id.equals(scene.id))).write(
          ScenesCompanion(summary: Value(summary), importance: Value(importance)));

      // L4 问题
      final q = result['l4_question'];
      if (q is Map) {
        await db.into(db.questions).insert(QuestionsCompanion.insert(
              projectId: projectId,
              sceneId: Value(scene.id),
              question: (q['question'] ?? '').toString(),
              perspectivesJson: Value(jsonEncode(q['perspectives'] ?? [])),
            ));
      }

      // 知识卡片：查重（DB unique + 本次运行内 set）
      final needed = ((result['knowledge_needed'] as List?) ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      for (final term in needed) {
        final dup = await (db.select(db.knowledgeCards)
              ..where((t) =>
                  t.projectId.equals(projectId) & t.term.equals(term)))
            .getSingleOrNull();
        if (dup != null) continue;
        try {
          final card = await llm.chatJson(
            [
              {
                'role': 'user',
                'content': Prompts.knowledgeCard(
                    term: term,
                    context: '$title · ${summary.isEmpty ? l1 : summary}'),
              },
            ],
            slot: LlmSlot.analysis,
            purpose: 'card',
            projectId: projectId,
          );
          await db.into(db.knowledgeCards).insert(KnowledgeCardsCompanion.insert(
                projectId: projectId,
                term: term,
                title: ((card['title'] ?? term) as String).isEmpty
                    ? term
                    : card['title'] as String? ?? term,
                content: (card['content'] ?? '').toString(),
                firstSceneIdx: Value(scene.idx),
                uncertain: Value(card['uncertain'] == true),
              ));
        } catch (_) {
          // 卡片失败不阻塞解说主线
        }
      }
    });
  }
}
