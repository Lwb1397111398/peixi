import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/asr/asr_client.dart';
import 'package:peixi/core/asr/local_asr_client.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

void main() {
  group('buildSentencesFromTokens（token→句子纯逻辑）', () {
    test('静音间隙切句 + ms 换算 + 全部 SPEAKER_00', () {
      // "你好" 0-0.5s，停顿 1s，"我是谁" 1.5-2.0s
      final tokens = ['你', '好', '我', '是', '谁'];
      final ts = [0.0, 0.4, 1.5, 1.7, 1.95];
      final sentences = buildSentencesFromTokens(tokens, ts);
      expect(sentences, hasLength(2));
      expect(sentences[0].text, '你好');
      expect(sentences[0].beginMs, 0);
      expect(sentences[0].endMs, greaterThanOrEqualTo(400));
      expect(sentences[1].text, '我是谁');
      expect(sentences[1].beginMs, 1500);
      expect(sentences.every((s) => s.speakerId == 'SPEAKER_00'), isTrue);
    });

    test('标点结尾优先切句', () {
      final tokens = ['好', '的', '。', '再', '见'];
      final ts = [0.0, 0.1, 0.2, 0.25, 0.5]; // 无明显间隙
      final sentences = buildSentencesFromTokens(tokens, ts);
      expect(sentences, hasLength(2));
      expect(sentences[0].text, '好的。');
      expect(sentences[1].text, '再见');
    });

    test('句长上限兜底切句（无标点无间隙）', () {
      final tokens = List.filled(65, '字');
      final ts = [for (var i = 0; i < 65; i++) i * 0.1]; // 间隙恒 0.1s < 0.6
      final sentences = buildSentencesFromTokens(tokens, ts);
      expect(sentences.length, greaterThanOrEqualTo(3));
      expect(sentences.every((s) => s.text.length <= 30), isTrue);
    });

    test('时间戳缺失 → 整段一句兜底', () {
      final sentences = buildSentencesFromTokens(['你', '好'], []);
      expect(sentences, hasLength(1));
      expect(sentences.single.text, '你好');
      expect(sentences.single.beginMs, 0);
    });

    test('空输入', () {
      expect(buildSentencesFromTokens([], []), isEmpty);
    });
  });

  group('LocalAsrClient', () {
    test('模型缺失 → isReady=false，recognize 抛可读 AsrException', () async {
      final dir = await Directory.systemTemp.createTemp('no_model');
      addTearDown(() => dir.deleteSync(recursive: true));
      final client = LocalAsrClient(modelDir: dir.path);
      expect(client.isReady, isFalse);
      await expectLater(
          client.recognize('/x.wav'), throwsA(isA<AsrException>()));
    });

    test('模型就绪判定（两个文件齐备）', () async {
      final dir = await Directory.systemTemp.createTemp('with_model');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/model.int8.onnx').writeAsBytesSync(List.filled(16, 0));
      File('${dir.path}/tokens.txt').writeAsStringSync('a b\n');
      expect(LocalAsrClient(modelDir: dir.path).isReady, isTrue);
    });

    test('可注入 loadWave（不触原生库）——空样本直接返回空结果', () async {
      final dir = await Directory.systemTemp.createTemp('with_model');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/model.int8.onnx').writeAsBytesSync(List.filled(16, 0));
      File('${dir.path}/tokens.txt').writeAsStringSync('a\n');
      final client = LocalAsrClient(
          modelDir: dir.path,
          loadWave: (path) => sherpa.WaveData(
              samples: Float32List(0), sampleRate: 16000));
      final r = await client.recognize('whatever.wav');
      expect(r.durationMs, 0);
      expect(r.sentences, isEmpty);
    });
  });

  group('linearResample', () {
    test('8k → 16k 长度翻倍、保持幅值', () {
      final input = Float32List.fromList([0.0, 0.5, 1.0, 0.5]);
      final out = linearResample(input, 8000, 16000);
      expect(out.length, 8);
      expect(out.first, 0.0);
      expect(out.last, closeTo(0.5, 1e-6));
    });

    test('同采样率原样返回', () {
      final input = Float32List.fromList([0.1, 0.2]);
      expect(identical(linearResample(input, 16000, 16000), input), isTrue);
    });
  });
}
