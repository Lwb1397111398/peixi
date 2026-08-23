import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    if (mounted) setState(() => _loaded = true);
  }

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
