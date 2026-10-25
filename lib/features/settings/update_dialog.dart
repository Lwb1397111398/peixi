import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/core/update/update_service.dart';
import 'package:peixi/providers.dart';

/// 更新流程弹窗：确认（版本+说明）→ 下载（进度条）→ 安装并重启。
/// 下载完成后文件已落盘，「安装并重启」只是触发替换脚本并退出本程序。
enum _UpdatePhase { confirm, downloading, readyToInstall, applying }

/// 打开更新弹窗（设置页手动检查与启动静默检查共用）。
Future<void> showUpdateDialog(BuildContext context, WidgetRef ref,
    UpdateInfo info, int currentVersionCode) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UpdateDialog(
        info: info, ref: ref, currentVersionCode: currentVersionCode),
  );
}

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.info,
    required this.ref,
    required this.currentVersionCode,
  });

  final UpdateInfo info;
  final WidgetRef ref;
  final int currentVersionCode;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  _UpdatePhase _phase = _UpdatePhase.confirm;
  double _progress = 0;
  File? _zip;
  String? _error;
  bool get _isAndroid => Platform.isAndroid;

  UpdateService get _service => widget.ref.read(updateServiceProvider);

  Future<void> _startDownload() async {
    setState(() {
      _phase = _UpdatePhase.downloading;
      _error = null;
    });
    try {
      final zip = await _service.download(widget.info,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          });
      if (!mounted) return;
      setState(() {
        _zip = zip;
        _phase = _UpdatePhase.readyToInstall;
      });
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _phase = _UpdatePhase.confirm;
      });
    }
  }

  Future<void> _install() async {
    if (_zip == null) return;
    setState(() {
      _phase = _UpdatePhase.applying;
      _error = null;
    });
    try {
      // Windows：分离进程已接管，等待本程序退出 → 覆盖安装目录 → 重启，
      // 这里直接退出；Android：系统安装器接管，本进程不退出（用户取消
      // 安装或安装完打开新版都是系统的事）。
      await _service.applyUpdate(widget.info, zip: _zip!);
      if (_isAndroid) {
        if (!mounted) return;
        setState(() {
          _phase = _UpdatePhase.readyToInstall;
          _error = '已交给系统安装器，按提示完成安装即可';
        });
      } else {
        exit(0);
      }
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _phase = _UpdatePhase.readyToInstall;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final textTheme = Theme.of(context).textTheme;
    final sem = context.semanticColors;
    final sizeMb = info.size > 0 ? (info.size / 1024 / 1024).toStringAsFixed(1) : null;

    return AlertDialog(
      title: Text('发现新版本 ${info.versionName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前构建 ${widget.currentVersionCode} → 新版 ${info.versionName}'
            '（构建 ${info.versionCode}）'
            '${sizeMb == null ? '' : '，安装包约 $sizeMb MB'}',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: Space.m),
          if (info.notes.trim().isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Text(info.notes.trim(), style: textTheme.bodyMedium),
              ),
            ),
          const SizedBox(height: Space.m),
          if (_phase == _UpdatePhase.downloading) ...[
            LinearProgressIndicator(value: info.size > 0 ? _progress : null),
            const SizedBox(height: Space.s),
            Text(
              info.size > 0
                  ? '正在下载 ${( _progress * 100).toStringAsFixed(0)}%'
                  : '正在下载…',
              style: textTheme.bodySmall,
            ),
          ],
          if (_phase == _UpdatePhase.applying)
            const Row(children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: Space.s),
              Text('正在准备安装…'),
            ]),
          if (_error != null)
            Text(_error!,
                style: textTheme.bodySmall?.copyWith(color: sem.error)),
        ],
      ),
      actions: [
        TextButton(
          // 下载完成后可离开，文件已落盘，重开弹窗不会重下
          onPressed: _phase == _UpdatePhase.applying
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('以后再说'),
        ),
        if (_phase == _UpdatePhase.confirm)
          FilledButton(
            onPressed: _startDownload,
            child: const Text('立即更新'),
          ),
        if (_phase == _UpdatePhase.readyToInstall)
          FilledButton(
            onPressed: _install,
            child: Text(_isAndroid ? '安装' : '安装并重启'),
          ),
      ],
    );
  }
}
