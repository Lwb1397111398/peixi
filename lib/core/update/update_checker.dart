import 'dart:convert';

/// 「最新版」发布的一条解析结果。
class ParsedRelease {
  const ParsedRelease({
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    required this.size,
    required this.notes,
  });

  final int versionCode;
  final String versionName;
  final String downloadUrl;
  final int size;
  final String notes;
}

/// Release 说明第一行的元数据注释：
/// `<!-- appupdate versionCode=21 versionName=0.1.21 -->`
/// （GitHub 页面渲染时不可见，App 用正则解析。）
final RegExp _metadataPattern =
    RegExp(r'<!--\s*appupdate\s+versionCode=(\d+)\s+versionName=(\S+?)\s*-->');

/// 从 Release 说明里解析元数据（只认第一行，避免正文里撞上同格式文本）。
({int versionCode, String versionName})? parseUpdateMetadata(String body) {
  if (body.isEmpty) return null;
  final firstLine = body.trimLeft().split('\n').first;
  final m = _metadataPattern.firstMatch(firstLine);
  if (m == null) return null;
  final code = int.tryParse(m.group(1)!);
  if (code == null) return null;
  return (versionCode: code, versionName: m.group(2)!);
}

/// 去掉元数据行后的更新说明（给用户看的部分）。
String stripMetadataLine(String body) {
  final lines = body.split('\n');
  if (lines.isEmpty) return body;
  if (_metadataPattern.hasMatch(lines.first)) return lines.skip(1).join('\n').trim();
  return body.trim();
}

/// 解析 GET /releases/latest 的响应 JSON。
/// [assetExtension] 按扩展名挑安装包资产（Windows 用 ".zip"）。
/// 没有元数据行 / 没有对应资产 → null（视为"无可更新信息"）。
ParsedRelease? parseLatestReleaseJson(String jsonText,
    {required String assetExtension}) {
  final dynamic root;
  try {
    root = jsonDecode(jsonText);
  } on FormatException {
    return null;
  }
  if (root is! Map<String, dynamic>) return null;
  final body = root['body'];
  if (body is! String) return null;
  final meta = parseUpdateMetadata(body);
  if (meta == null) return null;
  final assets = root['assets'];
  if (assets is! List) return null;
  for (final a in assets) {
    if (a is! Map<String, dynamic>) continue;
    final name = a['name'];
    if (name is! String || !name.toLowerCase().endsWith(assetExtension)) {
      continue;
    }
    final url = a['browser_download_url'];
    if (url is! String || url.isEmpty) continue;
    final size = a['size'];
    return ParsedRelease(
      versionCode: meta.versionCode,
      versionName: meta.versionName,
      downloadUrl: url,
      size: size is int ? size : 0,
      notes: stripMetadataLine(body),
    );
  }
  return null;
}

/// 远端版本号更大才算有更新（相同/更低都不弹窗）。
bool isNewer(ParsedRelease release, int currentVersionCode) =>
    release.versionCode > currentVersionCode;

/// 镜像前缀只拼 https://github.com/ 开头的地址；
/// 其他地址（本地假服务器、E2E 地址）原样返回 null 不拼，测试经参数注入假镜像。
String? applyMirror(String url, String mirrorPrefix) {
  if (mirrorPrefix.isEmpty) return url;
  if (!url.startsWith('https://github.com/')) return null;
  return '$mirrorPrefix$url';
}

/// 启动静默检查节流：距上次成功检查不足 [interval] 就不再查（null = 从未查过）。
bool shouldAutoCheck(int? lastCheckMs, DateTime now,
    {Duration interval = const Duration(hours: 24)}) {
  if (lastCheckMs == null) return true;
  return now.millisecondsSinceEpoch - lastCheckMs >= interval.inMilliseconds;
}
