import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peixi/core/asr/asr_model_downloader.dart';
import 'package:peixi/core/asr/local_asr_client.dart';
import 'package:peixi/providers.dart';

enum AsrModelPhase { resolving, ready, missing, downloading, failed }

/// 本地 ASR 模型的全局下载状态：设置页展示进度/入口，管线在缺模型时
/// 自动触发下载并复用同一状态（不会并发重复下载）。
class AsrModelState {
  const AsrModelState({
    required this.phase,
    this.modelDir = '',
    this.received = 0,
    this.total = -1,
    this.error,
  });

  final AsrModelPhase phase;
  final String modelDir;

  /// 所有文件累计已收字节（downloading 时有意义）
  final int received;

  /// 总字节，未知为 -1
  final int total;
  final String? error;

  /// 0.0–1.0；total 未知时为 null
  double? get ratio =>
      total > 0 ? (received / total).clamp(0.0, 1.0).toDouble() : null;
}

class AsrModelController extends Notifier<AsrModelState> {
  CancelToken? _cancelToken;

  @override
  AsrModelState build() {
    // 首次 watch 后异步解析模型目录与就绪状态（build 本身须同步返回）
    Future.microtask(() async {
      final dir = await LocalAsrClient.defaultLocalModelDir();
      if (state.phase == AsrModelPhase.downloading) return;
      final ready = LocalAsrClient(modelDir: dir).isReady;
      state = AsrModelState(
          phase: ready ? AsrModelPhase.ready : AsrModelPhase.missing,
          modelDir: dir);
    });
    return const AsrModelState(phase: AsrModelPhase.resolving);
  }

  /// 开始下载。返回是否成功（用户取消/失败均为 false，错误详情在 state.error）。
  /// 已在下载中时幂等返回。
  Future<bool> download() async {
    if (state.phase == AsrModelPhase.downloading) return false;
    final dir = state.modelDir.isNotEmpty
        ? state.modelDir
        : await LocalAsrClient.defaultLocalModelDir();
    _cancelToken = CancelToken();
    state = AsrModelState(
        phase: AsrModelPhase.downloading, modelDir: dir, received: 0, total: -1);
    final byFile = <String, int>{};
    final totals = <String, int>{};
    try {
      final downloader = AsrModelDownloader(dio: ref.read(dioProvider));
      await downloader.download(dir,
          cancelToken: _cancelToken,
          onProgress: (p) {
            byFile[p.file] = p.received;
            if (p.total > 0) totals[p.file] = p.total;
            final allKnown = AsrModelDownloader.files
                .every((f) => totals.containsKey(f));
            state = state.copyWith(
              received: byFile.values.fold<int>(0, (a, b) => a + b),
              total: allKnown ? totals.values.fold<int>(0, (a, b) => a + b) : -1,
            );
          });
      final ready = LocalAsrClient(modelDir: dir).isReady;
      if (!ready) {
        state = state.copyWith(
            phase: AsrModelPhase.failed, error: '下载完成但校验未通过');
        return false;
      }
      state = AsrModelState(
          phase: AsrModelPhase.ready, modelDir: dir);
      return true;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // 用户取消 → 回到未下载态
        state = AsrModelState(
            phase: LocalAsrClient(modelDir: dir).isReady
                ? AsrModelPhase.ready
                : AsrModelPhase.missing,
            modelDir: dir);
        return false;
      }
      state = state.copyWith(
          phase: AsrModelPhase.failed, error: e.message ?? e.toString());
      return false;
    } catch (e) {
      state = state.copyWith(
          phase: AsrModelPhase.failed, error: e.toString());
      return false;
    }
  }

  /// 取消进行中的下载
  void cancel() => _cancelToken?.cancel('用户取消');
}

extension on AsrModelState {
  AsrModelState copyWith({int? received, int? total, AsrModelPhase? phase, String? error}) =>
      AsrModelState(
          phase: phase ?? this.phase,
          modelDir: modelDir,
          received: received ?? this.received,
          total: total ?? this.total,
          error: error ?? this.error);
}

final asrModelStateProvider =
    NotifierProvider<AsrModelController, AsrModelState>(
        AsrModelController.new);
