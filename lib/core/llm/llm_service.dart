import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
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
  RoutingTable? _routing;

  /// 管线代码入口：启动与设置变更时注入最新路由表。
  void updateRouting(RoutingTable routing) => _routing = routing;

  /// 当前槽位解析出的模型名（评论落库 model 字段用；未配置返回 null）。
  String? modelOf(LlmSlot slot) => _routing?.resolve(slot)?.model;

  /// 兼容垫片：旧单配置 → 单渠道路由表（仅旧测试/迁移期使用，Group C 移除）。
  void updateConfig(ApiConfig config) {
    _config = config; // 供已废弃的 config getter 与 testConnection 过渡期使用
    updateRouting(RoutingTable(
      channels: [
        ChannelRoute(
            id: 0,
            name: 'legacy',
            baseUrl: config.baseUrl,
            apiKey: config.apiKey,
            enabled: true),
      ],
      slots: {
        LlmSlot.summary: SlotBinding(channelId: 0, model: config.modelCheap),
        LlmSlot.analysis:
            SlotBinding(channelId: 0, model: config.modelStandard),
        LlmSlot.vision: SlotBinding(channelId: 0, model: config.modelVision),
      },
    ));
  }

  /// 当前配置（协作器读取模型名等；未配置时为 null）
  @Deprecated('渠道化后由 loadRouting 驱动，Task 7 移除')
  ApiConfig? get config => _config;

  /// 并发/频控闸门：所有 LLM 调用共用，防止压垮限速中转站。
  final LlmGate gate = LlmGate();

  /// 通用系统前缀。同时含中英文 json/JSON 字样：
  /// 百炼 json_object 模式要求 messages 中必须出现 "json"（spec 3.2）。
  static const jsonSystemPrefix =
      '只输出 json（JSON），不要 markdown 代码块，不要解释。'
      '不确定的信息明确说不确定，严禁编造剧情和设定。';

  /// 普通 chat。messages 形如 [{"role":"system","content":...},...]。
  Future<String> chat(
    List<Map<String, String>> messages, {
    LlmSlot slot = LlmSlot.analysis,
    bool jsonMode = false,
    String purpose = '',
    int? projectId,
  }) =>
      _send(messages, slot: slot, jsonMode: jsonMode, purpose: purpose,
          projectId: projectId);

  /// 多模态（vision）调用：单条 user 消息 = 文本 + 图片 data URI。
  /// 用于 M3 实验性视觉辅助（关键帧判断"谁在说话"）。
  Future<String> chatVision({
    required String prompt,
    required String imageDataUri,
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
      slot: LlmSlot.vision,
      jsonMode: true,
      purpose: purpose,
      projectId: projectId,
    );
  }

  Future<String> _send(
    List<dynamic> messages, {
    LlmSlot slot = LlmSlot.analysis,
    bool jsonMode = false,
    String purpose = '',
    int? projectId,
  }) async {
    final r = _routing?.resolve(slot);
    if (r == null) {
      throw LlmException('未配置 LLM 渠道或槽位（设置页 → 模型渠道）');
    }
    final model = r.model;
    final baseUrl = r.channel.baseUrl;
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      if (jsonMode) 'response_format': {'type': 'json_object'},
    };

    // 预算闸门（响应缓存命中时不经过这里，见 chatJson）
    await _checkBudget();

    const maxAttempts = 4; // 1 次原始 + 3 次重试（设计稿 6/9.1）
    Object? lastError;
    await gate.acquire();
    try {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (attempt > 0) {
          await Future.delayed(backoffBase * (1 << (attempt - 1))); // 1s/2s/4s
        }
        try {
          final resp = await dio.post('$baseUrl/chat/completions',
              data: body,
              options: Options(
                validateStatus: (_) => true,
                headers: {'Authorization': 'Bearer ${r.channel.apiKey}'},
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
          final msg =
              _extractErrorMessage(resp.data) ?? 'HTTP ${resp.statusCode}';
          if (_retryable(resp.statusCode)) {
            lastError = LlmException(msg, statusCode: resp.statusCode);
            if (resp.statusCode == 429) {
              gate.cooldown(Duration(seconds: 5 + attempt * 5));
            }
            continue;
          }
          throw LlmException(msg, statusCode: resp.statusCode);
        } on DioException catch (e) {
          lastError = LlmException('网络错误: ${e.message}');
          continue; // 网络类错误一律重试（设计稿 9.1）
        }
      }
      throw lastError ?? LlmException('重试次数耗尽');
    } finally {
      gate.release();
    }
  }

  /// 响应缓存键：渠道 baseUrl + 模型 + 全部消息（渠道入键防不同中转站
  /// 同名模型串缓存；仅 chatJson 的成功结果入缓存）。
  String _cacheKey(String model, List<dynamic> messages, String baseUrl) =>
      sha256.convert(utf8.encode(jsonEncode([baseUrl, model, messages]))).toString();

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
    LlmSlot slot = LlmSlot.analysis,
    String purpose = '',
    int? projectId,
  }) async {
    final r = _routing?.resolve(slot);
    if (r == null) {
      throw LlmException('未配置 LLM 渠道或槽位（设置页 → 模型渠道）');
    }
    final model = r.model;
    final msgs = [
      {'role': 'system', 'content': jsonSystemPrefix},
      ...messages,
    ];
    final key = _cacheKey(model, msgs, r.channel.baseUrl);

    final cached = await _cacheGet(key);
    var raw = cached ??
        await chat(msgs,
            slot: slot, jsonMode: true, purpose: purpose, projectId: projectId);
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
    ], slot: slot, jsonMode: true, purpose: '$purpose(修复)', projectId: projectId);
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

  /// 语义向量（OpenAI 兼容 /embeddings）。语义回忆模块专用；未绑定 embedding
  /// 槽位时抛 LlmException（调用方捕获后静默跳过回忆层）。
  Future<List<List<double>>> embed(List<String> inputs,
      {String purpose = 'embed', int? projectId}) async {
    final r = _routing?.resolve(LlmSlot.embedding);
    if (r == null) {
      throw LlmException('未配置 embedding 模型（设置页 → 功能槽位）');
    }
    await _checkBudget();
    await gate.acquire();
    try {
      final resp = await dio.post('${r.channel.baseUrl}/embeddings',
          data: {'model': r.model, 'input': inputs},
          options: Options(
            validateStatus: (_) => true,
            headers: {'Authorization': 'Bearer ${r.channel.apiKey}'},
          ));
      if (resp.statusCode != 200) {
        throw LlmException(
            _extractErrorMessage(resp.data) ?? 'HTTP ${resp.statusCode}',
            statusCode: resp.statusCode);
      }
      final data = (resp.data as Map)['data'] as List;
      final usage = ((resp.data as Map)['usage'] as Map?) ?? const {};
      await db.into(db.llmLogs).insert(LlmLogsCompanion.insert(
            projectId: Value(projectId),
            purpose: purpose,
            model: r.model,
            promptTokens: Value((usage['prompt_tokens'] as int?) ?? 0),
            completionTokens: Value((usage['completion_tokens'] as int?) ?? 0),
          ));
      return [
        for (final d in data)
          [for (final v in (d['embedding'] as List)) (v as num).toDouble()]
      ];
    } finally {
      gate.release();
    }
  }

  /// 拉取渠道模型列表（设置页「测试连接/抓取模型」共用）。
  Future<List<String>> fetchModels(ChannelRoute channel) async {
    final resp = await dio.get('${channel.baseUrl}/models',
        options: Options(
          validateStatus: (_) => true,
          headers: {'Authorization': 'Bearer ${channel.apiKey}'},
        ));
    if (resp.statusCode != 200) {
      throw LlmException('HTTP ${resp.statusCode}', statusCode: resp.statusCode);
    }
    return [
      for (final m in ((resp.data as Map)['data'] as List))
        ((m as Map)['id'] ?? '').toString()
    ]..removeWhere((s) => s.isEmpty);
  }
}

/// 全局并发/频控闸门：所有 LLM 调用共用，防止压垮限速中转站。
class LlmGate {
  int maxConcurrent = 2;
  Duration minInterval = Duration.zero;
  DateTime _cooldownUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastDispatch = DateTime.fromMillisecondsSinceEpoch(0);
  int _inFlight = 0;

  void updateLimits({int? maxConcurrent, Duration? minInterval}) {
    if (maxConcurrent != null && maxConcurrent >= 1) {
      this.maxConcurrent = maxConcurrent;
    }
    if (minInterval != null) this.minInterval = minInterval;
  }

  /// 429 等限流信号：全局冷却（在途请求不受影响，新请求延后）。
  void cooldown(Duration d) {
    final until = DateTime.now().add(d);
    if (until.isAfter(_cooldownUntil)) _cooldownUntil = until;
  }

  Future<void> acquire() async {
    while (true) {
      final now = DateTime.now();
      if (_inFlight < maxConcurrent && !now.isBefore(_cooldownUntil)) {
        final earliest = _lastDispatch.add(minInterval);
        if (now.isBefore(earliest)) {
          await Future.delayed(earliest.difference(now));
          continue;
        }
        _inFlight++;
        _lastDispatch = DateTime.now();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  void release() => _inFlight--;
}
