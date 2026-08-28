#!/usr/bin/env bash
# Android 构建的原生依赖预取（media_kit 的 libmpv jar 从 GitHub 下载，直连超时）。
# jar 校验通过时 gradle 会跳过下载。flutter clean 后需重跑。
set -uo pipefail

DEST="$(dirname "$0")/../build/media_kit_libs_android_video/v1.1.7"
mkdir -p "$DEST"

BASE="https://github.com/media-kit/libmpv-android-video-build/releases/download/v1.1.7"
declare -A MD5=(
  [default-arm64-v8a.jar]=83df25b61193af8fa815e373143ac9af
  [default-armeabi-v7a.jar]=22e21526fefc0a2b8f17adbec9f57590
  [default-x86_64.jar]=6fa26bf0459b11f1c0b0dbc29e5b940d
  [default-x86.jar]=0d742b756dc9d1fcd84ea271d8b68f32
)
MIRRORS=("https://ghfast.top/" "https://gh-proxy.com/" "https://ghproxy.net/")

cd "$DEST" || exit 1
rc=0
for F in default-arm64-v8a.jar default-armeabi-v7a.jar default-x86_64.jar default-x86.jar; do
  if echo "${MD5[$F]}  $F" | md5sum -c --status - 2>/dev/null; then
    echo "[skip] $F"; continue
  fi
  ok=0
  for m in "${MIRRORS[@]}"; do
    echo "[try ] ${m}${BASE}/${F}"
    if curl -sL --connect-timeout 15 --max-time 600 -o "$F" "${m}${BASE}/${F}" \
       && echo "${MD5[$F]}  $F" | md5sum -c --status -; then
      echo "[ ok ] $F ($(stat -c %s "$F") bytes)"; ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { echo "[FAIL] $F"; rc=1; }
done
exit $rc
