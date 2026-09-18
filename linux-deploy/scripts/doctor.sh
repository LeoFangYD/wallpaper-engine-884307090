#!/usr/bin/env bash
# ==============================================================================
# doctor.sh — 换机部署后的体检脚本：逐项检查环境是否满足运行条件
# 用法: ./doctor.sh
# 退出码: 0 = 全部通过 / 1 = 有致命问题
# ==============================================================================
set -u

. "$(cd "$(dirname "$0")" && pwd -P)/common.sh"

FAIL=0
ok()   { printf '  ✓ %s\n' "$*"; }
bad()  { printf '  ✗ %s\n' "$*"; FAIL=1; }
warn() { printf '  ! %s\n' "$*"; }

echo "== 1. 会话环境 =="
if [ "${XDG_SESSION_TYPE:-}" = "x11" ] || [ -n "${DISPLAY:-}" ]; then
    ok "X11 会话 (DISPLAY=${DISPLAY:-未设置}, type=${XDG_SESSION_TYPE:-未知})"
else
    bad "不是 X11 会话。请使用 GNOME on Xorg 登录"
fi
[ -z "${WAYLAND_DISPLAY:-}" ] && ok "没有 Wayland 会话干扰" || warn "检测到 WAYLAND_DISPLAY=${WAYLAND_DISPLAY}，当前实现按 X11 处理"

echo "== 2. 运行依赖命令 =="
for c in bash xrandr xprop wmctrl python3; do
    if wpe_have "$c"; then ok "$c"; else bad "$c 缺失 -> sudo apt-get install -y wmctrl x11-utils x11-xserver-utils python3"; fi
done
for c in pactl fc-match; do
    if wpe_have "$c"; then ok "$c"; else warn "$c 缺失（音频可视化/字体检查会受影响）"; fi
done

echo "== 3. 引擎与壁纸 =="
if [ -x "$WPE_ENGINE_BIN" ]; then
    ok "引擎可执行: $WPE_ENGINE_BIN"
    [ -f "$(dirname "$WPE_ENGINE_BIN")/libcef.so" ] && ok "CEF 运行时 libcef.so 存在" || bad "缺少 libcef.so（编译未完成？）"
else
    bad "引擎未编译: $WPE_ENGINE_BIN -> 运行 build/build-engine.sh"
fi
if WP="$(wpe_resolve_wallpaper)"; then
    ok "壁纸目录: $WP"
    [ -f "$WP/project.json" ] && ok "project.json 存在" || bad "缺少 project.json"
else
    bad "找不到壁纸目录（含 project.json）"
fi
if [ -d "$WPE_ASSETS_DIR" ]; then
    ok "assets 目录: $WPE_ASSETS_DIR"
else
    warn "assets 目录不存在，将在启动时自动创建: $WPE_ASSETS_DIR"
fi

echo "== 4. 显示器 =="
if GEOM="$(wpe_geometry)"; then
    ok "几何信息: $GEOM (XxYxWxH)"
    echo "    xrandr 输出:"
    xrandr --current | grep -E " connected" | sed 's/^/      /'
else
    bad "无法探测显示器几何（检查 WPE_MONITOR=$WPE_MONITOR）"
fi

echo "== 5. 字体（壁纸排版依赖） =="
for f in "DengXian Light" "DengXian" "Microsoft YaHei Light" "Microsoft YaHei"; do
    m="$(fc-match "$f" 2>/dev/null || true)"
    case "$m" in
        *DengXian*|*等线*|*YaHei*|*雅黑*) ok "fc-match \"$f\" -> $m" ;;
        *) warn "fc-match \"$f\" -> $m （字体缺失时会回退，排版可能移位，见 docs/TROUBLESHOOTING.md）" ;;
    esac
done

echo "== 6. 开机自启动 =="
A="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/linux-wallpaperengine.desktop"
if [ -f "$A" ]; then
    ok "已安装: $A"
    sed -n 's/^Exec=/     Exec=/p' "$A"
else
    warn "未安装 GNOME 自启动 -> install.sh --autostart"
fi
if systemctl --user list-unit-files 2>/dev/null | grep -q '^wallpaper-engine.service'; then
    ok "systemd user 服务已安装"
fi

echo
if [ "$FAIL" = "0" ]; then
    echo "体检结果: 通过（警告项不致命）"
else
    echo "体检结果: 存在致命问题，请按上面 ✗ 提示修复"
fi
exit "$FAIL"
