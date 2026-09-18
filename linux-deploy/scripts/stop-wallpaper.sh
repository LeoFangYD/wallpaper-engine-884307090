#!/usr/bin/env bash
# ==============================================================================
# stop-wallpaper.sh — 手动关闭动态壁纸
#
# 会写入「手动关闭」标记，watchdog 看到标记后不会再把壁纸拉起来，
# 直到下次 start-wallpaper.sh（或重新登录）清除标记。
# 想临时停掉但保留 watchdog，用： stop-wallpaper.sh
# 想彻底停掉 watchdog 本身，用： stop-wallpaper.sh --watchdog
# ==============================================================================
set -u

# 公共库：安装后在同目录，仓库内直接运行时在 ../lib
_wpe_dir="$(cd "$(dirname "$0")" && pwd -P)"
if [ -r "$_wpe_dir/common.sh" ]; then
    . "$_wpe_dir/common.sh"
else
    . "$_wpe_dir/../lib/common.sh"
fi

STOP_WATCHDOG=0
[ "${1:-}" = "--watchdog" ] && STOP_WATCHDOG=1

mkdir -p "$WPE_RUNTIME_DIR" 2>/dev/null || true

# 明确告诉 watchdog：这是用户主动关闭，不是闪退
: >"$WPE_STOP_FLAG"

if wpe_engine_running; then
    pkill -f -- "$WPE_ENGINE_BIN" 2>/dev/null || true
    sleep 1
    if wpe_engine_running; then
        pkill -9 -f -- "$WPE_ENGINE_BIN" 2>/dev/null || true
    fi
    echo "Wallpaper Engine 已手动关闭。"
else
    echo "Wallpaper Engine 本来就没有在运行。"
fi

if [ "$STOP_WATCHDOG" = "1" ]; then
    if [ -f "$WPE_WATCHDOG_PIDFILE" ]; then
        WPID="$(cat "$WPE_WATCHDOG_PIDFILE" 2>/dev/null || true)"
        if [ -n "$WPID" ] && kill -0 "$WPID" 2>/dev/null; then
            kill "$WPID" 2>/dev/null || true
            echo "watchdog 已停止 (PID=$WPID)。"
        fi
        rm -f "$WPE_WATCHDOG_PIDFILE"
    else
        # 没有 pidfile（例如 watchdog 是手动启动的）：按脚本名兜底
        pkill -f -- "wallpaper-watchdog\.sh" 2>/dev/null || true
        echo "watchdog 已停止。"
    fi
else
    echo "watchdog 仍在运行，但不会重新启动壁纸。"
fi
