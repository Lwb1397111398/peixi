/// 语义回忆提供者（批注趟可选上下文层；null = 整层跳过，零影响）。
/// 默认实现 NovelRecallService（章摘要向量 + cos top3）随 Task 13 落地。
abstract class NovelRecallProvider {
  /// 为摘要就绪但无向量的章补建索引（幂等；失败静默）。
  Future<void> ensureIndexed(int projectId);

  /// [相关前文回忆] 文本：cos top3 前文章摘要；无命中/失败 → 空串。
  Future<String> recallContext(int projectId,
      {required int beforeChapterIdx, required String query});
}
