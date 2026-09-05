import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/cards/anki_exporter.dart';
import 'package:peixi/features/cards/srs_review_page.dart';
import 'package:peixi/features/cards/srs_scheduler.dart';
import 'package:peixi/providers.dart';

/// 卡片集（设计稿 8.5）：知识卡片按项目分组浏览（drift watch 响应式），
/// 点卡片可编辑/删除，AppBar 提供复习入口与 Anki CSV 导出。
class CardsPage extends ConsumerStatefulWidget {
  const CardsPage({super.key});

  @override
  ConsumerState<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends ConsumerState<CardsPage> {
  String _query = '';

  List<_ProjectCards> _group(
      List<KnowledgeCard> cards, Map<int, String> titleById) {
    final byProject = <int, List<KnowledgeCard>>{};
    for (final c in cards) {
      byProject.putIfAbsent(c.projectId, () => []).add(c);
    }
    final q = _query.trim().toLowerCase();
    return [
      for (final e in byProject.entries)
        _ProjectCards(
            projectId: e.key,
            projectTitle: titleById[e.key] ?? '项目 ${e.key}',
            cards: e.value
                .where((c) =>
                    q.isEmpty ||
                    c.term.toLowerCase().contains(q) ||
                    c.title.toLowerCase().contains(q) ||
                    c.content.toLowerCase().contains(q))
                .toList())
    ].where((g) => g.cards.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<List<KnowledgeCard>>(
          stream: db.select(db.knowledgeCards).watch(),
          builder: (context, cardsSnap) {
            final all = cardsSnap.data ?? const <KnowledgeCard>[];
            final dueCount =
                all.where((c) => isDue(c.dueAt, now)).length;
            return Text('卡片集（${all.length}）· 到期 $dueCount');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.style_outlined),
            tooltip: '复习到期卡片',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SrsReviewPage())),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: '导出 Anki CSV',
            onPressed: _exportAnki,
          ),
        ],
      ),
      body: StreamBuilder<List<KnowledgeCard>>(
        stream: db.select(db.knowledgeCards).watch(),
        builder: (context, cardsSnap) {
          return StreamBuilder<List<Project>>(
            stream: db.select(db.projects).watch(),
            builder: (context, projSnap) {
              final cards = cardsSnap.data;
              final projects = projSnap.data;
              if (cards == null || projects == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final titleById = {for (final p in projects) p.id: p.title};
              final groups = _group(cards, titleById);
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '搜索词条/标题/内容',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: groups.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.style_outlined,
                                  size: 64, color: Colors.grey.shade600),
                              const SizedBox(height: 8),
                              Text(_query.isEmpty
                                  ? '还没有知识卡片，处理一个项目后这里会自动积累'
                                  : '没有匹配「$_query」的卡片'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: groups.length,
                          itemBuilder: (_, i) => _groupSection(groups[i]),
                        ),
                ),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _groupSection(_ProjectCards g) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(g.projectTitle,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${g.cards.length} 张卡片'),
      children: [
        for (final c in g.cards)
          ListTile(
            dense: true,
            title: Row(children: [
              Flexible(child: Text(c.term, overflow: TextOverflow.ellipsis)),
              if (c.uncertain) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('不确定',
                      style: TextStyle(
                          fontSize: 10, color: Colors.orange.shade900)),
                ),
              ],
            ]),
            subtitle: Text(c.content, maxLines: 3, overflow: TextOverflow.ellipsis),
            onTap: () => _editCard(c),
          ),
      ],
    );
  }

  /// 编辑/删除卡片。term 受 (projectId, term) 唯一约束，
  /// 改成已有词条会撞约束——捕获后提示不落库。
  Future<void> _editCard(KnowledgeCard card) async {
    final termCtrl = TextEditingController(text: card.term);
    final titleCtrl = TextEditingController(text: card.title);
    final contentCtrl = TextEditingController(text: card.content);
    var uncertain = card.uncertain;
    final db = ref.read(databaseProvider);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('编辑卡片'),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: termCtrl,
                  decoration: const InputDecoration(labelText: '词条')),
              const SizedBox(height: 8),
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: '标题')),
              const SizedBox(height: 8),
              TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '解释')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('不确定'),
                value: uncertain,
                onChanged: (v) => setDialog(() => uncertain = v),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: ctx,
                  builder: (c2) => AlertDialog(
                    title: const Text('删除这张卡片？'),
                    content: Text('「${card.term}」将从卡片集中移除。'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c2, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c2, true),
                          child: const Text('删除')),
                    ],
                  ),
                );
                if (ok != true) return;
                await (db.delete(db.knowledgeCards)
                      ..where((t) => t.id.equals(card.id)))
                    .go();
                if (ctx.mounted) Navigator.pop(ctx, false);
              },
              child: Text('删除',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ),
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      try {
        await (db.update(db.knowledgeCards)
              ..where((t) => t.id.equals(card.id)))
            .write(KnowledgeCardsCompanion(
          term: Value(termCtrl.text.trim()),
          title: Value(titleCtrl.text.trim()),
          content: Value(contentCtrl.text.trim()),
          uncertain: Value(uncertain),
        ));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('保存失败：该词条在同一项目下已存在')));
      }
    }
  }

  Future<void> _exportAnki() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final built = await AnkiExporter(ref.read(databaseProvider)).buildCsv();
      if (built.count == 0) {
        messenger.showSnackBar(const SnackBar(content: Text('还没有卡片可导出')));
        return;
      }
      final bytes = Uint8List.fromList(built.csv.codeUnits);
      String? savedPath;
      if (Platform.isAndroid) {
        final docs = await getApplicationDocumentsDirectory();
        final f = File('${docs.path}/${built.fileName}');
        await f.writeAsBytes(bytes);
        savedPath = f.path;
      } else {
        final path = await FilePicker.saveFile(
            fileName: built.fileName, bytes: bytes);
        savedPath = path?.toFilePath(windows: Platform.isWindows);
      }
      messenger.showSnackBar(SnackBar(
          content: Text(savedPath == null
              ? '已取消导出'
              : '已导出 ${built.count} 张卡片：$savedPath')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }
}

class _ProjectCards {
  _ProjectCards(
      {required this.projectId, required this.projectTitle, required this.cards});
  final int projectId;
  final String projectTitle;
  final List<KnowledgeCard> cards;
}
