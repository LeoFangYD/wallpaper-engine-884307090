#!/bin/bash

ENGINE="/home/qy/linux-wallpaperengine/build/output/linux-wallpaperengine"

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STOPFLAG="$RUNTIME_DIR/linux-wallpaperengine.manual-stop"

# 明确告诉 watchdog：
# 这是用户主动关闭，不是闪退
touch "$STOPFLAG"

pkill -f "$ENGINE" 2>/dev/null || true

echo "Wallpaper Engine 已手动关闭。"
echo "watchdog 不会重新启动它。"
