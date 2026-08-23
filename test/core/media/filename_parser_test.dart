import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/media/filename_parser.dart';

void main() {
  void check(String input, String title, int? episode) {
    final r = FilenameParser.parse(input);
    expect(r.title, title, reason: '$input title');
    expect(r.episode, episode, reason: '$input episode');
  }

  test('S01E03 格式', () {
    check('潜伏.S01E03.1080p.mkv', '潜伏', 3);
    check('Westworld s02e10.mp4', 'Westworld', 10);
  });

  test('第X集 中文与阿拉伯', () {
    check('甄嬛传第12集.mp4', '甄嬛传', 12);
    check('走向共和 第卅四集.mkv', '走向共和', 34);
    check('大明王朝第廿三集.mp4', '大明王朝', 23);
  });

  test('E03 / EP03 格式', () {
    check('伪装者 E08.mkv', '伪装者', 8);
    check('狂飙EP01.mp4', '狂飙', 1);
  });

  test('裸数字尾巴', () {
    check('我的剧07.mkv', '我的剧', 7);
    check('父母爱情 36.mkv', '父母爱情', 36);
  });

  test('无集数信息', () {
    check('让子弹飞.mkv', '让子弹飞', null);
  });

  test('中文数字组合', () {
    expect(FilenameParser.parse('X第十二集.mkv').episode, 12);
    expect(FilenameParser.parse('X第二十三集.mkv').episode, 23);
    expect(FilenameParser.parse('X第零三集.mkv').episode, 3);
  });
}
