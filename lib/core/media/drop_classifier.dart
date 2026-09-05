/// 拖拽文件分类（媒体库 DropTarget 用），按扩展名识别。
enum DropKind { video, novel, package, unknown }

const _videoExts = {
  'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'ts', 'webm', 'm4v', 'mpg', 'mpeg'
};
const _novelExts = {'txt', 'epub'};
const _packageExts = {'zip', 'peixi'};

DropKind classifyDrop(String path) {
  final name = path.split(RegExp(r'[\\/]')).last;
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return DropKind.unknown;
  final ext = name.substring(dot + 1).toLowerCase();
  if (_videoExts.contains(ext)) return DropKind.video;
  if (_novelExts.contains(ext)) return DropKind.novel;
  if (_packageExts.contains(ext)) return DropKind.package;
  return DropKind.unknown;
}
