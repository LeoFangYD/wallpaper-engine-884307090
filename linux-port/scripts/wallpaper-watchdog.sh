#!/bin/bash

ENGINE="/home/qy/linux-wallpaperengine/build/output/linux-wallpaperengine"
START="/home/qy/linux-wallpaperengine/start-wallpaper.sh"

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STOPFLAG="$RUNTIME_DIR/linux-wallpaperengine.manual-stop"
LOCK="$RUNTIME_DIR/linux-wallpaperengine-watchdog.lock"

WATCHLOG="/tmp/linux-wallpaperengine-watchdog.log"

# 防止同一登录会话启动多个 watchdog
exec 9>"$LOCK"
flock -n 9 || exit 0

echo "========================================" >> "$WATCHLOG"
echo "$(date '+%F %T') watchdog started" >> "$WATCHLOG"

# 等 GNOME / X11 / PulseAudio 就绪
for i in $(seq 1 30); do
    if xrandr --current >/dev/null 2>&1 && \
       pactl info >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

sleep 5

restart_count=0
restart_window_start=$(date +%s)

while true; do

    #
    # 用户主动关闭：
    # watchdog 保持运行，但绝不重新拉起壁纸
    #
    if [ -f "$STOPFLAG" ]; then
        sleep 3
        continue
    fi

    #
    # 壁纸正常运行
    #
    if pgrep -f "$ENGINE" >/dev/null 2>&1; then

        now=$(date +%s)

        # 连续稳定运行超过 2 分钟后，
        # 清除之前的闪退计数
        if [ $((now - restart_window_start)) -ge 120 ]; then
            restart_count=0
            restart_window_start=$now
        fi

        sleep 3
        continue
    fi

    #
    # 到这里说明壁纸异常退出
    #
    now=$(date +%s)

    if [ $((now - restart_window_start)) -ge 120 ]; then
        restart_count=0
        restart_window_start=$now
    fi

    restart_count=$((restart_count + 1))

    echo "$(date '+%F %T') engine exited, restart attempt=$restart_count" \
        >> "$WATCHLOG"

    #
    # 防止无限闪退 → 无限重启
    #
    if [ "$restart_count" -gt 5 ]; then
        echo "$(date '+%F %T') crash loop detected, auto restart disabled" \
            >> "$WATCHLOG"

        touch "$STOPFLAG"

        sleep 3
        continue
    fi

    "$START" >> "$WATCHLOG" 2>&1

    # 给 CEF / OpenGL 足够时间初始化
    sleep 8
done
