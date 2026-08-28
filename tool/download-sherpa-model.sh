#!/usr/bin/env bash
# B1: 下载 sherpa-onnx 本地 ASR 模型（paraformer-zh-2024-03-09 int8，~100MB 级）
# 模型不入 git 仓库。用法：
#   ./tool/download-sherpa-model.sh [目标目录]
# 默认目标: <项目根>/models/asr
# 运行时查找顺序（LocalAsrClient.defaultLocalModelDir）:
#   ① <appSupport>/models/asr   ② Windows: exe 同级 models/asr
# 音频文件经 hf-mirror（国内镜像）优先，失败回退 huggingface。
set -euo pipefail

TARGET="${1:-models/asr}"
REPO="csukuangfj/sherpa-onnx-paraformer-zh-2024-03-09"
FILES=("model.int8.onnx" "tokens.txt")

MIRRORS=(
  "https://hf-mirror.com/${REPO}/resolve/main"
  "https://huggingface.co/${REPO}/resolve/main"
)

mkdir -p "$TARGET"

for f in "${FILES[@]}"; do
  if [ -s "$TARGET/$f" ]; then
    echo "已存在: $TARGET/$f（跳过）"
    continue
  fi
  ok=0
  for m in "${MIRRORS[@]}"; do
    echo "下载 $f ← ${m}"
    if curl -L --fail --connect-timeout 15 --retry 2 -o "$TARGET/$f.part" "$m/$f"; then
      mv "$TARGET/$f.part" "$TARGET/$f"
      ok=1
      break
    fi
    echo "镜像失败，尝试下一个…"
  done
  if [ "$ok" != 1 ]; then
    echo "错误: $f 下载失败（两个镜像均不可达）" >&2
    exit 1
  fi
done

# 完整性粗检（onnx 模型应远大于 10MB；tokens 非空）
model_size=$(wc -c <"$TARGET/model.int8.onnx" | tr -d ' ')
if [ "$model_size" -lt 10000000 ]; then
  echo "错误: model.int8.onnx 仅 ${model_size} 字节，下载不完整" >&2
  exit 1
fi
if [ ! -s "$TARGET/tokens.txt" ]; then
  echo "错误: tokens.txt 为空" >&2
  exit 1
fi

echo "模型已就绪: $(cd "$TARGET" && pwd)"
echo "分发生: Windows 可将 models/asr 放在 exe 同级目录；Android 放到 <应用支持目录>/models/asr"
