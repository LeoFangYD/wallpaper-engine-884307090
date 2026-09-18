#!/usr/bin/env bash
# ==============================================================================
# common.sh — wallpaper-engine-linux 部署套件公共库
#
# 被 start-wallpaper.sh / stop-wallpaper.sh / status-wallpaper.sh /
# wallpaper-watchdog.sh 引用。
#
# 设计原则：
#   1. 不含任何硬编码的用户名、家目录、壁纸路径 -> 换一台 Linux 机器可直接用；
#   2. 路径全部来自「配置文件 > 环境变量 > 内置默认」三级覆盖；
#   3. 所有依赖缺失/会话不对的情况都给出明确中文报错，而不是静默失败。
# ==============================================================================

# ---------- 0. 定位自身（bin 目录），供脚本互相调用 ----------
_wpe_self="${BASH_SOURCE[0]}"
WPE_BIN_DIR="$(cd "$(dirname "$_wpe_self")" && pwd -P)"
readonly WPE_BIN_DIR
unset _wpe_self

# ---------- 1. 内置默认值（环境变量可覆盖，配置文件可再覆盖） ----------
# 引擎安装根目录：源码、编译产物、壁纸软链、日志都在这里
: "${WPE_ROOT:=$HOME/.local/share/wallpaper-engine-linux}"
# 壁纸目录；留空则自动在 WPE_WALLPAPER_SEARCH 下查找含 project.json 的目录
: "${WPE_WALLPAPER:=}"
# 注意：WPE_SRC_DIR / WPE_BUILD_DIR / WPE_ASSETS_DIR / WPE_WALLPAPER_SEARCH /
# WPE_LOG_DIR 都是从 WPE_ROOT 派生的，必须在读取配置文件之后再展开默认值，
# 否则配置文件里只写 WPE_ROOT 时，这些路径会落到旧的默认根目录上。

# 渲染参数
: "${WPE_FPS:=60}"
# primary = 主显示器；也可填 xrandr 输出名(如 HDMI-0)，或直接填几何 0x0x2560x1440
: "${WPE_MONITOR:=primary}"
: "${WPE_DISABLE_MOUSE:=1}"
: "${WPE_EXTRA_ARGS:=}"
: "${WPE_GL_THREADED_OPTIMIZATIONS:=0}"

# 行为参数
: "${WPE_STABLE_SECONDS:=120}"   # 连续稳定运行多久后清零崩溃计数
: "${WPE_MAX_RESTARTS:=5}"       # 崩溃循环上限
: "${WPE_RESTART_DELAY:=8}"      # 每次重启前的等待秒数
: "${WPE_STARTUP_TIMEOUT:=12}"   # 等待引擎窗口出现的秒数
: "${WPE_LOG_MAX_BYTES:=5242880}"  # 日志超过 5MB 自动轮转

# ---------- 2. 用户配置文件（优先级最高） ----------
WPE_CONFIG_FILE="${WPE_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/wallpaper-engine-linux/wallpaper.conf}"
if [ -r "$WPE_CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$WPE_CONFIG_FILE"
fi

# ---------- 3. 派生路径（不要在配置文件里手改这些） ----------
# 从 WPE_ROOT 派生的目录默认值：放在配置文件之后展开，才能跟随配置里的 WPE_ROOT
: "${WPE_SRC_DIR:=$WPE_ROOT/src}"
: "${WPE_BUILD_DIR:=$WPE_ROOT/build}"
: "${WPE_ASSETS_DIR:=$WPE_ROOT/empty-assets}"
: "${WPE_WALLPAPER_SEARCH:=$WPE_ROOT/wallpapers}"
: "${WPE_LOG_DIR:=$WPE_ROOT/log}"

WPE_ENGINE_BIN="$WPE_BUILD_DIR/output/linux-wallpaperengine"
WPE_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
WPE_STOP_FLAG="$WPE_RUNTIME_DIR/wallpaper-engine-linux.manual-stop"
WPE_WATCHDOG_LOCK="$WPE_RUNTIME_DIR/wallpaper-engine-linux-watchdog.lock"
WPE_WATCHDOG_PIDFILE="$WPE_RUNTIME_DIR/wallpaper-engine-linux-watchdog.pid"
WPE_LOG_FILE="$WPE_LOG_DIR/engine.log"
WPE_WATCHDOG_LOG="$WPE_LOG_DIR/watchdog.log"

# ---------- 4. 基础工具函数 ----------
wpe_have() { command -v "$1" >/dev/null 2>&1; }

wpe_log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" >&2; }
wpe_warn() { printf '[%s] 警告: %s\n' "$(date '+%F %T')" "$*" >&2; }
wpe_die() { printf '[%s] 错误: %s\n' "$(date '+%F %T')" "$*" >&2; exit 1; }

wpe_prepare() {
    mkdir -p "$WPE_LOG_DIR" "$WPE_ASSETS_DIR" "$WPE_WALLPAPER_SEARCH" 2>/dev/null || true
}

# 日志轮转，避免长期运行把磁盘写满
wpe_rotate_log() {
    local f="$1" max="${2:-$WPE_LOG_MAX_BYTES}" size
    [ -f "$f" ] || return 0
    size=$(stat -c %s "$f" 2>/dev/null || echo 0)
    if [ "$size" -gt "$max" ]; then
        mv -f "$f" "$f.1" 2>/dev/null || true
    fi
}

# ---------- 5. 环境检查 ----------
wpe_require_x11() {
    if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
        wpe_die "当前是纯 Wayland 会话（没有 DISPLAY）。本套件的置底方案依赖 X11，
请改用 'GNOME on Xorg' 会话（登录界面右下角齿轮里选择）后重试。"
    fi
    if [ -z "${DISPLAY:-}" ]; then
        wpe_die "没有 DISPLAY 环境变量，无法连接 X11。请在图形会话的终端里运行。"
    fi
    if ! xrandr --current >/dev/null 2>&1; then
        wpe_die "无法读取显示器信息（xrandr 失败）。请确认 X11 会话正常、x11-xserver-utils 已安装。"
    fi
}

wpe_require_commands() {
    local missing=() c
    for c in "$@"; do
        wpe_have "$c" || missing+=("$c")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        wpe_die "缺少命令: ${missing[*]}
请安装（Ubuntu/Debian）: sudo apt-get install -y wmctrl x11-utils x11-xserver-utils python3"
    fi
}

# ---------- 6. 壁纸与引擎定位 ----------
wpe_resolve_wallpaper() {
    # 1) 配置里明确指定
    if [ -n "$WPE_WALLPAPER" ] && [ -f "$WPE_WALLPAPER/project.json" ]; then
        printf '%s\n' "$WPE_WALLPAPER"; return 0
    fi
    # 2) 在搜索目录下找第一个含 project.json 的目录（兼容 wallpapers 下放多个壁纸）
    local d
    for d in "$WPE_WALLPAPER_SEARCH"/*/; do
        [ -f "${d}project.json" ] && { printf '%s\n' "${d%/}"; return 0; }
    done
    # 3) 兼容旧仓库布局：<repo>/884307090
    local cand
    for cand in \
        "$WPE_BIN_DIR/../../884307090" \
        "$WPE_BIN_DIR/../wallpapers/884307090" \
        "$HOME/linux-wallpaperengine/../../884307090"; do
        [ -f "$cand/project.json" ] && { printf '%s\n' "$(cd "$cand" && pwd -P)"; return 0; }
    done
    return 1
}

wpe_assert_engine() {
    [ -x "$WPE_ENGINE_BIN" ] || wpe_die "找不到可执行文件: $WPE_ENGINE_BIN
说明：编译产物没有部署。请执行本套件的编译脚本：
  $WPE_BIN_DIR/../build/build-engine.sh   （仓库 linux-deploy/build/build-engine.sh）
或先用 --reuse-build <已编译的 build 目录> 复用其它机器/旧目录的编译结果。"
    [ -f "$(dirname "$WPE_ENGINE_BIN")/libcef.so" ] || wpe_warn "同目录下没有 libcef.so，引擎可能启动失败（CEF 运行时缺失）。"
}

# ---------- 7. 显示器几何 ----------
wpe_geometry() {
    local raw="" wh pos x y w h

    if [ -n "${WPE_GEOMETRY:-}" ]; then
        printf '%s\n' "$WPE_GEOMETRY"; return 0
    fi

    case "$WPE_MONITOR" in
        ''|primary)
            raw=$(xrandr --current | awk '
                / connected primary / {
                    for (i = 1; i <= NF; i++)
                        if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) { print $i; exit }
                }')
            # 没有 primary 标记时退化为第一个已连接屏幕
            [ -n "$raw" ] || raw=$(xrandr --current | awk '
                / connected/ {
                    for (i = 1; i <= NF; i++)
                        if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) { print $i; exit }
                }')
            ;;
        [0-9]*x[0-9]*+[0-9]*+[0-9]*)
            raw="$WPE_MONITOR"   # 直接给了几何 WxH+X+Y
            ;;
        *)
            raw=$(xrandr --current | awk -v m="$WPE_MONITOR" '
                $1 == m && / connected/ {
                    for (i = 1; i <= NF; i++)
                        if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) { print $i; exit }
                }')
            ;;
    esac

    [ -n "$raw" ] || return 1

    wh="${raw%%+*}"
    pos="${raw#*+}"
    x="${pos%%+*}"
    y="${pos#*+}"
    w="${wh%x*}"
    h="${wh#*x}"
    printf '%sx%sx%sx%s\n' "$x" "$y" "$w" "$h"
}

# ---------- 8. 运行状态 ----------
wpe_engine_pid() {
    pgrep -f -- "$WPE_ENGINE_BIN" 2>/dev/null | head -n1
}

wpe_engine_running() { [ -n "$(wpe_engine_pid)" ]; }

wpe_state() {
    if wpe_engine_running; then
        echo running
    elif [ -f "$WPE_STOP_FLAG" ]; then
        echo manual-stop
    else
        echo stopped
    fi
}
