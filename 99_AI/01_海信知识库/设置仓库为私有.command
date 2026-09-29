#!/bin/bash
# ============================================================
#  把 GitHub 仓库 baixiebaba/01_--  设为 Private，并验证生效
#  用法：双击运行。中途需要在浏览器里登录 GitHub 一次。
# ============================================================
set -u
REPO="baixiebaba/01_--"
WEB="https://github.com/baixiebaba/01_--"

# 让终端停留在脚本所在目录
cd "$(dirname "$0")" || exit 1

echo "=========================================="
echo " GitHub 仓库私有化工具"
echo " 目标仓库: $REPO"
echo "=========================================="
echo

# ---------- 0. 定位 gh（找不到就自动下载官方二进制）----------
GH=""
for c in "$HOME/.local/bin/gh" /usr/local/bin/gh /opt/homebrew/bin/gh "$(command -v gh 2>/dev/null)"; do
  [ -x "$c" ] && GH="$c" && break
done
if [ -z "$GH" ]; then
  echo "未找到 gh，正在下载官方版本（约 15MB）…"
  mkdir -p "$HOME/.local/bin"
  curl -sSL --max-time 240 -o /tmp/gh.zip \
    "https://github.com/cli/cli/releases/download/v2.101.0/gh_2.101.0_macOS_amd64.zip"
  unzip -o -q /tmp/gh.zip -d /tmp/ghx
  cp /tmp/ghx/gh_2.101.0_macOS_amd64/bin/gh "$HOME/.local/bin/gh"
  chmod +x "$HOME/.local/bin/gh"
  GH="$HOME/.local/bin/gh"
fi
if [ ! -x "$GH" ]; then
  echo "❌ gh 安装失败，请改用网页方式操作（见说明）。"
  echo
  read -r -p "按回车键关闭…"
  exit 1
fi
echo "✅ 找到 gh: $GH"
"$GH" --version | head -1
echo

# ---------- 1. 检查登录状态 ----------
echo "--- 第 1 步：检查 GitHub 登录状态 ---"
if "$GH" auth status >/dev/null 2>&1; then
  echo "✅ 已登录 GitHub，账号信息："
  "$GH" auth status 2>&1 | sed 's/^/     /'
else
  echo "⚠️  尚未登录，现在开始登录（需要你在浏览器里操作一次）"
  echo
  echo "   接下来会显示一个 8 位的一次性验证码（one-time code），"
  echo "   流程是："
  echo "     1) 终端显示验证码，例如  A1B2-C3D4"
  echo "     2) 按回车，自动打开浏览器"
  echo "     3) 浏览器里粘贴这个验证码 → 点 Authorize github"
  echo
  read -r -p "准备好了？按回车开始登录…"
  echo
  "$GH" auth login --hostname github.com --web --git-protocol https
  echo
  if ! "$GH" auth status >/dev/null 2>&1; then
    echo "❌ 登录似乎没成功，请重新运行本脚本再试一次。"
    read -r -p "按回车键关闭…"
    exit 1
  fi
  echo "✅ 登录成功"
fi
echo

# ---------- 2. 确认当前可见性 ----------
echo "--- 第 2 步：查看仓库当前可见性 ---"
"$GH" repo view "$REPO" --json visibility,nameWithOwner 2>&1 | sed 's/^/     /'
echo

read -r -p "确认要把这个仓库设为 Private 吗？(y/n) " ans
case "$ans" in
  [yY]*) ;;
  *) echo "已取消，未做任何修改。"; read -r -p "按回车键关闭…"; exit 0;;
esac
echo

# ---------- 3. 执行私有化 ----------
echo "--- 第 3 步：设置为 Private ---"
if "$GH" repo edit "$REPO" --visibility private --accept-visibility-change-consequences 2>&1 | sed 's/^/     /'; then
  echo "✅ 命令已执行"
else
  echo "⚠️  上面的命令返回了非 0 状态，尝试不带额外参数再执行一次…"
  "$GH" repo edit "$REPO" --visibility private 2>&1 | sed 's/^/     /'
fi
echo

# ---------- 4. 验证 ----------
echo "--- 第 4 步：验证结果 ---"
echo
echo "[验证 1] 从 GitHub 读取仓库可见性："
"$GH" repo view "$REPO" --json visibility -q '.visibility' 2>/dev/null | sed 's/^/     可见性 = /'
echo

echo "[验证 2] 未认证访问仓库主页（未登录的人看到的就是这个）："
code=$(curl -s -o /dev/null -w "%{http_code}" -m 20 "$WEB")
echo "     HTTP 状态码 = $code"
if [ "$code" = "404" ]; then
  echo "     ✅ 404 —— 未授权人员已无法访问（GitHub 对私有仓库故意返回 404，不泄露仓库存在性）"
else
  echo "     ⚠️  期望 404，实际 $code。可能还是公开，或网络异常。"
fi
echo

echo "[验证 3] 未认证调用 API："
apicode=$(curl -s -o /dev/null -w "%{http_code}" -m 20 "https://api.github.com/repos/$REPO")
echo "     HTTP 状态码 = $apicode   （404 = 已私有化）"
echo

echo "[验证 4] 你自己的访问权限（应该正常）："
"$GH" repo view "$REPO" --json name,visibility,defaultBranch -q '"     \(.name) | 可见性=\(.visibility) | 默认分支=\(.defaultBranch)"' 2>/dev/null
echo

echo "=========================================="
echo " 完成。上面 4 项验证结果请截图发给我确认。"
echo
echo " 提醒："
echo "  · 你是仓库 owner，私有化后依然拥有全部权限，无需额外授权。"
echo "  · 本地 git push 不受影响（凭据不变）；若提示认证失败，"
echo "    执行： gh auth setup-git"
echo "=========================================="
echo
read -r -p "按回车键关闭本窗口…"
