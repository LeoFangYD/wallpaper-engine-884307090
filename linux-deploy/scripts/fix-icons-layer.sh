#!/usr/bin/env bash
# ==============================================================================
# fix-icons-layer.sh — GNOME 46+ 适配：让「动态壁纸 + 桌面图标 + 应用窗口」三层共存
#
# 背景（为什么需要这个脚本）
#   * GNOME 42（原验证环境）：DING 桌面图标绘制在 GNOME Shell 内部，
#     其层级在 DESKTOP 型 X 窗口之上 → 引擎补丁 0001（GLFW_FLOATING=FALSE）
#     已足够让壁纸位于图标之下。
#   * GNOME 46/47（Ubuntu 24.04）：DING 改为**独立进程窗口**
#     （WM_CLASS=Gjs、_NET_WM_WINDOW_TYPE_DESKTOP），mutter 会把它排在
#     壁纸引擎（同为 DESKTOP 型）之下 → 壁纸盖住图标。
#     客户端无法把引擎压到它之下（mutter 会立即覆盖堆叠请求，实测有效），
#     因此改为**把图标窗口降级**：类型改 NORMAL + below/skip_taskbar，
#     层级变为：  壁纸引擎(DESKTOP, 最底) → 图标窗口(NORMAL,BELOW) → 应用窗口
#
# 用法
#   fix-icons-layer.sh            # 立即修正一次
#   fix-icons-layer.sh --loop     # 常驻守护（2 秒巡检，窗口重建后自动修正）
# ==============================================================================
set -u

DISP="${DISPLAY:-:1}"

apply_once() {
    DISPLAY="$DISP" python3 - <<'PY'
import ctypes, re, subprocess, time

DISP = __import__("os").environ.get("DISPLAY", ":1")

def xp(args):
    try:
        return subprocess.run(["xprop", "-display", DISP] + args,
                              capture_output=True, text=True, timeout=3).stdout
    except Exception:
        return ""

ids = re.findall(r'0x[0-9a-f]+', xp(["-root", "_NET_CLIENT_LIST_STACKING"]))
changed = 0
for w in ids:
    cls = xp(["-id", w, "WM_CLASS"])
    typ = xp(["-id", w, "_NET_WM_WINDOW_TYPE"])
    is_icon_window = ('"Gjs"' in cls or '"ding' in cls.lower())
    if not is_icon_window:
        continue
    if "WINDOW_TYPE_NORMAL" in typ:
        continue
    # 降级为普通窗口 + 压到普通层底部
    subprocess.run(["xprop", "-display", DISP, "-id", w,
                    "-f", "_NET_WM_WINDOW_TYPE", "32a",
                    "-set", "_NET_WM_WINDOW_TYPE", "_NET_WM_WINDOW_TYPE_NORMAL"],
                   timeout=3)
    subprocess.run(["wmctrl", "-i", "-r", w,
                    "-b", "add,below,skip_taskbar,skip_pager,sticky"], timeout=3)
    changed += 1

print(f"[fix-icons-layer] 已降级 {changed} 个图标窗口" if changed
      else "[fix-icons-layer] 图标窗口已处于正确层级")
PY
}

case "${1:-}" in
    --loop)
        while :; do apply_once; sleep 2; done
        ;;
    *)
        apply_once
        ;;
esac
