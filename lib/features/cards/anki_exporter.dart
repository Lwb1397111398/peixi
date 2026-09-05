import 'package:drift/drift.dart' show OrderingTerm;
import 'package:peixi/core/database/app_database.dart';

/// Anki CSV 导出：front=词条，back=标题+解释，tags=peixi/项目名/不确定。
/// 手写 CSV 转义（含逗号、引号、换行的字段按 RFC 4180 加引号翻倍），
/// Anki 导入向导可直接识别三列文本。
class AnkiExporter {
  AnkiExporter(this.db);
  final AppDatabase db;

  Future<({String fileName, String csv, int count})> buildCsv(
      {int? projectId}) async {
    final cardsQ = db.select(db.knowledgeCards);
    if (projectId != null) {
      cardsQ.where((c) => c.projectId.equals(projectId));
    }
    final cards = await (cardsQ
          ..orderBy([(c) => OrderingTerm.asc(c.projectId), (c) => OrderingTerm.asc(c.id)]))
        .get();
    final projects = await db.select(db.projects).get();
    final titleById = {for (final p in projects) p.id: p.title};

    final sb = StringBuffer('front,back,tags\n');
    for (final c in cards) {
      final back = c.title == c.term ? c.content : '${c.title}\n${c.content}';
      final tagParts = [
        'peixi',
        (titleById[c.projectId] ?? 'project${c.projectId}')
            .replaceAll(RegExp(r'\s+'), '_'),
        if (c.uncertain) '不确定',
      ];
      sb.writeln([
        _escape(c.term),
        _escape(back),
        _escape(tagParts.join(' ')),
      ].join(','));
    }
    final safeDate = DateTime.now().toIso8601String().substring(0, 10);
    return (
      fileName: 'peixi_cards_$safeDate.txt',
      csv: sb.toString(),
      count: cards.length,
    );
  }
}

String _escape(String field) {
  if (field.contains(RegExp(r'[",\r\n]'))) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}
