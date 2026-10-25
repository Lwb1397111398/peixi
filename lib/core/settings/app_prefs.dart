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
