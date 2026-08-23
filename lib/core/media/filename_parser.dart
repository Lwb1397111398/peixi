/// S1 文件名启发式：解析剧名与集数（设计稿第四节 S1）。
/// 依次尝试：S01E03 → 第X集/话/回 → E03/EP03 → 裸数字尾巴。
class FilenameParser {
  static const _cjkDigits = {
    '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4, '五': 5,
    '六': 6, '七': 7, '八': 8, '九': 9, '十': 10, '廿': 20, '卅': 30, '卌': 40,
  };

  /// 返回 (title, episode)。episode 为 null 表示未识别出集数。
  static ({String title, int? episode}) parse(String filename) {
    final base = _stripExtension(filename);
    // 1) S01E03 / s1e3
    var m = RegExp(r'[Ss](\d{1,2})[Ee](\d{1,3})').firstMatch(base);
    if (m != null) {
      return (title: _cleanTitle(base.substring(0, m.start)), episode: int.parse(m.group(2)!));
    }
    // 2) 第X集/话/回（中文数字或阿拉伯）
    m = RegExp(r'第([0-9一二两三四五六七八九十廿卅卌]+)[集话話回]').firstMatch(base);
    if (m != null) {
      final ep = int.tryParse(m.group(1)!) ?? _parseCjkNumber(m.group(1)!);
      if (ep != null) {
        return (title: _cleanTitle(base.substring(0, m.start)), episode: ep);
      }
    }
    // 3) E03 / EP03（需捕获 E 前的字符，避免剧名末字母被吞）
    m = RegExp(r'([^0-9])[Ee][Pp]?0*(\d{1,3})(?![0-9])').firstMatch(base);
    if (m != null) {
      return (
        title: _cleanTitle(base.substring(0, m.start) + m.group(1)!),
        episode: int.parse(m.group(2)!),
      );
    }
    // 4) 裸数字尾巴：剧名后紧跟 1-4 位数字且前面是 CJK 或字母
    m = RegExp(r'(?:[\u4e00-\u9fff A-Za-z])[ ]?0*(\d{1,4})$').firstMatch(base);
    if (m != null) {
      return (title: _cleanTitle(base.substring(0, m.start + 1)), episode: int.parse(m.group(1)!));
    }
    return (title: _cleanTitle(base), episode: null);
  }

  static String _stripExtension(String f) {
    final i = f.lastIndexOf('.');
    return (i > 0 && f.length - i <= 5) ? f.substring(0, i) : f;
  }

  /// 去掉尾部/首部的分隔符与 junk（".-_" 与常见发布标签）
  static String _cleanTitle(String s) {
    var t = s.replaceAll(RegExp(r'[.\-_]+ *\d{3,4}p.*$', caseSensitive: false), '');
    t = t.trim();
    while (t.isNotEmpty && ' .-_·'.contains(t[t.length - 1])) {
      t = t.substring(0, t.length - 1);
    }
    while (t.isNotEmpty && ' .-_'.contains(t[0])) {
      t = t.substring(0, 1) == t.substring(0) ? t : t.substring(1);
    }
    return t.isEmpty ? s.trim() : t;
  }

  /// 支持到 99 的中文数字（十/廿/卅 + 个位组合，如 二十三、卅四、十二）
  static int? _parseCjkNumber(String s) {
    if (s.isEmpty) return null;
    if (s.length == 1) return _cjkDigits[s];
    // 纯数字组合如 "零三"
    if (RegExp(r'^[零一二两三四五六七八九]+$').hasMatch(s) && !s.contains(RegExp('[十廿卅卌]'))) {
      var v = 0;
      for (final c in s.split('')) {
        v = v * 10 + (_cjkDigits[c] ?? -1);
        if (v < 0) return null;
      }
      return v;
    }
    // 「X十Y」型：二十三=23、廿三=23、十二=12、十=10
    const mult = {'十': 10, '廿': 20, '卅': 30, '卌': 40};
    final m2 =
        RegExp(r'^([一二两三四五六七八九]?)([十廿卅卌])([零一二两三四五六七八九]?)$')
            .firstMatch(s);
    if (m2 != null) {
      final tens = m2.group(1)!.isEmpty ? 1 : _cjkDigits[m2.group(1)]!;
      final ones = m2.group(3)!.isEmpty ? 0 : _cjkDigits[m2.group(3)]!;
      return tens * mult[m2.group(2)]! + ones;
    }
    return null;
  }
}
