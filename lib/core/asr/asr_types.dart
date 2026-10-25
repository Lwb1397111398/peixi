/// ASR 共享数据类型（本地 sherpa-onnx 识别与下游管线共用）。
/// 语音识别只有本地模式；云端 DashScope 转写（曾依赖 OSS 中转）已移除。
library;

class AsrException implements Exception {
  AsrException(this.message);
  final String message;
  @override
  String toString() => 'AsrException: $message';
}

class AsrSentence {
  const AsrSentence({
    required this.beginMs,
    required this.endMs,
    required this.text,
    required this.speakerId,
  });
  final int beginMs;
  final int endMs;
  final String text;
  /// 规范化后的 "SPEAKER_XX"（本地模型无分离，恒为 SPEAKER_00）
  final String speakerId;
}

class NormalizedAsr {
  const NormalizedAsr({required this.durationMs, required this.sentences});
  final int durationMs;
  final List<AsrSentence> sentences;
}
