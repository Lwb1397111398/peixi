import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/media/ffmpeg_service.dart';

void main() {
  test('parseSrt 标准与容错', () {
    const srt = '1\r\n'
        '00:01:02,340 --> 00:01:05,120\r\n'
        '站长，这件事恐怕没那么简单\r\n'
        '\r\n'
        '2\r\n'
        '00:01:06,000 --> 00:01:07,500\r\n'
        '你先别急\r\n'
        '我再想想\r\n';
    final entries = parseSrt(srt);
    expect(entries.length, 2);
    expect(entries[0].startMs, 62340);
    expect(entries[0].endMs, 65120);
    expect(entries[0].text, '站长，这件事恐怕没那么简单');
    expect(entries[1].text, '你先别急\n我再想想');
  });

  test('parseSrt BOM 与坏块', () {
    const srt = '\uFEFF1\n00:00:01,000 --> 00:00:02,000\n好\n\n垃圾块没有时间轴\n';
    final entries = parseSrt(srt);
    expect(entries.length, 1);
    expect(entries[0].text, '好');
  });

  test('SubtitleEntry json 往返', () {
    final e = SubtitleEntry(startMs: 1, endMs: 2, text: 'x');
    expect(SubtitleEntry.fromJson(e.toJson()).text, 'x');
  });
}
