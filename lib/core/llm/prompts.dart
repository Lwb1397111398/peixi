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

  /// Prompt N2v2（地图趟，设计文档 §7.1；summary 槽位）
  static String novelMap({
    required String roster,
    required List<String> chapterBlocks,
  }) =>
      '你是小说地图整理助手。以下是截至上一批为止的已知人物名单（仅主要与近期活跃人物），'
      '以及连续多章正文，请逐章整理。\n'
      '[已知人物名单]\n$roster\n'
      '[正文]\n${chapterBlocks.join('\n\n')}\n'
      '任务：\n'
      '①为每一章写 150~300 字摘要：概括本章情节、转折与人物关系变化。\n'
      '②列出每章出场人物（cast，用名单或正文中的名字）。\n'
      '③记录人物关键事件：只记对后文可能有意义的事（立誓、结怨、获物、别离、身份揭晓等），'
      '主要人物每章至多 2 条，龙套不记。\n'
      '④维护人物名单：新出现的重要人物给一句话人设（身份/性格/立场）；'
      '名单中已有人物若人设变化则更新其 profile；贯穿全书的重要人物 major=true。\n'
      '输出：{"chapters":[{"idx":0,"summary":"...","cast":["人物名"],'
      '"events":[{"name":"人物名","event":"一句"}],'
      '"characters":[{"name":"新人物或更新人物","profile":"一句话人设","major":false}]}]}\n'
      '要求：idx 必须与正文标注的章号一致；只依据文本，禁止编造；无名龙套不收录。';

  /// Prompt N3v2（故事地图趟，设计文档 §7.2；summary 槽位）
  static String digestMerge({
    required String oldDigest,
    required List<String> chapterSummaries,
  }) =>
      '将旧摘要与新章节摘要合并为不超过400字的"故事至今"摘要。\n'
      '必须保留：人物关系与立场、当前悬念、未回收伏笔（逐条短语列出）。\n'
      '[旧摘要]$oldDigest\n'
      '[新章摘要]\n${chapterSummaries.map((s) => '- $s').join('\n')}\n'
      '输出：{"digest":"..."}';

  /// Prompt N4v2（批注趟，设计文档 §7.3；analysis 槽位。人设=陪读老友）
  static String novelAnnotateV2({
    required String digest,
    required String cast,
    required String recall,
    required String recentSummaries,
    required String chaptersText,
    required int chapterStart,
    required int chapterEnd,
  }) =>
      '你是用户的陪读老友，陪用户读小说、提升情商与思维。只依据"故事至今"与本章前文发言。\n'
      '[故事至今]$digest\n'
      '[出场人物]\n$cast\n'
      '${recall.isEmpty ? '' : '[相关前文回忆]\n$recall\n'}'
      '[前文摘要]${recentSummaries.isEmpty ? '（本章即故事开头）' : recentSummaries}\n'
      '[本章正文（第$chapterStart~$chapterEnd章，每行开头 [n] 是段落编号 para_idx，批注必须锚定到它）]\n$chaptersText\n'
      '三条硬规则：\n'
      '1. 只基于"故事至今"与本章前文，绝不透露后文走向与结局；\n'
      '2. 可以点破"在酝酿什么"（如"他心里开始犯嘀咕，总觉得这事没完"），但不点名后果；\n'
      '3. 引用前文必须用[出场人物]与[前文摘要]里的具体事实，不许空泛。\n'
      '输出：\n'
      '{"chapters":[\n'
      ' {"idx":$chapterStart,"annotations":[\n'
      '  {"para_idx":0,"type":"L1","content":"潜台词解读，2~4句解释性叙述"},\n'
      '  {"para_idx":0,"type":"L2","content":"心理分析：动机/性格/情绪，2~4句"},\n'
      '  {"para_idx":0,"type":"L3","content":{"term":"名词","text":"150字内知识","uncertain":false}},\n'
      '  {"para_idx":0,"type":"L4","content":{"question":"抛给用户的开放性问题，逼其代入思考","perspectives":["参考角度1","参考角度2","参考角度3"]}}\n'
      ' ]}\n'
      ']}\n'
      '要求：每章 3~8 条为基准、可上下浮动，只标有分析价值的段落，宁缺毋滥；'
      '禁止"此处埋下伏笔"式标签短语；para_idx 必须取自正文出现过的编号；'
      'idx 必须取自本次送审的章号；type 只能是 L1/L2/L3/L4；'
      'L1/L2 的 content 为字符串，L3/L4 的 content 为对象。';

}

/// ms → [hh:mm:ss]（Prompt 对白行用）
String formatTimestamp(int ms) {
  final h = ms ~/ 3600000;
  final m = (ms % 3600000) ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}';
}
