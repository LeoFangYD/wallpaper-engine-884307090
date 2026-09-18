#!/usr/bin/env bash
# ==============================================================================
# wallpaper-watchdog.sh — 常驻守护：壁纸异常退出时自动重启
#
# 行为：
#   * 等到 X11 与 PulseAudio 就绪后再接管（避免开机抢跑）；
#   * 看到「手动关闭」标记时保持待命，绝不拉起壁纸；
#   * 2 分钟内连续崩溃超过 WPE_MAX_RESTARTS 次则判定崩溃循环，停止自动重启；
#   * 同一登录会话只允许一个实例（flock 保证）。
# ==============================================================================
set -u

# 公共库：安装后在同目录，仓库内直接运行时在 ../lib
_wpe_dir="$(cd "$(dirname "$0")" && pwd -P)"
if [ -r "$_wpe_dir/common.sh" ]; then
    . "$_wpe_dir/common.sh"
else
    . "$_wpe_dir/../lib/common.sh"
fi

START="$WPE_BIN_DIR/start-wallpaper.sh"
mkdir -p "$WPE_RUNTIME_DIR" "$WPE_LOG_DIR" 2>/dev/null || true

# 防止同一登录会话启动多个 watchdog
exec 9>"$WPE_WATCHDOG_LOCK" || wpe_die "无法创建锁文件: $WPE_WATCHDOG_LOCK"
flock -n 9 || exit 0

echo $$ >"$WPE_WATCHDOG_PIDFILE"

wpe_rotate_log "$WPE_WATCHDOG_LOG"

log() { echo "[$(date '+%F %T')] $*" >>"$WPE_WATCHDOG_LOG"; }

log "watchdog 启动 (PID=$$, 配置=$WPE_CONFIG_FILE)"

cleanup() {
    log "watchdog 退出"
    rm -f "$WPE_WATCHDOG_PIDFILE"
}
trap cleanup EXIT INT TERM

# ---------- 等待图形/音频环境就绪 ----------
# X11 是硬需求：一定要等到能读到显示器信息
for _ in $(seq 1 30); do
    xrandr --current >/dev/null 2>&1 && break
    sleep 1
done
xrandr --current >/dev/null 2>&1 || log "等待 X11 超时（30s），仍继续尝试启动"

# 音频是软需求：pactl 不可用（无 PulseAudio/PipeWire、或 ssh 里没有会话总线）
# 只影响声纹可视化，不该拖慢壁纸启动，因此最多等 10 秒就继续
if wpe_have pactl; then
    for _ in $(seq 1 10); do
        pactl info >/dev/null 2>&1 && break
        sleep 1
    done
    pactl info >/dev/null 2>&1 || log "PulseAudio 尚不可用，先启动壁纸（无音频可视化）"
fi

# 给 GNOME Shell / DING（桌面图标扩展）留出初始化时间
sleep 5

restart_count=0
window_start=$(date +%s)

while true; do
    # 1) 用户主动关闭 -> 待命
    if [ -f "$WPE_STOP_FLAG" ]; then
        sleep 3
        continue
    fi

    # 2) 壁纸正常运行
    if wpe_engine_running; then
        now=$(date +%s)
        if [ $((now - window_start)) -ge "$WPE_STABLE_SECONDS" ]; then
            restart_count=0
            window_start=$now
        fi
        sleep 3
        continue
    fi

    # 3) 异常退出 -> 重启（带崩溃循环保护）
    now=$(date +%s)
    if [ $((now - window_start)) -ge "$WPE_STABLE_SECONDS" ]; then
        restart_count=0
        window_start=$now
    fi

    restart_count=$((restart_count + 1))
    log "引擎未在运行（已退出或尚未启动），第 $restart_count 次启动尝试"

    if [ "$restart_count" -gt "$WPE_MAX_RESTARTS" ]; then
        log "检测到崩溃循环，停止自动重启（修复后执行 start-wallpaper.sh 或重新登录）"
        : >"$WPE_STOP_FLAG"
        sleep 30
        continue
    fi

    "$START" >>"$WPE_WATCHDOG_LOG" 2>&1
    sleep "$WPE_RESTART_DELAY"
done
