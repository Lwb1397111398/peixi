import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:peixi/core/database/app_database.dart';
import 'package:peixi/features/pipeline/project_meta.dart';

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

  /// 上次阅读位置（存 projects.meta_json.reading）；无记录返回 null。
  Future<ReadingProgress?> readingProgress(int projectId) async {
    final row = await (db.select(db.projects)
          ..where((t) => t.id.equals(projectId)))
        .getSingleOrNull();
    if (row == null) return null;
    return ProjectMeta.fromJson(row.metaJson).readingProgress;
  }

  Future<void> saveReadingProgress(int projectId,
      {required int chapterIdx,
      required double scrollOffset,
      double? progressPercent}) async {
    final row = await (db.select(db.projects)
          ..where((t) => t.id.equals(projectId)))
        .getSingleOrNull();
    if (row == null) return;
    final meta = ProjectMeta.fromJson(row.metaJson)
      ..readingProgress = ReadingProgress(
          chapterIdx: chapterIdx,
          scrollOffset: scrollOffset,
          progressPercent: progressPercent);
    await (db.update(db.projects)..where((t) => t.id.equals(projectId)))
        .write(ProjectsCompanion(metaJson: Value(meta.encode())));
  }

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

  // ---------- v6 全书搜索 + 书签 ----------

  /// 全书关键词搜索：LIKE 命中段落 + 所属章，供阅读器搜索弹层展示与跳转。
  /// SQLite LIKE 对 ASCII 默认不区分大小写；结果按全书段落序号升序，上限
  /// [limit]（默认 200，大书全扫秒级，上限兜底）。
  Future<List<SearchHit>> searchParagraphs(
    int projectId,
    String keyword, {
    int limit = 200,
  }) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return const [];
    final rows = await (db.select(db.paragraphs)
          ..where((t) =>
              t.projectId.equals(projectId) & t.content.like('%$kw%'))
          ..orderBy([(p) => OrderingTerm.asc(p.idx)])
          ..limit(limit))
        .join([
      leftOuterJoin(
          db.chapters, db.chapters.id.equalsExp(db.paragraphs.chapterId)),
    ])
        .get();
    return [
      for (final r in rows)
        SearchHit(
          paraId: r.readTable(db.paragraphs).id,
          paraIdx: r.readTable(db.paragraphs).idx,
          content: r.readTable(db.paragraphs).content,
          chapterTitle: r.readTableOrNull(db.chapters)?.title,
        )
    ];
  }

  /// 书签列表（新→旧），带命中段落与章名供展示/跳转
  Future<List<BookmarkHit>> bookmarksOf(int projectId) async {
    final rows = await (db.select(db.bookmarks)
          ..where((t) => t.projectId.equals(projectId))
          // createdAt 同毫秒并列时按自增 id 兜底（id 即插入先后）
          ..orderBy([
            (b) => OrderingTerm.desc(b.createdAt),
            (b) => OrderingTerm.desc(b.id),
          ]))
        .join([
      leftOuterJoin(
          db.paragraphs, db.paragraphs.id.equalsExp(db.bookmarks.paraId)),
      leftOuterJoin(
          db.chapters, db.chapters.id.equalsExp(db.paragraphs.chapterId)),
    ])
        .get();
    return [
      for (final r in rows)
        BookmarkHit(
          id: r.readTable(db.bookmarks).id,
          note: r.readTable(db.bookmarks).note,
          paraId: r.readTable(db.bookmarks).paraId,
          paraIdx: r.readTableOrNull(db.paragraphs)?.idx ?? -1,
          chapterId: r.readTableOrNull(db.paragraphs)?.chapterId,
          paraContent:
              r.readTableOrNull(db.paragraphs)?.content ?? '（段落已不存在）',
          chapterTitle: r.readTableOrNull(db.chapters)?.title,
        )
    ];
  }

  /// 段落是否已有书签（长按菜单展示「移除」用）
  Future<int?> bookmarkIdOf(int paraId) async {
    final row = await (db.select(db.bookmarks)
          ..where((t) => t.paraId.equals(paraId)))
        .getSingleOrNull();
    return row?.id;
  }

  Future<void> addBookmark(
      {required int projectId, required int paraId, String? note}) async {
    await db.into(db.bookmarks).insert(BookmarksCompanion.insert(
        projectId: projectId, paraId: paraId, note: Value(note)));
  }

  Future<void> removeBookmark(int id) =>
      (db.delete(db.bookmarks)..where((t) => t.id.equals(id))).go();
}

/// 搜索命中：段落 + 所属章
class SearchHit {
  const SearchHit({
    required this.paraId,
    required this.paraIdx,
    required this.content,
    this.chapterTitle,
  });
  final int paraId;
  final int paraIdx;
  final String content;
  final String? chapterTitle;
}

/// 书签条目：段落内容 + 章名 + 备注
class BookmarkHit {
  const BookmarkHit({
    required this.id,
    required this.paraId,
    required this.paraContent,
    this.paraIdx = -1,
    this.chapterId,
    this.note,
    this.chapterTitle,
  });
  final int id;
  final int paraId;

  /// 全书段落全局序号与所属章 id（跳章定位用）
  final int paraIdx;
  final int? chapterId;
  final String paraContent;
  final String? note;
  final String? chapterTitle;
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
