// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/llm/prompts.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';
import 'package:peixi/features/pipeline/project_status.dart';

/// 小说处理状态机（设计稿第五节 N1-N4）。
/// N1 导入在 NovelImporter 完成（status=IMPORTED）；本引擎推进
/// N2 人物提取（map）→ N3 批注（commentary，协作器注入）→ N4 完成（READY）。
/// 状态落盘/失败语义/防并发与视频 PipelineEngine 一致。
class NovelPipelineEngine {
  NovelPipelineEngine({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  final StreamController<PipelineEvent> _events =
      StreamController<PipelineEvent>.broadcast();
  Stream<PipelineEvent> get events => _events.stream;
  final Set<int> _busy = {};
  final Set<int> _cancelRequested = {};

  /// 请求取消（仅当项目正在运行时登记）。协作式：循环检查标记后抛
  /// [PipelineCancelled]，已完成的章/块已落库，续跑可无损恢复。
  void requestCancel(int projectId) {
    if (_busy.contains(projectId)) _cancelRequested.add(projectId);
  }

  bool isCancelled(int projectId) => _cancelRequested.contains(projectId);

  Future<void> Function(int projectId)? _extractCastFn;
  Future<void> Function(int projectId)? _annotateFn;

  /// N2/N3 协作器注入点（同视频引擎模式，保持引擎可独立测试）
  void attachCollaborators({
    Future<void> Function(int)? extractCast,
    Future<void> Function(int)? annotate,
  }) {
    _extractCastFn = extractCast;
    _annotateFn = annotate;
  }

  void _emit(int projectId, String stage, ProjectStatus status,
      {String? detail, bool cancelled = false}) {
    _events.add(PipelineEvent(
        projectId: projectId,
        stage: stage,
        status: status,
        detail: detail,
        cancelled: cancelled));
  }

  Future<Project> _project(int id) async {
    final p = await (_db.select(_db.projects)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (p == null) throw PipelineException('项目不存在: $id');
    return p;
  }

  Future<void> _setStatus(int id, ProjectStatus s, {String? failedStage}) async {
    await (_db.update(_db.projects)..where((t) => t.id.equals(id))).write(
        ProjectsCompanion(
            status: Value(s.db),
            failedStage: Value(failedStage),
            updatedAt: Value(DateTime.now())));
  }

  Future<bool> _stage(
      int id, String name, Future<void> Function(int) step) async {
    final p = await _project(id);
    _emit(id, name, ProjectStatus.fromDb(p.status));
    try {
      await step(id);
      if (_cancelRequested.remove(id)) {
        await _emitCancelled(id, name);
        return false;
      }
      return true;
    } catch (e) {
      if (_cancelRequested.remove(id) || e is PipelineCancelled) {
        await _emitCancelled(id, name);
        return false;
      }
      await _setStatus(id, ProjectStatus.failed, failedStage: name);
      _emit(id, name, ProjectStatus.failed, detail: '$e');
      return false;
    }
  }

  Future<void> _emitCancelled(int id, String name) async {
    final p = await _project(id);
    _emit(id, name, ProjectStatus.fromDb(p.status),
        detail: '已取消（进度已保存，可继续）', cancelled: true);
  }

  Future<void> run(int projectId) async {
    if (!_busy.add(projectId)) return; // 同项目防并发
    try {
      final p = await _project(projectId);
      var st = ProjectStatus.fromDb(p.status);
      if (st == ProjectStatus.failed) {
        st = novelEntryStatusOfStage(p.failedStage ?? '');
      }
      if (st == ProjectStatus.imported) {
        if (!await _stage(
            projectId, 'map', (id) async => _extractCastFn?.call(id))) {
          return;
        }
        await _setStatus(projectId, ProjectStatus.mapped);
        st = ProjectStatus.mapped;
      }
      if (st == ProjectStatus.mapped) {
        if (!await _stage(
            projectId, 'commentary', (id) async => _annotateFn?.call(id))) {
          return;
        }
        await _setStatus(projectId, ProjectStatus.commentaryDone);
        st = ProjectStatus.commentaryDone;
      }
      if (st == ProjectStatus.commentaryDone) {
        // N4：批注已全部落库，直接就绪进阅读器
        await _setStatus(projectId, ProjectStatus.ready);
        _emit(projectId, 'finalize', ProjectStatus.ready);
      }
    } finally {
      _busy.remove(projectId);
    }
  }

  Future<void> retry(int projectId) => run(projectId);
}

/// N2 人物提取：逐章调用轻量 LLM，滚动维护全书人物名单与一句话人设，
/// 同时为每章产出 60 字摘要（N3 前情上下文复用，省一轮调用）。
/// 幂等：已有 summary 的章跳过（崩溃续跑）；人物按名字去重合并。
class NovelCharacterExtractor {
  NovelCharacterExtractor({
    required AppDatabase db,
    required LlmService llm,
    this.maxChapterChars = 6000,
    this.onProgress,
    this.isCancelled,
  })  : _db = db,
        _llm = llm;

  final AppDatabase _db;
  final LlmService _llm;

  /// 超长章节截断送审（人物提取不需要逐字读完）
  final int maxChapterChars;
  final void Function(int done, int total)? onProgress;

  /// 返回 true 时抛 [PipelineCancelled] 中断循环（已完成章节已落库，可续跑）
  final bool Function()? isCancelled;

  Future<void> extract(int projectId) async {
    final chapters = await (_db.select(_db.chapters)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
        .get();

    // 全书名单：name → (charId, profile)。profile 存 aliasesJson（偏离：novel 人物
    // 无 speaker 概念，aliases 字段复用为人设文本，阅读器人物列表读取）
    final rows = await (_db.select(_db.characters)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    final idByName = <String, int>{for (final r in rows) r.name: r.id};
    final profileByName = <String, String>{
      for (final r in rows) r.name: r.aliasesJson,
    };

    var done = 0;
    for (final ch in chapters) {
      if (isCancelled?.call() ?? false) throw const PipelineCancelled();
      if (ch.summary != null && ch.summary!.isNotEmpty) {
        done++; // 续跑：本章已处理
        continue;
      }
      final paras = await (_db.select(_db.paragraphs)
            ..where((t) => t.chapterId.equals(ch.id))
            ..orderBy([(p) => OrderingTerm.asc(p.idx)]))
          .get();
      var text = paras.map((e) => e.content).join('\n');
      if (text.length > maxChapterChars) {
        text =
            '${text.substring(0, maxChapterChars)}\n……（本章其余内容截断，仅供人物参考）';
      }
      final rosterText = profileByName.isEmpty
          ? '（尚无，本章为开头）'
          : [
              for (final e in profileByName.entries)
                '${e.key}：${e.value.isEmpty ? '（暂无人设）' : e.value}'
            ].join('\n');

      final result = await _llm.chatJson([
        {
          'role': 'user',
          'content': Prompts.novelCast(
              roster: rosterText,
              chapterTitle: ch.title ?? '第${ch.idx + 1}部分',
              chapterText: text),
        }
      ], slot: LlmSlot.summary, purpose: 'novel_cast', projectId: projectId);

      for (final c in (result['characters'] as List? ?? []).cast<Map>()) {
        final name = (c['name'] ?? '').toString().trim();
        final profile = (c['profile'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final existingId = idByName[name];
        if (existingId != null) {
          if (profile.isNotEmpty && profile != profileByName[name]) {
            await (_db.update(_db.characters)
                  ..where((t) => t.id.equals(existingId)))
                .write(CharactersCompanion(aliasesJson: Value(profile)));
            profileByName[name] = profile;
          }
        } else {
          final newId = await _db.into(_db.characters).insert(
              CharactersCompanion.insert(
                  projectId: projectId, name: name, aliasesJson: Value(profile)));
          idByName[name] = newId;
          profileByName[name] = profile;
        }
      }

      final summary = (result['chapter_summary'] ?? '').toString();
      await (_db.update(_db.chapters)..where((t) => t.id.equals(ch.id)))
          .write(ChaptersCompanion(summary: Value(summary)));
      done++;
      onProgress?.call(done, chapters.length);
    }
  }
}
