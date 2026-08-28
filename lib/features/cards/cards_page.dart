import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/providers.dart';

/// 卡片集（设计稿 8.5）：全部知识卡片按项目分组浏览，搜索 term/title/content。
class CardsPage extends ConsumerStatefulWidget {
  const CardsPage({super.key});

  @override
  ConsumerState<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends ConsumerState<CardsPage> {
  String _query = '';
  bool _loading = true;
  List<_ProjectCards> _groups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final cards = await (db.select(db.knowledgeCards)
          ..orderBy([(c) => OrderingTerm.desc(c.id)]))
        .get();
    final projects = await db.select(db.projects).get();
    final titleById = {for (final p in projects) p.id: p.title};
    final byProject = <int, List<KnowledgeCard>>{};
    for (final c in cards) {
      byProject.putIfAbsent(c.projectId, () => []).add(c);
    }
    if (!mounted) return;
    setState(() {
      _groups = [
        for (final e in byProject.entries)
          _ProjectCards(
              projectId: e.key,
              projectTitle: titleById[e.key] ?? '项目 ${e.key}',
              cards: e.value),
      ];
      _loading = false;
    });
  }

  List<_ProjectCards> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _groups;
    return [
      for (final g in _groups)
        _ProjectCards(
            projectId: g.projectId,
            projectTitle: g.projectTitle,
            cards: g.cards
                .where((c) =>
                    c.term.toLowerCase().contains(q) ||
                    c.title.toLowerCase().contains(q) ||
                    c.content.toLowerCase().contains(q))
                .toList())
    ].where((g) => g.cards.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _filtered;
    final total =
        _groups.fold<int>(0, (n, g) => n + g.cards.length);
    return Scaffold(
      appBar: AppBar(title: Text('卡片集（$total）')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
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
            ]),
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
          ),
      ],
    );
  }
}

class _ProjectCards {
  _ProjectCards(
      {required this.projectId, required this.projectTitle, required this.cards});
  final int projectId;
  final String projectTitle;
  final List<KnowledgeCard> cards;
}
