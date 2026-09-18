#!/usr/bin/env bash
# ==============================================================================
# uninstall.sh — 卸载部署（默认只删部署目录与自启动，不动你的仓库和壁纸原文件）
#
# 用法:
#   ./uninstall.sh            # 交互确认后卸载
#   ./uninstall.sh --yes      # 不询问
#   ./uninstall.sh --keep-config   # 保留 ~/.config/wallpaper-engine-linux/wallpaper.conf
# ==============================================================================
set -u

HERE="$(cd "$(dirname "$0")" && pwd -P)"
WPE_ROOT="${WPE_ROOT:-$HOME/.local/share/wallpaper-engine-linux}"
AUTOSTART_DESKTOP="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/linux-wallpaperengine.desktop"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wallpaper-engine-linux"
UNIT="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/wallpaper-engine.service"

ASSUME_YES=0
KEEP_CONFIG=0
while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y) ASSUME_YES=1; shift ;;
        --keep-config) KEEP_CONFIG=1; shift ;;
        --root) WPE_ROOT="${2:?}"; shift 2 ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "未知参数: $1" >&2; exit 2 ;;
    esac
done

echo "将要删除："
echo "  - 运行中的壁纸进程"
echo "  - $WPE_ROOT  (源码/编译产物/脚本/日志)"
echo "  - $AUTOSTART_DESKTOP"
[ "$KEEP_CONFIG" = "1" ] || echo "  - $CONFIG_DIR"
echo "  - $UNIT (如果存在)"
echo "不会碰：仓库目录、壁纸原文件、~/.local/share 下其它内容"

if [ "$ASSUME_YES" != "1" ]; then
    printf '确认继续? [y/N] '
    read -r ans
    case "$ans" in y|Y|yes|YES) ;; *) echo "已取消"; exit 0 ;; esac
fi

if [ -x "$WPE_ROOT/bin/stop-wallpaper.sh" ]; then
    WPE_ROOT="$WPE_ROOT" "$WPE_ROOT/bin/stop-wallpaper.sh" --watchdog || true
else
    pkill -f "wallpaper-engine-linux" 2>/dev/null || true
fi

if systemctl --user list-unit-files 2>/dev/null | grep -q '^wallpaper-engine.service'; then
    systemctl --user disable --now wallpaper-engine.service 2>/dev/null || true
fi
rm -f "$UNIT"
rm -f "$AUTOSTART_DESKTOP"
rm -rf "$WPE_ROOT"
[ "$KEEP_CONFIG" = "1" ] || rm -rf "$CONFIG_DIR"

echo "✓ 卸载完成。"
echo "注意：仓库里的 linux-port/ 源码归档和 884307090/ 壁纸素材没有被删除。"
