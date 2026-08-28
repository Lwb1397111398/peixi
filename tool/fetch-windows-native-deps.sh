#!/usr/bin/env bash
# Windows 构建的原生依赖预取（绕过 GitHub 直连超时）。
# 三个包在 CMake 阶段从 GitHub 下载；存在且校验通过时 CMake 会跳过下载。
# flutter clean 后需要重新执行（ffmpeg-kit 位于 build 目录内）。
set -uo pipefail

BD="$(dirname "$0")/../build/windows/x64"
FFPRE="$BD/plugins/ffmpeg_kit_flutter_new/ffmpeg-kit"
mkdir -p "$BD" "$FFPRE"

MIRRORS=("https://ghfast.top/" "https://gh-proxy.com/" "https://ghproxy.net/")

fetch() { # fetch <url> <dest> <md5|-> [size]
  local url=$1 dest=$2 md5=${3:-} minsize=${4:-1000000}
  if [ -f "$dest" ]; then
    if [ "$md5" = "-" ] || echo "$md5  $dest" | md5sum -c --status - 2>/dev/null; then
      echo "[skip] $dest 已存在且校验通过"; return 0
    fi
  fi
  for m in "${MIRRORS[@]}"; do
    echo "[try ] ${m}${url}"
    if curl -sL --connect-timeout 15 --max-time 900 -o "$dest" "${m}${url}"; then
      local sz; sz=$(stat -c %s "$dest" 2>/dev/null || echo 0)
      if [ "$sz" -ge "$minsize" ] && { [ "$md5" = "-" ] || echo "$md5  $dest" | md5sum -c --status - 2>/dev/null; }; then
        echo "[ ok ] $dest ($sz bytes)"; return 0
      fi
    fi
  done
  echo "[FAIL] $url"; return 1
}

# 1) ffmpeg-kit full-gpl（含 libmp3lame），释放到插件 prebuilt 目录并写变体标记
FF_ZIP="ffmpeg-kit-windows-x86_64-full-gpl-8.1.2.zip"
FF_URL="https://github.com/sk3llo/ffmpeg_kit_flutter/releases/download/8.1.2-full-gpl/$FF_ZIP"
if [ ! -f "$FFPRE/bin/.ffmpegkit_variant" ]; then
  rm -rf "$FFPRE"; mkdir -p "$FFPRE"
  fetch "$FF_URL" "/tmp/$FF_ZIP" - 46895294 || exit 1
  WINPRE=$(cygpath -w "$FFPRE"); WINZIP=$(cygpath -w "/tmp/$FF_ZIP")
  python - "$WINZIP" "$WINPRE" <<'EOF'
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
print('extracted')
EOF
  printf '8.1.2-full-gpl\n' > "$FFPRE/bin/.ffmpegkit_variant"
else
  echo "[skip] ffmpeg-kit 已就位"
fi

# 2) libmpv（media_kit） 3) ANGLE（media_kit 视频渲染）
fetch "https://github.com/media-kit/libmpv-win32-video-build/releases/download/2023-09-24/mpv-dev-x86_64-20230924-git-652a1dd.7z" \
  "$BD/mpv-dev-x86_64-20230924-git-652a1dd.7z" a832ef24b3a6ff97cd2560b5b9d04cd8 || exit 1
fetch "https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z" \
  "$BD/ANGLE.7z" e866f13e8d552348058afaafe869b1ed || exit 1

echo "全部就绪，可执行: flutter build windows --release"
