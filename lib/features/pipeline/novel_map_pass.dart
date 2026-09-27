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
    // 一次查询整批段落（对齐批注趟的 isIn 写法，避免逐章 N+1）
    final paras = await (_db.select(_db.paragraphs)
          ..where((t) => t.chapterId.isIn([for (final ch in batch) ch.id]))
          ..orderBy([(p) => OrderingTerm.asc(p.idx)]))
        .get();
    final byChapter = <int, List<Paragraph>>{};
    for (final p in paras) {
      if (p.chapterId == null) continue;
      (byChapter[p.chapterId!] ??= []).add(p);
    }
    final blocks = [
      for (final ch in batch) _chapterBlock(ch, byChapter[ch.id] ?? const []),
    ];
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
      // UTF-16 截断点落在代理对中间（emoji 等增补字符）时回退 1 个码元，不劈开字符
      var cut = maxChapterChars;
      final u = text.codeUnitAt(cut - 1);
      if (u >= 0xD800 && u <= 0xDBFF) cut--;
      text =
          '${text.substring(0, cut)}\n……（本章其余内容截断，仅供地图参考）';
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
    ]..sort((a, b) {
        final byMajor = (b.major ? 1 : 0).compareTo(a.major ? 1 : 0);
        // id 次级排序键：List.sort 不稳定，同 major 时保证确定序（缓存键/重放一致）
        return byMajor != 0 ? byMajor : a.id.compareTo(b.id);
      });
    if (picked.isEmpty) return '（尚无，本批为开头）';
    return [
      for (final r in picked.take(80))
        '${r.name}：${r.aliasesJson.isEmpty ? '（暂无人设）' : r.aliasesJson}${r.major ? '【主要】' : ''}',
    ].join('\n');
  }

  /// 落库（单事务）：人物增量 → cast 解析 → 事件 → 章行（summary/map_done/cast_ids）。
  /// 返回实际完成章数（响应缺章/摘要为空的不计；已 mapDone 章不写不计数）。
  Future<int> _apply(int projectId, List<Chapter> batch,
      Map<String, dynamic> result) async {
    final entries = _parseResult(result); // 解析先行：失败走降批，不产生半途写库
    final rows = await (_db.select(_db.characters)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    final idByName = {for (final r in rows) r.name: r.id};
    var done = 0;
    await _db.transaction(() async {
      for (final ch in batch) {
        // 洞口续批包含已完成章（重试漏章的设计意图）：跳过不重写、done 不重复计数
        if (ch.mapDone) continue;
        final e = entries[ch.idx];
        if (e == null) continue; // 模型漏章：不置 map_done，下轮重试
        if (e.summary.isEmpty) continue;
        for (final c in e.characters) {
          final existingId = idByName[c.name];
          if (existingId == null) {
            idByName[c.name] = await _db.into(_db.characters).insert(
                CharactersCompanion.insert(
                    projectId: projectId, name: c.name,
                    aliasesJson: Value(c.profile), major: Value(c.major)));
          } else if (c.profile.isNotEmpty || c.major) {
            await (_db.update(_db.characters)
                  ..where((t) => t.id.equals(existingId)))
                .write(CharactersCompanion(
                    aliasesJson: c.profile.isNotEmpty
                        ? Value(c.profile)
                        : const Value.absent(),
                    major:
                        c.major ? const Value(true) : const Value.absent()));
          }
        }
        final castIds = <int>[];
        for (final name in e.cast) {
          var cid = idByName[name];
          if (cid == null) {
            cid = await _db.into(_db.characters).insert(
                CharactersCompanion.insert(projectId: projectId, name: name));
            idByName[name] = cid;
          }
          castIds.add(cid);
        }
        // 幂等兜底：先删本章旧事件再插（表无唯一约束，防重复膨胀）
        await (_db.delete(_db.characterEvents)
              ..where((t) => t.projectId.equals(projectId) &
                  t.chapterIdx.equals(ch.idx)))
            .go();
        for (final ev in e.events) {
          final cid = idByName[ev.name];
          if (cid == null) continue;
          await _db.into(_db.characterEvents).insert(
              CharacterEventsCompanion.insert(
                  projectId: projectId, characterId: cid,
                  chapterIdx: ch.idx, event: ev.event));
        }
        await (_db.update(_db.chapters)..where((t) => t.id.equals(ch.id)))
            .write(ChaptersCompanion(
                summary: Value(e.summary),
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

/// 响应条目的解析视图（解析层产出，落库层只消费，落库路径不再触碰原始动态结构）。
class _MapEntry {
  const _MapEntry({
    required this.summary,
    required this.characters,
    required this.cast,
    required this.events,
  });
  final String summary;
  final List<({String name, String profile, bool major})> characters;
  final List<String> cast;
  final List<({String name, String event})> events;
}

/// 解析模型响应 → {章 idx: 条目}。只包解析、不包落库（落库 bug 不得被伪装成
/// 模型错误）：顶层 chapters 非数组等形状错误转 LlmJsonException 走既有降批路径；
/// 元素非 Map / 字段类型错就地跳过。catch 兜住 TypeError——惰性 cast 绕过
/// on LlmJsonException 直冒 step、而毒响应已入缓存会导致重试永久失败。
Map<int, _MapEntry> _parseResult(Map<String, dynamic> result) {
  try {
    final raw = result['chapters'];
    if (raw == null) return const <int, _MapEntry>{};
    if (raw is! List) {
      throw LlmJsonException('地图响应 chapters 不是数组（${raw.runtimeType}）');
    }
    final entries = <int, _MapEntry>{};
    for (final e in raw.whereType<Map>()) {
      if (e['idx'] is! num) continue;
      final characters = <({String name, String profile, bool major})>[];
      if (e['characters'] is List) {
        for (final c in (e['characters'] as List).whereType<Map>()) {
          final name = (c['name'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          characters.add((
            name: name,
            profile: (c['profile'] ?? '').toString().trim(),
            major: c['major'] == true,
          ));
        }
      }
      final cast = <String>[];
      if (e['cast'] is List) {
        for (final n in e['cast'] as List) {
          final name = n.toString().trim();
          if (name.isNotEmpty) cast.add(name);
        }
      }
      final events = <({String name, String event})>[];
      if (e['events'] is List) {
        for (final ev in (e['events'] as List).whereType<Map>()) {
          final event = (ev['event'] ?? '').toString().trim();
          if (event.isEmpty) continue;
          events.add((name: (ev['name'] ?? '').toString().trim(), event: event));
        }
      }
      entries[(e['idx'] as num).toInt()] = _MapEntry(
        summary: (e['summary'] ?? '').toString().trim(),
        characters: characters,
        cast: cast,
        events: events,
      );
    }
    return entries;
  } on TypeError catch (e) {
    throw LlmJsonException('地图响应结构异常: $e');
  }
}
