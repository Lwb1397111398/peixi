/// 语音识别模式（M2 双模式）：cloud=DashScope 录音文件识别（需 OSS 中转），
/// local=sherpa-onnx 离线识别（无说话人分离、无需 OSS）。
enum AsrMode { cloud, local }

class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.apiKey,
    this.modelCheap = 'qwen-flash',
    this.modelStandard = 'qwen-plus',
    this.modelVision = 'qwen-vl-plus',
  });

  static const bailianBaseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1';

  final String baseUrl;
  final String apiKey;
  final String modelCheap;
  final String modelStandard;

  /// 视觉模型（M3 实验性视觉辅助：关键帧判断谁在说话）
  final String modelVision;

  bool get isComplete => baseUrl.isNotEmpty && apiKey.isNotEmpty;
}

class OssConfig {
  const OssConfig({
    required this.bucket,
    required this.endpoint,
    required this.accessKeyId,
    required this.accessKeySecret,
  });
  final String bucket;
  final String endpoint; // 形如 oss-cn-beijing.aliyuncs.com
  final String accessKeyId;
  final String accessKeySecret;
  bool get isComplete =>
      bucket.isNotEmpty &&
      endpoint.isNotEmpty &&
      accessKeyId.isNotEmpty &&
      accessKeySecret.isNotEmpty;
}

/// 弹幕提问偏好（设计稿 8.2/8.6 默认值）
class PlayPrefs {
  const PlayPrefs({
    this.quizEnabled = true,
    this.maxPerEpisode = 5,
    this.minGapMinutes = 4,
    this.triggerRatio = 0.3,
    this.keepTempAudio = true,
    this.playbackRate = 1.0,
  });
  final bool quizEnabled;
  final int maxPerEpisode;
  final int minGapMinutes;
  final double triggerRatio;
  final bool keepTempAudio;
  final double playbackRate;

  PlayPrefs copyWith({
    bool? quizEnabled,
    int? maxPerEpisode,
    int? minGapMinutes,
    double? triggerRatio,
    bool? keepTempAudio,
    double? playbackRate,
  }) =>
      PlayPrefs(
        quizEnabled: quizEnabled ?? this.quizEnabled,
        maxPerEpisode: maxPerEpisode ?? this.maxPerEpisode,
        minGapMinutes: minGapMinutes ?? this.minGapMinutes,
        triggerRatio: triggerRatio ?? this.triggerRatio,
        keepTempAudio: keepTempAudio ?? this.keepTempAudio,
        playbackRate: playbackRate ?? this.playbackRate,
      );
}

/// 阅读器偏好（设计稿 8.4：字号/行距/背景色含夜间）
enum ReaderTheme { paper, sepia, night }

class ReaderPrefs {
  const ReaderPrefs({
    this.fontSize = 17,
    this.lineHeight = 1.7,
    this.theme = ReaderTheme.paper,
  });
  final double fontSize;
  final double lineHeight;
  final ReaderTheme theme;
}
