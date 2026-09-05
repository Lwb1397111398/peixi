import 'package:flutter_test/flutter_test.dart';
import 'package:peixi/core/media/drop_classifier.dart';

void main() {
  test('视频扩展名（含大写与两种分隔符）', () {
    expect(classifyDrop(r'C:\剧\S01E01.MKV'), DropKind.video);
    expect(classifyDrop('/a/b/电影.mp4'), DropKind.video);
    expect(classifyDrop('rec.avi'), DropKind.video);
    expect(classifyDrop('clip.webm'), DropKind.video);
  });

  test('小说与项目包', () {
    expect(classifyDrop('小说.txt'), DropKind.novel);
    expect(classifyDrop('book.EPUB'), DropKind.novel);
    expect(classifyDrop(r'C:\backup\潜伏_1.peixi.zip'), DropKind.package);
    expect(classifyDrop('export.peixi'), DropKind.package);
  });

  test('未知与无扩展名', () {
    expect(classifyDrop('README.md'), DropKind.unknown);
    expect(classifyDrop('无扩展名'), DropKind.unknown);
    expect(classifyDrop('目录.'), DropKind.unknown);
    expect(classifyDrop('字幕.srt'), DropKind.unknown, reason: '字幕文件不直接导入');
  });
}
