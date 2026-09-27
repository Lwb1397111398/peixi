import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:peixi/core/database/app_database.dart';

/// v4→v5 旧项目回填（设计文档 §5）：
/// ①summary 非空 → map_done=1；②meta.annotatedPara ≥ end_para → annot_done=1；
/// ③旧 meta.digest → 首个未批注章的 digest_before（旧断点的"故事至今"）；
/// ④批注/人物/知识卡原样保留（不触碰）；⑤annotatedPara 保留不再使用。
///
/// meta 只取/回写 digest、annotatedPara、chapterCount、annotatedChapters，
/// 直接 jsonDecode 原对象改字段后 jsonEncode（其余键原样保留）。不 import
/// features/pipeline/novel_importer.dart 的 NovelMeta，避免 core→features
/// 反向依赖。
Future<void> backfillNovelV5(AppDatabase db) async {
  final novels = await (db.select(db.projects)
        ..where((t) => t.type.equals('novel')))
      .get();
  for (final p in novels) {
    final meta = _NovelMetaLite.parse(p.metaJson);
    final chapters = await (db.select(db.chapters)
          ..where((t) => t.projectId.equals(p.id))
          ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
        .get();
    if (chapters.isEmpty) continue;
    var annotCount = 0;
    Chapter? firstUnannot;
    for (final ch in chapters) {
      final mapDone = ch.summary != null && ch.summary!.isNotEmpty;
      final annotDone = meta.annotatedPara >= ch.endPara;
      if (annotDone) annotCount++;
      if (!annotDone && firstUnannot == null) firstUnannot = ch;
      if (!mapDone && !annotDone) continue;
      await (db.update(db.chapters)..where((t) => t.id.equals(ch.id))).write(
          ChaptersCompanion(
              mapDone: Value(mapDone), annotDone: Value(annotDone)));
    }
    final digest = meta.digest;
    final target = firstUnannot;
    if (digest != null && digest.isNotEmpty && target != null) {
      final targetId = target.id; // 闭包内取值：Chapter? 在 lambda 中不做类型提升
      await (db.update(db.chapters)..where((t) => t.id.equals(targetId)))
          .write(ChaptersCompanion(digestBefore: Value(digest)));
    }
    await (db.update(db.projects)..where((t) => t.id.equals(p.id))).write(
        ProjectsCompanion(
            metaJson: Value(meta.writeBackWith(
                chapterCount: chapters.length,
                annotatedChapters: annotCount))));
  }
}

/// metaJson 的轻量视图：解析出回填需要的两个字段，同时保留原 JSON 对象。
/// 容错语义与 NovelMeta.fromJson 一致：null/空/'null'/解析失败按空 meta 处理
/// （digest=null、annotatedPara=-1），不阻断迁移。
class _NovelMetaLite {
  _NovelMetaLite(this.raw, this.digest, this.annotatedPara);

  /// 解析成功的原 JSON 对象；失败/缺省时为空表（回写即丢弃脏值）。
  final Map<String, dynamic> raw;
  final String? digest;
  final int annotatedPara; // 缺省 -1：无断点凭据时不回填 annot_done

  static _NovelMetaLite parse(String? raw) {
    var map = <String, dynamic>{};
    String? digest;
    var annotatedPara = -1;
    if (raw != null && raw.isNotEmpty && raw != 'null') {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          map = Map<String, dynamic>.from(decoded);
          final d = map['digest'];
          if (d is String) digest = d;
          final ap = map['annotatedPara'];
          if (ap is num) annotatedPara = ap.toInt();
        }
      } catch (_) {
        // 脏 meta 按空处理
      }
    }
    return _NovelMetaLite(map, digest, annotatedPara);
  }

  /// 在原 JSON 对象上覆盖两个统计键后整体编码（未知键原样保留）。
  String writeBackWith(
      {required int chapterCount, required int annotatedChapters}) {
    raw['chapterCount'] = chapterCount;
    raw['annotatedChapters'] = annotatedChapters;
    return jsonEncode(raw);
  }
}
