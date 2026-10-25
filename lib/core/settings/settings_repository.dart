import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/core/llm/llm_routing.dart';
import 'package:peixi/core/settings/app_prefs.dart';

/// 明文偏好（settings 表）与机密（secure storage）的统一读写入口。
class SettingsRepository {
  SettingsRepository(this._db, this._secure);
  final AppDatabase _db;
  final FlutterSecureStorage _secure;

  // settings 表键
  // LLM 月度 token 预算（0 = 不限）
  static const _kLlmBudget = 'llm.monthly_budget_tokens';
  // 并发/频控：并发数默认 2（钳制 1~8），请求最小间隔默认 0ms（钳制 0~10000）
  static const _kLlmConcurrency = 'llm.concurrency';
  static const _kLlmMinInterval = 'llm.min_request_interval_ms';
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
  static const _kReaderMargin = 'reader.margin';
  // 小说两遍式管线参数（设计文档 §3）：批大小/首屏冲刺/地图领先/语义回忆开关
  static const _kNovelMapBatch = 'novel.mapBatchChapters';
  static const _kNovelDigestBatch = 'novel.digestBatchChapters';
  static const _kNovelAnnotateBatch = 'novel.annotateBatchChapters';
  static const _kNovelBurst = 'novel.initialBurstChapters';
  static const _kNovelMapLead = 'novel.mapLeadChapters';
  static const _kNovelVectorRecall = 'novel.vectorRecall';
  // 主题模式 'system' | 'light' | 'dark'（core 层不依赖 material，存原始串）
  static const _kThemeMode = 'app.theme_mode';
  // 桌面窗口边界 'left,top,width,height'
  static const _kWindowBounds = 'window.bounds';
  // 应用自更新：上次成功检查的毫秒时间戳（24h 节流）/ 启动自动检查开关
  static const _kUpdateLastCheck = 'update.last_check_ms';
  static const _kUpdateAutoCheck = 'update.auto_check';

  Future<String?> _get(String key) async =>
      (await (_db.select(_db.settings)..where((t) => t.key.equals(key)))
              .getSingleOrNull())
          ?.value;

  Future<void> _set(String key, String value) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: value));
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
    final marginName = await _get(_kReaderMargin);
    return ReaderPrefs(
      fontSize:
          double.tryParse(await _get(_kReaderFontSize) ?? '') ?? 17,
      lineHeight:
          double.tryParse(await _get(_kReaderLineHeight) ?? '') ?? 1.7,
      theme: ReaderTheme.values.firstWhere((t) => t.name == themeName,
          orElse: () => ReaderTheme.paper),
      margin: ReaderMargin.values.firstWhere((m) => m.name == marginName,
          orElse: () => ReaderMargin.standard),
    );
  }

  Future<void> saveReaderPrefs(ReaderPrefs p) async {
    await _set(_kReaderFontSize, p.fontSize.toString());
    await _set(_kReaderLineHeight, p.lineHeight.toString());
    await _set(_kReaderTheme, p.theme.name);
    await _set(_kReaderMargin, p.margin.name);
  }

  Future<int> loadLlmBudgetTokens() async =>
      int.tryParse(await _get(_kLlmBudget) ?? '') ?? 0;

  Future<void> saveLlmBudgetTokens(int tokens) async =>
      _set(_kLlmBudget, tokens.toString());

  /// 并发/频控：并发数默认 2（1~8），请求最小间隔默认 0ms。
  /// 读取侧与写入侧同样钳制，防外部/手改脏值直入闸门。
  Future<(int, int)> loadLlmLimits() async => (
        (int.tryParse(await _get(_kLlmConcurrency) ?? '') ?? 2).clamp(1, 8),
        (int.tryParse(await _get(_kLlmMinInterval) ?? '') ?? 0)
            .clamp(0, 10000),
      );

  Future<void> saveLlmLimits(
      {required int concurrency, required int minIntervalMs}) async {
    await _set(_kLlmConcurrency, concurrency.clamp(1, 8).toString());
    await _set(_kLlmMinInterval, minIntervalMs.clamp(0, 10000).toString());
  }

  /// 小说两遍式管线参数（设计文档 §3；mapLead 下限 1，为 0 会让地图/批注双泳道互等死锁）。
  /// 读取侧与写入侧同样钳制，防外部/手改脏值直入调度器。
  Future<NovelParams> loadNovelParams() async {
    Future<int?> readInt(String key) async => int.tryParse(await _get(key) ?? '');
    final mapBatch =
        (await readInt(_kNovelMapBatch) ?? 5).clamp(1, 10);
    final digestBatch =
        (await readInt(_kNovelDigestBatch) ?? 10).clamp(1, 50);
    final annotateBatch =
        (await readInt(_kNovelAnnotateBatch) ?? 3).clamp(1, 10);
    final burst = (await readInt(_kNovelBurst) ?? 10).clamp(1, 200);
    final mapLead = (await readInt(_kNovelMapLead) ?? 20).clamp(1, 500);
    final recall = await _get(_kNovelVectorRecall);
    return NovelParams(
        mapBatchChapters: mapBatch,
        digestBatchChapters: digestBatch,
        annotateBatchChapters: annotateBatch,
        initialBurstChapters: burst,
        mapLeadChapters: mapLead,
        vectorRecall: recall == 'true');
  }

  Future<void> saveNovelParams(NovelParams p) async {
    await _set(_kNovelMapBatch, p.mapBatchChapters.clamp(1, 10).toString());
    await _set(_kNovelDigestBatch, p.digestBatchChapters.clamp(1, 50).toString());
    await _set(
        _kNovelAnnotateBatch, p.annotateBatchChapters.clamp(1, 10).toString());
    await _set(_kNovelBurst, p.initialBurstChapters.clamp(1, 200).toString());
    await _set(_kNovelMapLead, p.mapLeadChapters.clamp(1, 500).toString());
    await _set(_kNovelVectorRecall, p.vectorRecall ? 'true' : 'false');
  }

  Future<String> loadThemeModeRaw() async => await _get(_kThemeMode) ?? 'light';

  Future<void> saveThemeModeRaw(String raw) => _set(_kThemeMode, raw);

  Future<int?> loadUpdateLastCheckMs() async =>
      int.tryParse(await _get(_kUpdateLastCheck) ?? '');

  Future<void> saveUpdateLastCheckMs(int ms) =>
      _set(_kUpdateLastCheck, '$ms');

  Future<bool> loadUpdateAutoCheck() async =>
      (await _get(_kUpdateAutoCheck) ?? '1') == '1';

  Future<void> saveUpdateAutoCheck(bool v) =>
      _set(_kUpdateAutoCheck, v ? '1' : '0');

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
    // 行删除与槽位绑定清理同事务，避免中途失败留下悬挂绑定
    await _db.transaction(() async {
      await (_db.delete(_db.llmChannels)..where((t) => t.id.equals(id))).go();
      // 清掉指向该渠道的槽位绑定（槽位回落默认渠道）
      for (final s in LlmSlot.values) {
        final b = await loadSlot(s);
        if (b?.channelId == id) {
          await (_db.delete(_db.settings)
                ..where((t) => t.key.equals('llm.slot.${s.name}')))
              .go();
        }
      }
    });
    await _secure.delete(key: _channelKey(id));
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

  /// 组装路由表：渠道行 + secure storage KEY + 各槽位绑定。
  /// 槽位未绑定的键不存在于表中，RoutingTable.resolve 返回 null（无默认回落）。
  Future<RoutingTable> loadRouting() async {
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
}

/// 小说两遍式管线参数（设计文档 §3；mapLead 下限 1，为 0 会让地图/批注双泳道互等死锁）。
class NovelParams {
  const NovelParams({
    this.mapBatchChapters = 5,
    this.digestBatchChapters = 10,
    this.annotateBatchChapters = 3,
    this.initialBurstChapters = 10,
    this.mapLeadChapters = 20,
    this.vectorRecall = false,
  });
  final int mapBatchChapters;
  final int digestBatchChapters;
  final int annotateBatchChapters;
  final int initialBurstChapters;
  final int mapLeadChapters;
  final bool vectorRecall;
}

/// 窗口边界（桌面端尺寸/位置记忆）。
class WindowBounds {
  const WindowBounds(
      {required this.left,
      required this.top,
      required this.width,
      required this.height});
  final double left;
  final double top;
  final double width;
  final double height;
}
