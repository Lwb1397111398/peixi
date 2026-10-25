/// projects.status 的枚举封装（设计稿第三节：状态一律 TEXT 存大写字面量）。
/// uploaded 是云端识别时代的残留值：云端模式（DashScope+OSS 中转）已移除，
/// 该状态仅为兼容旧库数据保留，新管线不会再写入。
enum ProjectStatus {
  imported('IMPORTED'),
  audioReady('AUDIO_READY'),
  uploaded('UPLOADED'),
  asrDone('ASR_DONE'),
  mapped('MAPPED'),
  waitCalibration('WAIT_CALIBRATION'),
  calibrated('CALIBRATED'),
  segmented('SEGMENTED'),
  commentaryDone('COMMENTARY_DONE'),
  ready('READY'),
  failed('FAILED');

  const ProjectStatus(this.db);
  final String db;

  static ProjectStatus fromDb(String s) =>
      values.firstWhere((e) => e.db == s, orElse: () => ProjectStatus.imported);
}

/// 各阶段的入口状态：FAILED 重试时回退到此状态重跑该阶段。
/// （upload 阶段已随云端识别移除；旧 failed_stage='upload' 的存量项目
/// 落到兜底 imported，音频缓存仍在会跳过重抽。）
ProjectStatus entryStatusOfStage(String stage) => switch (stage) {
      'subtitle' || 'audio' => ProjectStatus.imported,
      'asr' => ProjectStatus.uploaded,
      'map' => ProjectStatus.asrDone,
      'segment' => ProjectStatus.calibrated,
      'commentary' => ProjectStatus.segmented,
      'finalize' => ProjectStatus.commentaryDone,
      _ => ProjectStatus.imported,
    };

/// UI 进度条的阶段标签（媒体库卡片显示）。
String stageLabel(String stage) => switch (stage) {
      'subtitle' => '字幕提取',
      'audio' => '音频抽取',
      'asr' => '语音识别',
      'map' => '角色映射',
      'segment' => '场景切分',
      'commentary' => '解说生成',
      'finalize' => '收尾',
      'novel' => '处理中',
      _ => stage,
    };
