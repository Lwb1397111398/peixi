import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/settings/api_config.dart';

/// 明文偏好（settings 表）与机密（secure storage）的统一读写入口。
class SettingsRepository {
  SettingsRepository(this._db, this._secure);
  final AppDatabase _db;
  final FlutterSecureStorage _secure;

  // settings 表键
  static const _kBaseUrl = 'llm.base_url';
  static const _kModelCheap = 'llm.model_cheap';
  static const _kModelStandard = 'llm.model_standard';
  static const _kModelVision = 'llm.model_vision';
  static const _kOssBucket = 'oss.bucket';
  static const _kOssEndpoint = 'oss.endpoint';
  // secure storage 键
  static const _sApiKey = 'llm.api_key';
  static const _sOssAk = 'oss.access_key_id';
  static const _sOssSk = 'oss.access_key_secret';
  // 播放偏好键
  static const _kQuizEnabled = 'play.quiz_enabled';
  static const _kMaxPerEpisode = 'play.max_per_episode';
  static const _kMinGap = 'play.min_gap_minutes';
  static const _kTriggerRatio = 'play.trigger_ratio';
  static const _kKeepTempAudio = 'play.keep_temp_audio';
  static const _kPlaybackRate = 'play.playback_rate';
  // 阅读偏好键
  static const _kReaderFontSize = 'reader.font_size';
  static const _kReaderLineHeight = 'reader.line_height';
  static const _kReaderTheme = 'reader.theme';
  // ASR 模式键
  static const _kAsrMode = 'asr.mode';
  // LLM 月度 token 预算（0 = 不限）
  static const _kLlmBudget = 'llm.monthly_budget_tokens';
  // 主题模式 'system' | 'light' | 'dark'（core 层不依赖 material，存原始串）
  static const _kThemeMode = 'app.theme_mode';
  // 桌面窗口边界 'left,top,width,height'
  static const _kWindowBounds = 'window.bounds';

  Future<String?> _get(String key) async =>
      (await (_db.select(_db.settings)..where((t) => t.key.equals(key)))
              .getSingleOrNull())
          ?.value;

  Future<void> _set(String key, String value) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: value));
  }

  Future<ApiConfig> loadApiConfig() async => ApiConfig(
        baseUrl: await _get(_kBaseUrl) ?? ApiConfig.bailianBaseUrl,
        apiKey: await _secure.read(key: _sApiKey) ?? '',
        modelCheap: await _get(_kModelCheap) ?? 'qwen-flash',
        modelStandard: await _get(_kModelStandard) ?? 'qwen-plus',
        modelVision: await _get(_kModelVision) ?? 'qwen-vl-plus',
      );

  Future<void> saveApiConfig(ApiConfig c) async {
    await _set(_kBaseUrl, c.baseUrl);
    await _set(_kModelCheap, c.modelCheap);
    await _set(_kModelStandard, c.modelStandard);
    await _set(_kModelVision, c.modelVision);
    await _secure.write(key: _sApiKey, value: c.apiKey);
  }

  Future<OssConfig?> loadOssConfig() async {
    final bucket = await _get(_kOssBucket);
    final endpoint = await _get(_kOssEndpoint);
    final ak = await _secure.read(key: _sOssAk);
    final sk = await _secure.read(key: _sOssSk);
    if (bucket == null || endpoint == null || ak == null || sk == null) {
      return null;
    }
    return OssConfig(
        bucket: bucket, endpoint: endpoint, accessKeyId: ak, accessKeySecret: sk);
  }

  Future<void> saveOssConfig(OssConfig c) async {
    await _set(_kOssBucket, c.bucket);
    await _set(_kOssEndpoint, c.endpoint);
    await _secure.write(key: _sOssAk, value: c.accessKeyId);
    await _secure.write(key: _sOssSk, value: c.accessKeySecret);
  }

  Future<PlayPrefs> loadPlayPrefs() async => PlayPrefs(
        quizEnabled: (await _get(_kQuizEnabled) ?? '1') == '1',
        maxPerEpisode: int.tryParse(await _get(_kMaxPerEpisode) ?? '') ?? 5,
        minGapMinutes: int.tryParse(await _get(_kMinGap) ?? '') ?? 4,
        triggerRatio: double.tryParse(await _get(_kTriggerRatio) ?? '') ?? 0.3,
        keepTempAudio: (await _get(_kKeepTempAudio) ?? '1') == '1',
        playbackRate:
            double.tryParse(await _get(_kPlaybackRate) ?? '') ?? 1.0,
      );

  Future<void> savePlayPrefs(PlayPrefs p) async {
    await _set(_kQuizEnabled, p.quizEnabled ? '1' : '0');
    await _set(_kMaxPerEpisode, p.maxPerEpisode.toString());
    await _set(_kMinGap, p.minGapMinutes.toString());
    await _set(_kTriggerRatio, p.triggerRatio.toString());
    await _set(_kKeepTempAudio, p.keepTempAudio ? '1' : '0');
    await _set(_kPlaybackRate, p.playbackRate.toString());
  }

  Future<ReaderPrefs> loadReaderPrefs() async {
    final themeName = await _get(_kReaderTheme);
    return ReaderPrefs(
      fontSize:
          double.tryParse(await _get(_kReaderFontSize) ?? '') ?? 17,
      lineHeight:
          double.tryParse(await _get(_kReaderLineHeight) ?? '') ?? 1.7,
      theme: ReaderTheme.values.firstWhere((t) => t.name == themeName,
          orElse: () => ReaderTheme.paper),
    );
  }

  Future<void> saveReaderPrefs(ReaderPrefs p) async {
    await _set(_kReaderFontSize, p.fontSize.toString());
    await _set(_kReaderLineHeight, p.lineHeight.toString());
    await _set(_kReaderTheme, p.theme.name);
  }

  Future<AsrMode> loadAsrMode() async {
    final raw = await _get(_kAsrMode);
    return AsrMode.values
        .firstWhere((m) => m.name == raw, orElse: () => AsrMode.cloud);
  }

  Future<void> saveAsrMode(AsrMode mode) async =>
      _set(_kAsrMode, mode.name);

  Future<int> loadLlmBudgetTokens() async =>
      int.tryParse(await _get(_kLlmBudget) ?? '') ?? 0;

  Future<void> saveLlmBudgetTokens(int tokens) async =>
      _set(_kLlmBudget, tokens.toString());

  Future<String> loadThemeModeRaw() async => await _get(_kThemeMode) ?? 'light';

  Future<void> saveThemeModeRaw(String raw) => _set(_kThemeMode, raw);

  Future<WindowBounds?> loadWindowBounds() async {
    final raw = await _get(_kWindowBounds);
    if (raw == null) return null;
    final parts = raw.split(',').map(double.tryParse).toList();
    if (parts.length != 4 || parts.contains(null)) return null;
    return WindowBounds(
        left: parts[0]!, top: parts[1]!, width: parts[2]!, height: parts[3]!);
  }

  Future<void> saveWindowBounds(
      double left, double top, double width, double height) async {
    await _set(_kWindowBounds, '$left,$top,$width,$height');
  }

  // ---- 渠道与槽位 ----
  static String _channelKey(int id) => 'llm.channel.$id.api_key';

  Future<List<LlmChannel>> loadChannels() =>
      (_db.select(_db.llmChannels)..orderBy([(c) => OrderingTerm.asc(c.id)]))
          .get();

  Future<int> addChannel(
      {required String name,
      required String baseUrl,
      required String apiKey,
      bool enabled = true}) async {
    final id = await _db.into(_db.llmChannels).insert(LlmChannelsCompanion.insert(
        name: name, baseUrl: baseUrl, enabled: Value(enabled)));
    await _secure.write(key: _channelKey(id), value: apiKey);
    return id;
  }

  Future<void> updateChannel(int id,
      {required String name,
      required String baseUrl,
      required String apiKey,
      required bool enabled}) async {
    await (_db.update(_db.llmChannels)..where((t) => t.id.equals(id))).write(
        LlmChannelsCompanion(
            name: Value(name),
            baseUrl: Value(baseUrl),
            enabled: Value(enabled)));
    await _secure.write(key: _channelKey(id), value: apiKey);
  }

  Future<void> deleteChannel(int id) async {
    await (_db.delete(_db.llmChannels)..where((t) => t.id.equals(id))).go();
    await _secure.delete(key: _channelKey(id));
    // 清掉指向该渠道的槽位绑定（槽位回落默认渠道）
    for (final s in LlmSlot.values) {
      final b = await loadSlot(s);
      if (b?.channelId == id) {
        await (_db.delete(_db.settings)
              ..where((t) => t.key.equals('llm.slot.${s.name}')))
            .go();
      }
    }
  }

  Future<void> saveSlot(LlmSlot slot,
          {required int channelId, required String model}) =>
      _set('llm.slot.${slot.name}', '$channelId:$model');

  Future<({int channelId, String model})?> loadSlot(LlmSlot slot) async {
    final raw = await _get('llm.slot.${slot.name}');
    if (raw == null) return null;
    final i = raw.indexOf(':');
    if (i <= 0) return null;
    final cid = int.tryParse(raw.substring(0, i));
    final model = raw.substring(i + 1);
    if (cid == null || model.isEmpty) return null;
    return (channelId: cid, model: model);
  }

  /// 组装路由表。首次调用时把旧单配置（llm.base_url/api_key/三模型）迁移为
  /// "默认渠道 + 三槽位"；从未配置过则返回空表。
  Future<RoutingTable> loadRouting() async {
    await _migrateLegacyConfigIfNeeded();
    final channels = <ChannelRoute>[];
    for (final row in await loadChannels()) {
      final key = await _secure.read(key: _channelKey(row.id)) ?? '';
      channels.add(ChannelRoute(
          id: row.id,
          name: row.name,
          baseUrl: row.baseUrl,
          apiKey: key,
          enabled: row.enabled));
    }
    final slots = <LlmSlot, SlotBinding>{};
    for (final s in LlmSlot.values) {
      final b = await loadSlot(s);
      if (b != null) {
        slots[s] = SlotBinding(channelId: b.channelId, model: b.model);
      }
    }
    return RoutingTable(channels: channels, slots: slots);
  }

  Future<void> _migrateLegacyConfigIfNeeded() async {
    if ((await loadChannels()).isNotEmpty) return;
    final baseUrl = await _get(_kBaseUrl);
    final apiKey = await _secure.read(key: _sApiKey);
    if ((baseUrl == null || baseUrl.isEmpty) &&
        (apiKey == null || apiKey.isEmpty)) {
      return;
    }
    final id = await addChannel(
        name: '默认渠道',
        baseUrl: baseUrl ?? ApiConfig.bailianBaseUrl,
        apiKey: apiKey ?? '');
    for (final (slot, key) in [
      (LlmSlot.summary, _kModelCheap),
      (LlmSlot.analysis, _kModelStandard),
      (LlmSlot.vision, _kModelVision),
    ]) {
      final model = await _get(key);
      if (model != null && model.isNotEmpty) {
        await saveSlot(slot, channelId: id, model: model);
      }
    }
  }
}

/// 窗口边界（桌面端尺寸/位置记忆）。
class WindowBounds {
  const WindowBounds(
      {required this.left, required this.top, required this.width, required this.height});
  final double left;
  final double top;
  final double width;
  final double height;
}
