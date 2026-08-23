import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:peixi/core/database/app_database.dart';
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
      );

  Future<void> saveApiConfig(ApiConfig c) async {
    await _set(_kBaseUrl, c.baseUrl);
    await _set(_kModelCheap, c.modelCheap);
    await _set(_kModelStandard, c.modelStandard);
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
      );

  Future<void> savePlayPrefs(PlayPrefs p) async {
    await _set(_kQuizEnabled, p.quizEnabled ? '1' : '0');
    await _set(_kMaxPerEpisode, p.maxPerEpisode.toString());
    await _set(_kMinGap, p.minGapMinutes.toString());
    await _set(_kTriggerRatio, p.triggerRatio.toString());
    await _set(_kKeepTempAudio, p.keepTempAudio ? '1' : '0');
  }
}
