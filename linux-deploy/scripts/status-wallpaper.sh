#!/usr/bin/env bash
# ==============================================================================
# status-wallpaper.sh — 一眼看清当前部署与运行状态
# ==============================================================================
set -u

. "$(cd "$(dirname "$0")" && pwd -P)/common.sh"

hr() { printf '%s\n' "------------------------------------------------------------"; }

echo "== 配置 =="
echo "配置文件      : $WPE_CONFIG_FILE $([ -r "$WPE_CONFIG_FILE" ] && echo '(已加载)' || echo '(不存在，使用默认值)')"
echo "安装根目录    : $WPE_ROOT"
echo "源码目录      : $WPE_SRC_DIR"
echo "编译产物      : $WPE_BUILD_DIR"
echo "引擎可执行    : $WPE_ENGINE_BIN $([ -x "$WPE_ENGINE_BIN" ] && echo '✓' || echo '✗ 缺失')"
echo "壁纸目录      : $(wpe_resolve_wallpaper 2>/dev/null || echo '✗ 未找到')"
echo "日志目录      : $WPE_LOG_DIR"
echo "显示器配置    : $WPE_MONITOR   FPS: $WPE_FPS"

hr
echo "== 会话 =="
echo "DISPLAY           : ${DISPLAY:-未设置}"
echo "XDG_SESSION_TYPE  : ${XDG_SESSION_TYPE:-未知}"
echo "XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-未知}"
echo "几何 (XxYxWxH)    : $(wpe_geometry 2>/dev/null || echo '探测失败')"

hr
echo "== 运行状态 =="
STATE="$(wpe_state)"
case "$STATE" in
    running)
        echo "状态   : 运行中 (PID=$(wpe_engine_pid))"
        ;;
    manual-stop)
        echo "状态   : 已手动关闭（watchdog 待命中，不会自动拉起）"
        ;;
    *)
        echo "状态   : 未运行"
        ;;
esac
if [ -f "$WPE_WATCHDOG_PIDFILE" ] && kill -0 "$(cat "$WPE_WATCHDOG_PIDFILE" 2>/dev/null || echo 0)" 2>/dev/null; then
    echo "watchdog: 运行中 (PID=$(cat "$WPE_WATCHDOG_PIDFILE"))"
else
    echo "watchdog: 未运行"
fi

hr
echo "== 引擎日志末尾 =="
if [ -f "$WPE_LOG_FILE" ]; then
    tail -n 12 "$WPE_LOG_FILE"
else
    echo "(还没有 $WPE_LOG_FILE)"
fi

hr
echo "== watchdog 日志末尾 =="
if [ -f "$WPE_WATCHDOG_LOG" ]; then
    tail -n 8 "$WPE_WATCHDOG_LOG"
else
    echo "(还没有 $WPE_WATCHDOG_LOG)"
fi
