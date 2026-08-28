import 'package:peixi/core/llm/llm_service.dart';

/// Prompt 模板全集（设计稿第七节，措辞按原文，勿改结构）。
/// 所有模板在调用处附加 [LlmService.jsonSystemPrefix] 作为 system 消息。
class Prompts {
  /// Prompt A：角色映射（S6）
  static String characterMapping({
    required String filename,
    required String dialogueLines,
  }) =>
      '你是影视剧对白分析专家。以下对白中的 SPEAKER_xx 是声纹聚类编号，同一编号=同一真实声音。\n'
      '任务：推断每个编号对应的剧中角色名。\n'
      '依据优先级：①人物互相称呼与自称 ②语气风格 ③你对《{title}》这部剧的了解（如有把握）。\n'
      '无法确定的命名"未知·声音X"，禁止编造。\n'
      '输出：{"characters":[{"speaker_id":"","name":"","confidence":0.0,"evidence":"判断依据","is_major":false}]}\n'
      '[文件名]$filename\n'
      '[对白]\n$dialogueLines';

  /// Prompt B：场景解说（S9，顺序调用防剧透）
  static String sceneCommentary({
    required String digest,
    required String dialogues,
  }) =>
      '你是用户的私人观剧教练，陪用户提升情商与思维。只准使用截至本场景的信息。\n'
      '[前情摘要]$digest\n'
      '[本场景对白]$dialogues\n'
      '输出：\n'
      '{"scene_summary":"一句话",\n'
      ' "importance":"high|normal",\n'
      ' "l1_subtext":"潜台词解读，80字内，点破话外之音",\n'
      ' "l2_psychology":[{"character":"","analysis":"动机/性格/情绪，100字内"}],\n'
      ' "knowledge_needed":["观众可能不懂的名词，无则空数组"],\n'
      ' "l4_question":{"question":"抛给用户的开放性问题，逼其代入思考","perspectives":["参考角度1","参考角度2","参考角度3"]}}\n'
      '要求：分析必须引用具体台词；l4 问题要具体到本场景抉择，不要空泛鸡汤。';

  /// Prompt C：知识卡片（S9 附带）
  static String knowledgeCard({required String term, required String context}) =>
      '为观剧用户写背景知识卡片，词条「$term」，语境：$context。\n'
      '要求150-250字：是什么+为什么在此剧语境中重要，通俗准确。\n'
      '若对该词条无把握，输出 {"title":"$term","content":"","uncertain":true}。\n'
      '正常输出：{"title":"$term","content":"...","uncertain":false}';

  /// Prompt E：滚动摘要（S9 维护，≤300字）
  static String rollingDigest(
          {required String oldDigest, required String newScene}) =>
      '将旧摘要与新场景信息合并为不超过300字的前情摘要，必须保留：人物关系、立场悬念、未回收伏笔。\n'
      '[旧摘要]$oldDigest\n'
      '[新场景]$newScene\n'
      '输出：{"digest":"..."}';

  /// Prompt D（小说批注）结构与 B 同、锚定 para_range，见 novel_annotation()。
  /// 小说批注 Prompt D 在 M2 A3 中以 [novelAnnotation] 提供。

  /// Prompt N2（小说人物提取，设计稿第五节 N2；措辞自拟，需维持名单滚动更新）
  static String novelCast({
    required String roster,
    required String chapterTitle,
    required String chapterText,
  }) =>
      '你是小说人物整理助手。以下是截至本章为止的已知人物名单，以及本章全文。\n'
      '[已知人物名单]\n$roster\n'
      '[本章标题]$chapterTitle\n'
      '[本章全文]\n$chapterText\n'
      '任务：\n'
      '①维护人物名单：收录本章新出现的重要人物，并更新名单中本章人设发生变化的旧人物（未变化的人物不必重复输出）。\n'
      '②给本章写一句话剧情摘要（60字内），只概括本章内容。\n'
      '输出：{"characters":[{"name":"","profile":"一句话人设：身份/性格/立场"}],"chapter_summary":"..."}\n'
      '要求：只依据名单与本章文本，禁止编造未出现的人物；无名龙套不必收录。';

  /// Prompt D：小说批注（设计稿第七节：结构同 B，锚定 para_range，含密度指令）
  static String novelAnnotation({
    required String digest,
    required String recentContext,
    required String blockText,
    required int paraStart,
    required int paraEnd,
  }) =>
      '你是用户的私人阅读教练，陪用户提升情商与思维。只准使用截至当前段落的信息。\n'
      '[前情摘要]$digest\n'
      '[本章已读概要]$recentContext\n'
      '[当前块正文（每行开头 [n] 是段落编号 para_idx，批注必须锚定到它）]\n$blockText\n'
      '输出：\n'
      '{"para_range":[$paraStart,$paraEnd],\n'
      ' "block_summary":"两句话概括本块情节与转折",\n'
      ' "annotations":[\n'
      '  {"para_idx":0,"type":"L1","content":"潜台词解读，点破话外之音"},\n'
      '  {"para_idx":0,"type":"L2","content":"心理分析：动机/性格/情绪"},\n'
      '  {"para_idx":0,"type":"L3","content":{"term":"名词","text":"150字内知识","uncertain":false}},\n'
      '  {"para_idx":0,"type":"L4","content":{"question":"抛给用户的开放性问题，逼其代入思考","perspectives":["参考角度1","参考角度2","参考角度3"]}}\n'
      ' ]}\n'
      '要求：批注密度：平均每屏(约5段)1-2条，只在有分析价值的段落标注，宁缺毋滥。'
      'para_idx 必须取自正文出现过的编号；type 只能是 L1/L2/L3/L4；'
      'L1/L2 的 content 为字符串，L3/L4 的 content 为对象；'
      '分析必须引用具体原文；L4 问题要具体到本块中的抉择，不要空泛鸡汤。';

}

/// ms → [hh:mm:ss]（Prompt 对白行用）
String formatTimestamp(int ms) {
  final h = ms ~/ 3600000;
  final m = (ms % 3600000) ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}';
}
