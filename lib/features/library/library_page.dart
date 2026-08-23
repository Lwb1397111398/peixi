import 'package:flutter/material.dart';
import 'package:peixi/features/settings/settings_page.dart';

/// M1-P1：仅空态与设置入口。项目卡片网格在阶段二接入真实数据。
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('陪析 · 媒体库'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '设置',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsPage())),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_filter_outlined,
                  size: 72, color: Colors.grey.shade600),
              const SizedBox(height: 12),
              Text('还没有项目', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('视频导入与处理流水线将在阶段二上线',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}
