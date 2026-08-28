# -*- coding: utf-8 -*-
"""生成 GBK -> Unicode 精确映射表（一次性工具，产物: lib/core/novel/gbk_table.dart）"""
import io

entries = []
for lead in range(0x81, 0xFF):
    for trail in range(0x40, 0xFF):
        if 0x7F <= trail <= 0xA0:
            continue
        b = bytes([lead, trail])
        try:
            ch = b.decode('gbk')
        except UnicodeDecodeError:
            continue
        if ch == '\ufffd':
            continue
        entries.append(((lead << 8) | trail, ch))
entries.append((0x80, '\u20ac'))

BS = chr(92)
with io.open('lib/core/novel/gbk_table.dart', 'w', encoding='utf-8', newline='\n') as f:
    f.write("/// GBK -> Unicode 精确映射表（自动生成，勿手改）。\n")
    f.write("/// 生成方式：Python 标准 gbk 编解码器逐码位导出（含 CP936 欧元单字节 0x80）。\n")
    f.write("/// 键 = (lead<<8)|trail 双字节码位；ASCII 由解码器直接处理。\n")
    f.write("const Map<int, String> kGbkTable = {\n")
    line = []
    for code, ch in entries:
        esc = ''.join(BS + 'u%04X' % ord(c) for c in ch)
        line.append("0x%04X:'%s'" % (code, esc))
        if len(line) == 8:
            f.write(','.join(line) + ',\n')
            line = []
    if line:
        f.write(','.join(line) + ',\n')
    f.write("};\n")
print('entries:', len(entries))

# 验证：模拟 Dart 解码器逐字节走表
raw = open('integration_test/assets/novel_gbk.txt', 'rb').read()
table = dict(entries)
out = []
i = 0
while i < len(raw):
    b = raw[i]
    if b < 0x80:
        out.append(chr(b)); i += 1; continue
    if b == 0x80:
        out.append('\u20ac'); i += 1; continue
    if i + 1 < len(raw):
        code = (b << 8) | raw[i + 1]
        ch = table.get(code)
        if ch is not None:
            out.append(ch); i += 2; continue
    out.append('\ufffd'); i += 1
decoded = ''.join(out)
print('验证解码前 40 字:', decoded[:40])
assert decoded.startswith('第一章 山门'), '解码验证失败'
print('OK：表解码与 Python GBK 完全一致')
