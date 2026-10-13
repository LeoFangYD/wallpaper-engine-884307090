#!/usr/bin/env bash
# ==============================================================================
# fix-icons-layer.sh — GNOME 46+：让「动态壁纸 / 桌面图标 / 应用窗口」三层稳定共存
#
# 现象
#   GNOME 46 起 DING 桌面图标改为独立窗口（WM_CLASS=Gjs）。它与壁纸引擎
#   （同为全屏窗口）争夺层级：任一方被 mutter 压到下面，就会出现
#   “有壁纸没图标” 或 “有图标没壁纸”。
#
# 稳定方案（本脚本）
#   把**引擎**放进普通层并置底，图标窗口保持普通层（不 below）：
#       engine : _NET_WM_WINDOW_TYPE_NORMAL + _NET_WM_STATE_BELOW
#       icons  : _NET_WM_WINDOW_TYPE_NORMAL              （在引擎之上）
#       apps   : 普通窗口，聚焦时自然在最上
#   由 mutter 自身的层规则维持，不再靠“抢层”，窗口重建后自动回到正确顺序。
#
# 反面做法（曾导致图标消失，勿用）
#   给图标窗口加 `below`：它会掉到引擎之下 → 图标再次被壁纸盖住。
#
# 用法
#   fix-icons-layer.sh            # 修正一次
#   fix-icons-layer.sh --loop     # 常驻守护（2 秒巡检，推荐由 systemd 托管）
# ==============================================================================
set -u

DISP="${DISPLAY:-:1}"

apply_once() {
    DISPLAY="$DISP" python3 - <<'PY'
import os, re, subprocess

D = os.environ.get("DISPLAY", ":1")

def xp(args):
    try:
        return subprocess.run(["xprop", "-display", D] + args,
                              capture_output=True, text=True, timeout=3).stdout
    except Exception:
        return ""

def wm(args):
    try:
        return subprocess.run(["wmctrl"] + args,
                              capture_output=True, text=True, timeout=3).stdout
    except Exception:
        return ""

ids = re.findall(r'0x[0-9a-f]+', xp(["-root", "_NET_CLIENT_LIST_STACKING"]))
fixed = 0
for w in ids:
    cls = xp(["-id", w, "WM_CLASS"]).lower()
    if "wallpaperengine" in cls:
        subprocess.run(["xprop", "-display", D, "-id", w,
                        "-f", "_NET_WM_WINDOW_TYPE", "32a",
                        "-set", "_NET_WM_WINDOW_TYPE", "_NET_WM_WINDOW_TYPE_NORMAL"], timeout=3)
        wm(["-i", "-r", w, "-b", "add,below,skip_taskbar,skip_pager,sticky"])
        fixed += 1
    elif "gjs" in cls or '"ding' in cls:
        subprocess.run(["xprop", "-display", D, "-id", w,
                        "-f", "_NET_WM_WINDOW_TYPE", "32a",
                        "-set", "_NET_WM_WINDOW_TYPE", "_NET_WM_WINDOW_TYPE_NORMAL"], timeout=3)
        wm(["-i", "-r", w, "-b", "remove,below"])
        wm(["-i", "-r", w, "-b", "add,skip_taskbar,skip_pager,sticky"])
        fixed += 1

print(f"[fix-icons-layer] 已校正 {fixed} 个窗口" if fixed else "[fix-icons-layer] 无需校正")
PY
}

case "${1:-}" in
    --loop) while :; do apply_once; sleep 2; done ;;
    *)      apply_once ;;
esac
