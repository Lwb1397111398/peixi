#!/bin/bash
# sqlite3 包（native assets 钩子）在 Android 构建时默认从 GitHub Releases 下载
# libsqlite3.<abi>.android.so；本机访问 GitHub 间歇性超时会导致
# "Target build_hooks failed: Building native assets failed"。
#
# 本脚本把 tool/sqlite3-android-cache/ 中已校验的 .so 装入钩子共享缓存
# （.dart_tool/hooks_runner/shared/sqlite3/build/download-<sha256前8位>/libsqlite3.so）。
#
# 注意：flutter clean 会删除 .dart_tool，之后 Android 构建前需重跑本脚本。
# 若缓存文件缺失，会尝试 GitHub 直连及镜像下载并校验 SHA-256。
set -u
cd "$(dirname "$0")"
STAGE=sqlite3-android-cache
PROJ_ROOT=$(cd .. && pwd)
SHARED="$PROJ_ROOT/.dart_tool/hooks_runner/shared/sqlite3/build"
declare -A FILES=(
 [libsqlite3.arm.android.so]=a42fa9d0f5c006d30b000d4904bc497705191c5d7330b178618546004295bb49
 [libsqlite3.arm64.android.so]=0c2d3bfc8c87abceb21ed72a4bb49964121c5fe1a8ef3848d83ba907d01b6161
 [libsqlite3.ia32.android.so]=3888ba23a79904b968ad7f7cd3b3f59e856a25dcc90953b5a69ea6a4f9961f59
 [libsqlite3.x64.android.so]=949965f0eba976f707ae364cdcb42c342b5f0626081f8d7f0378fb7b52848772
)
BASE=https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.2
MIRRORS=("$BASE" "https://ghfast.top/$BASE" "https://gh-proxy.com/$BASE" "https://ghproxy.net/$BASE")
mkdir -p "$STAGE" "$SHARED"
FAIL=0
for f in "${!FILES[@]}"; do
  want=${FILES[$f]}
  if ! echo "$want  $STAGE/$f" | sha256sum -c --status 2>/dev/null; then
    ok=0
    for m in "${MIRRORS[@]}"; do
      echo "下载 $f <- $m"
      if curl -sSL --connect-timeout 15 --max-time 300 -o "$STAGE/$f" "$m/$f" \
         && echo "$want  $STAGE/$f" | sha256sum -c --status 2>/dev/null; then
        ok=1; break
      fi
    done
    [ $ok -eq 1 ] || { echo "无法获取 $f"; FAIL=1; }
  fi
done
[ $FAIL -eq 0 ] || exit 1
for pair in "a42fa9d0:arm" "0c2d3bfc:arm64" "3888ba23:ia32" "949965f0:x64"; do
  dir=${pair%%:*}; abi=${pair##*:}
  mkdir -p "$SHARED/download-$dir"
  cp "$STAGE/libsqlite3.$abi.android.so" "$SHARED/download-$dir/libsqlite3.so"
done
echo "sqlite3 Android 库已装入钩子缓存：$SHARED"
