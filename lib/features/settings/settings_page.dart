import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/asr/local_asr_client.dart';
import 'package:peixi/core/settings/api_config.dart';
import 'package:peixi/providers.dart';

/// 设计稿 8.6 的 M1 子集：供应商预设（默认阿里云百炼）、自定义
/// base_url/api_key/model 两档、〔测试连接〕、OSS 四项、token 成本统计。
/// 播放偏好开关随阶段四弹幕引擎一起做；ASR 模式切换（云端/本地）随阶段二做。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _modelCheap = TextEditingController();
  final _modelStandard = TextEditingController();
  final _ossBucket = TextEditingController();
  final _ossEndpoint = TextEditingController();
  final _ossAk = TextEditingController();
  final _ossSk = TextEditingController();
  String _preset = '阿里云百炼';
  int _totalTokens = 0;
  bool _testing = false;
  bool _loaded = false;
  AsrMode _asrMode = AsrMode.cloud;
  String? _localModelDir;
  bool _localModelReady = false;
  PlayPrefs _playPrefs = const PlayPrefs();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final repo = ref.read(settingsRepoProvider);
    final cfg = await repo.loadApiConfig();
    if (!mounted) return;
    _baseUrl.text = cfg.baseUrl;
    _apiKey.text = cfg.apiKey;
    _modelCheap.text = cfg.modelCheap;
    _modelStandard.text = cfg.modelStandard;
    _preset = cfg.baseUrl == ApiConfig.bailianBaseUrl ? '阿里云百炼' : '自定义';
    final oss = await repo.loadOssConfig();
    if (oss != null) {
      _ossBucket.text = oss.bucket;
      _ossEndpoint.text = oss.endpoint;
      _ossAk.text = oss.accessKeyId;
      _ossSk.text = oss.accessKeySecret;
    }
    _totalTokens =
        (await ref
                .read(databaseProvider)
                .customSelect(
                  'SELECT COALESCE(SUM(prompt_tokens+completion_tokens),0) AS t FROM llm_logs',
                )
                .getSingle())
            .read<int>('t');
    _asrMode = await repo.loadAsrMode();
    await _refreshLocalModel();
    _playPrefs = await repo.loadPlayPrefs();
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _refreshLocalModel() async {
    final dir = await LocalAsrClient.defaultLocalModelDir();
    _localModelDir = dir;
    _localModelReady = LocalAsrClient(modelDir: dir).isReady;
  }

  Future<void> _savePlayPrefs(PlayPrefs p) async {
    setState(() => _playPrefs = p);
    await ref.read(settingsRepoProvider).savePlayPrefs(p);
  }

  Widget _prefSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) =>
      Row(children: [
        SizedBox(width: 150, child: Text(label)),
        Expanded(
          child: Slider(
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            value: value.clamp(min, max),
            onChanged: onChanged,
          ),
        ),
      ]);

  @override
  void dispose() {
    for (final c in [
      _baseUrl,
      _apiKey,
      _modelCheap,
      _modelStandard,
      _ossBucket,
      _ossEndpoint,
      _ossAk,
      _ossSk,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: _loaded
        ? ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('LLM API', style: Theme.of(context).textTheme.titleMedium),
              DropdownButtonFormField<String>(
                initialValue: _preset,
                decoration: const InputDecoration(labelText: '供应商预设'),
                items: const [
                  DropdownMenuItem(value: '阿里云百炼', child: Text('阿里云百炼（推荐）')),
                  DropdownMenuItem(value: '自定义', child: Text('自定义')),
                ],
                onChanged: (v) => setState(() {
                  _preset = v!;
                  if (v == '阿里云百炼') {
                    _baseUrl.text = ApiConfig.bailianBaseUrl;
                  }
                }),
              ),
              TextFormField(
                controller: _baseUrl,
                enabled: _preset == '自定义',
                decoration: const InputDecoration(labelText: 'Base URL'),
              ),
              TextFormField(
                controller: _apiKey,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: '百炼控制台 → API-KEY 创建',
                ),
              ),
              TextFormField(
                controller: _modelCheap,
                decoration: const InputDecoration(
                  labelText: '轻量模型（映射/摘要/人物）',
                  suffixText: 'cheap',
                ),
              ),
              TextFormField(
                controller: _modelStandard,
                decoration: const InputDecoration(
                  labelText: '主力模型（解说/批注/知识卡）',
                  suffixText: 'standard',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(_testing ? '测试中…' : '测试连接'),
              ),
              const Divider(height: 32),
              Text(
                '阿里云 OSS（语音识别中转）',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextFormField(
                controller: _ossBucket,
                decoration: const InputDecoration(labelText: 'Bucket'),
              ),
              TextFormField(
                controller: _ossEndpoint,
                decoration: const InputDecoration(
                  labelText: 'Endpoint',
                  hintText: 'oss-cn-beijing.aliyuncs.com',
                ),
              ),
              TextFormField(
                controller: _ossAk,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'AccessKeyId'),
              ),
              TextFormField(
                controller: _ossSk,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'AccessKeySecret'),
              ),
              const Divider(height: 32),
              Text('语音识别（ASR）', style: Theme.of(context).textTheme.titleMedium),
              DropdownButtonFormField<AsrMode>(
                initialValue: _asrMode,
                decoration: const InputDecoration(labelText: '识别模式'),
                items: const [
                  DropdownMenuItem(
                      value: AsrMode.cloud,
                      child: Text('云端 · DashScope（需 OSS 中转，有说话人分离）')),
                  DropdownMenuItem(
                      value: AsrMode.local,
                      child: Text('本地 · sherpa-onnx（离线，无说话人分离）')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _asrMode = v);
                  await ref.read(settingsRepoProvider).saveAsrMode(v);
                },
              ),
              Row(children: [
                Icon(
                    _localModelReady
                        ? Icons.check_circle
                        : Icons.error_outline,
                    size: 18,
                    color: _localModelReady ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Text(_localModelReady ? '本地模型已就绪' : '本地模型未下载'),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await _refreshLocalModel();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('刷新状态'),
                ),
              ]),
              if (_localModelDir != null)
                Text('模型目录：$_localModelDir',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey.shade500)),
              if (!_localModelReady)
                Text(
                  '未下载时请运行 tool/download-sherpa-model.sh，'
                  '并把 models/asr 目录放到上面的模型目录（或 Windows exe 同级目录）。'
                  '本地模式无说话人分离，角色映射将全部归为一个说话人。',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.orange.shade300),
                ),
              const Divider(height: 32),
              Text('播放偏好', style: Theme.of(context).textTheme.titleMedium),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('弹幕提问打断（L4）'),
                subtitle: const Text('播放到关键场景自动暂停提问'),
                value: _playPrefs.quizEnabled,
                onChanged: (v) => _savePlayPrefs(
                    _playPrefs.copyWith(quizEnabled: v)),
              ),
              _prefSlider(
                label: '每集最多提问',
                value: _playPrefs.maxPerEpisode.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                display: '${_playPrefs.maxPerEpisode} 次',
                onChanged: (v) => _savePlayPrefs(
                    _playPrefs.copyWith(maxPerEpisode: v.round())),
              ),
              _prefSlider(
                label: '两次提问最小间隔',
                value: _playPrefs.minGapMinutes.toDouble(),
                min: 1,
                max: 15,
                divisions: 14,
                display: '${_playPrefs.minGapMinutes} 分钟',
                onChanged: (v) => _savePlayPrefs(
                    _playPrefs.copyWith(minGapMinutes: v.round())),
              ),
              _prefSlider(
                label: '触发位置（场景进度比例）',
                value: _playPrefs.triggerRatio,
                min: 0.1,
                max: 0.6,
                divisions: 10,
                display: '${(_playPrefs.triggerRatio * 100).round()}%',
                onChanged: (v) => _savePlayPrefs(
                    _playPrefs.copyWith(triggerRatio: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('保留临时音频'),
                subtitle: const Text('关闭可节省磁盘（重跑需重新抽取）'),
                value: _playPrefs.keepTempAudio,
                onChanged: (v) => _savePlayPrefs(
                    _playPrefs.copyWith(keepTempAudio: v)),
              ),
              const Divider(height: 32),
              Row(
                children: [
                  const Icon(Icons.paid_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('本项目累计 LLM 消耗：$_totalTokens tokens'),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存全部'),
              ),
            ],
          )
        : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 用表单当前值临时构造配置测试，未保存也能测
      ref
          .read(llmServiceProvider)
          .updateConfig(
            ApiConfig(
              baseUrl: _baseUrl.text.trim(),
              apiKey: _apiKey.text.trim(),
              modelCheap: _modelCheap.text.trim(),
              modelStandard: _modelStandard.text.trim(),
            ),
          );
      final msg = await ref.read(llmServiceProvider).testConnection();
      messenger.showSnackBar(SnackBar(content: Text('✅ $msg')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('❌ $e')));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final repo = ref.read(settingsRepoProvider);
    await repo.saveApiConfig(
      ApiConfig(
        baseUrl: _baseUrl.text.trim(),
        apiKey: _apiKey.text.trim(),
        modelCheap: _modelCheap.text.trim(),
        modelStandard: _modelStandard.text.trim(),
      ),
    );
    await repo.saveOssConfig(
      OssConfig(
        bucket: _ossBucket.text.trim(),
        endpoint: _ossEndpoint.text.trim(),
        accessKeyId: _ossAk.text.trim(),
        accessKeySecret: _ossSk.text.trim(),
      ),
    );
    ref.read(llmServiceProvider).updateConfig(await repo.loadApiConfig());
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
    }
  }
}
