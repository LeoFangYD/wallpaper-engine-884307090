#!/bin/bash

# ===== clear manual stop flag =====
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STOPFLAG="$RUNTIME_DIR/linux-wallpaperengine.manual-stop"
rm -f "$STOPFLAG"


ENGINE="/home/qy/linux-wallpaperengine/build/output"
WALLPAPER="/home/qy/壁纸/WallpaperEngine/wallpaper-engine-884307090/884307090"
ASSETS="/home/qy/linux-wallpaperengine/empty-assets"
LOG="/tmp/linux-wallpaperengine.log"

# 关闭旧壁纸
pkill -f "$ENGINE/linux-wallpaperengine" 2>/dev/null || true
sleep 1

# 获取主显示器几何信息：WxH+X+Y
RAW=$(xrandr --current | awk '
/ connected primary / {
    for (i=1;i<=NF;i++) {
        if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) {
            print $i
            exit
        }
    }
}')

# 没有 primary 时取第一个连接的屏幕
if [ -z "$RAW" ]; then
    RAW=$(xrandr --current | awk '
    / connected / {
        for (i=1;i<=NF;i++) {
            if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) {
                print $i
                exit
            }
        }
    }')
fi

if [ -z "$RAW" ]; then
    echo "无法取得显示器尺寸" > "$LOG"
    exit 1
fi

WH="${RAW%%+*}"
POS="${RAW#*+}"

X="${POS%%+*}"
Y="${POS#*+}"

W="${WH%x*}"
H="${WH#*x}"

GEOM="${X}x${Y}x${W}x${H}"

echo "屏幕: $RAW" > "$LOG"
echo "Wallpaper geometry: $GEOM" >> "$LOG"

cd "$ENGINE" || exit 1

# 启动 Wallpaper Engine
env \
LD_LIBRARY_PATH="$ENGINE" \
LD_PRELOAD="$ENGINE/libcef.so" \
__GL_THREADED_OPTIMIZATIONS=0 \
"$ENGINE/linux-wallpaperengine" \
  --disable-mouse \
  --assets-dir "$ASSETS" \
  --window "$GEOM" \
  --fps 60 \
  "$WALLPAPER" \
  >> "$LOG" 2>&1 &

PID=$!

echo "PID=$PID" >> "$LOG"

# 等待真正的 Wallpaper Engine 窗口出现
WID=""

for i in $(seq 1 80); do
    WID=$(wmctrl -lp | awk -v p="$PID" '$3 == p {print $1; exit}')

    if [ -n "$WID" ]; then
        break
    fi

    sleep 0.1
done

if [ -z "$WID" ]; then
    echo "找不到 Wallpaper Engine 主窗口" >> "$LOG"
    exit 1
fi

echo "WID=$WID" >> "$LOG"

# 设置成桌面窗口
xprop -id "$WID" \
  -f _NET_WM_WINDOW_TYPE 32a \
  -set _NET_WM_WINDOW_TYPE _NET_WM_WINDOW_TYPE_DESKTOP

# 位于普通窗口与桌面图标下面
wmctrl -i -r "$WID" -b remove,above
wmctrl -i -r "$WID" -b add,below,sticky,skip_taskbar,skip_pager

# 用真正的 X11 XLowerWindow 降到底层
export WID

python3 <<'PY' >> "$LOG" 2>&1
import os
import ctypes
import time

wid = int(os.environ["WID"], 16)

x11 = ctypes.CDLL("libX11.so.6")

x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]

x11.XLowerWindow.argtypes = [
    ctypes.c_void_p,
    ctypes.c_ulong
]

x11.XFlush.argtypes = [ctypes.c_void_p]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]

dpy = x11.XOpenDisplay(None)

if not dpy:
    raise RuntimeError("无法打开 X11 DISPLAY")

# GNOME 映射窗口期间可能重新排序，多压几次
for _ in range(8):
    x11.XLowerWindow(dpy, wid)
    x11.XFlush(dpy)
    time.sleep(0.15)

x11.XCloseDisplay(dpy)

print("Wallpaper 已降到桌面图标下方")
PY

echo "启动完成" >> "$LOG"

exit 0
