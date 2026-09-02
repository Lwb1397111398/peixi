#!/usr/bin/env bash
# 把 peixi 子目录单独同步到 GitHub（工作区大仓库含其他项目，不能整仓推送）。
# 用 git subtree split 生成"只含 peixi 历史"的临时分支，强推为远端 main。
#
# 首次使用：
#   1) 在 github.com 创建空仓库（建议 Private）
#   2) git remote add github https://github.com/<你的用户名>/peixi.git
# 之后每次同步只需运行：bash tool/push-github.sh
set -euo pipefail
cd "$(dirname "$0")/.." # peixi 根

REMOTE="${1:-github}"
BRANCH="${2:-github-main}"

if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
  echo "未配置远端 '$REMOTE'。执行："
  echo "  git remote add $REMOTE https://github.com/<用户名>/peixi.git"
  exit 1
fi

echo "[1/2] 生成 peixi 子树分支 $BRANCH …"
git subtree split -P peixi -b "$BRANCH" >/dev/null

echo "[2/2] 推送 $BRANCH → $REMOTE/main …"
git push "$REMOTE" "$BRANCH:main" --force
echo "完成。"
