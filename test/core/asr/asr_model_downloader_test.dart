import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/asr/asr_model_downloader.dart';
import 'package:peixi/core/asr/local_asr_client.dart';

void main() {
  late HttpServer server;
  late Directory target;
  var requested = <String>[];

  setUp(() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    target = await Directory.systemTemp.createTemp('asr_model_test');
    requested = [];
  });
  tearDown(() async {
    await server.close(force: true);
    target.deleteSync(recursive: true);
  });

  String url() => 'http://127.0.0.1:${server.port}';

  /// 本地起一个"模型镜像"：tokens.txt 8 字节，model.int8.onnx 可配大小
  void serve({int modelBytes = 64 * 1024}) {
    server.listen((req) async {
      requested.add(req.uri.path);
      final Uint8List body = req.uri.path.contains('model')
          ? Uint8List(modelBytes)
          : Uint8List.fromList(List.filled(8, 0x61));
      req.response.contentLength = body.length;
      req.response.add(body);
      await req.response.close();
    });
  }

  AsrModelDownloader downloader({List<String>? mirrors, int? minModelBytes}) =>
      AsrModelDownloader(
          dio: Dio(),
          mirrors: mirrors ?? [url()],
          minModelBytes: minModelBytes ?? 1024);

  test('下载两个文件到目标目录，.part 清理，isReady 变 true', () async {
    serve();
    await downloader().download(target.path);

    expect(File('${target.path}/tokens.txt').lengthSync(), 8);
    expect(
        File('${target.path}/model.int8.onnx').lengthSync(), 64 * 1024);
    final leftovers = target.listSync().whereType<File>();
    expect(leftovers.any((f) => f.path.endsWith('.part')), isFalse);
    expect(LocalAsrClient(modelDir: target.path).isReady, isTrue);
  });

  test('首选镜像不可达时回退到下一镜像', () async {
    serve();
    // 127.0.0.1:1 连接被拒，模拟首选镜像宕机
    await downloader(mirrors: ['http://127.0.0.1:1', url()])
        .download(target.path);

    expect(File('${target.path}/tokens.txt').existsSync(), isTrue);
    expect(File('${target.path}/model.int8.onnx').existsSync(), isTrue);
    expect(requested.length, 2); // 两个文件都只落到备用镜像
  });

  test('模型小于阈值 → 抛 AsrModelDownloadException 且 .part 清理', () async {
    serve(modelBytes: 10);
    await expectLater(downloader().download(target.path),
        throwsA(isA<AsrModelDownloadException>()));

    final leftovers = target.listSync().whereType<File>();
    expect(leftovers.any((f) => f.path.endsWith('.part')), isFalse);
  });

  test('目标文件已有效时跳过下载，不发起网络请求', () async {
    File('${target.path}/tokens.txt').writeAsStringSync('tok');
    File('${target.path}/model.int8.onnx')
        .writeAsBytesSync(List.filled(2048, 0));
    serve();

    await downloader().download(target.path);

    expect(requested, isEmpty);
    expect(File('${target.path}/model.int8.onnx').lengthSync(), 2048);
  });

  test('进度回调回报文件名与累计字节', () async {
    serve();
    final events = <AsrModelDownloadProgress>[];
    await downloader().download(target.path, onProgress: events.add);

    final modelEvents = events.where((e) => e.file == 'model.int8.onnx');
    expect(modelEvents, isNotEmpty);
    final last = modelEvents.last;
    expect(last.received, greaterThan(0));
    expect(last.total, 64 * 1024); // 本地镜像回传 Content-Length
  });
}
