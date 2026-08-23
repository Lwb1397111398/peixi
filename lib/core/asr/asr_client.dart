import 'dart:convert';

import 'package:dio/dio.dart';

/// DashScope 录音文件识别（paraformer-v2）客户端。
/// 端点与参数已按 2026-08 实测核对（spec §3.1）：
/// 提交 POST /api/v1/services/audio/asr/transcription（X-DashScope-Async: enable）
/// 轮询 POST /api/v1/tasks/{task_id}，output.task_status ∈ PENDING/RUNNING/SUCCEEDED/FAILED
/// 结果 GET output.transcription_url（24h 有效），transcripts[].sentences[] 带
/// begin_time/end_time(ms)/text/speaker_id(int 0 基)。
enum AsrTaskPhase { pending, running, succeeded, failed }

class AsrPollResult {
  const AsrPollResult(
      {required this.phase, this.transcriptionUrl, this.message});
  final AsrTaskPhase phase;
  final String? transcriptionUrl;
  final String? message;
}

class AsrSentence {
  const AsrSentence(
      {required this.beginMs,
      required this.endMs,
      required this.text,
      required this.speakerId});
  final int beginMs;
  final int endMs;
  final String text;
  /// 规范化后的 "SPEAKER_XX"
  final String speakerId;
}

class NormalizedAsr {
  const NormalizedAsr({required this.durationMs, required this.sentences});
  final int durationMs;
  final List<AsrSentence> sentences;
}

class AsrException implements Exception {
  AsrException(this.message);
  final String message;
  @override
  String toString() => 'AsrException: $message';
}

class AsrClient {
  AsrClient(this.dio, {this.baseUrl = 'https://dashscope.aliyuncs.com'});
  final Dio dio;
  final String baseUrl;

  Map<String, dynamic> _parse(Response resp) {
    if (resp.statusCode != 200) {
      throw AsrException('ASR HTTP ${resp.statusCode}: ${resp.data}');
    }
    return resp.data as Map<String, dynamic>;
  }

  /// 提交转录任务，返回 task_id。
  Future<String> submit(String apiKey, String signedUrl) async {
    final resp = await dio.post('$baseUrl/api/v1/services/audio/asr/transcription',
        data: {
          'model': 'paraformer-v2',
          'input': {
            // OSS 签名 URL 已含 query，需整体再编码一次作为 file_urls 元素
            'file_urls': [Uri.encodeFull(signedUrl)],
          },
          'parameters': {
            'language_hints': ['zh'],
            'diarization_enabled': true,
            'timestamp_alignment_enabled': true,
          },
        },
        options: Options(validateStatus: (_) => true, headers: {
          'Authorization': 'Bearer $apiKey',
          'X-DashScope-Async': 'enable',
        }));
    final data = _parse(resp);
    final output = data['output'] as Map<String, dynamic>?;
    final taskId = output?['task_id'] as String?;
    if (taskId == null || taskId.isEmpty) {
      throw AsrException('ASR 提交未返回 task_id: ${resp.data}');
    }
    return taskId;
  }

  /// 轮询一次任务状态。
  Future<AsrPollResult> poll(String apiKey, String taskId) async {
    final resp = await dio.post('$baseUrl/api/v1/tasks/$taskId',
        options: Options(validateStatus: (_) => true, headers: {
          'Authorization': 'Bearer $apiKey',
        }));
    final data = _parse(resp);
    final output = (data['output'] as Map<String, dynamic>?) ?? {};
    final status = output['task_status'] as String? ?? '';
    final phase = switch (status) {
      'SUCCEEDED' => AsrTaskPhase.succeeded,
      'FAILED' => AsrTaskPhase.failed,
      'RUNNING' => AsrTaskPhase.running,
      _ => AsrTaskPhase.pending,
    };
    return AsrPollResult(
        phase: phase,
        transcriptionUrl: output['transcription_url'] as String?,
        message: output['message'] as String?);
  }

  /// 下载并解析结果 JSON → 规范化结构。
  Future<NormalizedAsr> downloadResult(String transcriptionUrl) async {
    final resp = await dio.get(transcriptionUrl,
        options: Options(
            validateStatus: (_) => true,
            responseType: ResponseType.plain));
    if (resp.statusCode != 200) {
      throw AsrException('下载转录结果失败 HTTP ${resp.statusCode}');
    }
    return parseAsrResultJson(resp.data is String
        ? resp.data as String
        : jsonEncode(resp.data));
  }
}

/// 原始结果 JSON → 规范化（设计稿第三节"核心中间产物"）。
/// 多 transcripts 取并集按 begin_time 排序；speaker_id int → SPEAKER_XX。
NormalizedAsr parseAsrResultJson(String raw) {
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final transcripts = (data['transcripts'] as List?) ?? [];
  final sentences = <AsrSentence>[];
  var durationMs = 0;
  for (final t in transcripts.cast<Map<String, dynamic>>()) {
    final d = t['duration_ms'];
    if (d is int && d > durationMs) durationMs = d;
    for (final s in ((t['sentences'] as List?) ?? []).cast<Map<String, dynamic>>()) {
      final begin = (s['begin_time'] as num?)?.toInt() ?? 0;
      final end = (s['end_time'] as num?)?.toInt() ?? begin;
      sentences.add(AsrSentence(
          beginMs: begin,
          endMs: end,
          text: (s['text'] as String?)?.trim() ?? '',
          speakerId: normalizeSpeakerId(s['speaker_id'])));
      if (end > durationMs) durationMs = end;
    }
  }
  sentences.sort((a, b) => a.beginMs.compareTo(b.beginMs));
  if (sentences.isEmpty && durationMs == 0) {
    throw AsrException('转录结果为空');
  }
  return NormalizedAsr(durationMs: durationMs, sentences: sentences);
}

String normalizeSpeakerId(Object? raw) {
  if (raw is String && raw.startsWith('SPEAKER_')) return raw;
  final n = raw is int ? raw : int.tryParse('$raw') ?? 0;
  return 'SPEAKER_${n.toString().padLeft(2, '0')}';
}
