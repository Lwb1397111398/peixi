import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:peixi/core/settings/api_config.dart';

/// 阿里云 OSS V1 签名客户端（S4 上传 / 签名 GET URL / S5 后删除）。
/// 自实现而非三方包：签名逻辑纯本地可单测，且 PUT 20MB 音频无需分片。
class OssClient {
  OssClient(this.dio, this.config, {DateTime Function()? clock})
      : _clockNullable = clock;
  final Dio dio;
  final OssConfig config;
  final DateTime Function()? _clockNullable;
  late final DateTime Function() _clock = _clockNullable ?? DateTime.now;

  String get _host => '${config.bucket}.${config.endpoint}';
  String objectUrl(String key) => 'https://$_host/${_encodeKey(key)}';

  static String _encodeKey(String key) => key
      .split('/')
      .map((s) => Uri.encodeComponent(s))
      .join('/');

  /// CanonicalizedResource = /bucket/key（key 未编码参与签名）
  String _stringToSign(String verb, String key,
      {required String dateOrExpires,
      String contentType = '',
      String contentMd5 = '',
      Map<String, String> ossHeaders = const {}}) {
    final canonicalHeaders = (ossHeaders.keys.toList()
          ..sort())
        .map((k) => '${k.toLowerCase()}:${ossHeaders[k]!}\n')
        .join();
    return '$verb\n$contentMd5\n$contentType\n$dateOrExpires\n'
        '$canonicalHeaders/${config.bucket}/$key';
  }

  String _hmacSign(String stringToSign) =>
      base64Encode(Hmac(sha1, utf8.encode(config.accessKeySecret))
          .convert(utf8.encode(stringToSign))
          .bytes);

  /// 上传文件（单次 PUT + 进度回调）。设计稿的"分片上传"对 ~20MB 音频无必要（偏离#1）。
  Future<void> putFile(File file, String key,
      {String contentType = 'audio/mpeg',
      void Function(double)? onProgress}) async {
    final date = HttpDate.format(_clock().toUtc());
    final signature = _hmacSign(_stringToSign('PUT', key,
        dateOrExpires: date, contentType: contentType));
    final bytes = await file.readAsBytes();
    final resp = await dio.put(objectUrl(key),
        data: Stream.fromIterable([bytes]),
        options: Options(
          validateStatus: (_) => true,
          headers: {
            'Date': date,
            'Content-Type': contentType,
            'Content-Length': bytes.length,
            'Authorization':
                'OSS ${config.accessKeyId}:$signature',
          },
        ),
        onSendProgress: (c, t) => onProgress?.call(t == 0 ? 0 : (c / t).clamp(0.0, 1.0)));
    if (resp.statusCode != 200) {
      throw OssException('OSS PUT 失败 ${resp.statusCode}: ${resp.data}');
    }
  }

  /// 生成限时签名 GET URL（供 ASR 拉取）。
  String signedGetUrl(String key, {Duration expires = const Duration(hours: 24)}) {
    final exp = _clock().toUtc().add(expires).millisecondsSinceEpoch ~/ 1000;
    final signature =
        _hmacSign(_stringToSign('GET', key, dateOrExpires: exp.toString()));
    return '${objectUrl(key)}'
        '?Expires=$exp'
        '&OSSAccessKeyId=${Uri.encodeQueryComponent(config.accessKeyId)}'
        '&Signature=${Uri.encodeQueryComponent(signature)}';
  }

  Future<void> deleteObject(String key) async {
    final date = HttpDate.format(_clock().toUtc());
    final signature =
        _hmacSign(_stringToSign('DELETE', key, dateOrExpires: date));
    final resp = await dio.delete(objectUrl(key),
        options: Options(
          validateStatus: (_) => true,
          headers: {
            'Date': date,
            'Authorization': 'OSS ${config.accessKeyId}:$signature',
          },
        ));
    // 2xx 或 404（已不存在）都算成功
    if (resp.statusCode != null &&
        resp.statusCode! >= 200 &&
        resp.statusCode! < 300) {
      return;
    }
    if (resp.statusCode != 404) {
      throw OssException('OSS DELETE 失败 ${resp.statusCode}: ${resp.data}');
    }
  }
}

class OssException implements Exception {
  OssException(this.message);
  final String message;
  @override
  String toString() => 'OssException: $message';
}
