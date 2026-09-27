// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/llm/prompts.dart';
import 'package:peixi/features/pipeline/pipeline_engine.dart';

/// 地图趟（设计文档 §3/§7.1，summary 槽位）：每批连续 N 章一次调用，
/// 产出章摘要/出场名单/人物事件/人物增量；名单按 major + 50 章窗口快照，防 O(n²)。
/// 批边界 = 首个未 map_done 章起连续 N 章（静态可重放，缓存命中）；
/// 解析失败自适应降批（减半 → 单章兜底）。返回值 = 本批新完成章数（模型漏章不计）。
class NovelMapPass {
  NovelMapPass({
    required AppDatabase db,
    required LlmService llm,
    this.batchChapters = 5,
    this.rosterWindowChapters = 50,
    this.maxChapterChars = 6000,
    this.onProgress,
    this.onDegraded,
    this.isCancelled,
  })  : _db = db,
        _llm = llm;

  final AppDatabase _db;
  final LlmService _llm;
  final int batchChapters;
  final int rosterWindowChapters;
  final int maxChapterChars;
  final void Function(int done, int total)? onProgress;
  final void Function(String detail)? onDegraded;
  final bool Function()? isCancelled;

  /// 推进一批；返回新完成章数（0 = 全书地图已完成）。
  Future<int> step(int projectId) async {
    final chapters = await _chapters(projectId);
    final first = chapters.indexWhere((c) => !c.mapDone);
    if (first < 0) return 0;
    final end = math.min(first + batchChapters, chapters.length);
    return _processBatch(projectId, chapters.sublist(first, end), chapters.length);
  }

  Future<int> _processBatch(
      int projectId, List<Chapter> batch, int total) async {
    if (isCancelled?.call() ?? false) throw const PipelineCancelled();
    final rosterText = await _roster(projectId, beforeIdx: batch.first.idx);
    final blocks = <String>[];
    for (final ch in batch) {
      final paras = await (_db.select(_db.paragraphs)
            ..where((t) => t.chapterId.equals(ch.id))
            ..orderBy([(p) => OrderingTerm.asc(p.idx)]))
          .get();
      blocks.add(_chapterBlock(ch, paras));
    }
    try {
      final result = await _llm.chatJson([
        {'role': 'user', 'content': Prompts.novelMap(roster: rosterText, chapterBlocks: blocks)},
      ], slot: LlmSlot.summary, purpose: 'novel_map', projectId: projectId);
      final doneCount = await _apply(projectId, batch, result);
      onProgress?.call(await _doneCount(projectId), total);
      return doneCount;
    } on LlmJsonException {
      if (batch.length == 1) rethrow;
      final mid = batch.length ~/ 2;
      onDegraded?.call('地图批解析失败，降批：${batch.length} → $mid + ${batch.length - mid}');
      return await _processBatch(projectId, batch.sublist(0, mid), total) +
          await _processBatch(projectId, batch.sublist(mid), total);
    }
  }

  String _chapterBlock(Chapter ch, List<Paragraph> paras) {
    var text = paras.map((p) => p.content).join('\n');
    if (text.length > maxChapterChars) {
      text =
          '${text.substring(0, maxChapterChars)}\n……（本章其余内容截断，仅供地图参考）';
    }
    return '[章${ch.idx} ${ch.title ?? '第${ch.idx + 1}部分'}]\n$text';
  }

  /// 名单摘录：major 全量 + 最近 rosterWindow 章出场者，合并去重，≤80 行。
  Future<String> _roster(int projectId, {required int beforeIdx}) async {
    final windowStart = beforeIdx - rosterWindowChapters;
    final windowChapters = await (_db.select(_db.chapters)
          ..where((t) => t.projectId.equals(projectId) &
              t.idx.isBiggerOrEqualValue(windowStart) &
              t.idx.isSmallerThanValue(beforeIdx)))
        .get();
    final recentIds = <int>{
      for (final ch in windowChapters)
        ...((jsonDecode(ch.castIds) as List? ?? []).cast<int>()),
    };
    final rows = await (_db.select(_db.characters)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    final picked = [
      for (final r in rows)
        if (r.major || recentIds.contains(r.id)) r,
    ]..sort((a, b) => (b.major ? 1 : 0).compareTo(a.major ? 1 : 0));
    if (picked.isEmpty) return '（尚无，本批为开头）';
    return [
      for (final r in picked.take(80))
        '${r.name}：${r.aliasesJson.isEmpty ? '（暂无人设）' : r.aliasesJson}${r.major ? '【主要】' : ''}',
    ].join('\n');
  }

  /// 落库（单事务）：人物增量 → cast 解析 → 事件 → 章行（summary/map_done/cast_ids）。
  /// 返回实际完成章数（响应缺章/摘要为空的不计）。
  Future<int> _apply(int projectId, List<Chapter> batch,
      Map<String, dynamic> result) async {
    final entries = <int, Map>{
      for (final e in (result['chapters'] as List? ?? []).cast<Map>())
        if (e['idx'] is num) (e['idx'] as num).toInt(): e,
    };
    final rows = await (_db.select(_db.characters)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    final idByName = {for (final r in rows) r.name: r.id};
    var done = 0;
    await _db.transaction(() async {
      for (final ch in batch) {
        final e = entries[ch.idx];
        if (e == null) continue;
        final summary = (e['summary'] ?? '').toString().trim();
        if (summary.isEmpty) continue;
        for (final c in (e['characters'] as List? ?? []).cast<Map>()) {
          final name = (c['name'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          final profile = (c['profile'] ?? '').toString().trim();
          final major = c['major'] == true;
          final existingId = idByName[name];
          if (existingId == null) {
            idByName[name] = await _db.into(_db.characters).insert(
                CharactersCompanion.insert(
                    projectId: projectId, name: name,
                    aliasesJson: Value(profile), major: Value(major)));
          } else if (profile.isNotEmpty || major) {
            await (_db.update(_db.characters)
                  ..where((t) => t.id.equals(existingId)))
                .write(CharactersCompanion(
                    aliasesJson: profile.isNotEmpty
                        ? Value(profile)
                        : const Value.absent(),
                    major: major ? const Value(true) : const Value.absent()));
          }
        }
        final castIds = <int>[];
        for (final n in (e['cast'] as List? ?? [])) {
          final name = n.toString().trim();
          if (name.isEmpty) continue;
          var cid = idByName[name];
          if (cid == null) {
            cid = await _db.into(_db.characters).insert(
                CharactersCompanion.insert(projectId: projectId, name: name));
            idByName[name] = cid;
          }
          castIds.add(cid);
        }
        for (final ev in (e['events'] as List? ?? []).cast<Map>()) {
          final name = (ev['name'] ?? '').toString().trim();
          final event = (ev['event'] ?? '').toString().trim();
          final cid = idByName[name];
          if (cid == null || event.isEmpty) continue;
          await _db.into(_db.characterEvents).insert(
              CharacterEventsCompanion.insert(
                  projectId: projectId, characterId: cid,
                  chapterIdx: ch.idx, event: event));
        }
        await (_db.update(_db.chapters)..where((t) => t.id.equals(ch.id)))
            .write(ChaptersCompanion(
                summary: Value(summary),
                mapDone: const Value(true),
                castIds: Value(jsonEncode(castIds))));
        done++;
      }
    });
    return done;
  }

  Future<List<Chapter>> _chapters(int projectId) =>
      (_db.select(_db.chapters)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
          .get();

  Future<int> _doneCount(int projectId) async {
    final rows = await _chapters(projectId);
    return rows.where((c) => c.mapDone).length;
  }
}
