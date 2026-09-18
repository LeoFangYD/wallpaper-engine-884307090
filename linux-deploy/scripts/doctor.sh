#!/usr/bin/env bash
# ==============================================================================
# doctor.sh — 换机部署后的体检脚本：逐项检查环境是否满足运行条件
# 用法: ./doctor.sh
# 退出码: 0 = 全部通过 / 1 = 有致命问题
# ==============================================================================
set -u

# 公共库：安装后在同目录，仓库内直接运行时在 ../lib
_wpe_dir="$(cd "$(dirname "$0")" && pwd -P)"
if [ -r "$_wpe_dir/common.sh" ]; then
    . "$_wpe_dir/common.sh"
else
    . "$_wpe_dir/../lib/common.sh"
fi

FAIL=0
ok()   { printf '  ✓ %s\n' "$*"; }
bad()  { printf '  ✗ %s\n' "$*"; FAIL=1; }
warn() { printf '  ! %s\n' "$*"; }

echo "== 1. 会话环境 =="
if [ "${XDG_SESSION_TYPE:-}" = "x11" ] || [ -n "${DISPLAY:-}" ]; then
    ok "X11 会话 (DISPLAY=${DISPLAY:-未设置}, type=${XDG_SESSION_TYPE:-未知})"
else
    bad "不是 X11 会话。请使用 GNOME on Xorg 登录"
fi
[ -z "${WAYLAND_DISPLAY:-}" ] && ok "没有 Wayland 会话干扰" || warn "检测到 WAYLAND_DISPLAY=${WAYLAND_DISPLAY}，当前实现按 X11 处理"

echo "== 2. 运行依赖命令 =="
for c in bash xrandr xprop wmctrl python3; do
    if wpe_have "$c"; then ok "$c"; else bad "$c 缺失 -> sudo apt-get install -y wmctrl x11-utils x11-xserver-utils python3"; fi
done
for c in pactl fc-match; do
    if wpe_have "$c"; then ok "$c"; else warn "$c 缺失（音频可视化/字体检查会受影响）"; fi
done

echo "== 3. 引擎与壁纸 =="
if [ -x "$WPE_ENGINE_BIN" ]; then
    ok "引擎可执行: $WPE_ENGINE_BIN"
    [ -f "$(dirname "$WPE_ENGINE_BIN")/libcef.so" ] && ok "CEF 运行时 libcef.so 存在" || bad "缺少 libcef.so（编译未完成？）"
else
    bad "引擎未编译: $WPE_ENGINE_BIN -> 运行 $(wpe_build_script)"
fi
if WP="$(wpe_resolve_wallpaper)"; then
    ok "壁纸目录: $WP"
    [ -f "$WP/project.json" ] && ok "project.json 存在" || bad "缺少 project.json"

    # 素材是否真的下载了（克隆时忘了 git-lfs 会是 130 字节的指针文件，
    # 症状是壁纸能显示但没声音、声纹圈不动）
    if [ -d "$WP/audio" ] || [ -d "$WP/video" ]; then
        LFS_TOTAL=0
        LFS_PTR=0
        while IFS= read -r f; do
            LFS_TOTAL=$((LFS_TOTAL + 1))
            if head -c 80 "$f" 2>/dev/null | grep -q "git-lfs.github.com/spec"; then
                LFS_PTR=$((LFS_PTR + 1))
            fi
        done < <(find "$WP/audio" "$WP/video" -maxdepth 1 -type f \
                     \( -name '*.ogg' -o -name '*.OGG' -o -name '*.webm' \) 2>/dev/null)
        if [ "$LFS_PTR" -gt 0 ]; then
            bad "素材未下载: $LFS_PTR/$LFS_TOTAL 个音视频是 git-lfs 指针文件（壁纸会没声音、声纹圈不动）"
            echo "      修复: sudo apt-get install -y git-lfs && git lfs install && git lfs pull"
        elif [ "$LFS_TOTAL" -gt 0 ]; then
            ok "音视频素材已就位（$LFS_TOTAL 个文件，非 LFS 指针）"
        fi
    fi

    # 壁纸是否是"适配过 Linux"的那一份，而不是原版（原版在 Linux 上排版和声纹都不对）
    if [ -f "$WP/js/time.js" ]; then
        if grep -q "Linux exact group centering" "$WP/js/time.js" 2>/dev/null; then
            ok "壁纸包含 Linux 定制（time.js 居中补丁）"
        else
            warn "壁纸看起来是原版：time.js 里没有 Linux 定制标记，排版可能与预期不同"
        fi
    fi
else
    bad "找不到壁纸目录（含 project.json）"
fi
if [ -d "$WPE_ASSETS_DIR" ]; then
    ok "assets 目录: $WPE_ASSETS_DIR"
else
    warn "assets 目录不存在，将在启动时自动创建: $WPE_ASSETS_DIR"
fi

echo "== 4. 显示器 =="
if GEOM="$(wpe_geometry)"; then
    ok "几何信息: $GEOM (XxYxWxH)"
    echo "    xrandr 输出:"
    xrandr --current | grep -E " connected" | sed 's/^/      /'
else
    bad "无法探测显示器几何（检查 WPE_MONITOR=$WPE_MONITOR）"
fi

echo "== 5. 字体（壁纸排版依赖） =="
for f in "DengXian Light" "DengXian" "Microsoft YaHei Light" "Microsoft YaHei"; do
    m="$(fc-match "$f" 2>/dev/null || true)"
    case "$m" in
        *DengXian*|*等线*|*YaHei*|*雅黑*) ok "fc-match \"$f\" -> $m" ;;
        *) warn "fc-match \"$f\" -> $m （字体缺失时会回退，排版可能移位，见 docs/TROUBLESHOOTING.md）" ;;
    esac
done

echo "== 6. 开机自启动 =="
A="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/linux-wallpaperengine.desktop"
if [ -f "$A" ]; then
    ok "已安装: $A"
    sed -n 's/^Exec=/     Exec=/p' "$A"
else
    warn "未安装 GNOME 自启动 -> install.sh --autostart"
fi
if systemctl --user list-unit-files 2>/dev/null | grep -q '^wallpaper-engine.service'; then
    ok "systemd user 服务已安装"
fi

echo
if [ "$FAIL" = "0" ]; then
    echo "体检结果: 通过（警告项不致命）"
else
    echo "体检结果: 存在致命问题，请按上面 ✗ 提示修复"
fi
exit "$FAIL"
