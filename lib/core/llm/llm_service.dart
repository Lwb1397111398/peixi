import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/settings/api_config.dart';

class LlmException implements Exception {
  LlmException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'LlmException($statusCode): $message';
}

class LlmJsonException implements Exception {
  LlmJsonException(this.message);
  final String message;
  @override
  String toString() => 'LlmJsonException: $message';
}

/// 本月 token 用量达到设置页配置的预算上限时抛出；
/// 管线按普通阶段失败落盘，提示可直接被用户读懂。
class LlmBudgetException extends LlmException {
  LlmBudgetException(super.message);
}

/// LLM 调用唯一出口（设计稿 6.1）。业务代码禁止直连任何厂商 SDK。
class LlmService {
  LlmService({Dio? dio, required this.db, this.backoffBase = const Duration(seconds: 1)})
      : dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 5),
            ));

  final Dio dio;
  final AppDatabase db;
  final Duration backoffBase;
  ApiConfig? _config;

  void updateConfig(ApiConfig config) => _config = config;

  /// 当前配置（协作器读取模型名等；未配置时为 null）
  ApiConfig? get config => _config;

  /// 通用系统前缀。同时含中英文 json/JSON 字样：
  /// 百炼 json_object 模式要求 messages 中必须出现 "json"（spec 3.2）。
  static const jsonSystemPrefix =
      '只输出 json（JSON），不要 markdown 代码块，不要解释。'
      '不确定的信息明确说不确定，严禁编造剧情和设定。';

  /// 普通 chat。messages 形如 [{"role":"system","content":...},...]。
  Future<String> chat(
    List<Map<String, String>> messages, {
    LlmTier tier = LlmTier.standard,
    bool jsonMode = false,
    String purpose = '',
    int? projectId,
  }) =>
      _send(messages, tier: tier, jsonMode: jsonMode, purpose: purpose,
          projectId: projectId);

  /// 多模态（vision）调用：单条 user 消息 = 文本 + 图片 data URI。
  /// 用于 M3 实验性视觉辅助（关键帧判断"谁在说话"）。
  Future<String> chatVision({
    required String prompt,
    required String imageDataUri,
    LlmTier tier = LlmTier.standard,
    String purpose = 'vision',
    int? projectId,
  }) {
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      {
        'type': 'image_url',
        'image_url': {'url': imageDataUri},
      },
    ];
    return _send(
      [
        {
          'role': 'user',
          'content': content,
        }
      ],
      tier: tier,
      jsonMode: true,
      purpose: purpose,
      projectId: projectId,
      modelOverride: _config?.modelVision,
    );
  }

  Future<String> _send(
    List<dynamic> messages, {
    LlmTier tier = LlmTier.standard,
    bool jsonMode = false,
    String purpose = '',
    int? projectId,
    String? modelOverride,
  }) async {
    final cfg = _config;
    if (cfg == null || !cfg.isComplete) {
      throw LlmException('未配置 API（设置页填写 base_url 与 api_key）');
    }
    final model = modelOverride ?? cfg.modelOf(tier);
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      if (jsonMode) 'response_format': {'type': 'json_object'},
    };

    // 预算闸门（响应缓存命中时不经过这里，见 chatJson）
    await _checkBudget();

    const maxAttempts = 4; // 1 次原始 + 3 次重试（设计稿 6/9.1）
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(backoffBase * (1 << (attempt - 1))); // 1s/2s/4s
      }
      try {
        final resp = await dio.post('${cfg.baseUrl}/chat/completions',
            data: body,
            options: Options(
              validateStatus: (_) => true,
              headers: {'Authorization': 'Bearer ${cfg.apiKey}'},
            ));
        if (resp.statusCode == 200) {
          final data = resp.data as Map<String, dynamic>;
          final usage = (data['usage'] as Map<String, dynamic>?) ?? {};
          await db.into(db.llmLogs).insert(LlmLogsCompanion.insert(
                projectId: Value(projectId),
                purpose: purpose,
                model: model,
                promptTokens: Value((usage['prompt_tokens'] as int?) ?? 0),
                completionTokens:
                    Value((usage['completion_tokens'] as int?) ?? 0),
              ));
          final choices = data['choices'] as List;
          return ((choices[0] as Map)['message'] as Map)['content'] as String;
        }
        final msg = _extractErrorMessage(resp.data) ?? 'HTTP ${resp.statusCode}';
        if (_retryable(resp.statusCode)) {
          lastError = LlmException(msg, statusCode: resp.statusCode);
          continue;
        }
        throw LlmException(msg, statusCode: resp.statusCode);
      } on DioException catch (e) {
        lastError = LlmException('网络错误: ${e.message}');
        continue; // 网络类错误一律重试（设计稿 9.1）
      }
    }
    throw lastError ?? LlmException('重试次数耗尽');
  }

  /// 响应缓存键：模型 + 全部消息（仅 chatJson 的成功结果入缓存）。
  String _cacheKey(String model, List<dynamic> messages) =>
      sha256.convert(utf8.encode(jsonEncode([model, messages]))).toString();

  Future<String?> _cacheGet(String key) async =>
      (await (db.select(db.llmCache)..where((t) => t.key.equals(key)))
              .getSingleOrNull())
          ?.response;

  Future<void> _cachePut(String key, String model, String response) async {
    await db.into(db.llmCache).insertOnConflictUpdate(
        LlmCacheCompanion.insert(key: key, response: response, model: model));
  }

  static const _kBudgetKey = 'llm.monthly_budget_tokens';

  /// 本月已用 token 总量（自然月，按本机时区）。
  Future<int> monthUsedTokens() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final row = await db.customSelect(
      'SELECT COALESCE(SUM(prompt_tokens + completion_tokens), 0) AS t '
      'FROM llm_logs WHERE created_at >= ?',
      variables: [Variable.withDateTime(monthStart)],
    ).getSingle();
    return (row.data['t'] as int?) ?? 0;
  }

  Future<void> _checkBudget() async {
    final row = await (db.select(db.settings)
          ..where((t) => t.key.equals(_kBudgetKey)))
        .getSingleOrNull();
    final budget = int.tryParse(row?.value ?? '') ?? 0;
    if (budget <= 0) return; // 0 = 不限
    final used = await monthUsedTokens();
    if (used >= budget) {
      throw LlmBudgetException(
          '本月 LLM token 预算已用尽（已用 $used / 上限 $budget），可在设置页调整');
    }
  }

  /// 清理超过 days 天的调用日志与响应缓存（App 启动时调用一次）。
  Future<void> pruneOldEntries({int days = 90}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    await (db.delete(db.llmLogs)
          ..where((t) => t.createdAt.isSmallerThanValue(cutoff)))
        .go();
    await (db.delete(db.llmCache)
          ..where((t) => t.createdAt.isSmallerThanValue(cutoff)))
        .go();
  }

  bool _retryable(int? status) =>
      status == null || status == 429 || (status >= 500);

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final err = data['error'];
      if (err is Map && err['message'] is String) return err['message'] as String;
      if (err is String) return err;
    }
    return null;
  }

  /// JSON 模式调用 + 兜底解析链（设计稿 6.3）：
  /// 直接解析 → 剥围栏 → 首尾大括号截取 → LLM 修复一次 → 抛 LlmJsonException。
  ///
  /// 响应缓存只参与此方法，且**仅在解析成功后写入**：把解析失败的原始
  /// 响应缓存住会让"重跑覆盖 failed 占位"的恢复机制永久失效（重跑只会
  /// 命中同一份坏响应）。修复调用完全不进缓存——它依赖失败上下文，复用无意义。
  Future<Map<String, dynamic>> chatJson(
    List<Map<String, String>> messages, {
    LlmTier tier = LlmTier.standard,
    String purpose = '',
    int? projectId,
  }) async {
    final cfg = _config;
    if (cfg == null || !cfg.isComplete) {
      throw LlmException('未配置 API（设置页填写 base_url 与 api_key）');
    }
    final model = cfg.modelOf(tier);
    final msgs = [
      {'role': 'system', 'content': jsonSystemPrefix},
      ...messages,
    ];
    final key = _cacheKey(model, msgs);

    final cached = await _cacheGet(key);
    var raw = cached ??
        await chat(msgs,
            tier: tier, jsonMode: true, purpose: purpose, projectId: projectId);
    dynamic parsed = _tryParse(raw);
    if (parsed is Map<String, dynamic>) {
      if (cached == null) await _cachePut(key, model, raw);
      return parsed;
    }

    // 修复链（最多 1 次）
    raw = await chat([
      ...msgs,
      {'role': 'assistant', 'content': raw},
      {
        'role': 'user',
        'content': '上面的输出不是合法 json。请只输出修复后的合法 json，不要任何其他文字。',
      },
    ], tier: tier, jsonMode: true, purpose: '$purpose(修复)', projectId: projectId);
    parsed = _tryParse(raw);
    if (parsed is Map<String, dynamic>) return parsed;
    throw LlmJsonException(
        '解析失败，最后输出: ${raw.length > 200 ? raw.substring(0, 200) : raw}');
  }

  dynamic _tryParse(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {}
    // 剥 markdown 围栏
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(raw);
    if (fence != null) {
      try {
        return jsonDecode(fence.group(1)!);
      } catch (_) {}
    }
    // 首尾大括号截取
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        return jsonDecode(raw.substring(start, end + 1));
      } catch (_) {}
    }
    return null;
  }

  /// 设置页〔测试连接〕：GET /models
  Future<String> testConnection() async {
    final cfg = _config;
    if (cfg == null || !cfg.isComplete) throw LlmException('未配置 API');
    final resp = await dio.get('${cfg.baseUrl}/models',
        options: Options(
          validateStatus: (_) => true,
          headers: {'Authorization': 'Bearer ${cfg.apiKey}'},
        ));
    if (resp.statusCode != 200) {
      throw LlmException('HTTP ${resp.statusCode}', statusCode: resp.statusCode);
    }
    final data = (resp.data as Map)['data'] as List;
    if (data.isEmpty) return '连接成功，但模型列表为空';
    final first = ((data[0] as Map)['id'] ?? '?').toString();
    return '连接成功，可用模型 ${data.length} 个（如 $first）';
  }
}
