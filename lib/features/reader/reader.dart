import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:peixi/core/database/app_database.dart';

/// 阅读器数据层：章节/段落/批注/人物加载，L4 作答落库（设计稿 8.4）。
class ReaderRepository {
  ReaderRepository(this.db);
  final AppDatabase db;

  Future<List<Chapter>> chapters(int projectId) => (db.select(db.chapters)
        ..where((t) => t.projectId.equals(projectId))
        ..orderBy([(c) => OrderingTerm.asc(c.idx)]))
      .get();

  Future<List<Paragraph>> paragraphs(int chapterId) => (db.select(db.paragraphs)
        ..where((t) => t.chapterId.equals(chapterId))
        ..orderBy([(p) => OrderingTerm.asc(p.idx)]))
      .get();

  Future<List<Character>> cast(int projectId) => (db.select(db.characters)
        ..where((t) => t.projectId.equals(projectId))
        ..orderBy([(c) => OrderingTerm.asc(c.id)]))
      .get();

  /// 批注按 paraId 分组（一段可有多类型批注）
  Future<Map<int, List<Annotation>>> annotationsByParaId(
      List<int> paraIds) async {
    if (paraIds.isEmpty) return {};
    final rows = await (db.select(db.annotations)
          ..where((t) => t.paraId.isIn(paraIds)))
        .get();
    final map = <int, List<Annotation>>{};
    for (final r in rows) {
      (map[r.paraId] ??= []).add(r);
    }
    return map;
  }

  /// L4 作答（作答交互同 8.2）：Question 行 + QaRecords（跳过也记录）。
  Future<void> recordAnswer({
    required int projectId,
    required String question,
    required List<String> perspectives,
    required String? answer,
    required bool skipped,
  }) async {
    final qId = await db.into(db.questions).insert(QuestionsCompanion.insert(
          projectId: projectId,
          question: question,
          perspectivesJson: Value(jsonEncode(perspectives)),
        ));
    await db.into(db.qaRecords).insert(QaRecordsCompanion.insert(
          questionId: qId,
          userAnswer: answer ?? '',
          skipped: Value(skipped),
        ));
  }
}

// ---------- 批注 contentJson 解码 ----------
// L1/L2: {"text": "..."}；L3: {"term","text","uncertain"}；L4: {"question","perspectives"}

String? decodeL1L2(String contentJson) {
  try {
    return (jsonDecode(contentJson) as Map)['text']?.toString();
  } catch (_) {
    return null;
  }
}

({String term, String text, bool uncertain})? decodeL3(String contentJson) {
  try {
    final j = jsonDecode(contentJson) as Map;
    final term = (j['term'] ?? '').toString();
    if (term.isEmpty) return null;
    return (
      term: term,
      text: (j['text'] ?? '').toString(),
      uncertain: j['uncertain'] == true,
    );
  } catch (_) {
    return null;
  }
}

({String question, List<String> perspectives})? decodeL4(String contentJson) {
  try {
    final j = jsonDecode(contentJson) as Map;
    final question = (j['question'] ?? '').toString();
    if (question.isEmpty) return null;
    return (
      question: question,
      perspectives: [
        for (final p in (j['perspectives'] as List? ?? [])) p.toString()
      ],
    );
  } catch (_) {
    return null;
  }
}
