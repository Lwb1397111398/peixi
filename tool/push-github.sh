#!/usr/bin/env bash
# 把 peixi 子目录单独同步到 GitHub（工作区大仓库含其他项目，不能整仓推送）。
# 用 git subtree split 生成"只含 peixi 历史"的临时分支，强推为远端 main。
# 注意：subtree 的 -P 路径相对当前目录，必须回到仓库根执行。
#
# 前置（一次性，已完成）：
#   gh auth login && gh auth setup-git
#   git remote add github https://github.com/Lwb1397111398/peixi.git
# 之后每次同步只需：bash tool/push-github.sh
# 直连被重置时自动改走代理（可用环境变量 PROXY 覆盖端口）。
set -euo pipefail
cd "$(dirname "$0")/../.." # 仓库根（peixi 的上一级）

REMOTE="${1:-github}"
BRANCH="${2:-github-main}"
PROXY="${PROXY:-http://127.0.0.1:7890}"

if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
  echo "未配置远端 '$REMOTE'。执行："
  echo "  git remote add $REMOTE https://github.com/Lwb1397111398/peixi.git"
  exit 1
fi

echo "[1/2] 生成 peixi 子树分支 $BRANCH …"
git subtree split -P peixi -b "$BRANCH" >/dev/null

echo "[2/2] 推送 $BRANCH → $REMOTE/main …"
if ! git push "$REMOTE" "$BRANCH:main" --force 2>&1; then
  echo "直连推送失败，改走代理 $PROXY 重试 …"
  git -c "http.proxy=$PROXY" push "$REMOTE" "$BRANCH:main" --force
fi
echo "完成。"
