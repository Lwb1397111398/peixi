import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/asr/asr_types.dart';
import 'package:peixi/core/media/ffmpeg_service.dart';
import 'package:peixi/features/pipeline/subtitle_aligner.dart';

AsrSentence s(int begin, int end, String text, {String spk = 'SPEAKER_00'}) =>
    AsrSentence(beginMs: begin, endMs: end, text: text, speakerId: spk);

SubtitleEntry sub(int start, int end, String text) =>
    SubtitleEntry(startMs: start, endMs: end, text: text);

void main() {
  test('高重叠：文本替换，时间轴与说话人不变', () {
    final out = correctWithSubtitles([s(1000, 4000, '站长这事儿咋办')],
        [sub(900, 4100, '站长，这件事恐怕没那么简单')]);
    expect(out.single.text, '站长，这件事恐怕没那么简单');
    expect(out.single.beginMs, 1000);
    expect(out.single.endMs, 4000);
    expect(out.single.speakerId, 'SPEAKER_00');
  });

  test('重叠占比低于阈值：保留 ASR 原文', () {
    // ASR 句 3 秒，字幕只覆盖开头 0.9 秒（0.3 < 0.7）
    final out = correctWithSubtitles(
        [s(1000, 4000, '原句')], [sub(900, 1800, '不相关的字幕')]);
    expect(out.single.text, '原句');
  });

  test('多行字幕合并为一行', () {
    final out = correctWithSubtitles(
        [s(1000, 4000, '原句')], [sub(1000, 4000, '第一行\n第二行')]);
    expect(out.single.text, '第一行第二行');
  });

  test('空白字幕不替换', () {
    final out =
        correctWithSubtitles([s(1000, 4000, '原句')], [sub(1000, 4000, '  ')]);
    expect(out.single.text, '原句');
  });

  test('单句 CJK 守卫：中文 ASR 不被英文字幕替换', () {
    final out = correctWithSubtitles(
        [s(1000, 4000, '站长，出事了')], [sub(1000, 4000, 'Something is wrong')]);
    expect(out.single.text, '站长，出事了');
  });

  test('整体 CJK 守卫：英文整片字幕直接放弃对齐', () {
    final subs = [sub(0, 5000, 'hello world'), sub(5000, 9000, 'goodbye')];
    final out = correctWithSubtitles([s(1000, 4000, '中文台词')], subs);
    expect(out.single.text, '中文台词');
  });

  test('非 CJK 场景（中英混排互不误伤）：无 CJK 的 ASR 可被英文替换', () {
    // ASR 输出英文（如英文影片 + 英文 ASR），字幕可纠错
    final out = correctWithSubtitles(
        [s(1000, 4000, 'somethin is rong')], [sub(1000, 4000, 'Something is wrong')]);
    expect(out.single.text, 'Something is wrong');
  });

  test('空输入原样返回', () {
    expect(correctWithSubtitles(const [], [sub(0, 1, 'x')]), isEmpty);
    expect(correctWithSubtitles([s(0, 1, 'x')], const []), hasLength(1));
  });
}
