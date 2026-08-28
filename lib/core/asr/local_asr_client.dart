import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:peixi/core/asr/asr_client.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// 本地 ASR（sherpa-onnx paraformer-zh-2024-03-09 int8，离线推理）。
///
/// 与云端 AsrClient 的产物同构（NormalizedAsr）。
/// 已知限制（交付说明 M2 已注明）：
/// - 本地 paraformer 无说话人分离 → 所有句子 speaker 归一为 SPEAKER_00；
/// - 无 VAD，按 30s 窗切块、窗口边界吸附到低能量点，边界仍可能截词；
/// - int8 量化精度略低于云端 paraformer-v2。
class LocalAsrClient {
  LocalAsrClient({required this.modelDir, this.loadWave = _sherpaLoadWave});

  final String modelDir;

  /// 音频加载器（默认 sherpa readWave，仅支持 WAV；测试可注入）
  final sherpa.WaveData Function(String path) loadWave;

  static sherpa.WaveData _sherpaLoadWave(String path) => sherpa.readWave(path);

  static const _sampleRate = 16000;
  static const _windowSec = 30;

  bool get isReady =>
      File('$modelDir/model.int8.onnx').existsSync() &&
      File('$modelDir/tokens.txt').existsSync();

  /// 模型目录查找顺序：①appSupport/models/asr ②exe 同级 models/asr（Windows 便携）
  static Future<String> defaultLocalModelDir() async {
    final support = await getApplicationSupportDirectory();
    final primary = '${support.path}/models/asr';
    if (Directory(primary).existsSync()) return primary;
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final portable = '$exeDir/models/asr';
      if (Directory(portable).existsSync()) return portable;
    } catch (_) {}
    return primary;
  }

  Future<NormalizedAsr> recognize(String audioPath) async {
    if (!isReady) {
      throw AsrException(
          '本地 ASR 模型缺失（$modelDir）。请运行 tool/download-sherpa-model.sh 下载模型，'
          '并将 models/asr 目录放到应用支持目录（或 Windows exe 同级目录）。');
    }
    final wave = loadWave(audioPath);
    if (wave.samples.isEmpty) {
      return const NormalizedAsr(durationMs: 0, sentences: []);
    }
    final samples = wave.sampleRate == _sampleRate
        ? wave.samples
        : linearResample(wave.samples, wave.sampleRate, _sampleRate);

    final recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          paraformer: sherpa.OfflineParaformerModelConfig(
              model: '$modelDir/model.int8.onnx'),
          tokens: '$modelDir/tokens.txt',
          modelType: 'paraformer',
          numThreads: 1,
        ),
      ),
    );

    final tokens = <String>[];
    final tsSec = <double>[];
    final windowSamples = _sampleRate * _windowSec;
    var start = 0;
    try {
      while (start < samples.length) {
        var end = start + windowSamples;
        if (end >= samples.length) {
          end = samples.length;
        } else {
          end = _snapToLowEnergy(samples, end);
        }
        final chunk = Float32List.sublistView(samples, start, end);
        final stream = recognizer.createStream();
        stream.acceptWaveform(samples: chunk, sampleRate: _sampleRate);
        recognizer.decode(stream);
        final r = recognizer.getResult(stream);
        for (var i = 0; i < r.tokens.length; i++) {
          final t = i < r.timestamps.length ? r.timestamps[i] : 0.0;
          tokens.add(r.tokens[i]);
          tsSec.add(t + start / _sampleRate);
        }
        stream.free();
        start = end;
      }
    } finally {
      recognizer.free();
    }

    final durationMs = samples.length * 1000 ~/ _sampleRate;
    final sentences = buildSentencesFromTokens(tokens, tsSec);
    return NormalizedAsr(durationMs: durationMs, sentences: sentences);
  }

  /// 在 ±0.25s 邻域内找 20ms 帧能量最低的位置切窗，减少截词。
  static int _snapToLowEnergy(Float32List samples, int cutAt) {
    const radius = 4000; // ±0.25s @16k
    const frame = 320; // 20ms
    final lo = max(0, cutAt - radius);
    final hi = min(samples.length - 1, cutAt + radius);
    var best = cutAt;
    var bestEnergy = double.infinity;
    for (var s = lo; s + frame <= hi; s += frame) {
      var acc = 0.0;
      for (var i = s; i < s + frame; i++) {
        acc += samples[i] * samples[i];
      }
      if (acc < bestEnergy) {
        bestEnergy = acc;
        best = s;
      }
    }
    return best;
  }
}

/// 纯逻辑：离线识别的 token+时间戳 → 句子列表（DashScope 同构）。
/// 切句依据（优先级）：标点结尾 > 静音间隙(gapSec) > 句长上限(maxTokens)。
/// 时间戳为每 token 的绝对秒；本地模型无说话人分离，全部归 SPEAKER_00。
List<AsrSentence> buildSentencesFromTokens(
    List<String> tokens, List<double> tsSec,
    {double gapSec = 0.6, int maxTokens = 30}) {
  final sentences = <AsrSentence>[];
  if (tokens.isEmpty) return sentences;
  final punct = RegExp(r'[，。！？；、,.!?;:]$');

  void flush(int beginIdx, int endIdx) {
    final text = tokens.sublist(beginIdx, endIdx + 1).join().trim();
    if (text.isEmpty) return;
    final beginMs = tsSec.length > beginIdx
        ? (tsSec[beginIdx] * 1000).round()
        : 0;
    final endMs = tsSec.length > endIdx
        ? ((tsSec[endIdx] + 0.3) * 1000).round()
        : beginMs + text.length * 200;
    sentences.add(AsrSentence(
        beginMs: beginMs, endMs: endMs, text: text, speakerId: 'SPEAKER_00'));
  }

  if (tsSec.length < tokens.length) {
    flush(0, tokens.length - 1); // 时间戳缺失：整段一句
    return sentences;
  }

  var beginIdx = 0;
  for (var i = 0; i < tokens.length; i++) {
    final isLast = i == tokens.length - 1;
    final gap = isLast ? 0.0 : tsSec[i + 1] - tsSec[i];
    final hitPunct = punct.hasMatch(tokens[i]);
    if (isLast || hitPunct || gap > gapSec || i - beginIdx + 1 >= maxTokens) {
      flush(beginIdx, i);
      beginIdx = i + 1;
    }
  }
  return sentences;
}

/// 简单线性重采样（目标 16k；extractAudio 通常已产出 16k wav，此为兜底）。
Float32List linearResample(Float32List input, int srcRate, int dstRate) {
  if (srcRate == dstRate || input.isEmpty) return input;
  final ratio = srcRate / dstRate;
  final outLen = (input.length / ratio).floor();
  final out = Float32List(outLen);
  for (var i = 0; i < outLen; i++) {
    final pos = i * ratio;
    final i0 = pos.floor();
    final i1 = min(i0 + 1, input.length - 1);
    final frac = pos - i0;
    out[i] = input[i0] * (1 - frac) + input[i1] * frac;
  }
  return out;
}
