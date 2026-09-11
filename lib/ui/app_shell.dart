import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:peixi/core/theme/tokens.dart';
import 'package:peixi/features/cards/cards_page.dart';
import 'package:peixi/features/library/library_page.dart';
import 'package:peixi/features/review/review_page.dart';
import 'package:peixi/features/settings/settings_page.dart';

/// 应用外壳：导航在宽屏（≥900）为左侧 NavigationRail，窄屏（手机）为
/// 底部 NavigationBar，共用同一 IndexedStack（媒体库/卡片集/复盘/设置）。
/// 内容页（播放器、阅读器、处理详情、校准、SRS 会话）仍从各入口全屏 push，
/// 会盖住整个外壳——符合"导航常驻、任务页专注"的层级。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = <Widget>[
    LibraryPage(),
    CardsPage(),
    ReviewPage(),
    SettingsPage(),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= kTwoPaneBreakpoint;
    return Scaffold(
      bottomNavigationBar:
          isWide ? null : _buildNavBar(context),
      body: CallbackShortcuts(
        // 桌面端快速切换目的地：Ctrl+1 媒体库 / 2 卡片集 / 3 复盘 / 4 设置
        bindings: {
          const SingleActivator(LogicalKeyboardKey.digit1, control: true):
              () => _select(0),
          const SingleActivator(LogicalKeyboardKey.digit2, control: true):
              () => _select(1),
          const SingleActivator(LogicalKeyboardKey.digit3, control: true):
              () => _select(2),
          const SingleActivator(LogicalKeyboardKey.digit4, control: true):
              () => _select(3),
        },
        // 快捷键要求焦点落在 CallbackShortcuts 子树内，autofocus 兜底初始焦点；
        // SafeArea 避免手机端内容顶进状态栏（桌面 inset 为 0，无视觉影响）
        child: Focus(
          autofocus: true,
          child: SafeArea(
            top: true,
            bottom: false,
            child: isWide
                ? Row(
                    children: [
                      _buildRail(context, scheme),
                      VerticalDivider(width: 1, thickness: 1),
                      Expanded(
                        child: IndexedStack(index: _index, children: _pages),
                      ),
                    ],
                  )
                : IndexedStack(index: _index, children: _pages),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    return NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: _select,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.movie_outlined),
          selectedIcon: Icon(Icons.movie),
          label: '媒体库',
        ),
        NavigationDestination(
          icon: Icon(Icons.style_outlined),
          selectedIcon: Icon(Icons.style),
          label: '卡片集',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_edu_outlined),
          selectedIcon: Icon(Icons.history_edu),
          label: '复盘',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: '设置',
        ),
      ],
    );
  }

  Widget _buildRail(BuildContext context, ColorScheme scheme) {
    return NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: _select,
      labelType: NavigationRailLabelType.all,
      groupAlignment: -1,
      leading: Padding(
        padding: const EdgeInsets.only(top: Space.m, bottom: Space.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: AppRadius.rMd,
              ),
              child: Icon(Icons.auto_stories,
                  size: 20, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: Space.xs),
            Text('陪析', style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.movie_outlined),
          selectedIcon: Icon(Icons.movie),
          label: Text('媒体库'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.style_outlined),
          selectedIcon: Icon(Icons.style),
          label: Text('卡片集'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.history_edu_outlined),
          selectedIcon: Icon(Icons.history_edu),
          label: Text('复盘'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('设置'),
        ),
      ],
    );
  }
}
