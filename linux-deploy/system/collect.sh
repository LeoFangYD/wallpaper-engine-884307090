#!/usr/bin/env bash
# ==============================================================================
# collect.sh — 重新采集本机的桌面侧配套设置快照
#
# 会在脚本所在目录（linux-deploy/system/）刷新：
#   system.txt                 系统、内核、会话、GPU 驱动、显示器、字体解析
#   gnome-desktop-settings.txt GNOME 扩展列表 + dconf 里与壁纸相关的关键项
#   packages.txt               依赖包的实际安装版本
#   fonts.sha256               已安装微软字体的校验值
#
# 什么时候跑：换了显示器/分辨率、调了 GNOME 设置、装了或删了依赖、升级了驱动之后。
#
# 用法:
#   ./collect.sh          # 采集并打印 git diff 摘要
#   ./collect.sh --quiet  # 只采集
# ==============================================================================
set -u

HERE="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$HERE/../.." && pwd -P)"
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

say() { [ "$QUIET" = "1" ] || printf '%s\n' "$*"; }
FONT_DIR="/usr/local/share/fonts/microsoft"

# ---------------------------------------------------------------- system.txt
say "== 采集 system.txt"
{
    echo "=== 备份日期 ==="
    date
    echo
    echo "=== 系统 ==="
    lsb_release -a 2>/dev/null || head -5 /etc/os-release
    echo
    echo "=== 内核 ==="
    uname -a
    echo
    echo "=== 桌面会话 ==="
    echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-}"
    echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-}"
    echo "DISPLAY=${DISPLAY:-}"
    echo "XAUTHORITY=${XAUTHORITY:-}"
    gnome-shell --version 2>/dev/null || echo "gnome-shell 版本未知"
    echo
    echo "=== GPU / 驱动 ==="
    # nvidia-smi 读不到设备时会把错误打到 stdout，这里只认真正的 CSV 输出
    GPU_INFO="$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null \
                | grep -v 'failed because' | head -2)"
    if [ -n "$GPU_INFO" ]; then
        printf '%s\n' "$GPU_INFO"
    else
        # 兜底：型号从 lspci，驱动版本从内核模块（不依赖设备节点）
        echo "(nvidia-smi 不可用，改用 lspci / /proc/driver/nvidia/version)"
        lspci -nn 2>/dev/null | grep -Ei "vga|3d controller" | sed 's/^/GPU: /'
        [ -r /proc/driver/nvidia/version ] && head -1 /proc/driver/nvidia/version | sed 's/^/驱动: /'
    fi
    echo
    echo "=== 编译工具 ==="
    gcc --version 2>/dev/null | head -1
    cmake --version 2>/dev/null | head -1
    echo
    echo "=== 显示器 ==="
    (xrandr --current 2>/dev/null | grep -E " connected") || echo "无法读取"
    echo
    echo "=== 字体 ==="
    fc-match "DengXian Light" 2>/dev/null
    fc-match "Microsoft YaHei Light" 2>/dev/null
    echo "字体安装位置: $FONT_DIR"
} >"$HERE/system.txt"

# ------------------------------------------------------- gnome-desktop-settings.txt
say "== 采集 gnome-desktop-settings.txt"
# dconf 在没有图形会话/会话总线的环境（ssh、沙箱）里会返回空。
# 这时**保留原文件**，避免把已经归档好的设置刷成空白。
BG_DUMP="$(dconf dump /org/gnome/desktop/background/ 2>/dev/null)"
DING_DUMP="$(dconf dump /org/gnome/shell/extensions/ding/ 2>/dev/null)"
SCALE="$(dconf read /org/gnome/desktop/interface/text-scaling-factor 2>/dev/null)"
if [ -z "$BG_DUMP$DING_DUMP" ]; then
    say "   ! 读不到 dconf（需要在图形会话里运行），保留原有 gnome-desktop-settings.txt"
else
    {
        echo "=== GNOME Shell 扩展（桌面图标依赖 ding）==="
        gnome-extensions list --enabled 2>/dev/null || gnome-extensions list 2>/dev/null || echo "(无法读取)"
        echo
        echo "=== dconf: 桌面背景（壁纸模式下背景纯黑，动态壁纸在下方）==="
        printf '%s\n' "$BG_DUMP"
        echo "=== dconf: DING 桌面图标扩展 ==="
        printf '%s\n' "$DING_DUMP"
        echo "=== dconf: 界面缩放 ==="
        [ -n "$SCALE" ] && echo "text-scaling-factor: $SCALE" || echo "text-scaling-factor: (未设置，使用默认)"
    } >"$HERE/gnome-desktop-settings.txt"
fi

# ---------------------------------------------------------------- packages.txt
say "== 采集 packages.txt"
{
    echo "=== 依赖包实际版本（name  版本 / (未安装)）==="
    for p in $(cat "$HERE"/../deps/ubuntu-22.04.txt "$HERE"/../deps/ubuntu-24.04.txt 2>/dev/null \
               | grep -v '^#' | sort -u); do
        v="$(dpkg-query -W -f='${Version}' "$p" 2>/dev/null)" || v="(未安装)"
        printf '%-24s %s\n' "$p" "$v"
    done
    echo
    echo "=== 运行时工具 ==="
    for c in xrandr xprop wmctrl python3 pactl fc-match git git-lfs cmake g++; do
        printf '%-12s %s\n' "$c" "$(command -v "$c" 2>/dev/null || echo '(缺失)')"
    done
} >"$HERE/packages.txt"

# ---------------------------------------------------------------- fonts.sha256
say "== 采集 fonts.sha256"
if [ -d "$FONT_DIR" ] && ls "$FONT_DIR"/*.TT[FC] >/dev/null 2>&1; then
    (cd "$FONT_DIR" && sha256sum *.TTF *.TTC 2>/dev/null | sort -k2) >"$HERE/fonts.sha256"
    say "   已记录 $(wc -l < "$HERE/fonts.sha256") 个字体文件"
else
    say "   ! 未找到 $FONT_DIR 下的字体，保留原 fonts.sha256"
fi

say
say "采集完成。查看变更："
if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$REPO_ROOT" --no-pager diff --stat -- linux-deploy/system
    say
    say "提交： git add linux-deploy/system && git commit -m 'Refresh desktop settings snapshot' && git push"
else
    say "（$REPO_ROOT 不是 git 仓库，跳过 diff）"
fi
