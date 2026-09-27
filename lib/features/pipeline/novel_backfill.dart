import 'package:drift/drift.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';

/// v4→v5 旧项目回填（设计文档 §5）：
/// ①summary 非空 → map_done=1；②meta.annotatedPara ≥ end_para → annot_done=1；
/// ③旧 meta.digest → 首个未批注章的 digest_before（旧断点的"故事至今"）；
/// ④批注/人物/知识卡原样保留（不触碰）；⑤annotatedPara 保留不再使用。
Future<void> backfillNovelV5(AppDatabase db) async {
  final novels = await (db.select(db.projects)
        ..where((t) => t.type.equals('novel')))
      .get();
  for (final p in novels) {
    final meta = NovelMeta.fromJson(p.metaJson);
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
    meta
      ..chapterCount = chapters.length
      ..annotatedChapters = annotCount;
    await (db.update(db.projects)..where((t) => t.id.equals(p.id))).write(
        ProjectsCompanion(metaJson: Value(meta.encode())));
  }
}
