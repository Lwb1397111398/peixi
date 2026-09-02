import 'dart:io';

import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:peixi/core/asr/asr_client.dart';
import 'package:peixi/core/asr/local_asr_client.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_service.dart';
import 'package:peixi/core/media/ffmpeg_service.dart';
import 'package:peixi/core/novel/novel_parser.dart';
import 'package:peixi/core/settings/api_config.dart';
import 'package:peixi/features/pipeline/novel_importer.dart';

/// 实测（真实原生链路，Windows 桌面运行）：
///   flutter test integration_test/real_pipeline_test.dart -d windows
/// 覆盖：
///   ① sherpa-onnx 本地 ASR 真识别（TTS 生成的真实中文语音）
///   ② ffmpeg-kit 真视频：探测/抽音频(16k mono wav)/抽帧
///   ③ GBK 小说真实解码 → 切章 → 真实文件级 SQLite 入库
///   ④ 云端 LLM/ASR 真实网络错误处理（无效 key → 干净可读异常）
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('peixi_e2e');
  });
  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  testWidgets('① 本地 ASR 真识别（sherpa-onnx + TTS 中文语音，后台 isolate）',
      (tester) async {
    // 真实下载的模型目录（tool/download-sherpa-model.sh 产物）
    final modelDir = Directory('models/asr').absolute.path;
    expect(LocalAsrClient(modelDir: modelDir).isReady, isTrue,
        reason: '请先运行 tool/download-sherpa-model.sh');
    final wav = File('integration_test/assets/tts_zh.wav').absolute.path;
    // 走正式调用路径（后台 isolate），验证 isolate 内 FFI 绑定初始化可用
    final norm = await LocalAsrClient.recognizeInBackground(
        modelDir: modelDir, audioPath: wav);

    final text = norm.sentences.map((s) => s.text).join('/');
    // ignore: avoid_print
    print('=== 本地 ASR 识别结果: $text');
    expect(norm.durationMs, greaterThan(5000), reason: 'TTS 音频约 8 秒');
    expect(norm.sentences, isNotEmpty);
    expect(norm.sentences.every((s) => s.speakerId == 'SPEAKER_00'), isTrue);
    // 中文 TTS 语音，识别文本应命中播报关键词（模糊匹配防口音/同音字）
    final joined = norm.sentences.map((s) => s.text).join();
    expect(
      ['陪析', '解说', '工具', '少年', '青萍', '背剑'].any(joined.contains),
      isTrue,
      reason: '识别文本应包含播报内容关键词，实际: $joined',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('② ffmpeg-kit 真实链路：生成视频→探测→抽音频→抽帧', (tester) async {
    final videoPath = '${tmp.path}/testsrc.mp4';
    final session = await FFmpegKit.execute(
        '-y -f lavfi -i testsrc=duration=5:size=320x240:rate=15 '
        '-f lavfi -i sine=frequency=440:duration=5 '
        '-c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$videoPath"');
    expect(await session.getReturnCode(), ReturnCode.isSuccess,
        reason: 'ffmpeg-kit full-gpl 应能生成测试视频');

    final svc = FFmpegKitService();
    final info = await svc.probe(videoPath);
    // ignore: avoid_print
    print('=== probe: ${info.durationMs}ms, 有音轨=${info.durationMs > 0}');
    expect(info.durationMs, inInclusiveRange(4300, 5800));

    final wav = '${tmp.path}/out.wav';
    await svc.extractAudio(videoPath, wav);
    final wavFile = File(wav);
    expect(wavFile.existsSync(), isTrue);
    // 16k mono 16bit × 5s ≈ 160KB
    expect(wavFile.lengthSync(), greaterThan(100000));

    final jpg = '${tmp.path}/frame.jpg';
    await svc.extractKeyframe(videoPath, 2000, jpg);
    expect(File(jpg).existsSync(), isTrue);
    expect(File(jpg).lengthSync(), greaterThan(1000));
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('③ GBK 小说真实解码 → 切章 → 文件级 SQLite 入库', (tester) async {
    final gbkPath = File('integration_test/assets/novel_gbk.txt').absolute.path;
    final doc = parseNovel(decodeNovelText(File(gbkPath).readAsBytesSync()));
    expect(doc.chapters.map((c) => c.title).toList(),
        ['第一章 山门', '第二章 客栈'],
        reason: 'GBK 编码必须被正确检测与解码');

    final db = AppDatabase(NativeDatabase(File('${tmp.path}/novel.sqlite')));
    final id = await NovelImporter(db: db)
        .import(title: 'GBK测试', sourcePath: gbkPath, doc: doc);
    final paras = await (db.select(db.paragraphs)
          ..where((t) => t.projectId.equals(id)))
        .get();
    expect(paras.map((e) => e.content).toList(), [
      '少年背剑而行，晨雾还未散尽。',
      '他叫沈砚，是山门里最沉默的弟子。',
      '店家压低了声音："那位客人不简单。"',
      '沈砚握紧了剑柄，指节发白。',
    ]);
    final chapters = await (db.select(db.chapters)
          ..where((t) => t.projectId.equals(id)))
        .get();
    expect(chapters[1].startPara, 2);
    expect(chapters[1].endPara, 3);
    await db.close();
  });

  testWidgets('④ 云端真实网络错误处理（无效 key）', (tester) async {
    // LLM：真实请求 dashscope，无效 key → LlmException（非崩溃）
    final db = AppDatabase(NativeDatabase.memory());
    final llm = LlmService(db: db, dio: Dio());
    llm.updateConfig(const ApiConfig(
        baseUrl: ApiConfig.bailianBaseUrl, apiKey: 'sk-invalid-e2e-key'));
    Object? caught;
    try {
      await llm.chat(
          [const {'role': 'user', 'content': '你好'}],
          tier: LlmTier.cheap);
    } catch (e) {
      caught = e;
    }
    expect(caught, isA<LlmException>(),
        reason: '无效 key 必须抛干净的 LlmException');
    // ignore: avoid_print
    print('=== 云端 LLM 真实错误响应: $caught');
    expect((caught as LlmException).toString(), isNot(isEmpty));
    await db.close();

    // ASR 提交端点：无效 key → AsrException
    final asr = AsrClient(Dio());
    Object? asrErr;
    try {
      await asr.submit('sk-invalid-e2e-key', 'https://peixi.invalid/a.mp3');
    } catch (e) {
      asrErr = e;
    }
    expect(asrErr, isA<AsrException>());
    // ignore: avoid_print
    print('=== 云端 ASR 真实错误响应: $asrErr');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
