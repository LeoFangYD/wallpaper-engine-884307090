#!/usr/bin/env bash
# ==============================================================================
# start-wallpaper.sh — 启动动态壁纸并把它压到 GNOME 桌面图标下方
#
# 与旧版（硬编码 /home/qy）的区别：
#   * 所有路径来自 common.sh 的配置体系，换机器无需改脚本；
#   * 启动前做完整的环境自检，缺什么直接中文报错；
#   * 日志自动轮转，不再无限增长；
#   * 支持多显示器（WPE_MONITOR）与分辨率自动探测。
# ==============================================================================
set -u

# 公共库：安装后在同目录，仓库内直接运行时在 ../lib
_wpe_dir="$(cd "$(dirname "$0")" && pwd -P)"
if [ -r "$_wpe_dir/common.sh" ]; then
    . "$_wpe_dir/common.sh"
else
    . "$_wpe_dir/../lib/common.sh"
fi

wpe_prepare
wpe_rotate_log "$WPE_LOG_FILE"

wpe_require_x11
wpe_require_commands wmctrl xprop xrandr python3
wpe_assert_engine

WALLPAPER="$(wpe_resolve_wallpaper)" || wpe_die "找不到壁纸目录（需要含 project.json）。
请检查配置 $WPE_CONFIG_FILE 里的 WPE_WALLPAPER，或把壁纸放到 $WPE_WALLPAPER_SEARCH/ 下。"

GEOM="$(wpe_geometry)" || wpe_die "无法取得显示器几何信息。请检查 WPE_MONITOR 配置（当前: $WPE_MONITOR）。"

# 计划内重启：清掉“手动关闭”标记，watchdog 才会继续守护
rm -f "$WPE_STOP_FLAG"

# 先关掉旧实例
if wpe_engine_running; then
    pkill -f -- "$WPE_ENGINE_BIN" 2>/dev/null || true
    sleep 1
fi

{
    echo "=================================================="
    echo "[$(date '+%F %T')] 启动动态壁纸"
    echo "  引擎   : $WPE_ENGINE_BIN"
    echo "  壁纸   : $WALLPAPER"
    echo "  几何   : $GEOM (XxYxWxH, 显示器=$WPE_MONITOR)"
    echo "  FPS    : $WPE_FPS"
} >>"$WPE_LOG_FILE"

ARGS=(
    --assets-dir "$WPE_ASSETS_DIR"
    --window "$GEOM"
    --fps "$WPE_FPS"
)
[ "${WPE_DISABLE_MOUSE:-1}" = "1" ] && ARGS+=(--disable-mouse)
# 额外参数（例如 --no-audio-processing、--audio-volume 等）由配置提供
if [ -n "${WPE_EXTRA_ARGS:-}" ]; then
    # shellcheck disable=SC2206
    ARGS+=($WPE_EXTRA_ARGS)
fi
ARGS+=("$WALLPAPER")

cd "$(dirname "$WPE_ENGINE_BIN")" || wpe_die "无法进入引擎目录: $(dirname "$WPE_ENGINE_BIN")"

env \
    LD_LIBRARY_PATH="$(dirname "$WPE_ENGINE_BIN")" \
    LD_PRELOAD="$(dirname "$WPE_ENGINE_BIN")/libcef.so" \
    __GL_THREADED_OPTIMIZATIONS="$WPE_GL_THREADED_OPTIMIZATIONS" \
    "$WPE_ENGINE_BIN" "${ARGS[@]}" >>"$WPE_LOG_FILE" 2>&1 &

PID=$!
echo "  PID    : $PID" >>"$WPE_LOG_FILE"

# ---------- 等待真正的引擎窗口出现 ----------
# 引擎由 watchdog 拉起时，本脚本会先退出、引擎继续常驻；
# disown 让 bash 不再把这个后台任务登记为“job”，
# 否则它被 kill 时 bash 会往日志里写一行 "Killed" 干扰排查。
disown "$PID" 2>/dev/null || true

WID=""
TRIES=$(( WPE_STARTUP_TIMEOUT * 10 ))
for _ in $(seq 1 "$TRIES"); do
    WID=$(wmctrl -lp 2>/dev/null | awk -v p="$PID" '$3 == p {print $1; exit}')
    [ -n "$WID" ] && break
    if ! kill -0 "$PID" 2>/dev/null; then
        echo "  引擎进程已退出（见 $WPE_LOG_FILE 末尾日志）" >>"$WPE_LOG_FILE"
        wpe_die "引擎启动后立即退出，请查看日志: $WPE_LOG_FILE"
    fi
    sleep 0.1
done

[ -n "$WID" ] || wpe_die "等待 ${WPE_STARTUP_TIMEOUT}s 仍未见引擎窗口，请查看日志: $WPE_LOG_FILE"

echo "  WID    : $WID" >>"$WPE_LOG_FILE"

# ---------- 设为桌面窗口层级 ----------
xprop -id "$WID" \
    -f _NET_WM_WINDOW_TYPE 32a \
    -set _NET_WM_WINDOW_TYPE _NET_WM_WINDOW_TYPE_DESKTOP >>"$WPE_LOG_FILE" 2>&1

wmctrl -i -r "$WID" -b remove,above >>"$WPE_LOG_FILE" 2>&1
wmctrl -i -r "$WID" -b add,below,sticky,skip_taskbar,skip_pager >>"$WPE_LOG_FILE" 2>&1

# ---------- 用 X11 XLowerWindow 真正压到最底层 ----------
python3 - "$WID" >>"$WPE_LOG_FILE" 2>&1 <<'PY'
import ctypes
import sys
import time

wid = int(sys.argv[1], 16)

x11 = ctypes.CDLL("libX11.so.6")
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XLowerWindow.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
x11.XFlush.argtypes = [ctypes.c_void_p]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]

dpy = x11.XOpenDisplay(None)
if not dpy:
    raise SystemExit("无法打开 X11 DISPLAY")

# GNOME 映射窗口期间可能重新排序，多压几次
for _ in range(8):
    x11.XLowerWindow(dpy, wid)
    x11.XFlush(dpy)
    time.sleep(0.15)

x11.XCloseDisplay(dpy)
print("Wallpaper 已降到桌面图标下方")
PY

echo "[$(date '+%F %T')] 启动完成 (PID=$PID WID=$WID)" >>"$WPE_LOG_FILE"
exit 0
