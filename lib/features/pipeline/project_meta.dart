import 'dart:convert';

import 'package:peixi/core/media/ffmpeg_service.dart';

/// 阅读进度（小说项目）：章节下标 + 滚动偏移，恢复上次阅读位置。
class ReadingProgress {
  ReadingProgress({required this.chapterIdx, required this.scrollOffset});
  final int chapterIdx;
  final double scrollOffset;
}

/// projects.meta_json 的结构化读写（S1 探测结果 + 各阶段中间产物）。
/// 规范化 ASR 结果（设计稿"核心中间产物"）存在 [asrNormalized]。
class ProjectMeta {
  ProjectMeta({
    this.sourceFilename,
    this.episode,
    this.durationMs = 0,
    this.hasSubtitle = false,
    this.audioFormat,
    List<SubtitleEntry>? subtitle,
    this.ossKey,
    this.asrTaskId,
    this.asrNormalized,
    this.digest,
    this.mediaMissing = false,
    this.readingProgress,
  });

  String? sourceFilename;
  int? episode;
  int durationMs;
  bool hasSubtitle;
  String? audioFormat; // mp3|m4a|wav
  List<SubtitleEntry>? subtitle; // S2 产物，null = 无流或提取失败
  String? ossKey; // S4 产物
  String? asrTaskId; // S5 断点续跑凭据（app 被杀后凭它续轮询）
  Map<String, dynamic>? asrNormalized; // {"duration_ms":..,"sentences":[..]}
  String? digest; // S9 前情滚动摘要（跨 run 保持）

  /// 项目包迁移标记：视频本体不在包内（仅解说/问答可看，重播需重新导入视频）
  bool mediaMissing;

  /// 阅读进度（小说项目，设计稿 8.4 进度记忆）
  ReadingProgress? readingProgress;

  String audioPath(String audioDir, int projectId) =>
      '$audioDir/$projectId.${audioFormat ?? 'mp3'}';

  Map<String, dynamic> toJson() => {
        if (sourceFilename != null) 'sourceFilename': sourceFilename,
        if (episode != null) 'episode': episode,
        'durationMs': durationMs,
        'hasSubtitle': hasSubtitle,
        if (audioFormat != null) 'audioFormat': audioFormat,
        if (subtitle != null)
          'subtitle': [for (final s in subtitle!) s.toJson()],
        if (ossKey != null) 'ossKey': ossKey,
        if (asrTaskId != null) 'asrTaskId': asrTaskId,
        if (asrNormalized != null) 'asrNormalized': asrNormalized,
        if (digest != null) 'digest': digest,
        if (mediaMissing) 'mediaMissing': true,
        if (readingProgress != null)
          'reading': {
            'chapterIdx': readingProgress!.chapterIdx,
            'scrollOffset': readingProgress!.scrollOffset,
          },
      };

  String encode() => jsonEncode(toJson());

  static ProjectMeta fromJson(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return ProjectMeta();
    final Map<String, dynamic> j;
    try {
      j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return ProjectMeta();
    }
    return ProjectMeta(
      sourceFilename: j['sourceFilename'] as String?,
      episode: j['episode'] as int?,
      durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
      hasSubtitle: j['hasSubtitle'] == true,
      audioFormat: j['audioFormat'] as String?,
      subtitle: (j['subtitle'] as List?)
          ?.map((e) => SubtitleEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      ossKey: j['ossKey'] as String?,
      asrTaskId: j['asrTaskId'] as String?,
      asrNormalized: j['asrNormalized'] == null
          ? null
          : Map<String, dynamic>.from(j['asrNormalized'] as Map),
      digest: j['digest'] as String?,
      mediaMissing: j['mediaMissing'] == true,
      readingProgress: j['reading'] == null
          ? null
          : ReadingProgress(
              chapterIdx:
                  ((j['reading'] as Map)['chapterIdx'] as num?)?.toInt() ?? 0,
              scrollOffset: ((j['reading'] as Map)['scrollOffset'] as num?)
                      ?.toDouble() ??
                  0.0,
            ),
    );
  }
}
