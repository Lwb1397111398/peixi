import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/novel/novel_parser.dart';
import 'package:peixi/features/pipeline/project_status.dart';

/// 小说项目 meta_json（sourceFilename 键与视频 ProjectMeta 对齐，
/// 便于删除逻辑等共用代码读取；novel 专属字段为计数与批注进度）。
class NovelMeta {
  NovelMeta(
      {this.sourceFilename,
      this.paraCount = 0,
      this.charCount = 0,
      this.digest,
      this.annotatedPara = -1,
      this.chapterCount = 0,
      this.annotatedChapters = 0});

  String? sourceFilename;
  int paraCount;
  int charCount;

  /// N3 滚动前情摘要（Prompt E 产物，≤300 字，跨 run 保持）
  String? digest;

  /// N3 断点凭据：已批注完成的最大段落全局 idx。
  /// （v5 起两遍式管线改用 chapters.annot_done 按章断点，本字段保留不再使用。）
  int annotatedPara;

  /// v5：总章数（导入时回填；UI 徽章/进度用）
  int chapterCount;

  /// v5：已完成批注的章数（调度器进度徽章 denormalized 到 meta）
  int annotatedChapters;

  Map<String, dynamic> toJson() => {
        if (sourceFilename != null) 'sourceFilename': sourceFilename,
        'paraCount': paraCount,
        'charCount': charCount,
        if (digest != null) 'digest': digest,
        'annotatedPara': annotatedPara,
        'chapterCount': chapterCount,
        'annotatedChapters': annotatedChapters,
      };

  String encode() => jsonEncode(toJson());

  static NovelMeta fromJson(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return NovelMeta();
    final Map<String, dynamic> j;
    try {
      j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return NovelMeta();
    }
    return NovelMeta(
      sourceFilename: j['sourceFilename'] as String?,
      paraCount: (j['paraCount'] as num?)?.toInt() ?? 0,
      charCount: (j['charCount'] as num?)?.toInt() ?? 0,
      digest: j['digest'] as String?,
      annotatedPara: (j['annotatedPara'] as num?)?.toInt() ?? -1,
      chapterCount: (j['chapterCount'] as num?)?.toInt() ?? 0,
      annotatedChapters: (j['annotatedChapters'] as num?)?.toInt() ?? 0,
    );
  }
}

/// N1 入库：projects(type='novel') + chapters + paragraphs 一个事务写入。
/// paragraphs.idx 为全书全局序号（批注 para_range 锚定就用它），
/// chapters.start_para/end_para 指向该章正文首/末段落的全局 idx。
class NovelImporter {
  NovelImporter({required this.db});
  final AppDatabase db;

  static const _batchSize = 1000;

  Future<int> import({
    required String title,
    required String sourcePath,
    required NovelDoc doc,
  }) {
    return db.transaction(() async {
      final meta = NovelMeta(
          sourceFilename: sourcePath.split('/').last.split('\\').last,
          paraCount: doc.paragraphCount,
          charCount: doc.charCount,
          chapterCount: doc.chapters.length);
      final projectId =
          await db.into(db.projects).insert(ProjectsCompanion.insert(
                type: 'novel',
                title: title,
                sourcePath: sourcePath,
                status: ProjectStatus.imported.db,
                metaJson: Value(meta.encode()),
              ));

      var globalIdx = 0;
      for (final ch in doc.chapters) {
        final startPara = globalIdx;
        final chapterId =
            await db.into(db.chapters).insert(ChaptersCompanion.insert(
                  projectId: projectId,
                  idx: ch.idx,
                  title: Value(ch.title),
                  startPara: startPara,
                  endPara: ch.paragraphs.isEmpty
                      ? startPara
                      : startPara + ch.paragraphs.length - 1,
                ));
        for (var i = 0; i < ch.paragraphs.length; i += _batchSize) {
          final slice = ch.paragraphs.skip(i).take(_batchSize).toList();
          await db.batch((batch) {
            for (final para in slice) {
              batch.insert(
                  db.paragraphs,
                  ParagraphsCompanion.insert(
                    projectId: projectId,
                    chapterId: Value(chapterId),
                    idx: globalIdx++,
                    content: para,
                  ));
            }
          });
        }
      }
      return projectId;
    });
  }
}
