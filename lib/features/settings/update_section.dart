import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/core/update/update_service.dart';
import 'package:peixi/features/settings/update_dialog.dart';
import 'package:peixi/providers.dart';
import 'package:peixi/ui/widgets/section_card.dart';

/// 「应用更新」分区：当前版本、启动自动检查开关、手动检查更新按钮。
class UpdateSection extends ConsumerStatefulWidget {
  const UpdateSection({super.key});
  @override
  ConsumerState<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends ConsumerState<UpdateSection> {
  String _version = '';
  bool _autoCheck = true;
  DateTime? _lastCheck;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final svc = ref.read(updateServiceProvider);
    final repo = ref.read(settingsRepoProvider);
    final info = await svc.packageInfo();
    final autoCheck = await repo.loadUpdateAutoCheck();
    final lastMs = await repo.loadUpdateLastCheckMs();
    if (!mounted) return;
    setState(() {
      _version = '${info.version}+${info.buildNumber}';
      _autoCheck = autoCheck;
      _lastCheck = lastMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastMs);
    });
  }

  Future<void> _toggleAutoCheck(bool v) async {
    setState(() => _autoCheck = v);
    await ref.read(settingsRepoProvider).saveUpdateAutoCheck(v);
  }

  Future<void> _checkNow() async {
    if (_checking) return;
    setState(() => _checking = true);
    final svc = ref.read(updateServiceProvider);
    final repo = ref.read(settingsRepoProvider);
    try {
      final localCode = await svc.localVersionCode();
      final info = await svc.check(currentVersionCode: localCode);
      await repo.saveUpdateLastCheckMs(
          DateTime.now().millisecondsSinceEpoch);
      if (!mounted) return;
      setState(() => _lastCheck = DateTime.now());
      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已是最新版本')));
      } else {
        await showUpdateDialog(context, ref, info, localCode);
      }
    } on UpdateException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SectionCard(
      leading: Icons.system_update_alt,
      title: '应用更新',
      subtitle: '新版本通过 GitHub Releases 自动发布，启动时会静默检查（24 小时节流）',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('当前版本：$_version',
                    style: textTheme.bodyMedium),
              ),
              FilledButton.tonal(
                onPressed: _checking ? null : _checkNow,
                child: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('检查更新'),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          Row(
            children: [
              Expanded(
                child: Text(
                  '启动时自动检查'
                  '${_lastCheck == null ? '' : '（上次检查：${_format(_lastCheck!)}）'}',
                  style: textTheme.bodyMedium,
                ),
              ),
              Switch(value: _autoCheck, onChanged: _toggleAutoCheck),
            ],
          ),
        ],
      ),
    );
  }

  String _format(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
